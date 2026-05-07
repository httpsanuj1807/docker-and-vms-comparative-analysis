#!/bin/bash
# =============================================================================
# System Metrics Collection Script
# Research: Comparative Analysis of Docker Containers vs Virtual Machines
# =============================================================================
# Collects CPU, memory, disk I/O, and network metrics during benchmark runs
# =============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="${SCRIPT_DIR}/../results"

# Default values
TARGET_HOST=""
SSH_KEY=""
DURATION=300
INTERVAL=1
OUTPUT_PREFIX="metrics"

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --host HOST       Target host IP (required)"
    echo "  -k, --ssh-key PATH    SSH private key path (required)"
    echo "  -d, --duration SEC    Collection duration (default: 300)"
    echo "  -i, --interval SEC    Collection interval (default: 1)"
    echo "  -o, --output PREFIX   Output file prefix (default: metrics)"
    echo "  --help                Show this help"
    exit 1
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--host) TARGET_HOST="$2"; shift 2 ;;
            -k|--ssh-key) SSH_KEY="$2"; shift 2 ;;
            -d|--duration) DURATION="$2"; shift 2 ;;
            -i|--interval) INTERVAL="$2"; shift 2 ;;
            -o|--output) OUTPUT_PREFIX="$2"; shift 2 ;;
            --help) usage ;;
            *) echo "Unknown option: $1"; usage ;;
        esac
    done

    if [[ -z "$TARGET_HOST" ]] || [[ -z "$SSH_KEY" ]]; then
        echo -e "${RED}Error: host and ssh-key are required${NC}"
        usage
    fi
}

ssh_cmd() {
    ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no -o ConnectTimeout=10 ubuntu@"$TARGET_HOST" "$@"
}

collect_metrics() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local output_dir="${RESULTS_DIR}/${OUTPUT_PREFIX}_${timestamp}"

    mkdir -p "$output_dir"

    echo -e "${BLUE}=============================================================="
    echo "  System Metrics Collection"
    echo "  Host: ${TARGET_HOST}"
    echo "  Duration: ${DURATION}s, Interval: ${INTERVAL}s"
    echo "==============================================================${NC}"
    echo ""

    echo -e "${YELLOW}Starting metrics collection on remote host...${NC}"

    # Create collection script on remote host
    ssh_cmd "cat > /tmp/collect_metrics.sh" << 'REMOTE_SCRIPT'
#!/bin/bash
DURATION=$1
INTERVAL=$2
OUTPUT_DIR=$3

mkdir -p "$OUTPUT_DIR"

# CPU and Memory (sar)
echo "Starting CPU/Memory collection..."
sar -u -r $INTERVAL $((DURATION/INTERVAL)) > "${OUTPUT_DIR}/cpu_memory.log" 2>&1 &
SAR_PID=$!

# Disk I/O (iostat)
echo "Starting Disk I/O collection..."
iostat -x $INTERVAL $((DURATION/INTERVAL)) > "${OUTPUT_DIR}/disk_io.log" 2>&1 &
IOSTAT_PID=$!

# Network (sar -n)
echo "Starting Network collection..."
sar -n DEV $INTERVAL $((DURATION/INTERVAL)) > "${OUTPUT_DIR}/network.log" 2>&1 &
NET_PID=$!

# Process-level metrics
echo "Starting process metrics collection..."
while true; do
    echo "=== $(date '+%Y-%m-%d %H:%M:%S') ===" >> "${OUTPUT_DIR}/process_stats.log"
    ps aux --sort=-%cpu | head -20 >> "${OUTPUT_DIR}/process_stats.log"
    echo "" >> "${OUTPUT_DIR}/process_stats.log"
    sleep $INTERVAL
done &
PS_PID=$!

# Docker stats (if docker is running)
if command -v docker &> /dev/null && docker ps -q | grep -q .; then
    echo "Starting Docker stats collection..."
    while true; do
        echo "=== $(date '+%Y-%m-%d %H:%M:%S') ===" >> "${OUTPUT_DIR}/docker_stats.log"
        docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}" >> "${OUTPUT_DIR}/docker_stats.log"
        sleep $INTERVAL
    done &
    DOCKER_PID=$!
fi

# Memory details
echo "Starting memory details collection..."
while true; do
    echo "=== $(date '+%Y-%m-%d %H:%M:%S') ===" >> "${OUTPUT_DIR}/memory_detail.log"
    free -m >> "${OUTPUT_DIR}/memory_detail.log"
    echo "" >> "${OUTPUT_DIR}/memory_detail.log"
    sleep $INTERVAL
done &
MEM_PID=$!

echo "Collection started. Waiting for ${DURATION} seconds..."
sleep $DURATION

# Cleanup
echo "Stopping collectors..."
kill $SAR_PID $IOSTAT_PID $NET_PID $PS_PID $MEM_PID 2>/dev/null || true
[[ -n "$DOCKER_PID" ]] && kill $DOCKER_PID 2>/dev/null || true

echo "Collection complete. Files in ${OUTPUT_DIR}"
ls -la "$OUTPUT_DIR"
REMOTE_SCRIPT

    ssh_cmd "chmod +x /tmp/collect_metrics.sh"

    # Run collection
    echo -e "${YELLOW}Collecting metrics for ${DURATION} seconds...${NC}"
    ssh_cmd "/tmp/collect_metrics.sh $DURATION $INTERVAL /tmp/benchmark_metrics"

    # Download results
    echo -e "${YELLOW}Downloading results...${NC}"
    scp -i "$SSH_KEY" -o StrictHostKeyChecking=no -r ubuntu@"${TARGET_HOST}":/tmp/benchmark_metrics/* "$output_dir/"

    # Parse and create summary
    create_metrics_summary "$output_dir"

    echo ""
    echo -e "${GREEN}Metrics saved to: ${output_dir}${NC}"
}

create_metrics_summary() {
    local output_dir=$1
    local summary_file="${output_dir}/summary.csv"

    echo -e "${YELLOW}Creating metrics summary...${NC}"

    # Parse CPU metrics from sar output
    if [[ -f "${output_dir}/cpu_memory.log" ]]; then
        echo "timestamp,cpu_user,cpu_system,cpu_iowait,cpu_idle,mem_used_pct" > "$summary_file"

        grep -E "^[0-9]{2}:" "${output_dir}/cpu_memory.log" | grep -v "CPU\|%" | while read line; do
            # Extract CPU metrics (adjust parsing based on sar output format)
            echo "$line" | awk '{print $1","$3","$5","$6","$8",0"}' >> "$summary_file"
        done
    fi

    echo -e "${GREEN}Summary created: ${summary_file}${NC}"
}

main() {
    parse_args "$@"
    collect_metrics
}

main "$@"
