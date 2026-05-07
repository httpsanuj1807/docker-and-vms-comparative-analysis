# Data Analysis Suite

Python-based analysis tools for **"Comparative Analysis of Docker Containers vs Virtual Machines"** research.

## Overview

This module processes JMeter benchmark results and system metrics to generate:
- Statistical analysis and comparisons
- Publication-quality charts and figures
- LaTeX and Markdown tables for the research paper
- Comprehensive analysis reports

## Directory Structure

```
analysis/
├── run_analysis.py           # Main analysis runner
├── parse_results.py          # JMeter/metrics parsers
├── generate_charts.py        # Chart generation
├── generate_tables.py        # LaTeX/Markdown tables
├── generate_sample_data.py   # Sample data generator
├── utils.py                  # Utility functions
├── requirements.txt          # Python dependencies
└── README.md                 # This file
```

## Installation

```bash
# Create virtual environment (recommended)
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt
```

## Quick Start

### Run Full Analysis

```bash
# Analyze benchmark results
python run_analysis.py ../benchmarks/results

# Specify output directory
python run_analysis.py ../benchmarks/results -o ./my_analysis

# Generate with sample data (for testing/demonstration)
python run_analysis.py --sample-data
```

### Generate Sample Data

```bash
# Generate realistic sample benchmark data
python generate_sample_data.py ./sample_results
```

### Generate Charts Only

```bash
python generate_charts.py ../benchmarks/results
```

### Generate Tables Only

```bash
python generate_tables.py ../benchmarks/results
```

## Output Structure

```
output/
├── analysis_YYYYMMDD_HHMMSS/
│   ├── analysis_summary.json    # Complete analysis data
│   ├── analysis_report.md       # Human-readable report
│   ├── charts/
│   │   ├── throughput_comparison_static.png
│   │   ├── throughput_comparison_compute.png
│   │   ├── response_time_comparison_*.png
│   │   ├── cpu_utilization.png
│   │   ├── memory_usage.png
│   │   ├── startup_time.png
│   │   ├── disk_io_comparison.png
│   │   ├── network_throughput.png
│   │   └── summary_heatmap.png
│   └── tables/
│       ├── throughput_comparison.tex
│       ├── throughput_comparison.md
│       ├── response_time_comparison.tex
│       ├── response_time_comparison.md
│       ├── resource_utilization.tex
│       ├── startup_time.tex
│       ├── statistical_significance.tex
│       └── summary.tex
```

## Input File Formats

### JMeter JTL Files

Expected filename pattern: `{platform}_{workload}_{concurrency}users_run{iteration}.jtl`

Example: `docker_static_200users_run1.jtl`

Standard JMeter CSV columns:
- timeStamp, elapsed, label, responseCode, responseMessage
- threadName, dataType, success, failureMessage
- bytes, sentBytes, grpThreads, allThreads
- URL, Latency, IdleTime, Connect

### System Metrics

**CPU/Memory** (`*_cpu_memory.csv`):
```csv
timestamp,cpu_user,cpu_system,cpu_iowait,cpu_idle,mem_used,mem_free,mem_cached
```

**Disk I/O** (`*_disk_io.csv`):
```csv
timestamp,device,r_s,w_s,rkB_s,wkB_s,await,util
```

**Network** (`*_network.csv`):
```csv
timestamp,interface,rx_bytes,tx_bytes,rx_packets,tx_packets
```

### Startup Times

`startup_times.csv`:
```csv
iteration,platform,startup_time_ms
1,docker,243
1,vm,30125
...
```

## Generated Charts

| Chart | Description |
|-------|-------------|
| `throughput_comparison_*.png` | Bar chart comparing Docker vs VM throughput |
| `response_time_comparison_*.png` | Response time percentiles (P50, P90, P95, P99) |
| `response_time_scaling_*.png` | Response time vs concurrency line chart |
| `cpu_utilization.png` | CPU usage comparison by workload |
| `memory_usage.png` | Memory footprint comparison |
| `startup_time.png` | Startup time comparison (log scale) |
| `disk_io_comparison.png` | IOPS and I/O latency comparison |
| `network_throughput.png` | Network bandwidth comparison |
| `error_rate.png` | Error rate under load |
| `summary_heatmap.png` | Overall improvement heatmap |

## Generated Tables

| Table | Format | Description |
|-------|--------|-------------|
| `throughput_comparison` | LaTeX, MD | Throughput by workload and concurrency |
| `response_time_comparison` | LaTeX, MD | Response time percentiles |
| `resource_utilization` | LaTeX, MD | CPU, memory, I/O metrics |
| `startup_time` | LaTeX, MD | Startup time statistics |
| `statistical_significance` | LaTeX, MD | t-test and effect size |
| `summary` | LaTeX, MD | Key findings summary |

## Statistical Analysis

The analysis includes:

1. **Descriptive Statistics**
   - Mean, median, standard deviation
   - Min, max, percentiles (P50, P90, P95, P99)
   - Coefficient of variation

2. **Comparative Analysis**
   - Percentage improvement calculations
   - Docker advantage metrics

3. **Statistical Significance**
   - Welch's t-test (unequal variances)
   - Mann-Whitney U test (non-parametric)
   - Cohen's d effect size
   - 95% confidence intervals

## Command Line Options

```
usage: run_analysis.py [-h] [-o OUTPUT_DIR] [--no-charts] [--no-tables]
                       [--no-report] [-v] [--sample-data]
                       [results_dir]

positional arguments:
  results_dir           Directory containing benchmark results

optional arguments:
  -h, --help            show this help message and exit
  -o, --output OUTPUT_DIR
                        Output directory for analysis results
  --no-charts           Skip chart generation
  --no-tables           Skip table generation
  --no-report           Skip report generation
  -v, --verbose         Enable verbose output
  --sample-data         Use sample data for demonstration
```

## Using in Research Paper

### Including Charts

```latex
\begin{figure}[htbp]
    \centering
    \includegraphics[width=0.8\textwidth]{charts/throughput_comparison_static.png}
    \caption{Throughput comparison for I/O-bound workload}
    \label{fig:throughput}
\end{figure}
```

### Including Tables

```latex
\input{tables/throughput_comparison.tex}
```

## Metrics Reference

### Key Metrics Analyzed

| Metric | Unit | Higher is Better |
|--------|------|------------------|
| Throughput | req/s | Yes |
| Response Time | ms | No |
| CPU Utilization | % | No |
| Memory Usage | MB | No |
| I/O Latency | ms | No |
| Network Bandwidth | Mbps | Yes |
| Startup Time | ms | No |
| Error Rate | % | No |

### Research Baseline Values

Based on the research paper findings:

| Metric | Docker | VM | Docker Advantage |
|--------|--------|-----|------------------|
| Throughput | ~4850 req/s | ~4250 req/s | +14% |
| Response Time | ~10.3 ms | ~11.8 ms | +15% |
| CPU Overhead | 35% | 42% | -17% |
| Memory Usage | 512 MB | 850 MB | -40% |
| Startup Time | 245 ms | 30150 ms | 123x faster |
| I/O Latency | 0.42 ms | 0.68 ms | +38% |

## Extending the Analysis

### Adding New Metrics

1. Update `parse_results.py` with new parser methods
2. Add calculation functions to `utils.py`
3. Create chart methods in `generate_charts.py`
4. Add table generators in `generate_tables.py`
5. Update `run_analysis.py` to include new metrics

### Custom Chart Styles

Modify `generate_charts.py`:

```python
# Change color scheme
COLORS = {
    'docker': '#your_color',
    'vm': '#your_color'
}

# Change matplotlib style
plt.style.use('your_preferred_style')
```

## Troubleshooting

### No Data Found

```
Error: No JTL files found in results directory
```

Solution: Ensure benchmark results follow the naming convention:
`{platform}_{workload}_{concurrency}users_run{iteration}.jtl`

### Missing Dependencies

```bash
pip install -r requirements.txt
```

### Chart Generation Fails

Ensure matplotlib backend is configured:
```python
import matplotlib
matplotlib.use('Agg')  # For headless environments
```

## License

This project is for educational and research purposes.
