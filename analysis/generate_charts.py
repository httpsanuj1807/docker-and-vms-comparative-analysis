#!/usr/bin/env python3
"""
Chart Generation for Docker vs VM Comparative Analysis.
Generates publication-quality figures for the research paper.
"""

import logging
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
import seaborn as sns
from matplotlib.ticker import FuncFormatter

from utils import (
    calculate_improvement_percentage,
    get_platform_label,
    get_workload_label,
    format_number,
    logger
)

# Set publication-quality defaults
plt.rcParams.update({
    'font.family': 'serif',
    'font.size': 10,
    'axes.labelsize': 11,
    'axes.titlesize': 12,
    'xtick.labelsize': 9,
    'ytick.labelsize': 9,
    'legend.fontsize': 9,
    'figure.titlesize': 13,
    'figure.dpi': 150,
    'savefig.dpi': 300,
    'savefig.bbox': 'tight',
    'axes.grid': True,
    'grid.alpha': 0.3,
    'axes.axisbelow': True
})

# Color scheme for Docker vs VM
COLORS = {
    'docker': '#2196F3',      # Blue
    'vm': '#FF9800',          # Orange
    'docker_light': '#90CAF9',
    'vm_light': '#FFE0B2',
    'success': '#4CAF50',
    'error': '#F44336'
}

# Marker styles
MARKERS = {
    'docker': 'o',
    'vm': 's'
}


class ChartGenerator:
    """Generator for benchmark result charts."""

    def __init__(self, output_dir: Path, style: str = 'seaborn-v0_8-whitegrid'):
        """
        Initialize chart generator.

        Args:
            output_dir: Directory to save generated charts
            style: Matplotlib style to use
        """
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(parents=True, exist_ok=True)

        try:
            plt.style.use(style)
        except OSError:
            plt.style.use('seaborn-whitegrid')

    def _save_figure(self, fig: plt.Figure, name: str, formats: List[str] = ['png', 'pdf']):
        """Save figure in multiple formats."""
        for fmt in formats:
            filepath = self.output_dir / f"{name}.{fmt}"
            fig.savefig(filepath, format=fmt, bbox_inches='tight', dpi=300)
            logger.info(f"Saved chart: {filepath}")
        plt.close(fig)

    def plot_throughput_comparison(
        self,
        data: pd.DataFrame,
        workload: str = 'static',
        save_name: str = 'throughput_comparison'
    ) -> plt.Figure:
        """
        Create bar chart comparing throughput between Docker and VM.

        Args:
            data: DataFrame with columns [platform, concurrency, throughput_rps]
            workload: Workload type for title
            save_name: Filename for saved chart

        Returns:
            Matplotlib figure
        """
        fig, ax = plt.subplots(figsize=(10, 6))

        # Filter and prepare data
        df = data[data['workload'] == workload].copy()

        if df.empty:
            logger.warning(f"No data for workload: {workload}")
            return fig

        concurrency_levels = sorted(df['concurrency'].unique())
        x = np.arange(len(concurrency_levels))
        width = 0.35

        # Get means for each platform
        docker_data = df[df['platform'] == 'docker'].groupby('concurrency')['throughput_rps'].mean()
        vm_data = df[df['platform'] == 'vm'].groupby('concurrency')['throughput_rps'].mean()

        # Get standard deviations for error bars
        docker_std = df[df['platform'] == 'docker'].groupby('concurrency')['throughput_rps'].std()
        vm_std = df[df['platform'] == 'vm'].groupby('concurrency')['throughput_rps'].std()

        # Create bars
        bars1 = ax.bar(x - width/2, [docker_data.get(c, 0) for c in concurrency_levels],
                       width, label='Docker', color=COLORS['docker'],
                       yerr=[docker_std.get(c, 0) for c in concurrency_levels],
                       capsize=5, error_kw={'linewidth': 1})

        bars2 = ax.bar(x + width/2, [vm_data.get(c, 0) for c in concurrency_levels],
                       width, label='VM (KVM)', color=COLORS['vm'],
                       yerr=[vm_std.get(c, 0) for c in concurrency_levels],
                       capsize=5, error_kw={'linewidth': 1})

        # Add improvement percentages
        for i, c in enumerate(concurrency_levels):
            docker_val = docker_data.get(c, 0)
            vm_val = vm_data.get(c, 0)
            if vm_val > 0:
                improvement = calculate_improvement_percentage(vm_val, docker_val, higher_is_better=True)
                ax.annotate(f'+{improvement:.1f}%',
                           xy=(i, max(docker_val, vm_val)),
                           xytext=(0, 10),
                           textcoords='offset points',
                           ha='center', va='bottom',
                           fontsize=9, fontweight='bold',
                           color=COLORS['success'] if improvement > 0 else COLORS['error'])

        ax.set_xlabel('Concurrent Users')
        ax.set_ylabel('Throughput (requests/sec)')
        ax.set_title(f'Throughput Comparison - {get_workload_label(workload)} Workload')
        ax.set_xticks(x)
        ax.set_xticklabels(concurrency_levels)
        ax.legend(loc='upper left')
        ax.set_ylim(bottom=0)

        # Add grid
        ax.yaxis.grid(True, linestyle='--', alpha=0.7)
        ax.set_axisbelow(True)

        self._save_figure(fig, f"{save_name}_{workload}")
        return fig

    def plot_response_time_comparison(
        self,
        data: pd.DataFrame,
        workload: str = 'static',
        save_name: str = 'response_time_comparison'
    ) -> plt.Figure:
        """
        Create grouped bar chart for response time percentiles.

        Args:
            data: DataFrame with response time columns
            workload: Workload type
            save_name: Filename for saved chart

        Returns:
            Matplotlib figure
        """
        fig, ax = plt.subplots(figsize=(12, 6))

        df = data[data['workload'] == workload].copy()

        if df.empty:
            return fig

        # Focus on highest concurrency for percentile comparison
        max_concurrency = df['concurrency'].max()
        df = df[df['concurrency'] == max_concurrency]

        percentiles = ['p50', 'p90', 'p95', 'p99']
        x = np.arange(len(percentiles))
        width = 0.35

        docker_vals = []
        vm_vals = []

        for p in percentiles:
            col = f'response_time_{p}_ms'
            if col in df.columns:
                docker_vals.append(df[df['platform'] == 'docker'][col].mean())
                vm_vals.append(df[df['platform'] == 'vm'][col].mean())
            else:
                docker_vals.append(0)
                vm_vals.append(0)

        bars1 = ax.bar(x - width/2, docker_vals, width, label='Docker', color=COLORS['docker'])
        bars2 = ax.bar(x + width/2, vm_vals, width, label='VM (KVM)', color=COLORS['vm'])

        # Add value labels on bars
        for bar, val in zip(bars1, docker_vals):
            if val > 0:
                ax.annotate(f'{val:.0f}',
                           xy=(bar.get_x() + bar.get_width()/2, bar.get_height()),
                           xytext=(0, 3), textcoords='offset points',
                           ha='center', va='bottom', fontsize=8)

        for bar, val in zip(bars2, vm_vals):
            if val > 0:
                ax.annotate(f'{val:.0f}',
                           xy=(bar.get_x() + bar.get_width()/2, bar.get_height()),
                           xytext=(0, 3), textcoords='offset points',
                           ha='center', va='bottom', fontsize=8)

        ax.set_xlabel('Percentile')
        ax.set_ylabel('Response Time (ms)')
        ax.set_title(f'Response Time Percentiles - {get_workload_label(workload)} ({max_concurrency} users)')
        ax.set_xticks(x)
        ax.set_xticklabels(['P50', 'P90', 'P95', 'P99'])
        ax.legend()
        ax.set_ylim(bottom=0)

        self._save_figure(fig, f"{save_name}_{workload}")
        return fig

    def plot_response_time_by_concurrency(
        self,
        data: pd.DataFrame,
        workload: str = 'static',
        save_name: str = 'response_time_scaling'
    ) -> plt.Figure:
        """
        Create line chart showing response time vs concurrency.

        Args:
            data: DataFrame with response time data
            workload: Workload type
            save_name: Filename for saved chart

        Returns:
            Matplotlib figure
        """
        fig, ax = plt.subplots(figsize=(10, 6))

        df = data[data['workload'] == workload].copy()

        if df.empty:
            return fig

        for platform in ['docker', 'vm']:
            pdf = df[df['platform'] == platform]
            grouped = pdf.groupby('concurrency').agg({
                'response_time_mean_ms': ['mean', 'std']
            }).reset_index()

            grouped.columns = ['concurrency', 'mean', 'std']

            ax.errorbar(grouped['concurrency'], grouped['mean'],
                       yerr=grouped['std'],
                       marker=MARKERS[platform],
                       label=get_platform_label(platform),
                       color=COLORS[platform],
                       linewidth=2, markersize=8,
                       capsize=5, capthick=1.5)

        ax.set_xlabel('Concurrent Users')
        ax.set_ylabel('Mean Response Time (ms)')
        ax.set_title(f'Response Time Scaling - {get_workload_label(workload)} Workload')
        ax.legend()
        ax.set_ylim(bottom=0)

        self._save_figure(fig, f"{save_name}_{workload}")
        return fig

    def plot_cpu_utilization(
        self,
        data: pd.DataFrame,
        save_name: str = 'cpu_utilization'
    ) -> plt.Figure:
        """
        Create CPU utilization comparison chart.

        Args:
            data: DataFrame with CPU metrics
            save_name: Filename for saved chart

        Returns:
            Matplotlib figure
        """
        fig, axes = plt.subplots(1, 2, figsize=(14, 5))

        for idx, workload in enumerate(['static', 'compute']):
            ax = axes[idx]
            df = data[data['workload'] == workload]

            if df.empty:
                continue

            concurrency_levels = sorted(df['concurrency'].unique())
            x = np.arange(len(concurrency_levels))
            width = 0.35

            docker_cpu = df[df['platform'] == 'docker'].groupby('concurrency')['cpu_utilization_mean'].mean()
            vm_cpu = df[df['platform'] == 'vm'].groupby('concurrency')['cpu_utilization_mean'].mean()

            ax.bar(x - width/2, [docker_cpu.get(c, 0) for c in concurrency_levels],
                   width, label='Docker', color=COLORS['docker'])
            ax.bar(x + width/2, [vm_cpu.get(c, 0) for c in concurrency_levels],
                   width, label='VM (KVM)', color=COLORS['vm'])

            ax.set_xlabel('Concurrent Users')
            ax.set_ylabel('CPU Utilization (%)')
            ax.set_title(f'{get_workload_label(workload)} Workload')
            ax.set_xticks(x)
            ax.set_xticklabels(concurrency_levels)
            ax.legend()
            ax.set_ylim(0, 100)

        fig.suptitle('CPU Utilization Comparison', fontsize=13, fontweight='bold')
        plt.tight_layout()

        self._save_figure(fig, save_name)
        return fig

    def plot_memory_usage(
        self,
        data: pd.DataFrame,
        save_name: str = 'memory_usage'
    ) -> plt.Figure:
        """
        Create memory usage comparison chart.

        Args:
            data: DataFrame with memory metrics
            save_name: Filename for saved chart

        Returns:
            Matplotlib figure
        """
        fig, ax = plt.subplots(figsize=(10, 6))

        if 'mem_used_mean_mb' not in data.columns:
            logger.warning("Memory metrics not available in data")
            return fig

        # Aggregate by platform
        docker_mem = data[data['platform'] == 'docker']['mem_used_mean_mb'].mean()
        vm_mem = data[data['platform'] == 'vm']['mem_used_mean_mb'].mean()

        platforms = ['Docker', 'VM (KVM)']
        memory = [docker_mem, vm_mem]
        colors = [COLORS['docker'], COLORS['vm']]

        bars = ax.bar(platforms, memory, color=colors, width=0.5)

        # Add value labels
        for bar, val in zip(bars, memory):
            ax.annotate(f'{val:.0f} MB',
                       xy=(bar.get_x() + bar.get_width()/2, bar.get_height()),
                       xytext=(0, 5), textcoords='offset points',
                       ha='center', va='bottom', fontsize=11, fontweight='bold')

        # Add improvement annotation
        if vm_mem > 0:
            improvement = calculate_improvement_percentage(vm_mem, docker_mem, higher_is_better=False)
            ax.annotate(f'{improvement:.1f}% reduction',
                       xy=(0.5, max(memory) * 0.9),
                       ha='center', fontsize=12,
                       color=COLORS['success'] if improvement > 0 else COLORS['error'])

        ax.set_ylabel('Memory Usage (MB)')
        ax.set_title('Average Memory Footprint Comparison')
        ax.set_ylim(0, max(memory) * 1.2)

        self._save_figure(fig, save_name)
        return fig

    def plot_startup_time(
        self,
        docker_times: np.ndarray,
        vm_times: np.ndarray,
        save_name: str = 'startup_time'
    ) -> plt.Figure:
        """
        Create startup time comparison chart.

        Args:
            docker_times: Array of Docker startup times (ms)
            vm_times: Array of VM startup times (ms)
            save_name: Filename for saved chart

        Returns:
            Matplotlib figure
        """
        fig, axes = plt.subplots(1, 2, figsize=(14, 5))

        # Left plot: Bar comparison with log scale
        ax1 = axes[0]

        docker_mean = np.mean(docker_times)
        vm_mean = np.mean(vm_times)
        docker_std = np.std(docker_times)
        vm_std = np.std(vm_times)

        platforms = ['Docker\nContainer', 'Virtual\nMachine']
        means = [docker_mean, vm_mean]
        stds = [docker_std, vm_std]
        colors = [COLORS['docker'], COLORS['vm']]

        bars = ax1.bar(platforms, means, yerr=stds, color=colors, width=0.5,
                       capsize=10, error_kw={'linewidth': 2})

        # Add speedup annotation
        speedup = vm_mean / docker_mean if docker_mean > 0 else 0
        ax1.annotate(f'{speedup:.0f}x faster',
                    xy=(0, docker_mean),
                    xytext=(0.5, vm_mean * 0.5),
                    ha='center', fontsize=14, fontweight='bold',
                    color=COLORS['success'],
                    arrowprops=dict(arrowstyle='->', color=COLORS['success']))

        ax1.set_ylabel('Startup Time (ms)')
        ax1.set_title('Mean Startup Time')
        ax1.set_yscale('log')

        # Right plot: Box plot distribution
        ax2 = axes[1]

        bp = ax2.boxplot([docker_times, vm_times],
                        labels=['Docker', 'VM'],
                        patch_artist=True)

        bp['boxes'][0].set_facecolor(COLORS['docker_light'])
        bp['boxes'][0].set_edgecolor(COLORS['docker'])
        bp['boxes'][1].set_facecolor(COLORS['vm_light'])
        bp['boxes'][1].set_edgecolor(COLORS['vm'])

        for median in bp['medians']:
            median.set_color('black')
            median.set_linewidth(2)

        ax2.set_ylabel('Startup Time (ms)')
        ax2.set_title('Startup Time Distribution')
        ax2.set_yscale('log')

        fig.suptitle('Startup Time Comparison', fontsize=13, fontweight='bold')
        plt.tight_layout()

        self._save_figure(fig, save_name)
        return fig

    def plot_disk_io_comparison(
        self,
        data: pd.DataFrame,
        save_name: str = 'disk_io_comparison'
    ) -> plt.Figure:
        """
        Create disk I/O performance comparison chart.

        Args:
            data: DataFrame with disk I/O metrics
            save_name: Filename for saved chart

        Returns:
            Matplotlib figure
        """
        fig, axes = plt.subplots(1, 2, figsize=(14, 5))

        # Left: IOPS comparison
        ax1 = axes[0]

        if 'read_iops_mean' in data.columns and 'write_iops_mean' in data.columns:
            docker_data = data[data['platform'] == 'docker']
            vm_data = data[data['platform'] == 'vm']

            x = np.arange(2)
            width = 0.35

            docker_vals = [docker_data['read_iops_mean'].mean(),
                          docker_data['write_iops_mean'].mean()]
            vm_vals = [vm_data['read_iops_mean'].mean(),
                      vm_data['write_iops_mean'].mean()]

            ax1.bar(x - width/2, docker_vals, width, label='Docker', color=COLORS['docker'])
            ax1.bar(x + width/2, vm_vals, width, label='VM (KVM)', color=COLORS['vm'])

            ax1.set_xticks(x)
            ax1.set_xticklabels(['Read IOPS', 'Write IOPS'])
            ax1.set_ylabel('IOPS')
            ax1.set_title('I/O Operations Per Second')
            ax1.legend()

        # Right: Latency comparison
        ax2 = axes[1]

        if 'io_await_ms_mean' in data.columns:
            docker_latency = data[data['platform'] == 'docker']['io_await_ms_mean'].mean()
            vm_latency = data[data['platform'] == 'vm']['io_await_ms_mean'].mean()

            platforms = ['Docker', 'VM (KVM)']
            latencies = [docker_latency, vm_latency]

            bars = ax2.bar(platforms, latencies,
                          color=[COLORS['docker'], COLORS['vm']], width=0.5)

            # Add improvement
            if vm_latency > 0:
                improvement = calculate_improvement_percentage(vm_latency, docker_latency, higher_is_better=False)
                ax2.annotate(f'{improvement:.1f}% improvement',
                           xy=(0.5, max(latencies) * 0.8),
                           ha='center', fontsize=11, color=COLORS['success'])

            ax2.set_ylabel('I/O Latency (ms)')
            ax2.set_title('Average I/O Latency')

        fig.suptitle('Disk I/O Performance Comparison', fontsize=13, fontweight='bold')
        plt.tight_layout()

        self._save_figure(fig, save_name)
        return fig

    def plot_network_throughput(
        self,
        data: pd.DataFrame,
        save_name: str = 'network_throughput'
    ) -> plt.Figure:
        """
        Create network throughput comparison chart.

        Args:
            data: DataFrame with network metrics
            save_name: Filename for saved chart

        Returns:
            Matplotlib figure
        """
        fig, ax = plt.subplots(figsize=(10, 6))

        if 'bandwidth_received_kbps' not in data.columns:
            logger.warning("Network metrics not available")
            return fig

        concurrency_levels = sorted(data['concurrency'].unique())
        x = np.arange(len(concurrency_levels))
        width = 0.35

        docker_bw = data[data['platform'] == 'docker'].groupby('concurrency')['bandwidth_received_kbps'].mean() / 1000
        vm_bw = data[data['platform'] == 'vm'].groupby('concurrency')['bandwidth_received_kbps'].mean() / 1000

        ax.bar(x - width/2, [docker_bw.get(c, 0) for c in concurrency_levels],
               width, label='Docker', color=COLORS['docker'])
        ax.bar(x + width/2, [vm_bw.get(c, 0) for c in concurrency_levels],
               width, label='VM (KVM)', color=COLORS['vm'])

        ax.set_xlabel('Concurrent Users')
        ax.set_ylabel('Network Throughput (Mbps)')
        ax.set_title('Network Throughput Comparison')
        ax.set_xticks(x)
        ax.set_xticklabels(concurrency_levels)
        ax.legend()

        self._save_figure(fig, save_name)
        return fig

    def plot_error_rate(
        self,
        data: pd.DataFrame,
        save_name: str = 'error_rate'
    ) -> plt.Figure:
        """
        Create error rate comparison chart.

        Args:
            data: DataFrame with error rate data
            save_name: Filename for saved chart

        Returns:
            Matplotlib figure
        """
        fig, ax = plt.subplots(figsize=(10, 6))

        if 'error_rate' not in data.columns:
            logger.warning("Error rate not available in data")
            return fig

        for platform in ['docker', 'vm']:
            pdf = data[data['platform'] == platform]
            grouped = pdf.groupby('concurrency')['error_rate'].mean()

            ax.plot(grouped.index, grouped.values,
                   marker=MARKERS[platform],
                   label=get_platform_label(platform),
                   color=COLORS[platform],
                   linewidth=2, markersize=8)

        ax.set_xlabel('Concurrent Users')
        ax.set_ylabel('Error Rate (%)')
        ax.set_title('Error Rate Under Load')
        ax.legend()
        ax.set_ylim(bottom=0)

        self._save_figure(fig, save_name)
        return fig

    def plot_summary_heatmap(
        self,
        data: pd.DataFrame,
        save_name: str = 'summary_heatmap'
    ) -> plt.Figure:
        """
        Create summary heatmap showing Docker advantage across metrics.

        Args:
            data: DataFrame with all metrics
            save_name: Filename for saved chart

        Returns:
            Matplotlib figure
        """
        fig, ax = plt.subplots(figsize=(12, 8))

        # Calculate improvements for key metrics
        metrics = {
            'Throughput': ('throughput_rps', True),
            'Response Time': ('response_time_mean_ms', False),
            'CPU Overhead': ('cpu_utilization_mean', False),
            'Memory Usage': ('mem_used_mean_mb', False),
            'I/O Latency': ('io_await_ms_mean', False),
            'Network BW': ('bandwidth_received_kbps', True)
        }

        workloads = ['static', 'compute']
        concurrency_levels = sorted(data['concurrency'].unique())

        # Build improvement matrix
        improvement_data = []

        for metric_name, (col, higher_better) in metrics.items():
            if col not in data.columns:
                continue

            row = []
            for workload in workloads:
                for conc in concurrency_levels:
                    df_filtered = data[(data['workload'] == workload) & (data['concurrency'] == conc)]

                    docker_val = df_filtered[df_filtered['platform'] == 'docker'][col].mean()
                    vm_val = df_filtered[df_filtered['platform'] == 'vm'][col].mean()

                    if vm_val > 0 or docker_val > 0:
                        improvement = calculate_improvement_percentage(vm_val, docker_val, higher_better)
                    else:
                        improvement = 0

                    row.append(improvement)

            if row:
                improvement_data.append(row)

        if not improvement_data:
            logger.warning("No data available for heatmap")
            return fig

        # Create heatmap
        improvement_matrix = np.array(improvement_data)

        # Column labels
        col_labels = [f'{w[:3].upper()}\n{c}u' for w in workloads for c in concurrency_levels]
        row_labels = [m for m in metrics.keys() if metrics[m][0] in data.columns]

        im = ax.imshow(improvement_matrix, cmap='RdYlGn', aspect='auto', vmin=-50, vmax=50)

        ax.set_xticks(np.arange(len(col_labels)))
        ax.set_yticks(np.arange(len(row_labels)))
        ax.set_xticklabels(col_labels)
        ax.set_yticklabels(row_labels)

        # Add colorbar
        cbar = ax.figure.colorbar(im, ax=ax)
        cbar.ax.set_ylabel('Docker Advantage (%)', rotation=-90, va='bottom')

        # Add text annotations
        for i in range(len(row_labels)):
            for j in range(len(col_labels)):
                val = improvement_matrix[i, j]
                color = 'white' if abs(val) > 25 else 'black'
                ax.text(j, i, f'{val:.1f}%', ha='center', va='center', color=color, fontsize=8)

        ax.set_title('Docker vs VM Performance Improvement Summary\n(Positive = Docker Better)')
        plt.tight_layout()

        self._save_figure(fig, save_name)
        return fig

    def generate_all_charts(self, data: pd.DataFrame) -> List[str]:
        """
        Generate all charts from benchmark data.

        Args:
            data: Complete benchmark results DataFrame

        Returns:
            List of generated chart filenames
        """
        generated = []

        # Throughput comparisons
        for workload in ['static', 'compute']:
            self.plot_throughput_comparison(data, workload)
            generated.append(f'throughput_comparison_{workload}')

            self.plot_response_time_comparison(data, workload)
            generated.append(f'response_time_comparison_{workload}')

            self.plot_response_time_by_concurrency(data, workload)
            generated.append(f'response_time_scaling_{workload}')

        # Resource usage
        if 'cpu_utilization_mean' in data.columns:
            self.plot_cpu_utilization(data)
            generated.append('cpu_utilization')

        if 'mem_used_mean_mb' in data.columns:
            self.plot_memory_usage(data)
            generated.append('memory_usage')

        # I/O and network
        if 'read_iops_mean' in data.columns:
            self.plot_disk_io_comparison(data)
            generated.append('disk_io_comparison')

        if 'bandwidth_received_kbps' in data.columns:
            self.plot_network_throughput(data)
            generated.append('network_throughput')

        # Error rate
        if 'error_rate' in data.columns:
            self.plot_error_rate(data)
            generated.append('error_rate')

        # Summary
        self.plot_summary_heatmap(data)
        generated.append('summary_heatmap')

        logger.info(f"Generated {len(generated)} charts")
        return generated


if __name__ == "__main__":
    import sys
    from parse_results import aggregate_benchmark_results

    # Determine results directory
    if len(sys.argv) > 1:
        results_dir = Path(sys.argv[1])
    else:
        results_dir = Path("../benchmarks/results")

    output_dir = Path("./output/charts")

    print(f"Loading results from: {results_dir}")
    print(f"Saving charts to: {output_dir}")

    # Generate charts
    generator = ChartGenerator(output_dir)

    if results_dir.exists():
        data = aggregate_benchmark_results(results_dir)

        if not data.empty:
            generated = generator.generate_all_charts(data)
            print(f"\nGenerated {len(generated)} charts:")
            for name in generated:
                print(f"  - {name}")
        else:
            print("No data to generate charts from")
    else:
        print(f"Results directory not found: {results_dir}")
        print("Using sample data for demonstration...")

        # Generate sample data for testing
        from generate_sample_data import generate_sample_benchmark_data
        data = generate_sample_benchmark_data()
        generated = generator.generate_all_charts(data)
        print(f"\nGenerated {len(generated)} charts with sample data")
