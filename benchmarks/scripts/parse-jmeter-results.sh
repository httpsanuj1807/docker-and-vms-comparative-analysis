#!/bin/bash
# =============================================================================
# JMeter Results Parser
# Research: Comparative Analysis of Docker Containers vs Virtual Machines
# =============================================================================
# Parses JTL files and generates CSV summary for analysis
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
    echo "Usage: $0 <results_directory>"
    echo ""
    echo "Parses all JTL files in the directory and generates summary CSV"
    exit 1
}

if [[ $# -lt 1 ]]; then
    usage
fi

RESULTS_DIR="$1"
OUTPUT_FILE="${RESULTS_DIR}/parsed_results.csv"

if [[ ! -d "$RESULTS_DIR" ]]; then
    echo "Error: Directory not found: $RESULTS_DIR"
    exit 1
fi

echo "Parsing JMeter results from: $RESULTS_DIR"

# Create header
echo "environment,workload,concurrency,iteration,total_requests,successful_requests,failed_requests,error_rate,throughput_rps,avg_response_time_ms,min_response_time_ms,max_response_time_ms,p50_response_time_ms,p90_response_time_ms,p95_response_time_ms,p99_response_time_ms,avg_latency_ms,avg_bytes_received" > "$OUTPUT_FILE"

# Process each JTL file
find "$RESULTS_DIR" -name "*.jtl" -type f | while read jtl_file; do
    filename=$(basename "$jtl_file" .jtl)
    dir_name=$(basename $(dirname "$jtl_file"))

    # Parse filename: workload_concurrencyusers_iterN
    # Example: static_50users_iter1
    workload=$(echo "$filename" | cut -d'_' -f1)
    concurrency=$(echo "$filename" | grep -oE '[0-9]+users' | grep -oE '[0-9]+')
    iteration=$(echo "$filename" | grep -oE 'iter[0-9]+' | grep -oE '[0-9]+')

    # Environment from directory name (docker or vm)
    environment="$dir_name"

    # Skip if file is empty or header only
    line_count=$(wc -l < "$jtl_file")
    if [[ $line_count -lt 2 ]]; then
        echo "  Skipping empty file: $jtl_file"
        continue
    fi

    echo "  Processing: $jtl_file"

    # Parse JTL (CSV format)
    # Columns: timeStamp,elapsed,label,responseCode,responseMessage,threadName,dataType,success,failureMessage,bytes,sentBytes,grpThreads,allThreads,URL,Latency,IdleTime,Connect
    # Index:   1         2       3     4            5               6          7        8       9              10    11        12         13        14  15      16       17

    stats=$(tail -n +2 "$jtl_file" | awk -F',' '
    BEGIN {
        count = 0
        success = 0
        failed = 0
        total_time = 0
        total_latency = 0
        total_bytes = 0
        min_time = 999999999
        max_time = 0
    }
    {
        count++
        elapsed = $2
        is_success = ($8 == "true")
        bytes = $10
        latency = $15

        if (is_success) success++
        else failed++

        total_time += elapsed
        total_latency += latency
        total_bytes += bytes

        times[count] = elapsed

        if (elapsed < min_time) min_time = elapsed
        if (elapsed > max_time) max_time = elapsed
    }
    END {
        if (count == 0) {
            print "0,0,0,0,0,0,0,0,0,0,0,0,0"
            exit
        }

        # Sort times for percentiles
        n = asort(times)
        p50 = times[int(n * 0.50)]
        p90 = times[int(n * 0.90)]
        p95 = times[int(n * 0.95)]
        p99 = times[int(n * 0.99)]

        avg_time = total_time / count
        avg_latency = total_latency / count
        avg_bytes = total_bytes / count
        error_rate = (failed / count) * 100

        # Throughput: assuming 300 second test duration
        throughput = count / 300

        printf "%d,%d,%d,%.2f,%.2f,%.2f,%d,%d,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f\n",
            count, success, failed, error_rate, throughput, avg_time,
            min_time, max_time, p50, p90, p95, p99, avg_latency, avg_bytes
    }')

    # Append to output
    echo "${environment},${workload},${concurrency},${iteration},${stats}" >> "$OUTPUT_FILE"
done

echo ""
echo "Results parsed and saved to: $OUTPUT_FILE"
echo ""

# Generate quick summary
echo "=== Quick Summary ==="
echo ""
if [[ -f "$OUTPUT_FILE" ]]; then
    echo "Results by Environment and Workload:"
    echo ""
    tail -n +2 "$OUTPUT_FILE" | awk -F',' '
    {
        key = $1 " | " $2 " | " $3 " users"
        throughput[$1][$2][$3] += $6
        count[$1][$2][$3]++
        response[$1][$2][$3] += $7
    }
    END {
        printf "%-10s | %-10s | %-10s | %-15s | %-15s\n", "Env", "Workload", "Users", "Avg Throughput", "Avg Response"
        printf "%-10s-+-%-10s-+-%-10s-+-%-15s-+-%-15s\n", "----------", "----------", "----------", "---------------", "---------------"
        for (env in throughput) {
            for (wl in throughput[env]) {
                for (users in throughput[env][wl]) {
                    avg_tp = throughput[env][wl][users] / count[env][wl][users]
                    avg_rt = response[env][wl][users] / count[env][wl][users]
                    printf "%-10s | %-10s | %-10s | %-15.2f | %-15.2f\n", env, wl, users, avg_tp, avg_rt
                }
            }
        }
    }'
fi
