# Benchmark Automation Suite

Automated benchmarking tools for **"Comparative Analysis of Docker Containers vs Virtual Machines"**

## Directory Structure

```
benchmarks/
├── scripts/
│   ├── run-full-benchmark.sh      # Complete benchmark suite runner
│   ├── measure-startup-time.sh    # Startup time measurement
│   ├── collect-metrics.sh         # System metrics collection
│   └── parse-jmeter-results.sh    # Results parser
├── jmeter/
│   ├── static-test.jmx            # I/O-bound workload test plan
│   └── compute-test.jmx           # CPU-bound workload test plan
└── results/                        # Benchmark results (gitignored)
```

## Prerequisites

- Apache JMeter 5.6+
- SSH access to target hosts
- `curl`, `bc`, `awk` utilities

## Quick Start

### Run Full Benchmark Suite

```bash
./scripts/run-full-benchmark.sh \
    -d 10.0.1.10 \    # Docker host IP
    -v 10.0.1.20 \    # VM host IP
    -i 5              # 5 iterations per test
```

### Measure Startup Time

```bash
# Docker startup time
./scripts/measure-startup-time.sh \
    -t docker \
    -h 10.0.1.10 \
    -k ~/.ssh/key.pem \
    -n 30

# VM startup time
./scripts/measure-startup-time.sh \
    -t vm \
    -h 10.0.1.20 \
    -k ~/.ssh/key.pem \
    -n 30
```

### Collect System Metrics

```bash
./scripts/collect-metrics.sh \
    -h 10.0.1.10 \
    -k ~/.ssh/key.pem \
    -d 300
```

### Parse Results

```bash
./scripts/parse-jmeter-results.sh ./results/20240101_120000/
```

## Test Configuration

| Parameter | Default | Description |
|-----------|---------|-------------|
| Warmup | 60s | Ramp-up period |
| Duration | 300s | Test duration |
| Iterations | 5 | Runs per configuration |
| Concurrency | 50, 200, 500 | Concurrent users |

## JMeter Test Plans

### Static Test (I/O-bound)
- Endpoint: `GET /api/static`
- Payload: ~50KB JSON
- Assertions: HTTP 200, success=true

### Compute Test (CPU-bound)
- Endpoint: `GET /api/compute?n=35`
- Workload: Fibonacci(35) calculation
- Assertions: HTTP 200, result=9227465

## Running Individual JMeter Tests

```bash
# Static endpoint test
jmeter -n \
    -t jmeter/static-test.jmx \
    -Jtarget.host=10.0.1.10 \
    -Jtarget.port=3000 \
    -Jthreads=200 \
    -Jduration=300 \
    -l results/static_200users.jtl

# Compute endpoint test
jmeter -n \
    -t jmeter/compute-test.jmx \
    -Jtarget.host=10.0.1.10 \
    -Jthreads=50 \
    -l results/compute_50users.jtl
```

## Output Files

| File | Description |
|------|-------------|
| `*.jtl` | JMeter raw results (CSV) |
| `*_startup_times.csv` | Startup time measurements |
| `cpu_memory.log` | CPU/memory metrics (sar) |
| `disk_io.log` | Disk I/O metrics (iostat) |
| `network.log` | Network metrics |
| `parsed_results.csv` | Aggregated results |
| `summary.md` | Human-readable summary |

## Metrics Collected

1. **Throughput**: Requests per second
2. **Response Time**: Mean, P50, P90, P95, P99
3. **Error Rate**: Failed requests percentage
4. **CPU Usage**: User, system, iowait, idle
5. **Memory**: Used, free, cached
6. **Disk I/O**: IOPS, latency
7. **Network**: Bytes in/out, packets
8. **Startup Time**: Container/VM boot to ready
