#!/usr/bin/env python3
"""
Sample Data Generator for Docker vs VM Comparative Analysis.
Generates realistic benchmark data based on research paper findings.
"""

import csv
import random
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Tuple

import numpy as np
import pandas as pd

# Research paper baseline metrics
# Docker shows advantages across all metrics
BASELINE_METRICS = {
    'throughput': {
        'static': {
            'docker': {'50': 4850, '200': 4720, '500': 4380},
            'vm': {'50': 4250, '200': 3980, '500': 3520}
        },
        'compute': {
            'docker': {'50': 285, '200': 275, '500': 258},
            'vm': {'50': 248, '200': 235, '500': 218}
        }
    },
    'response_time': {  # in ms
        'static': {
            'docker': {'50': 10.3, '200': 42.4, '500': 114.2},
            'vm': {'50': 11.8, '200': 50.3, '500': 142.0}
        },
        'compute': {
            'docker': {'50': 175.4, '200': 727.3, '500': 1938.5},
            'vm': {'50': 201.6, '200': 851.1, '500': 2293.6}
        }
    },
    'cpu_utilization': {  # percentage
        'static': {
            'docker': {'50': 35, '200': 58, '500': 78},
            'vm': {'50': 42, '200': 68, '500': 92}
        },
        'compute': {
            'docker': {'50': 82, '200': 94, '500': 98},
            'vm': {'50': 88, '200': 97, '500': 99}
        }
    },
    'memory_usage': {  # in MB
        'docker': 512,  # Base container + app
        'vm': 850  # Guest OS + app
    },
    'startup_time': {  # in ms
        'docker': 245,
        'vm': 30150
    },
    'io_latency': {  # in ms
        'docker': 0.42,
        'vm': 0.68
    }
}


def add_noise(value: float, noise_pct: float = 5.0) -> float:
    """Add random noise to a value."""
    noise = value * (noise_pct / 100) * (random.random() * 2 - 1)
    return max(0, value + noise)


def generate_jmeter_samples(
    platform: str,
    workload: str,
    concurrency: int,
    duration_sec: int = 300,
    warmup_sec: int = 60
) -> pd.DataFrame:
    """
    Generate synthetic JMeter sample data.

    Args:
        platform: 'docker' or 'vm'
        workload: 'static' or 'compute'
        concurrency: Number of concurrent users
        duration_sec: Test duration in seconds
        warmup_sec: Warmup period in seconds

    Returns:
        DataFrame with JMeter-style sample data
    """
    conc_str = str(concurrency)

    # Get baseline metrics
    base_throughput = BASELINE_METRICS['throughput'][workload][platform][conc_str]
    base_response_time = BASELINE_METRICS['response_time'][workload][platform][conc_str]

    # Calculate number of samples based on throughput
    total_samples = int(base_throughput * duration_sec)

    # Generate timestamps
    start_time = datetime.now() - timedelta(seconds=duration_sec)
    timestamps = []
    current_time = start_time

    for _ in range(total_samples):
        interval = 1.0 / base_throughput  # Average time between requests
        current_time += timedelta(seconds=add_noise(interval, 20))
        timestamps.append(int(current_time.timestamp() * 1000))

    # Generate response times with realistic distribution
    # Use log-normal distribution for response times
    response_times = np.random.lognormal(
        mean=np.log(base_response_time),
        sigma=0.3,
        size=total_samples
    )

    # Generate success/failure (very low error rate)
    error_rate = 0.001 if platform == 'docker' else 0.002
    successes = np.random.random(total_samples) > error_rate

    # Generate byte sizes
    if workload == 'static':
        # ~50KB payload
        bytes_received = np.random.normal(51200, 100, total_samples).astype(int)
    else:
        # Smaller compute response
        bytes_received = np.random.normal(256, 20, total_samples).astype(int)

    bytes_sent = np.random.normal(150, 10, total_samples).astype(int)

    # Generate latency (time to first byte)
    latencies = response_times * np.random.uniform(0.1, 0.3, total_samples)

    # Create DataFrame
    df = pd.DataFrame({
        'timeStamp': timestamps,
        'elapsed': response_times.astype(int),
        'label': f'GET /api/{workload}',
        'responseCode': np.where(successes, 200, 500),
        'responseMessage': np.where(successes, 'OK', 'Internal Server Error'),
        'threadName': [f'Thread Group 1-{i % concurrency + 1}' for i in range(total_samples)],
        'dataType': 'text',
        'success': successes,
        'failureMessage': '',
        'bytes': bytes_received,
        'sentBytes': bytes_sent,
        'grpThreads': concurrency,
        'allThreads': concurrency,
        'URL': f'http://localhost:3000/api/{workload}',
        'Latency': latencies.astype(int),
        'IdleTime': 0,
        'Connect': np.random.randint(1, 5, total_samples)
    })

    return df


def generate_sample_benchmark_data(
    iterations: int = 5,
    concurrency_levels: List[int] = [50, 200, 500],
    workloads: List[str] = ['static', 'compute']
) -> pd.DataFrame:
    """
    Generate complete sample benchmark dataset.

    Args:
        iterations: Number of test iterations per configuration
        concurrency_levels: List of concurrency levels to generate
        workloads: List of workload types

    Returns:
        Aggregated benchmark results DataFrame
    """
    results = []

    for platform in ['docker', 'vm']:
        for workload in workloads:
            for concurrency in concurrency_levels:
                for iteration in range(1, iterations + 1):
                    conc_str = str(concurrency)

                    # Get baseline values
                    base_throughput = BASELINE_METRICS['throughput'][workload][platform][conc_str]
                    base_rt = BASELINE_METRICS['response_time'][workload][platform][conc_str]
                    base_cpu = BASELINE_METRICS['cpu_utilization'][workload][platform][conc_str]

                    # Add iteration variance
                    throughput = add_noise(base_throughput, 3)
                    rt_mean = add_noise(base_rt, 5)

                    # Generate percentiles (based on typical distribution)
                    rt_p50 = rt_mean * 0.85
                    rt_p90 = rt_mean * 1.8
                    rt_p95 = rt_mean * 2.5
                    rt_p99 = rt_mean * 4.0

                    # Resource metrics
                    cpu_util = add_noise(base_cpu, 5)
                    mem_usage = add_noise(BASELINE_METRICS['memory_usage'][platform], 3)
                    io_latency = add_noise(BASELINE_METRICS['io_latency'][platform], 10)

                    # Error rate
                    error_rate = add_noise(0.1 if platform == 'docker' else 0.2, 50)

                    results.append({
                        'platform': platform,
                        'workload': workload,
                        'concurrency': concurrency,
                        'iteration': iteration,
                        'throughput_rps': throughput,
                        'response_time_mean_ms': rt_mean,
                        'response_time_p50_ms': add_noise(rt_p50, 3),
                        'response_time_p90_ms': add_noise(rt_p90, 3),
                        'response_time_p95_ms': add_noise(rt_p95, 3),
                        'response_time_p99_ms': add_noise(rt_p99, 3),
                        'error_rate': max(0, error_rate),
                        'cpu_utilization_mean': min(100, cpu_util),
                        'mem_used_mean_mb': mem_usage,
                        'io_await_ms_mean': io_latency,
                        'bandwidth_received_kbps': throughput * 50 * 8 if workload == 'static' else throughput * 0.25 * 8,
                        'total_requests': int(throughput * 300),
                        'successful_requests': int(throughput * 300 * (1 - error_rate / 100)),
                        'failed_requests': int(throughput * 300 * error_rate / 100)
                    })

    return pd.DataFrame(results)


def generate_startup_time_data(iterations: int = 30) -> pd.DataFrame:
    """
    Generate startup time measurement data.

    Args:
        iterations: Number of startup measurements

    Returns:
        DataFrame with startup times
    """
    results = []

    for i in range(1, iterations + 1):
        # Docker startup (fast, low variance)
        docker_time = add_noise(BASELINE_METRICS['startup_time']['docker'], 5)

        # VM startup (slow, higher variance)
        vm_time = add_noise(BASELINE_METRICS['startup_time']['vm'], 3)

        results.append({
            'iteration': i,
            'platform': 'docker',
            'startup_time_ms': docker_time
        })

        results.append({
            'iteration': i,
            'platform': 'vm',
            'startup_time_ms': vm_time
        })

    return pd.DataFrame(results)


def generate_system_metrics_log(
    platform: str,
    workload: str,
    concurrency: int,
    duration_sec: int = 300,
    interval_sec: int = 1
) -> Tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    """
    Generate system metrics time series data.

    Args:
        platform: 'docker' or 'vm'
        workload: 'static' or 'compute'
        concurrency: Number of concurrent users
        duration_sec: Test duration
        interval_sec: Sampling interval

    Returns:
        Tuple of (cpu_memory_df, disk_io_df, network_df)
    """
    conc_str = str(concurrency)
    n_samples = duration_sec // interval_sec

    start_time = datetime.now() - timedelta(seconds=duration_sec)
    timestamps = [start_time + timedelta(seconds=i * interval_sec) for i in range(n_samples)]

    # CPU/Memory metrics
    base_cpu = BASELINE_METRICS['cpu_utilization'][workload][platform][conc_str]
    base_mem = BASELINE_METRICS['memory_usage'][platform]

    cpu_user = [add_noise(base_cpu * 0.7, 10) for _ in range(n_samples)]
    cpu_system = [add_noise(base_cpu * 0.2, 15) for _ in range(n_samples)]
    cpu_iowait = [add_noise(base_cpu * 0.1, 20) for _ in range(n_samples)]
    cpu_idle = [max(0, 100 - u - s - w) for u, s, w in zip(cpu_user, cpu_system, cpu_iowait)]

    cpu_memory_df = pd.DataFrame({
        'timestamp': timestamps,
        'cpu_user': cpu_user,
        'cpu_system': cpu_system,
        'cpu_iowait': cpu_iowait,
        'cpu_idle': cpu_idle,
        'mem_used': [add_noise(base_mem, 2) for _ in range(n_samples)],
        'mem_free': [add_noise(8192 - base_mem, 2) for _ in range(n_samples)],
        'mem_cached': [add_noise(1024, 5) for _ in range(n_samples)]
    })

    # Disk I/O metrics
    base_io = BASELINE_METRICS['io_latency'][platform]
    base_iops = 5000 if workload == 'static' else 1000

    disk_io_df = pd.DataFrame({
        'timestamp': timestamps,
        'device': 'nvme0n1',
        'r_s': [add_noise(base_iops * 0.3, 20) for _ in range(n_samples)],
        'w_s': [add_noise(base_iops * 0.7, 20) for _ in range(n_samples)],
        'rkB_s': [add_noise(base_iops * 4 * 0.3, 20) for _ in range(n_samples)],
        'wkB_s': [add_noise(base_iops * 4 * 0.7, 20) for _ in range(n_samples)],
        'await': [add_noise(base_io, 15) for _ in range(n_samples)],
        'util': [add_noise(30 if platform == 'docker' else 45, 20) for _ in range(n_samples)]
    })

    # Network metrics
    base_throughput = BASELINE_METRICS['throughput'][workload][platform][conc_str]
    bytes_per_request = 51200 if workload == 'static' else 256

    rx_bytes = [0]
    tx_bytes = [0]

    for i in range(1, n_samples):
        rx_bytes.append(rx_bytes[-1] + int(add_noise(base_throughput * bytes_per_request, 10)))
        tx_bytes.append(tx_bytes[-1] + int(add_noise(base_throughput * 150, 10)))

    network_df = pd.DataFrame({
        'timestamp': timestamps,
        'interface': 'eth0',
        'rx_bytes': rx_bytes,
        'tx_bytes': tx_bytes,
        'rx_packets': [int(b / 1500) for b in rx_bytes],
        'tx_packets': [int(b / 150) for b in tx_bytes]
    })

    return cpu_memory_df, disk_io_df, network_df


def save_sample_data(output_dir: Path):
    """
    Save complete sample dataset to directory.

    Args:
        output_dir: Directory to save sample data
    """
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    print(f"Generating sample data in: {output_dir}")

    # Generate and save JTL files
    for platform in ['docker', 'vm']:
        for workload in ['static', 'compute']:
            for concurrency in [50, 200, 500]:
                for iteration in range(1, 6):
                    filename = f"{platform}_{workload}_{concurrency}users_run{iteration}.jtl"
                    filepath = output_dir / filename

                    df = generate_jmeter_samples(platform, workload, concurrency)
                    df.to_csv(filepath, index=False)
                    print(f"  Created: {filename}")

    # Generate and save startup time data
    startup_df = generate_startup_time_data()
    startup_df.to_csv(output_dir / "startup_times.csv", index=False)
    print("  Created: startup_times.csv")

    # Generate and save system metrics for one configuration (sample)
    for platform in ['docker', 'vm']:
        cpu_mem, disk_io, network = generate_system_metrics_log(
            platform, 'static', 200
        )
        cpu_mem.to_csv(output_dir / f"{platform}_cpu_memory.csv", index=False)
        disk_io.to_csv(output_dir / f"{platform}_disk_io.csv", index=False)
        network.to_csv(output_dir / f"{platform}_network.csv", index=False)
        print(f"  Created: {platform}_*.csv metrics files")

    print(f"\nSample data generation complete!")
    print(f"Total files: {len(list(output_dir.glob('*')))}")


if __name__ == "__main__":
    import sys

    if len(sys.argv) > 1:
        output_dir = Path(sys.argv[1])
    else:
        output_dir = Path("./sample_results")

    save_sample_data(output_dir)

    # Also generate aggregated data for quick testing
    print("\nGenerating aggregated benchmark data...")
    df = generate_sample_benchmark_data()
    df.to_csv(output_dir / "aggregated_results.csv", index=False)
    print(f"Saved aggregated results: {len(df)} records")

    # Print sample statistics
    print("\nSample Statistics:")
    print("-" * 50)

    for platform in ['docker', 'vm']:
        print(f"\n{platform.upper()}:")
        pdf = df[df['platform'] == platform]
        print(f"  Avg Throughput (static): {pdf[pdf['workload']=='static']['throughput_rps'].mean():.1f} req/s")
        print(f"  Avg Response Time (static): {pdf[pdf['workload']=='static']['response_time_mean_ms'].mean():.1f} ms")
        print(f"  Avg CPU Utilization: {pdf['cpu_utilization_mean'].mean():.1f}%")
        print(f"  Avg Memory Usage: {pdf['mem_used_mean_mb'].mean():.0f} MB")
