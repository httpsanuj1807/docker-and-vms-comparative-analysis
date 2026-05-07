#!/bin/bash
# =============================================================================
# Startup Time Measurement Script
# Research: Comparative Analysis of Docker Containers vs Virtual Machines
# =============================================================================
# Measures time from container/VM start until HTTP health endpoint responds
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
TARGET_TYPE="docker"  # docker or vm
TARGET_HOST=""
SSH_KEY=""
TRIALS=30
APP_PORT=3000

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -t, --type TYPE       Target type: 'docker' or 'vm' (required)"
    echo "  -h, --host HOST       Target host IP/hostname (required)"
    echo "  -k, --ssh-key PATH    SSH private key path (required)"
    echo "  -n, --trials NUM      Number of trials (default: 30)"
    echo "  -p, --port PORT       Application port (default: 3000)"
    echo "  --help                Show this help"
    echo ""
    echo "Example:"
    echo "  $0 -t docker -h 10.0.1.10 -k ~/.ssh/key.pem -n 30"
    exit 1
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -t|--type) TARGET_TYPE="$2"; shift 2 ;;
            -h|--host) TARGET_HOST="$2"; shift 2 ;;
            -k|--ssh-key) SSH_KEY="$2"; shift 2 ;;
            -n|--trials) TRIALS="$2"; shift 2 ;;
            -p|--port) APP_PORT="$2"; shift 2 ;;
            --help) usage ;;
            *) echo "Unknown option: $1"; usage ;;
        esac
    done

    if [[ -z "$TARGET_HOST" ]] || [[ -z "$SSH_KEY" ]]; then
        echo -e "${RED}Error: host and ssh-key are required${NC}"
        usage
    fi

    if [[ "$TARGET_TYPE" != "docker" ]] && [[ "$TARGET_TYPE" != "vm" ]]; then
        echo -e "${RED}Error: type must be 'docker' or 'vm'${NC}"
        usage
    fi
}

ssh_cmd() {
    ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no -o ConnectTimeout=10 ubuntu@"$TARGET_HOST" "$@"
}

# Docker startup measurement
measure_docker_startup() {
    local trial=$1

    # Stop existing container
    ssh_cmd "docker stop research-app 2>/dev/null || true"
    ssh_cmd "docker rm research-app 2>/dev/null || true"
    sleep 1

    # Start timing
    local start_time=$(date +%s%3N)

    # Start container
    ssh_cmd "docker run -d --name research-app --cpus=4 --memory=8g -p ${APP_PORT}:3000 research-app:latest" > /dev/null

    # Wait for health endpoint
    local max_wait=60000  # 60 seconds in ms
    while true; do
        if curl -s --connect-timeout 1 "http://${TARGET_HOST}:${APP_PORT}/health" > /dev/null 2>&1; then
            break
        fi

        local current_time=$(date +%s%3N)
        if [[ $((current_time - start_time)) -gt $max_wait ]]; then
            echo "TIMEOUT"
            return 1
        fi

        sleep 0.05
    done

    local end_time=$(date +%s%3N)
    echo $((end_time - start_time))
}

# VM startup measurement
measure_vm_startup() {
    local trial=$1
    local vm_name="research-vm"

    # Shutdown VM
    ssh_cmd "sudo virsh destroy $vm_name 2>/dev/null || true"
    sleep 2

    # Start timing
    local start_time=$(date +%s%3N)

    # Start VM
    ssh_cmd "sudo virsh start $vm_name" > /dev/null 2>&1

    # Wait for VM to get IP and respond
    local vm_ip=""
    local max_wait=180000  # 3 minutes in ms

    while true; do
        # Try to get VM IP
        vm_ip=$(ssh_cmd "sudo virsh domifaddr $vm_name 2>/dev/null | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1" 2>/dev/null || true)

        if [[ -n "$vm_ip" ]]; then
            # Try health check via the VM host (internal network)
            if ssh_cmd "curl -s --connect-timeout 1 http://${vm_ip}:${APP_PORT}/health" > /dev/null 2>&1; then
                break
            fi
        fi

        local current_time=$(date +%s%3N)
        if [[ $((current_time - start_time)) -gt $max_wait ]]; then
            echo "TIMEOUT"
            return 1
        fi

        sleep 0.5
    done

    local end_time=$(date +%s%3N)
    echo $((end_time - start_time))
}

run_measurements() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local output_file="${RESULTS_DIR}/${TARGET_TYPE}_startup_times_${timestamp}.csv"

    mkdir -p "$RESULTS_DIR"

    echo -e "${BLUE}=============================================================="
    echo "  Startup Time Measurement - ${TARGET_TYPE^^}"
    echo "  Host: ${TARGET_HOST}"
    echo "  Trials: ${TRIALS}"
    echo "==============================================================${NC}"
    echo ""

    echo "trial,startup_time_ms" > "$output_file"

    local successful=0
    local failed=0
    local total_time=0
    local min_time=999999999
    local max_time=0
    local times=()

    for i in $(seq 1 $TRIALS); do
        echo -n "Trial $i/$TRIALS: "

        local duration
        if [[ "$TARGET_TYPE" == "docker" ]]; then
            duration=$(measure_docker_startup $i)
        else
            duration=$(measure_vm_startup $i)
        fi

        if [[ "$duration" == "TIMEOUT" ]] || [[ -z "$duration" ]]; then
            echo -e "${RED}TIMEOUT${NC}"
            ((failed++))
            continue
        fi

        echo "$i,$duration" >> "$output_file"
        times+=($duration)
        ((successful++))
        total_time=$((total_time + duration))

        if [[ $duration -lt $min_time ]]; then min_time=$duration; fi
        if [[ $duration -gt $max_time ]]; then max_time=$duration; fi

        if [[ "$TARGET_TYPE" == "docker" ]]; then
            echo -e "${GREEN}${duration} ms${NC}"
        else
            echo -e "${GREEN}${duration} ms ($(echo "scale=2; $duration/1000" | bc)s)${NC}"
        fi

        sleep 2
    done

    echo ""
    echo -e "${BLUE}=== Results ===${NC}"
    echo "Successful: $successful / $TRIALS"
    echo "Failed: $failed"

    if [[ $successful -gt 0 ]]; then
        local mean=$((total_time / successful))

        # Calculate std dev
        local sum_sq=0
        for t in "${times[@]}"; do
            local diff=$((t - mean))
            sum_sq=$((sum_sq + diff * diff))
        done
        local variance=$((sum_sq / successful))
        local stddev=$(echo "scale=2; sqrt($variance)" | bc)

        echo ""
        if [[ "$TARGET_TYPE" == "docker" ]]; then
            echo "Mean:   ${mean} ms"
            echo "Min:    ${min_time} ms"
            echo "Max:    ${max_time} ms"
            echo "StdDev: ${stddev} ms"
        else
            echo "Mean:   ${mean} ms ($(echo "scale=2; $mean/1000" | bc)s)"
            echo "Min:    ${min_time} ms ($(echo "scale=2; $min_time/1000" | bc)s)"
            echo "Max:    ${max_time} ms ($(echo "scale=2; $max_time/1000" | bc)s)"
            echo "StdDev: ${stddev} ms"
        fi
    fi

    echo ""
    echo -e "${GREEN}Results saved to: ${output_file}${NC}"
}

main() {
    parse_args "$@"
    run_measurements
}

main "$@"
