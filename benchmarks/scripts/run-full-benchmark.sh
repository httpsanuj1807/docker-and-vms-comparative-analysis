#!/bin/bash
# =============================================================================
# Full Benchmark Suite Runner
# Research: Comparative Analysis of Docker Containers vs Virtual Machines
# =============================================================================
# Runs complete benchmark suite against Docker and VM targets
# Collects metrics, generates reports, measures startup times
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_BASE_DIR="${SCRIPT_DIR}/../results"
JMETER_DIR="${SCRIPT_DIR}/../jmeter"

# Default values
DOCKER_HOST=""
VM_HOST=""
APP_PORT=3000
WARMUP_DURATION=60
TEST_DURATION=300
ITERATIONS=5
CONCURRENCY_LEVELS="50 200 500"

# Print banner
print_banner() {
    echo -e "${BLUE}"
    echo "=============================================================="
    echo "  Docker vs VM Benchmark Suite"
    echo "  Chitkara University Research Project"
    echo "=============================================================="
    echo -e "${NC}"
}

# Print usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -d, --docker-host HOST    Docker host IP/hostname (required)"
    echo "  -v, --vm-host HOST        VM host IP/hostname (required)"
    echo "  -p, --port PORT           Application port (default: 3000)"
    echo "  -w, --warmup SECONDS      Warmup duration (default: 60)"
    echo "  -t, --duration SECONDS    Test duration (default: 300)"
    echo "  -i, --iterations NUM      Iterations per test (default: 5)"
    echo "  -c, --concurrency LIST    Concurrency levels (default: '50 200 500')"
    echo "  -h, --help                Show this help message"
    echo ""
    echo "Example:"
    echo "  $0 -d 10.0.1.10 -v 10.0.1.20 -i 3"
    exit 1
}

# Parse arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--docker-host) DOCKER_HOST="$2"; shift 2 ;;
            -v|--vm-host) VM_HOST="$2"; shift 2 ;;
            -p|--port) APP_PORT="$2"; shift 2 ;;
            -w|--warmup) WARMUP_DURATION="$2"; shift 2 ;;
            -t|--duration) TEST_DURATION="$2"; shift 2 ;;
            -i|--iterations) ITERATIONS="$2"; shift 2 ;;
            -c|--concurrency) CONCURRENCY_LEVELS="$2"; shift 2 ;;
            -h|--help) usage ;;
            *) echo "Unknown option: $1"; usage ;;
        esac
    done

    if [[ -z "$DOCKER_HOST" ]] || [[ -z "$VM_HOST" ]]; then
        echo -e "${RED}Error: Both docker-host and vm-host are required${NC}"
        usage
    fi
}

# Check prerequisites
check_prerequisites() {
    echo -e "${YELLOW}Checking prerequisites...${NC}"

    # Check JMeter
    if ! command -v jmeter &> /dev/null; then
        echo -e "${RED}Error: JMeter not found. Please install Apache JMeter.${NC}"
        exit 1
    fi

    # Check curl
    if ! command -v curl &> /dev/null; then
        echo -e "${RED}Error: curl not found.${NC}"
        exit 1
    fi

    echo -e "${GREEN}Prerequisites OK${NC}"
}

# Check target health
check_target_health() {
    local host=$1
    local name=$2

    echo -n "  Checking $name ($host:$APP_PORT)... "

    if curl -s --connect-timeout 5 "http://${host}:${APP_PORT}/health" > /dev/null 2>&1; then
        echo -e "${GREEN}OK${NC}"
        return 0
    else
        echo -e "${RED}FAILED${NC}"
        return 1
    fi
}

# Run JMeter test
run_jmeter_test() {
    local target_host=$1
    local target_name=$2
    local workload=$3
    local concurrency=$4
    local iteration=$5
    local output_dir=$6

    local test_plan="${JMETER_DIR}/${workload}-test.jmx"
    local output_prefix="${output_dir}/${workload}_${concurrency}users_iter${iteration}"

    echo -e "    Running ${workload} test, ${concurrency} users, iteration ${iteration}..."

    jmeter -n \
        -t "$test_plan" \
        -Jtarget.host="${target_host}" \
        -Jtarget.port="${APP_PORT}" \
        -Jthreads="${concurrency}" \
        -Jrampup="${WARMUP_DURATION}" \
        -Jduration="${TEST_DURATION}" \
        -l "${output_prefix}.jtl" \
        -j "${output_prefix}.log" \
        > /dev/null 2>&1

    if [[ $? -eq 0 ]]; then
        echo -e "      ${GREEN}Completed${NC} -> ${output_prefix}.jtl"
    else
        echo -e "      ${RED}Failed${NC}"
    fi
}

# Measure startup time
measure_startup_time() {
    local host=$1
    local name=$2
    local trials=$3
    local output_file=$4

    echo -e "${YELLOW}Measuring $name startup time ($trials trials)...${NC}"
    echo "trial,startup_time_ms" > "$output_file"

    for i in $(seq 1 $trials); do
        echo -n "  Trial $i/$trials: "

        # This assumes the container/VM can be restarted remotely
        # For Docker: ssh to host and restart container
        # For VM: use virsh to restart

        local start_time=$(date +%s%3N)

        # Wait for health endpoint
        local max_wait=120  # 2 minutes max
        local waited=0
        while ! curl -s --connect-timeout 1 "http://${host}:${APP_PORT}/health" > /dev/null 2>&1; do
            sleep 0.1
            waited=$((waited + 1))
            if [[ $waited -gt $((max_wait * 10)) ]]; then
                echo -e "${RED}Timeout${NC}"
                continue 2
            fi
        done

        local end_time=$(date +%s%3N)
        local duration=$((end_time - start_time))

        echo "$i,$duration" >> "$output_file"
        echo -e "${GREEN}${duration}ms${NC}"

        sleep 2  # Brief pause between trials
    done
}

# Collect system metrics during test
collect_metrics() {
    local host=$1
    local duration=$2
    local output_file=$3

    # Collect metrics via SSH (assumes passwordless SSH is configured)
    ssh -o ConnectTimeout=5 ubuntu@"$host" "
        sar -u -r 1 $duration > /tmp/metrics.log 2>&1 &
        SAR_PID=\$!
        sleep $duration
        kill \$SAR_PID 2>/dev/null
        cat /tmp/metrics.log
    " > "$output_file" 2>/dev/null || true
}

# Generate summary report
generate_summary() {
    local results_dir=$1
    local summary_file="${results_dir}/summary.md"

    echo -e "${YELLOW}Generating summary report...${NC}"

    cat > "$summary_file" << EOF
# Benchmark Results Summary

**Date:** $(date)
**Docker Host:** ${DOCKER_HOST}
**VM Host:** ${VM_HOST}

## Test Configuration

| Parameter | Value |
|-----------|-------|
| Warmup Duration | ${WARMUP_DURATION}s |
| Test Duration | ${TEST_DURATION}s |
| Iterations | ${ITERATIONS} |
| Concurrency Levels | ${CONCURRENCY_LEVELS} |

## Results

### Throughput (requests/sec)

| Workload | Users | Docker | VM | Difference |
|----------|-------|--------|-----|------------|
EOF

    # Parse JTL files and add results
    for workload in static compute; do
        for concurrency in $CONCURRENCY_LEVELS; do
            local docker_throughput=$(calculate_throughput "${results_dir}/docker/${workload}_${concurrency}users_iter1.jtl" 2>/dev/null || echo "N/A")
            local vm_throughput=$(calculate_throughput "${results_dir}/vm/${workload}_${concurrency}users_iter1.jtl" 2>/dev/null || echo "N/A")
            echo "| ${workload} | ${concurrency} | ${docker_throughput} | ${vm_throughput} | - |" >> "$summary_file"
        done
    done

    echo "" >> "$summary_file"
    echo "## Files Generated" >> "$summary_file"
    echo "" >> "$summary_file"
    find "$results_dir" -name "*.jtl" -o -name "*.csv" | while read f; do
        echo "- $(basename $f)" >> "$summary_file"
    done

    echo -e "${GREEN}Summary saved to: ${summary_file}${NC}"
}

# Calculate throughput from JTL file
calculate_throughput() {
    local jtl_file=$1
    if [[ -f "$jtl_file" ]]; then
        # JTL is CSV: timeStamp,elapsed,label,responseCode,responseMessage,threadName,dataType,success,failureMessage,bytes,sentBytes,grpThreads,allThreads,URL,Latency,IdleTime,Connect
        local count=$(tail -n +2 "$jtl_file" | wc -l)
        local duration=$TEST_DURATION
        echo "scale=2; $count / $duration" | bc
    else
        echo "N/A"
    fi
}

# Main benchmark run
run_benchmarks() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local results_dir="${RESULTS_BASE_DIR}/${timestamp}"

    mkdir -p "${results_dir}/docker"
    mkdir -p "${results_dir}/vm"

    echo -e "${BLUE}Results will be saved to: ${results_dir}${NC}"
    echo ""

    # Check targets
    echo -e "${YELLOW}Checking target health...${NC}"
    check_target_health "$DOCKER_HOST" "Docker" || exit 1
    check_target_health "$VM_HOST" "VM" || exit 1
    echo ""

    # Run Docker benchmarks
    echo -e "${BLUE}=== Running Docker Benchmarks ===${NC}"
    for workload in static compute; do
        echo -e "${YELLOW}Workload: ${workload}${NC}"
        for concurrency in $CONCURRENCY_LEVELS; do
            echo -e "  Concurrency: ${concurrency} users"
            for iter in $(seq 1 $ITERATIONS); do
                run_jmeter_test "$DOCKER_HOST" "docker" "$workload" "$concurrency" "$iter" "${results_dir}/docker"
                sleep 5  # Brief pause between iterations
            done
        done
    done
    echo ""

    # Run VM benchmarks
    echo -e "${BLUE}=== Running VM Benchmarks ===${NC}"
    for workload in static compute; do
        echo -e "${YELLOW}Workload: ${workload}${NC}"
        for concurrency in $CONCURRENCY_LEVELS; do
            echo -e "  Concurrency: ${concurrency} users"
            for iter in $(seq 1 $ITERATIONS); do
                run_jmeter_test "$VM_HOST" "vm" "$workload" "$concurrency" "$iter" "${results_dir}/vm"
                sleep 5
            done
        done
    done
    echo ""

    # Generate summary
    generate_summary "$results_dir"

    echo ""
    echo -e "${GREEN}=============================================================="
    echo "  Benchmarks Complete!"
    echo "  Results: ${results_dir}"
    echo "==============================================================${NC}"
}

# Main
main() {
    print_banner
    parse_args "$@"
    check_prerequisites
    run_benchmarks
}

main "$@"
