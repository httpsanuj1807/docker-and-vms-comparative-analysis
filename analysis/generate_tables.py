#!/usr/bin/env python3
"""
Table Generation for Docker vs VM Comparative Analysis.
Generates LaTeX and Markdown tables for the research paper.
"""

import logging
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import numpy as np
import pandas as pd
from tabulate import tabulate

from utils import (
    calculate_statistics,
    calculate_improvement_percentage,
    calculate_confidence_interval,
    perform_statistical_test,
    format_number,
    format_duration,
    get_platform_label,
    get_workload_label,
    logger
)


class TableGenerator:
    """Generator for benchmark result tables."""

    def __init__(self, output_dir: Path):
        """
        Initialize table generator.

        Args:
            output_dir: Directory to save generated tables
        """
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(parents=True, exist_ok=True)

    def _save_table(self, content: str, name: str, format: str = 'tex'):
        """Save table to file."""
        filepath = self.output_dir / f"{name}.{format}"
        with open(filepath, 'w') as f:
            f.write(content)
        logger.info(f"Saved table: {filepath}")

    def generate_throughput_table(
        self,
        data: pd.DataFrame,
        save_name: str = 'throughput_comparison'
    ) -> Tuple[str, str]:
        """
        Generate throughput comparison table.

        Args:
            data: DataFrame with benchmark results
            save_name: Filename for saved table

        Returns:
            Tuple of (LaTeX table, Markdown table)
        """
        # Aggregate data
        rows = []

        for workload in ['static', 'compute']:
            for concurrency in sorted(data['concurrency'].unique()):
                df = data[(data['workload'] == workload) & (data['concurrency'] == concurrency)]

                docker_df = df[df['platform'] == 'docker']
                vm_df = df[df['platform'] == 'vm']

                docker_mean = docker_df['throughput_rps'].mean()
                docker_std = docker_df['throughput_rps'].std()
                vm_mean = vm_df['throughput_rps'].mean()
                vm_std = vm_df['throughput_rps'].std()

                improvement = calculate_improvement_percentage(vm_mean, docker_mean, higher_is_better=True)

                rows.append({
                    'Workload': get_workload_label(workload),
                    'Users': concurrency,
                    'Docker (req/s)': f'{docker_mean:.1f} ± {docker_std:.1f}',
                    'VM (req/s)': f'{vm_mean:.1f} ± {vm_std:.1f}',
                    'Improvement': f'+{improvement:.1f}%' if improvement > 0 else f'{improvement:.1f}%'
                })

        df_table = pd.DataFrame(rows)

        # Generate LaTeX
        latex = self._dataframe_to_latex(
            df_table,
            caption='Throughput Comparison: Docker vs Virtual Machine',
            label='tab:throughput'
        )

        # Generate Markdown
        markdown = tabulate(df_table, headers='keys', tablefmt='github', showindex=False)

        self._save_table(latex, save_name, 'tex')
        self._save_table(markdown, save_name, 'md')

        return latex, markdown

    def generate_response_time_table(
        self,
        data: pd.DataFrame,
        save_name: str = 'response_time_comparison'
    ) -> Tuple[str, str]:
        """
        Generate response time comparison table with percentiles.

        Args:
            data: DataFrame with benchmark results
            save_name: Filename for saved table

        Returns:
            Tuple of (LaTeX table, Markdown table)
        """
        rows = []

        for workload in ['static', 'compute']:
            for concurrency in sorted(data['concurrency'].unique()):
                df = data[(data['workload'] == workload) & (data['concurrency'] == concurrency)]

                for platform in ['docker', 'vm']:
                    pdf = df[df['platform'] == platform]

                    if pdf.empty:
                        continue

                    rows.append({
                        'Workload': get_workload_label(workload),
                        'Users': concurrency,
                        'Platform': 'Docker' if platform == 'docker' else 'VM',
                        'Mean (ms)': f'{pdf["response_time_mean_ms"].mean():.1f}',
                        'P50 (ms)': f'{pdf["response_time_p50_ms"].mean():.1f}',
                        'P90 (ms)': f'{pdf["response_time_p90_ms"].mean():.1f}',
                        'P95 (ms)': f'{pdf["response_time_p95_ms"].mean():.1f}',
                        'P99 (ms)': f'{pdf["response_time_p99_ms"].mean():.1f}'
                    })

        df_table = pd.DataFrame(rows)

        latex = self._dataframe_to_latex(
            df_table,
            caption='Response Time Percentiles: Docker vs Virtual Machine',
            label='tab:response_time'
        )

        markdown = tabulate(df_table, headers='keys', tablefmt='github', showindex=False)

        self._save_table(latex, save_name, 'tex')
        self._save_table(markdown, save_name, 'md')

        return latex, markdown

    def generate_resource_utilization_table(
        self,
        data: pd.DataFrame,
        save_name: str = 'resource_utilization'
    ) -> Tuple[str, str]:
        """
        Generate resource utilization comparison table.

        Args:
            data: DataFrame with resource metrics
            save_name: Filename for saved table

        Returns:
            Tuple of (LaTeX table, Markdown table)
        """
        rows = []

        for workload in ['static', 'compute']:
            df = data[data['workload'] == workload]

            docker_df = df[df['platform'] == 'docker']
            vm_df = df[df['platform'] == 'vm']

            # CPU
            if 'cpu_utilization_mean' in df.columns:
                docker_cpu = docker_df['cpu_utilization_mean'].mean()
                vm_cpu = vm_df['cpu_utilization_mean'].mean()
                cpu_improvement = calculate_improvement_percentage(vm_cpu, docker_cpu, higher_is_better=False)

                rows.append({
                    'Workload': get_workload_label(workload),
                    'Metric': 'CPU Utilization (%)',
                    'Docker': f'{docker_cpu:.1f}',
                    'VM': f'{vm_cpu:.1f}',
                    'Difference': f'{cpu_improvement:+.1f}%'
                })

            # Memory
            if 'mem_used_mean_mb' in df.columns:
                docker_mem = docker_df['mem_used_mean_mb'].mean()
                vm_mem = vm_df['mem_used_mean_mb'].mean()
                mem_improvement = calculate_improvement_percentage(vm_mem, docker_mem, higher_is_better=False)

                rows.append({
                    'Workload': get_workload_label(workload),
                    'Metric': 'Memory Usage (MB)',
                    'Docker': f'{docker_mem:.0f}',
                    'VM': f'{vm_mem:.0f}',
                    'Difference': f'{mem_improvement:+.1f}%'
                })

            # Disk I/O
            if 'io_await_ms_mean' in df.columns:
                docker_io = docker_df['io_await_ms_mean'].mean()
                vm_io = vm_df['io_await_ms_mean'].mean()
                io_improvement = calculate_improvement_percentage(vm_io, docker_io, higher_is_better=False)

                rows.append({
                    'Workload': get_workload_label(workload),
                    'Metric': 'I/O Latency (ms)',
                    'Docker': f'{docker_io:.2f}',
                    'VM': f'{vm_io:.2f}',
                    'Difference': f'{io_improvement:+.1f}%'
                })

        df_table = pd.DataFrame(rows)

        latex = self._dataframe_to_latex(
            df_table,
            caption='Resource Utilization Comparison',
            label='tab:resource_utilization'
        )

        markdown = tabulate(df_table, headers='keys', tablefmt='github', showindex=False)

        self._save_table(latex, save_name, 'tex')
        self._save_table(markdown, save_name, 'md')

        return latex, markdown

    def generate_startup_time_table(
        self,
        docker_times: np.ndarray,
        vm_times: np.ndarray,
        save_name: str = 'startup_time'
    ) -> Tuple[str, str]:
        """
        Generate startup time comparison table.

        Args:
            docker_times: Array of Docker startup times (ms)
            vm_times: Array of VM startup times (ms)
            save_name: Filename for saved table

        Returns:
            Tuple of (LaTeX table, Markdown table)
        """
        docker_stats = calculate_statistics(docker_times)
        vm_stats = calculate_statistics(vm_times)

        speedup = vm_stats['mean'] / docker_stats['mean'] if docker_stats['mean'] > 0 else 0

        rows = [
            {
                'Metric': 'Mean',
                'Docker (ms)': f'{docker_stats["mean"]:.1f}',
                'VM (ms)': f'{vm_stats["mean"]:.1f}',
                'Speedup': f'{speedup:.1f}x'
            },
            {
                'Metric': 'Std Dev',
                'Docker (ms)': f'{docker_stats["std"]:.1f}',
                'VM (ms)': f'{vm_stats["std"]:.1f}',
                'Speedup': '-'
            },
            {
                'Metric': 'Min',
                'Docker (ms)': f'{docker_stats["min"]:.1f}',
                'VM (ms)': f'{vm_stats["min"]:.1f}',
                'Speedup': f'{vm_stats["min"]/docker_stats["min"]:.1f}x' if docker_stats["min"] > 0 else '-'
            },
            {
                'Metric': 'Max',
                'Docker (ms)': f'{docker_stats["max"]:.1f}',
                'VM (ms)': f'{vm_stats["max"]:.1f}',
                'Speedup': f'{vm_stats["max"]/docker_stats["max"]:.1f}x' if docker_stats["max"] > 0 else '-'
            },
            {
                'Metric': 'P95',
                'Docker (ms)': f'{docker_stats["p95"]:.1f}',
                'VM (ms)': f'{vm_stats["p95"]:.1f}',
                'Speedup': f'{vm_stats["p95"]/docker_stats["p95"]:.1f}x' if docker_stats["p95"] > 0 else '-'
            }
        ]

        df_table = pd.DataFrame(rows)

        latex = self._dataframe_to_latex(
            df_table,
            caption='Startup Time Comparison: Docker Container vs Virtual Machine',
            label='tab:startup_time'
        )

        markdown = tabulate(df_table, headers='keys', tablefmt='github', showindex=False)

        self._save_table(latex, save_name, 'tex')
        self._save_table(markdown, save_name, 'md')

        return latex, markdown

    def generate_statistical_significance_table(
        self,
        data: pd.DataFrame,
        metric: str = 'throughput_rps',
        save_name: str = 'statistical_significance'
    ) -> Tuple[str, str]:
        """
        Generate statistical significance table for a metric.

        Args:
            data: DataFrame with benchmark results
            metric: Metric column to analyze
            save_name: Filename for saved table

        Returns:
            Tuple of (LaTeX table, Markdown table)
        """
        rows = []

        for workload in ['static', 'compute']:
            for concurrency in sorted(data['concurrency'].unique()):
                df = data[(data['workload'] == workload) & (data['concurrency'] == concurrency)]

                docker_vals = df[df['platform'] == 'docker'][metric].values
                vm_vals = df[df['platform'] == 'vm'][metric].values

                if len(docker_vals) < 2 or len(vm_vals) < 2:
                    continue

                stats = perform_statistical_test(docker_vals, vm_vals)

                rows.append({
                    'Workload': get_workload_label(workload),
                    'Users': concurrency,
                    't-statistic': f'{stats["welch_t_test"]["statistic"]:.3f}',
                    'p-value': f'{stats["welch_t_test"]["p_value"]:.4f}',
                    'Significant': 'Yes' if stats['welch_t_test']['significant'] else 'No',
                    "Cohen's d": f'{stats["effect_size"]["cohens_d"]:.3f}',
                    'Effect': stats['effect_size']['interpretation'].capitalize()
                })

        df_table = pd.DataFrame(rows)

        latex = self._dataframe_to_latex(
            df_table,
            caption=f'Statistical Significance Analysis ({metric.replace("_", " ").title()})',
            label='tab:statistical_significance'
        )

        markdown = tabulate(df_table, headers='keys', tablefmt='github', showindex=False)

        self._save_table(latex, save_name, 'tex')
        self._save_table(markdown, save_name, 'md')

        return latex, markdown

    def generate_summary_table(
        self,
        data: pd.DataFrame,
        save_name: str = 'summary'
    ) -> Tuple[str, str]:
        """
        Generate summary table of key findings.

        Args:
            data: DataFrame with benchmark results
            save_name: Filename for saved table

        Returns:
            Tuple of (LaTeX table, Markdown table)
        """
        rows = []

        # Throughput
        docker_throughput = data[data['platform'] == 'docker']['throughput_rps'].mean()
        vm_throughput = data[data['platform'] == 'vm']['throughput_rps'].mean()
        throughput_improvement = calculate_improvement_percentage(vm_throughput, docker_throughput, True)

        rows.append({
            'Metric': 'Average Throughput',
            'Docker': f'{docker_throughput:.1f} req/s',
            'VM': f'{vm_throughput:.1f} req/s',
            'Docker Advantage': f'+{throughput_improvement:.1f}%'
        })

        # Response Time
        docker_rt = data[data['platform'] == 'docker']['response_time_mean_ms'].mean()
        vm_rt = data[data['platform'] == 'vm']['response_time_mean_ms'].mean()
        rt_improvement = calculate_improvement_percentage(vm_rt, docker_rt, False)

        rows.append({
            'Metric': 'Mean Response Time',
            'Docker': f'{docker_rt:.1f} ms',
            'VM': f'{vm_rt:.1f} ms',
            'Docker Advantage': f'+{rt_improvement:.1f}%'
        })

        # CPU Utilization
        if 'cpu_utilization_mean' in data.columns:
            docker_cpu = data[data['platform'] == 'docker']['cpu_utilization_mean'].mean()
            vm_cpu = data[data['platform'] == 'vm']['cpu_utilization_mean'].mean()
            cpu_improvement = calculate_improvement_percentage(vm_cpu, docker_cpu, False)

            rows.append({
                'Metric': 'CPU Overhead',
                'Docker': f'{docker_cpu:.1f}%',
                'VM': f'{vm_cpu:.1f}%',
                'Docker Advantage': f'+{cpu_improvement:.1f}%'
            })

        # Memory
        if 'mem_used_mean_mb' in data.columns:
            docker_mem = data[data['platform'] == 'docker']['mem_used_mean_mb'].mean()
            vm_mem = data[data['platform'] == 'vm']['mem_used_mean_mb'].mean()
            mem_improvement = calculate_improvement_percentage(vm_mem, docker_mem, False)

            rows.append({
                'Metric': 'Memory Footprint',
                'Docker': f'{docker_mem:.0f} MB',
                'VM': f'{vm_mem:.0f} MB',
                'Docker Advantage': f'+{mem_improvement:.1f}%'
            })

        # Error Rate
        if 'error_rate' in data.columns:
            docker_err = data[data['platform'] == 'docker']['error_rate'].mean()
            vm_err = data[data['platform'] == 'vm']['error_rate'].mean()

            rows.append({
                'Metric': 'Error Rate',
                'Docker': f'{docker_err:.2f}%',
                'VM': f'{vm_err:.2f}%',
                'Docker Advantage': f'{vm_err - docker_err:+.2f}%'
            })

        df_table = pd.DataFrame(rows)

        latex = self._dataframe_to_latex(
            df_table,
            caption='Summary of Key Performance Metrics',
            label='tab:summary'
        )

        markdown = tabulate(df_table, headers='keys', tablefmt='github', showindex=False)

        self._save_table(latex, save_name, 'tex')
        self._save_table(markdown, save_name, 'md')

        return latex, markdown

    def _dataframe_to_latex(
        self,
        df: pd.DataFrame,
        caption: str,
        label: str,
        column_format: Optional[str] = None
    ) -> str:
        """
        Convert DataFrame to LaTeX table format.

        Args:
            df: DataFrame to convert
            caption: Table caption
            label: LaTeX label
            column_format: Optional column format string

        Returns:
            LaTeX table string
        """
        if column_format is None:
            column_format = 'l' + 'c' * (len(df.columns) - 1)

        # Escape special characters
        df_escaped = df.copy()
        for col in df_escaped.columns:
            if df_escaped[col].dtype == 'object':
                df_escaped[col] = df_escaped[col].str.replace('%', r'\\%', regex=False)
                df_escaped[col] = df_escaped[col].str.replace('±', r'$\\pm$', regex=False)

        latex = f"""\\begin{{table}}[htbp]
\\centering
\\caption{{{caption}}}
\\label{{{label}}}
\\begin{{tabular}}{{{column_format}}}
\\hline
"""
        # Header
        latex += ' & '.join([f'\\textbf{{{col}}}' for col in df_escaped.columns]) + ' \\\\\n'
        latex += '\\hline\n'

        # Data rows
        for _, row in df_escaped.iterrows():
            latex += ' & '.join([str(val) for val in row.values]) + ' \\\\\n'

        latex += """\\hline
\\end{tabular}
\\end{table}
"""
        return latex

    def generate_all_tables(self, data: pd.DataFrame) -> List[str]:
        """
        Generate all tables from benchmark data.

        Args:
            data: Complete benchmark results DataFrame

        Returns:
            List of generated table filenames
        """
        generated = []

        # Throughput table
        self.generate_throughput_table(data)
        generated.append('throughput_comparison')

        # Response time table
        self.generate_response_time_table(data)
        generated.append('response_time_comparison')

        # Resource utilization table
        if 'cpu_utilization_mean' in data.columns or 'mem_used_mean_mb' in data.columns:
            self.generate_resource_utilization_table(data)
            generated.append('resource_utilization')

        # Statistical significance
        self.generate_statistical_significance_table(data)
        generated.append('statistical_significance')

        # Summary table
        self.generate_summary_table(data)
        generated.append('summary')

        logger.info(f"Generated {len(generated)} tables")
        return generated


if __name__ == "__main__":
    import sys
    from parse_results import aggregate_benchmark_results

    if len(sys.argv) > 1:
        results_dir = Path(sys.argv[1])
    else:
        results_dir = Path("../benchmarks/results")

    output_dir = Path("./output/tables")

    print(f"Loading results from: {results_dir}")
    print(f"Saving tables to: {output_dir}")

    generator = TableGenerator(output_dir)

    if results_dir.exists():
        data = aggregate_benchmark_results(results_dir)

        if not data.empty:
            generated = generator.generate_all_tables(data)
            print(f"\nGenerated {len(generated)} tables:")
            for name in generated:
                print(f"  - {name}.tex, {name}.md")
        else:
            print("No data to generate tables from")
    else:
        print(f"Results directory not found: {results_dir}")
        print("Using sample data for demonstration...")

        from generate_sample_data import generate_sample_benchmark_data
        data = generate_sample_benchmark_data()
        generated = generator.generate_all_tables(data)
        print(f"\nGenerated {len(generated)} tables with sample data")
