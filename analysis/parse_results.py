#!/usr/bin/env python3
"""
JMeter Results Parser for Docker vs VM Comparative Analysis.
Parses JTL files and system metrics logs into structured DataFrames.
"""

import re
import csv
import logging
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from datetime import datetime

import pandas as pd
import numpy as np

from utils import (
    calculate_statistics,
    calculate_confidence_interval,
    perform_statistical_test,
    logger,
    METRICS_CONFIG
)


class JMeterResultsParser:
    """Parser for JMeter JTL result files."""

    # JTL column names (standard JMeter CSV output)
    JTL_COLUMNS = [
        'timeStamp', 'elapsed', 'label', 'responseCode', 'responseMessage',
        'threadName', 'dataType', 'success', 'failureMessage', 'bytes',
        'sentBytes', 'grpThreads', 'allThreads', 'URL', 'Latency',
        'IdleTime', 'Connect'
    ]

    def __init__(self, results_dir: Path):
        """
        Initialize parser with results directory.

        Args:
            results_dir: Path to directory containing JTL files
        """
        self.results_dir = Path(results_dir)
        self.parsed_data = {}

    def parse_jtl_file(self, filepath: Path) -> pd.DataFrame:
        """
        Parse a single JTL file into a DataFrame.

        Args:
            filepath: Path to JTL file

        Returns:
            DataFrame with parsed results
        """
        try:
            # Try reading with headers first
            df = pd.read_csv(filepath)

            # Check if first row looks like data (timestamp is numeric)
            if df.columns[0] != 'timeStamp':
                # No header row, use predefined columns
                df = pd.read_csv(filepath, names=self.JTL_COLUMNS)

            # Convert success column to boolean
            if 'success' in df.columns:
                df['success'] = df['success'].astype(str).str.lower() == 'true'

            # Convert timestamp to datetime
            if 'timeStamp' in df.columns:
                df['datetime'] = pd.to_datetime(df['timeStamp'], unit='ms')

            # Calculate response time in seconds
            if 'elapsed' in df.columns:
                df['response_time_sec'] = df['elapsed'] / 1000.0

            logger.info(f"Parsed {len(df)} samples from {filepath.name}")
            return df

        except Exception as e:
            logger.error(f"Error parsing {filepath}: {e}")
            return pd.DataFrame()

    def parse_all_jtl_files(self) -> Dict[str, pd.DataFrame]:
        """
        Parse all JTL files in the results directory.

        Returns:
            Dictionary mapping filename to DataFrame
        """
        jtl_files = list(self.results_dir.glob("**/*.jtl"))

        if not jtl_files:
            logger.warning(f"No JTL files found in {self.results_dir}")
            return {}

        for jtl_file in jtl_files:
            key = jtl_file.stem
            self.parsed_data[key] = self.parse_jtl_file(jtl_file)

        return self.parsed_data

    def calculate_throughput_metrics(self, df: pd.DataFrame) -> Dict:
        """
        Calculate throughput metrics from JMeter results.

        Args:
            df: DataFrame with JMeter results

        Returns:
            Dictionary with throughput metrics
        """
        if df.empty:
            return {}

        # Filter warmup period
        warmup_ms = METRICS_CONFIG['warmup_duration'] * 1000
        if 'timeStamp' in df.columns:
            start_time = df['timeStamp'].min()
            df_filtered = df[df['timeStamp'] >= start_time + warmup_ms]
        else:
            df_filtered = df

        if df_filtered.empty:
            df_filtered = df

        # Calculate time range
        if 'timeStamp' in df_filtered.columns:
            duration_sec = (df_filtered['timeStamp'].max() - df_filtered['timeStamp'].min()) / 1000.0
        else:
            duration_sec = METRICS_CONFIG['test_duration']

        if duration_sec == 0:
            duration_sec = 1

        total_requests = len(df_filtered)
        successful_requests = df_filtered['success'].sum() if 'success' in df_filtered.columns else total_requests
        failed_requests = total_requests - successful_requests

        return {
            'total_requests': int(total_requests),
            'successful_requests': int(successful_requests),
            'failed_requests': int(failed_requests),
            'error_rate': float(failed_requests / total_requests * 100) if total_requests > 0 else 0,
            'throughput_rps': float(total_requests / duration_sec),
            'successful_throughput_rps': float(successful_requests / duration_sec),
            'duration_sec': float(duration_sec)
        }

    def calculate_response_time_metrics(self, df: pd.DataFrame) -> Dict:
        """
        Calculate response time metrics from JMeter results.

        Args:
            df: DataFrame with JMeter results

        Returns:
            Dictionary with response time metrics
        """
        if df.empty or 'elapsed' not in df.columns:
            return {}

        # Filter to successful requests only for response time analysis
        if 'success' in df.columns:
            df_success = df[df['success'] == True]
        else:
            df_success = df

        if df_success.empty:
            df_success = df

        response_times = df_success['elapsed'].values

        stats = calculate_statistics(response_times)
        mean, ci_lower, ci_upper = calculate_confidence_interval(response_times)

        return {
            'response_time_mean_ms': stats['mean'],
            'response_time_median_ms': stats['median'],
            'response_time_std_ms': stats['std'],
            'response_time_min_ms': stats['min'],
            'response_time_max_ms': stats['max'],
            'response_time_p50_ms': stats['p50'],
            'response_time_p90_ms': stats['p90'],
            'response_time_p95_ms': stats['p95'],
            'response_time_p99_ms': stats['p99'],
            'response_time_ci_lower_ms': ci_lower,
            'response_time_ci_upper_ms': ci_upper
        }

    def calculate_latency_metrics(self, df: pd.DataFrame) -> Dict:
        """
        Calculate latency metrics (time to first byte).

        Args:
            df: DataFrame with JMeter results

        Returns:
            Dictionary with latency metrics
        """
        if df.empty or 'Latency' not in df.columns:
            return {}

        latencies = df['Latency'].dropna().values

        if len(latencies) == 0:
            return {}

        stats = calculate_statistics(latencies)

        return {
            'latency_mean_ms': stats['mean'],
            'latency_median_ms': stats['median'],
            'latency_p95_ms': stats['p95'],
            'latency_p99_ms': stats['p99']
        }

    def calculate_bandwidth_metrics(self, df: pd.DataFrame) -> Dict:
        """
        Calculate bandwidth metrics from JMeter results.

        Args:
            df: DataFrame with JMeter results

        Returns:
            Dictionary with bandwidth metrics
        """
        if df.empty:
            return {}

        # Calculate duration
        if 'timeStamp' in df.columns:
            duration_sec = (df['timeStamp'].max() - df['timeStamp'].min()) / 1000.0
        else:
            duration_sec = METRICS_CONFIG['test_duration']

        if duration_sec == 0:
            duration_sec = 1

        total_bytes_received = df['bytes'].sum() if 'bytes' in df.columns else 0
        total_bytes_sent = df['sentBytes'].sum() if 'sentBytes' in df.columns else 0

        return {
            'total_bytes_received': int(total_bytes_received),
            'total_bytes_sent': int(total_bytes_sent),
            'bandwidth_received_kbps': float(total_bytes_received * 8 / 1000 / duration_sec),
            'bandwidth_sent_kbps': float(total_bytes_sent * 8 / 1000 / duration_sec),
            'avg_response_size_bytes': float(df['bytes'].mean()) if 'bytes' in df.columns else 0
        }

    def get_complete_metrics(self, df: pd.DataFrame) -> Dict:
        """
        Calculate all metrics for a JMeter result set.

        Args:
            df: DataFrame with JMeter results

        Returns:
            Dictionary with all calculated metrics
        """
        metrics = {}
        metrics.update(self.calculate_throughput_metrics(df))
        metrics.update(self.calculate_response_time_metrics(df))
        metrics.update(self.calculate_latency_metrics(df))
        metrics.update(self.calculate_bandwidth_metrics(df))
        return metrics


class SystemMetricsParser:
    """Parser for system metrics (CPU, memory, disk I/O, network)."""

    def __init__(self, results_dir: Path):
        """
        Initialize parser with results directory.

        Args:
            results_dir: Path to directory containing metric logs
        """
        self.results_dir = Path(results_dir)

    def parse_cpu_memory_log(self, filepath: Path) -> pd.DataFrame:
        """
        Parse SAR-style CPU/memory log file.

        Expected format:
        timestamp,cpu_user,cpu_system,cpu_iowait,cpu_idle,mem_used,mem_free,mem_cached

        Args:
            filepath: Path to CPU/memory log file

        Returns:
            DataFrame with CPU and memory metrics
        """
        try:
            df = pd.read_csv(filepath)
            if 'timestamp' in df.columns:
                df['datetime'] = pd.to_datetime(df['timestamp'])
            return df
        except Exception as e:
            logger.error(f"Error parsing CPU/memory log {filepath}: {e}")
            return pd.DataFrame()

    def parse_disk_io_log(self, filepath: Path) -> pd.DataFrame:
        """
        Parse iostat-style disk I/O log file.

        Expected format:
        timestamp,device,rrqm_s,wrqm_s,r_s,w_s,rkB_s,wkB_s,avgrq_sz,avgqu_sz,await,r_await,w_await,svctm,util

        Args:
            filepath: Path to disk I/O log file

        Returns:
            DataFrame with disk I/O metrics
        """
        try:
            df = pd.read_csv(filepath)
            if 'timestamp' in df.columns:
                df['datetime'] = pd.to_datetime(df['timestamp'])
            return df
        except Exception as e:
            logger.error(f"Error parsing disk I/O log {filepath}: {e}")
            return pd.DataFrame()

    def parse_network_log(self, filepath: Path) -> pd.DataFrame:
        """
        Parse network metrics log file.

        Expected format:
        timestamp,interface,rx_bytes,tx_bytes,rx_packets,tx_packets

        Args:
            filepath: Path to network log file

        Returns:
            DataFrame with network metrics
        """
        try:
            df = pd.read_csv(filepath)
            if 'timestamp' in df.columns:
                df['datetime'] = pd.to_datetime(df['timestamp'])
            return df
        except Exception as e:
            logger.error(f"Error parsing network log {filepath}: {e}")
            return pd.DataFrame()

    def calculate_cpu_metrics(self, df: pd.DataFrame) -> Dict:
        """Calculate aggregated CPU metrics."""
        if df.empty:
            return {}

        metrics = {}

        for col in ['cpu_user', 'cpu_system', 'cpu_iowait', 'cpu_idle']:
            if col in df.columns:
                values = df[col].dropna().values
                if len(values) > 0:
                    stats = calculate_statistics(values)
                    metrics[f'{col}_mean'] = stats['mean']
                    metrics[f'{col}_max'] = stats['max']
                    metrics[f'{col}_std'] = stats['std']

        # Calculate total CPU utilization
        if 'cpu_idle' in df.columns:
            metrics['cpu_utilization_mean'] = 100 - df['cpu_idle'].mean()
            metrics['cpu_utilization_max'] = 100 - df['cpu_idle'].min()

        return metrics

    def calculate_memory_metrics(self, df: pd.DataFrame) -> Dict:
        """Calculate aggregated memory metrics."""
        if df.empty:
            return {}

        metrics = {}

        for col in ['mem_used', 'mem_free', 'mem_cached']:
            if col in df.columns:
                values = df[col].dropna().values
                if len(values) > 0:
                    stats = calculate_statistics(values)
                    metrics[f'{col}_mean_mb'] = stats['mean']
                    metrics[f'{col}_max_mb'] = stats['max']

        return metrics

    def calculate_disk_io_metrics(self, df: pd.DataFrame) -> Dict:
        """Calculate aggregated disk I/O metrics."""
        if df.empty:
            return {}

        metrics = {}

        # Read/Write IOPS
        if 'r_s' in df.columns:
            metrics['read_iops_mean'] = df['r_s'].mean()
            metrics['read_iops_max'] = df['r_s'].max()
        if 'w_s' in df.columns:
            metrics['write_iops_mean'] = df['w_s'].mean()
            metrics['write_iops_max'] = df['w_s'].max()

        # Throughput
        if 'rkB_s' in df.columns:
            metrics['read_throughput_kbps_mean'] = df['rkB_s'].mean()
        if 'wkB_s' in df.columns:
            metrics['write_throughput_kbps_mean'] = df['wkB_s'].mean()

        # Latency
        if 'await' in df.columns:
            metrics['io_await_ms_mean'] = df['await'].mean()
            metrics['io_await_ms_p95'] = df['await'].quantile(0.95)

        # Utilization
        if 'util' in df.columns:
            metrics['disk_util_mean'] = df['util'].mean()
            metrics['disk_util_max'] = df['util'].max()

        return metrics

    def calculate_network_metrics(self, df: pd.DataFrame) -> Dict:
        """Calculate aggregated network metrics."""
        if df.empty:
            return {}

        metrics = {}

        # Calculate rates from cumulative values
        if 'rx_bytes' in df.columns and 'timestamp' in df.columns:
            df_sorted = df.sort_values('timestamp')
            time_diff = df_sorted['timestamp'].diff().dt.total_seconds()

            rx_rate = df_sorted['rx_bytes'].diff() / time_diff / 1024  # KB/s
            tx_rate = df_sorted['tx_bytes'].diff() / time_diff / 1024  # KB/s

            metrics['network_rx_kbps_mean'] = rx_rate.mean() * 8 if not rx_rate.isna().all() else 0
            metrics['network_tx_kbps_mean'] = tx_rate.mean() * 8 if not tx_rate.isna().all() else 0

        # Packet rates
        if 'rx_packets' in df.columns:
            metrics['total_rx_packets'] = df['rx_packets'].max() - df['rx_packets'].min()
        if 'tx_packets' in df.columns:
            metrics['total_tx_packets'] = df['tx_packets'].max() - df['tx_packets'].min()

        return metrics


class StartupTimeParser:
    """Parser for startup time measurements."""

    def __init__(self, results_dir: Path):
        """
        Initialize parser with results directory.

        Args:
            results_dir: Path to directory containing startup time CSVs
        """
        self.results_dir = Path(results_dir)

    def parse_startup_times(self, filepath: Path) -> pd.DataFrame:
        """
        Parse startup time CSV file.

        Expected format:
        iteration,startup_time_ms,platform

        Args:
            filepath: Path to startup time CSV

        Returns:
            DataFrame with startup times
        """
        try:
            df = pd.read_csv(filepath)
            return df
        except Exception as e:
            logger.error(f"Error parsing startup times {filepath}: {e}")
            return pd.DataFrame()

    def calculate_startup_metrics(
        self,
        docker_times: np.ndarray,
        vm_times: np.ndarray
    ) -> Dict:
        """
        Calculate startup time comparison metrics.

        Args:
            docker_times: Array of Docker startup times (ms)
            vm_times: Array of VM startup times (ms)

        Returns:
            Dictionary with startup time metrics
        """
        docker_stats = calculate_statistics(docker_times)
        vm_stats = calculate_statistics(vm_times)

        # Calculate speedup factor
        speedup = vm_stats['mean'] / docker_stats['mean'] if docker_stats['mean'] > 0 else 0

        # Statistical comparison
        stat_test = perform_statistical_test(docker_times, vm_times)

        return {
            'docker_startup_mean_ms': docker_stats['mean'],
            'docker_startup_std_ms': docker_stats['std'],
            'docker_startup_min_ms': docker_stats['min'],
            'docker_startup_max_ms': docker_stats['max'],
            'vm_startup_mean_ms': vm_stats['mean'],
            'vm_startup_std_ms': vm_stats['std'],
            'vm_startup_min_ms': vm_stats['min'],
            'vm_startup_max_ms': vm_stats['max'],
            'startup_speedup_factor': speedup,
            'statistical_test': stat_test
        }


def parse_filename_metadata(filename: str) -> Dict:
    """
    Extract metadata from benchmark result filename.

    Expected patterns:
    - docker_static_50users_run1.jtl
    - vm_compute_200users_run3.jtl

    Args:
        filename: Result filename

    Returns:
        Dictionary with extracted metadata
    """
    metadata = {
        'platform': None,
        'workload': None,
        'concurrency': None,
        'iteration': None
    }

    # Try to match pattern
    pattern = r'(docker|vm)_(static|compute)_(\d+)users?_run(\d+)'
    match = re.match(pattern, filename, re.IGNORECASE)

    if match:
        metadata['platform'] = match.group(1).lower()
        metadata['workload'] = match.group(2).lower()
        metadata['concurrency'] = int(match.group(3))
        metadata['iteration'] = int(match.group(4))

    return metadata


def aggregate_benchmark_results(results_dir: Path) -> pd.DataFrame:
    """
    Aggregate all benchmark results from a directory into a single DataFrame.

    Args:
        results_dir: Path to results directory

    Returns:
        DataFrame with all aggregated results
    """
    parser = JMeterResultsParser(results_dir)
    all_results = []

    jtl_files = list(results_dir.glob("**/*.jtl"))

    for jtl_file in jtl_files:
        # Parse filename for metadata
        metadata = parse_filename_metadata(jtl_file.stem)

        if metadata['platform'] is None:
            logger.warning(f"Could not parse metadata from {jtl_file.name}, skipping")
            continue

        # Parse JTL file
        df = parser.parse_jtl_file(jtl_file)

        if df.empty:
            continue

        # Calculate metrics
        metrics = parser.get_complete_metrics(df)

        # Combine metadata and metrics
        result = {**metadata, **metrics, 'source_file': jtl_file.name}
        all_results.append(result)

    return pd.DataFrame(all_results)


if __name__ == "__main__":
    import sys

    if len(sys.argv) > 1:
        results_dir = Path(sys.argv[1])
    else:
        results_dir = Path("../benchmarks/results")

    print(f"Parsing results from: {results_dir}")

    if results_dir.exists():
        df = aggregate_benchmark_results(results_dir)
        print(f"\nParsed {len(df)} result files")

        if not df.empty:
            print("\nSample results:")
            print(df.head())
    else:
        print(f"Results directory not found: {results_dir}")
        print("Run benchmarks first or provide a valid results directory")
