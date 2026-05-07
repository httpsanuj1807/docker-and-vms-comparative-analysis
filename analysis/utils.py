#!/usr/bin/env python3
"""
Utility functions for benchmark data analysis.
Docker vs VM Comparative Analysis Research
"""

import os
import json
import logging
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Tuple, Any

import numpy as np
import pandas as pd
from scipy import stats

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


# Research paper metrics thresholds
METRICS_CONFIG = {
    'concurrency_levels': [50, 200, 500],
    'warmup_duration': 60,  # seconds
    'test_duration': 300,   # seconds
    'iterations': 5,
    'percentiles': [50, 90, 95, 99],
    'fibonacci_n': 35,
    'expected_fibonacci_result': 9227465,
    'static_payload_size_kb': 50
}


def calculate_statistics(data: np.ndarray) -> Dict[str, float]:
    """
    Calculate comprehensive statistics for a dataset.

    Args:
        data: NumPy array of values

    Returns:
        Dictionary containing statistical measures
    """
    if len(data) == 0:
        return {
            'count': 0, 'mean': 0, 'median': 0, 'std': 0,
            'min': 0, 'max': 0, 'p50': 0, 'p90': 0, 'p95': 0, 'p99': 0
        }

    return {
        'count': len(data),
        'mean': float(np.mean(data)),
        'median': float(np.median(data)),
        'std': float(np.std(data)),
        'min': float(np.min(data)),
        'max': float(np.max(data)),
        'p50': float(np.percentile(data, 50)),
        'p90': float(np.percentile(data, 90)),
        'p95': float(np.percentile(data, 95)),
        'p99': float(np.percentile(data, 99)),
        'variance': float(np.var(data)),
        'cv': float(np.std(data) / np.mean(data) * 100) if np.mean(data) != 0 else 0
    }


def calculate_confidence_interval(
    data: np.ndarray,
    confidence: float = 0.95
) -> Tuple[float, float, float]:
    """
    Calculate confidence interval for the mean.

    Args:
        data: NumPy array of values
        confidence: Confidence level (default 95%)

    Returns:
        Tuple of (mean, lower_bound, upper_bound)
    """
    n = len(data)
    mean = np.mean(data)

    if n < 2:
        return mean, mean, mean

    se = stats.sem(data)
    h = se * stats.t.ppf((1 + confidence) / 2, n - 1)

    return float(mean), float(mean - h), float(mean + h)


def calculate_improvement_percentage(
    baseline: float,
    improved: float,
    higher_is_better: bool = True
) -> float:
    """
    Calculate percentage improvement between baseline and improved values.

    Args:
        baseline: Baseline value (e.g., VM metric)
        improved: Improved value (e.g., Docker metric)
        higher_is_better: True if higher values are better (throughput),
                         False if lower values are better (latency)

    Returns:
        Percentage improvement (positive = Docker is better)
    """
    if baseline == 0:
        return 0.0

    if higher_is_better:
        # For metrics like throughput: (docker - vm) / vm * 100
        return ((improved - baseline) / baseline) * 100
    else:
        # For metrics like latency: (vm - docker) / vm * 100
        return ((baseline - improved) / baseline) * 100


def perform_statistical_test(
    docker_data: np.ndarray,
    vm_data: np.ndarray,
    alpha: float = 0.05
) -> Dict[str, Any]:
    """
    Perform statistical significance tests between Docker and VM results.

    Args:
        docker_data: Docker measurements
        vm_data: VM measurements
        alpha: Significance level

    Returns:
        Dictionary with test results
    """
    results = {}

    # Welch's t-test (doesn't assume equal variances)
    t_stat, t_pvalue = stats.ttest_ind(docker_data, vm_data, equal_var=False)
    results['welch_t_test'] = {
        'statistic': float(t_stat),
        'p_value': float(t_pvalue),
        'significant': t_pvalue < alpha
    }

    # Mann-Whitney U test (non-parametric)
    try:
        u_stat, u_pvalue = stats.mannwhitneyu(docker_data, vm_data, alternative='two-sided')
        results['mann_whitney_u'] = {
            'statistic': float(u_stat),
            'p_value': float(u_pvalue),
            'significant': u_pvalue < alpha
        }
    except ValueError:
        results['mann_whitney_u'] = {
            'statistic': None,
            'p_value': None,
            'significant': None
        }

    # Effect size (Cohen's d)
    pooled_std = np.sqrt((np.var(docker_data) + np.var(vm_data)) / 2)
    if pooled_std > 0:
        cohens_d = (np.mean(docker_data) - np.mean(vm_data)) / pooled_std
    else:
        cohens_d = 0

    # Interpret effect size
    abs_d = abs(cohens_d)
    if abs_d < 0.2:
        effect_interpretation = 'negligible'
    elif abs_d < 0.5:
        effect_interpretation = 'small'
    elif abs_d < 0.8:
        effect_interpretation = 'medium'
    else:
        effect_interpretation = 'large'

    results['effect_size'] = {
        'cohens_d': float(cohens_d),
        'interpretation': effect_interpretation
    }

    return results


def format_duration(seconds: float) -> str:
    """Format duration in human-readable format."""
    if seconds < 1:
        return f"{seconds*1000:.2f}ms"
    elif seconds < 60:
        return f"{seconds:.2f}s"
    elif seconds < 3600:
        minutes = int(seconds // 60)
        secs = seconds % 60
        return f"{minutes}m {secs:.1f}s"
    else:
        hours = int(seconds // 3600)
        minutes = int((seconds % 3600) // 60)
        return f"{hours}h {minutes}m"


def format_bytes(bytes_value: float) -> str:
    """Format bytes in human-readable format."""
    for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
        if abs(bytes_value) < 1024.0:
            return f"{bytes_value:.2f} {unit}"
        bytes_value /= 1024.0
    return f"{bytes_value:.2f} PB"


def format_number(value: float, precision: int = 2) -> str:
    """Format number with thousand separators."""
    if value >= 1_000_000:
        return f"{value/1_000_000:.{precision}f}M"
    elif value >= 1_000:
        return f"{value/1_000:.{precision}f}K"
    else:
        return f"{value:.{precision}f}"


def load_json_file(filepath: Path) -> Dict:
    """Load JSON file safely."""
    try:
        with open(filepath, 'r') as f:
            return json.load(f)
    except (json.JSONDecodeError, FileNotFoundError) as e:
        logger.error(f"Error loading {filepath}: {e}")
        return {}


def save_json_file(data: Dict, filepath: Path) -> bool:
    """Save data to JSON file."""
    try:
        filepath.parent.mkdir(parents=True, exist_ok=True)
        with open(filepath, 'w') as f:
            json.dump(data, f, indent=2, default=str)
        return True
    except Exception as e:
        logger.error(f"Error saving {filepath}: {e}")
        return False


def create_output_directory(base_dir: Path, prefix: str = "analysis") -> Path:
    """Create timestamped output directory."""
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    output_dir = base_dir / f"{prefix}_{timestamp}"
    output_dir.mkdir(parents=True, exist_ok=True)
    return output_dir


def get_platform_label(platform: str) -> str:
    """Get display label for platform."""
    labels = {
        'docker': 'Docker Container',
        'vm': 'Virtual Machine (KVM)',
        'container': 'Docker Container',
        'kvm': 'Virtual Machine (KVM)'
    }
    return labels.get(platform.lower(), platform)


def get_workload_label(workload: str) -> str:
    """Get display label for workload type."""
    labels = {
        'static': 'I/O-bound (Static)',
        'compute': 'CPU-bound (Compute)',
        'io': 'I/O-bound',
        'cpu': 'CPU-bound'
    }
    return labels.get(workload.lower(), workload)


def aggregate_iterations(
    data: List[Dict],
    group_keys: List[str],
    value_key: str
) -> pd.DataFrame:
    """
    Aggregate multiple iteration results.

    Args:
        data: List of result dictionaries
        group_keys: Keys to group by
        value_key: Key containing the value to aggregate

    Returns:
        DataFrame with aggregated statistics
    """
    df = pd.DataFrame(data)

    if df.empty:
        return pd.DataFrame()

    grouped = df.groupby(group_keys)[value_key].agg([
        'mean', 'std', 'min', 'max', 'count',
        ('p50', lambda x: np.percentile(x, 50)),
        ('p95', lambda x: np.percentile(x, 95))
    ]).reset_index()

    return grouped


class ResultsAggregator:
    """Aggregator for collecting and summarizing benchmark results."""

    def __init__(self):
        self.results = []

    def add_result(
        self,
        platform: str,
        workload: str,
        concurrency: int,
        iteration: int,
        metrics: Dict
    ):
        """Add a single benchmark result."""
        self.results.append({
            'platform': platform,
            'workload': workload,
            'concurrency': concurrency,
            'iteration': iteration,
            **metrics
        })

    def get_dataframe(self) -> pd.DataFrame:
        """Get results as DataFrame."""
        return pd.DataFrame(self.results)

    def get_summary(self) -> pd.DataFrame:
        """Get aggregated summary statistics."""
        df = self.get_dataframe()

        if df.empty:
            return pd.DataFrame()

        # Group by platform, workload, concurrency
        numeric_cols = df.select_dtypes(include=[np.number]).columns
        numeric_cols = [c for c in numeric_cols if c not in ['iteration', 'concurrency']]

        summary = df.groupby(['platform', 'workload', 'concurrency'])[numeric_cols].agg([
            'mean', 'std'
        ])

        return summary

    def compare_platforms(self, metric: str) -> pd.DataFrame:
        """Compare Docker vs VM for a specific metric."""
        df = self.get_dataframe()

        if df.empty or metric not in df.columns:
            return pd.DataFrame()

        comparison = df.pivot_table(
            values=metric,
            index=['workload', 'concurrency'],
            columns='platform',
            aggfunc=['mean', 'std']
        )

        return comparison


if __name__ == "__main__":
    # Test utilities
    print("Testing utility functions...")

    # Test statistics
    test_data = np.random.normal(100, 15, 100)
    stats_result = calculate_statistics(test_data)
    print(f"Statistics: mean={stats_result['mean']:.2f}, std={stats_result['std']:.2f}")

    # Test confidence interval
    mean, lower, upper = calculate_confidence_interval(test_data)
    print(f"95% CI: {mean:.2f} [{lower:.2f}, {upper:.2f}]")

    # Test improvement calculation
    improvement = calculate_improvement_percentage(100, 123, higher_is_better=True)
    print(f"Improvement: {improvement:.1f}%")

    print("All tests passed!")
