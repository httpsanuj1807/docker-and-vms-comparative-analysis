#!/bin/bash
# =============================================================================
# Load Generator Setup Script
# Research: Comparative Analysis of Docker Containers vs Virtual Machines
# =============================================================================
# This script sets up Apache JMeter 5.6 for load testing as per research paper
# Separate machine for load generation to eliminate network contention
# =============================================================================

set -e

exec > >(tee /var/log/load-generator-setup.log) 2>&1
echo "=== Starting Load Generator Setup at $(date) ==="

# ------------------------------------------------------------------------------
# System Update and Essential Packages
# ------------------------------------------------------------------------------
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    software-properties-common \
    git \
    htop \
    iotop \
    sysstat \
    net-tools \
    jq \
    unzip \
    wget \
    bc

# ------------------------------------------------------------------------------
# Java Installation (Required for JMeter)
# ------------------------------------------------------------------------------
echo "=== Installing Java 17 ==="

apt-get install -y openjdk-17-jdk openjdk-17-jre

java -version

# Set JAVA_HOME
echo 'export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64' >> /etc/environment
echo 'export PATH=$PATH:$JAVA_HOME/bin' >> /etc/environment
source /etc/environment

# ------------------------------------------------------------------------------
# Apache JMeter Installation (Version 5.6.x as per research paper)
# ------------------------------------------------------------------------------
echo "=== Installing Apache JMeter 5.6.3 ==="

JMETER_VERSION="5.6.3"
JMETER_HOME="/opt/jmeter"

cd /tmp
wget -q "https://archive.apache.org/dist/jmeter/binaries/apache-jmeter-${JMETER_VERSION}.tgz"
tar -xzf "apache-jmeter-${JMETER_VERSION}.tgz"
mv "apache-jmeter-${JMETER_VERSION}" "$JMETER_HOME"

# Set JMeter environment variables
cat >> /etc/environment << EOF
JMETER_HOME=$JMETER_HOME
PATH=$PATH:$JMETER_HOME/bin
EOF

# Create symlinks for easier access
ln -sf "$JMETER_HOME/bin/jmeter" /usr/local/bin/jmeter
ln -sf "$JMETER_HOME/bin/jmeter-server" /usr/local/bin/jmeter-server

# Verify installation
$JMETER_HOME/bin/jmeter --version

# ------------------------------------------------------------------------------
# JMeter Heap Configuration for High Concurrency Testing
# ------------------------------------------------------------------------------
echo "=== Configuring JMeter for high concurrency ==="

# Increase heap size for high concurrency tests (500 users)
cat > "$JMETER_HOME/bin/setenv.sh" << 'EOF'
# JMeter Environment Settings for Research Benchmarks
export HEAP="-Xms2g -Xmx4g"
export GC_ALGO="-XX:+UseG1GC -XX:MaxGCPauseMillis=100"
export JMETER_OPTS="-Djava.net.preferIPv4Stack=true"
EOF

chmod +x "$JMETER_HOME/bin/setenv.sh"

# ------------------------------------------------------------------------------
# Network Tuning for Load Generation
# ------------------------------------------------------------------------------
echo "=== Applying network tuning for load generation ==="

cat >> /etc/sysctl.conf << EOF
# Network tuning for load testing
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 65535
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_tw_reuse = 1
net.ipv4.ip_local_port_range = 1024 65535
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
EOF

sysctl -p

# Increase file descriptor limits
cat >> /etc/security/limits.conf << EOF
* soft nofile 65535
* hard nofile 65535
* soft nproc 65535
* hard nproc 65535
EOF

# ------------------------------------------------------------------------------
# Create Research Directories
# ------------------------------------------------------------------------------
mkdir -p /opt/benchmarks
mkdir -p /opt/results
mkdir -p /opt/jmeter-tests

chown -R ubuntu:ubuntu /opt/benchmarks
chown -R ubuntu:ubuntu /opt/results
chown -R ubuntu:ubuntu /opt/jmeter-tests

# ------------------------------------------------------------------------------
# Create JMeter Test Plans for Research
# As per research methodology: static and compute endpoints, 50/200/500 users
# ------------------------------------------------------------------------------
echo "=== Creating JMeter test plans ==="

# Static Endpoint Test Plan (I/O-bound workload)
cat > /opt/jmeter-tests/static-endpoint-test.jmx << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<jmeterTestPlan version="1.2" properties="5.0" jmeter="5.6.3">
  <hashTree>
    <TestPlan guiclass="TestPlanGui" testclass="TestPlan" testname="Static Endpoint Test Plan" enabled="true">
      <stringProp name="TestPlan.comments">Research: Docker vs VM - Static/I/O-bound workload test</stringProp>
      <boolProp name="TestPlan.functional_mode">false</boolProp>
      <boolProp name="TestPlan.tearDown_on_shutdown">true</boolProp>
      <boolProp name="TestPlan.serialize_threadgroups">false</boolProp>
      <elementProp name="TestPlan.user_defined_variables" elementType="Arguments">
        <collectionProp name="Arguments.arguments">
          <elementProp name="TARGET_HOST" elementType="Argument">
            <stringProp name="Argument.name">TARGET_HOST</stringProp>
            <stringProp name="Argument.value">${__P(target.host,localhost)}</stringProp>
          </elementProp>
          <elementProp name="TARGET_PORT" elementType="Argument">
            <stringProp name="Argument.name">TARGET_PORT</stringProp>
            <stringProp name="Argument.value">${__P(target.port,3000)}</stringProp>
          </elementProp>
          <elementProp name="THREADS" elementType="Argument">
            <stringProp name="Argument.name">THREADS</stringProp>
            <stringProp name="Argument.value">${__P(threads,50)}</stringProp>
          </elementProp>
          <elementProp name="RAMP_UP" elementType="Argument">
            <stringProp name="Argument.name">RAMP_UP</stringProp>
            <stringProp name="Argument.value">${__P(rampup,60)}</stringProp>
          </elementProp>
          <elementProp name="DURATION" elementType="Argument">
            <stringProp name="Argument.name">DURATION</stringProp>
            <stringProp name="Argument.value">${__P(duration,300)}</stringProp>
          </elementProp>
        </collectionProp>
      </elementProp>
    </TestPlan>
    <hashTree>
      <ThreadGroup guiclass="ThreadGroupGui" testclass="ThreadGroup" testname="Static Endpoint Users" enabled="true">
        <stringProp name="ThreadGroup.on_sample_error">continue</stringProp>
        <elementProp name="ThreadGroup.main_controller" elementType="LoopController">
          <boolProp name="LoopController.continue_forever">false</boolProp>
          <intProp name="LoopController.loops">-1</intProp>
        </elementProp>
        <stringProp name="ThreadGroup.num_threads">${THREADS}</stringProp>
        <stringProp name="ThreadGroup.ramp_time">${RAMP_UP}</stringProp>
        <boolProp name="ThreadGroup.scheduler">true</boolProp>
        <stringProp name="ThreadGroup.duration">${DURATION}</stringProp>
        <stringProp name="ThreadGroup.delay">0</stringProp>
      </ThreadGroup>
      <hashTree>
        <HTTPSamplerProxy guiclass="HttpTestSampleGui" testclass="HTTPSamplerProxy" testname="GET /api/static" enabled="true">
          <elementProp name="HTTPsampler.Arguments" elementType="Arguments">
            <collectionProp name="Arguments.arguments"/>
          </elementProp>
          <stringProp name="HTTPSampler.domain">${TARGET_HOST}</stringProp>
          <stringProp name="HTTPSampler.port">${TARGET_PORT}</stringProp>
          <stringProp name="HTTPSampler.protocol">http</stringProp>
          <stringProp name="HTTPSampler.path">/api/static</stringProp>
          <stringProp name="HTTPSampler.method">GET</stringProp>
          <boolProp name="HTTPSampler.follow_redirects">true</boolProp>
          <boolProp name="HTTPSampler.use_keepalive">true</boolProp>
        </HTTPSamplerProxy>
        <hashTree/>
        <ResultCollector guiclass="SummaryReport" testclass="ResultCollector" testname="Summary Report" enabled="true">
          <boolProp name="ResultCollector.error_logging">false</boolProp>
          <objProp>
            <name>saveConfig</name>
            <value class="SampleSaveConfiguration">
              <time>true</time>
              <latency>true</latency>
              <timestamp>true</timestamp>
              <success>true</success>
              <label>true</label>
              <code>true</code>
              <message>true</message>
              <threadName>true</threadName>
              <dataType>true</dataType>
              <encoding>false</encoding>
              <assertions>true</assertions>
              <subresults>true</subresults>
              <responseData>false</responseData>
              <samplerData>false</samplerData>
              <xml>false</xml>
              <fieldNames>true</fieldNames>
              <responseHeaders>false</responseHeaders>
              <requestHeaders>false</requestHeaders>
              <responseDataOnError>false</responseDataOnError>
              <saveAssertionResultsFailureMessage>true</saveAssertionResultsFailureMessage>
              <bytes>true</bytes>
              <sentBytes>true</sentBytes>
              <url>true</url>
              <threadCounts>true</threadCounts>
              <idleTime>true</idleTime>
              <connectTime>true</connectTime>
            </value>
          </objProp>
          <stringProp name="filename"></stringProp>
        </ResultCollector>
        <hashTree/>
      </hashTree>
    </hashTree>
  </hashTree>
</jmeterTestPlan>
EOF

# Compute Endpoint Test Plan (CPU-bound workload)
cat > /opt/jmeter-tests/compute-endpoint-test.jmx << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<jmeterTestPlan version="1.2" properties="5.0" jmeter="5.6.3">
  <hashTree>
    <TestPlan guiclass="TestPlanGui" testclass="TestPlan" testname="Compute Endpoint Test Plan" enabled="true">
      <stringProp name="TestPlan.comments">Research: Docker vs VM - Compute/CPU-bound workload test</stringProp>
      <boolProp name="TestPlan.functional_mode">false</boolProp>
      <boolProp name="TestPlan.tearDown_on_shutdown">true</boolProp>
      <boolProp name="TestPlan.serialize_threadgroups">false</boolProp>
      <elementProp name="TestPlan.user_defined_variables" elementType="Arguments">
        <collectionProp name="Arguments.arguments">
          <elementProp name="TARGET_HOST" elementType="Argument">
            <stringProp name="Argument.name">TARGET_HOST</stringProp>
            <stringProp name="Argument.value">${__P(target.host,localhost)}</stringProp>
          </elementProp>
          <elementProp name="TARGET_PORT" elementType="Argument">
            <stringProp name="Argument.name">TARGET_PORT</stringProp>
            <stringProp name="Argument.value">${__P(target.port,3000)}</stringProp>
          </elementProp>
          <elementProp name="THREADS" elementType="Argument">
            <stringProp name="Argument.name">THREADS</stringProp>
            <stringProp name="Argument.value">${__P(threads,50)}</stringProp>
          </elementProp>
          <elementProp name="RAMP_UP" elementType="Argument">
            <stringProp name="Argument.name">RAMP_UP</stringProp>
            <stringProp name="Argument.value">${__P(rampup,60)}</stringProp>
          </elementProp>
          <elementProp name="DURATION" elementType="Argument">
            <stringProp name="Argument.name">DURATION</stringProp>
            <stringProp name="Argument.value">${__P(duration,300)}</stringProp>
          </elementProp>
        </collectionProp>
      </elementProp>
    </TestPlan>
    <hashTree>
      <ThreadGroup guiclass="ThreadGroupGui" testclass="ThreadGroup" testname="Compute Endpoint Users" enabled="true">
        <stringProp name="ThreadGroup.on_sample_error">continue</stringProp>
        <elementProp name="ThreadGroup.main_controller" elementType="LoopController">
          <boolProp name="LoopController.continue_forever">false</boolProp>
          <intProp name="LoopController.loops">-1</intProp>
        </elementProp>
        <stringProp name="ThreadGroup.num_threads">${THREADS}</stringProp>
        <stringProp name="ThreadGroup.ramp_time">${RAMP_UP}</stringProp>
        <boolProp name="ThreadGroup.scheduler">true</boolProp>
        <stringProp name="ThreadGroup.duration">${DURATION}</stringProp>
        <stringProp name="ThreadGroup.delay">0</stringProp>
      </ThreadGroup>
      <hashTree>
        <HTTPSamplerProxy guiclass="HttpTestSampleGui" testclass="HTTPSamplerProxy" testname="GET /api/compute" enabled="true">
          <elementProp name="HTTPsampler.Arguments" elementType="Arguments">
            <collectionProp name="Arguments.arguments">
              <elementProp name="n" elementType="HTTPArgument">
                <boolProp name="HTTPArgument.always_encode">false</boolProp>
                <stringProp name="Argument.value">35</stringProp>
                <stringProp name="Argument.metadata">=</stringProp>
                <boolProp name="HTTPArgument.use_equals">true</boolProp>
                <stringProp name="Argument.name">n</stringProp>
              </elementProp>
            </collectionProp>
          </elementProp>
          <stringProp name="HTTPSampler.domain">${TARGET_HOST}</stringProp>
          <stringProp name="HTTPSampler.port">${TARGET_PORT}</stringProp>
          <stringProp name="HTTPSampler.protocol">http</stringProp>
          <stringProp name="HTTPSampler.path">/api/compute</stringProp>
          <stringProp name="HTTPSampler.method">GET</stringProp>
          <boolProp name="HTTPSampler.follow_redirects">true</boolProp>
          <boolProp name="HTTPSampler.use_keepalive">true</boolProp>
        </HTTPSamplerProxy>
        <hashTree/>
        <ResultCollector guiclass="SummaryReport" testclass="ResultCollector" testname="Summary Report" enabled="true">
          <boolProp name="ResultCollector.error_logging">false</boolProp>
          <objProp>
            <name>saveConfig</name>
            <value class="SampleSaveConfiguration">
              <time>true</time>
              <latency>true</latency>
              <timestamp>true</timestamp>
              <success>true</success>
              <label>true</label>
              <code>true</code>
              <message>true</message>
              <threadName>true</threadName>
              <dataType>true</dataType>
              <encoding>false</encoding>
              <assertions>true</assertions>
              <subresults>true</subresults>
              <responseData>false</responseData>
              <samplerData>false</samplerData>
              <xml>false</xml>
              <fieldNames>true</fieldNames>
              <responseHeaders>false</responseHeaders>
              <requestHeaders>false</requestHeaders>
              <responseDataOnError>false</responseDataOnError>
              <saveAssertionResultsFailureMessage>true</saveAssertionResultsFailureMessage>
              <bytes>true</bytes>
              <sentBytes>true</sentBytes>
              <url>true</url>
              <threadCounts>true</threadCounts>
              <idleTime>true</idleTime>
              <connectTime>true</connectTime>
            </value>
          </objProp>
          <stringProp name="filename"></stringProp>
        </ResultCollector>
        <hashTree/>
      </hashTree>
    </hashTree>
  </hashTree>
</jmeterTestPlan>
EOF

# ------------------------------------------------------------------------------
# Create Benchmark Runner Script
# Automates running tests at 50, 200, and 500 concurrent users
# ------------------------------------------------------------------------------
echo "=== Creating benchmark runner script ==="

cat > /opt/benchmarks/run-benchmarks.sh << 'BENCHMARKSCRIPT'
#!/bin/bash
# =============================================================================
# Research Benchmark Runner
# Runs JMeter tests against Docker and VM targets at different concurrency levels
# =============================================================================

set -e

# Configuration
JMETER_HOME="/opt/jmeter"
TEST_DIR="/opt/jmeter-tests"
RESULTS_DIR="/opt/results"
WARMUP_DURATION=60  # 60 seconds warmup
TEST_DURATION=300   # 300 seconds test

# Parse arguments
TARGET_HOST="${1:-localhost}"
TARGET_PORT="${2:-3000}"
TEST_NAME="${3:-docker}"  # docker or vm

echo "=== Research Benchmark Runner ==="
echo "Target: ${TARGET_HOST}:${TARGET_PORT}"
echo "Test Name: ${TEST_NAME}"
echo "Warmup: ${WARMUP_DURATION}s, Test Duration: ${TEST_DURATION}s"
echo ""

# Create results directory
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULT_DIR="${RESULTS_DIR}/${TEST_NAME}_${TIMESTAMP}"
mkdir -p "$RESULT_DIR"

# Concurrency levels as per research paper
CONCURRENCY_LEVELS=(50 200 500)

# Test both static (I/O-bound) and compute (CPU-bound) workloads
WORKLOADS=("static" "compute")

for WORKLOAD in "${WORKLOADS[@]}"; do
    echo ""
    echo "=== Testing ${WORKLOAD} workload ==="

    for THREADS in "${CONCURRENCY_LEVELS[@]}"; do
        echo ""
        echo "--- Running ${WORKLOAD} test with ${THREADS} concurrent users ---"

        # Run 5 iterations as per research methodology
        for ITERATION in $(seq 1 5); do
            echo "Iteration ${ITERATION}/5"

            OUTPUT_FILE="${RESULT_DIR}/${WORKLOAD}_${THREADS}users_iter${ITERATION}"

            # Run JMeter test
            $JMETER_HOME/bin/jmeter -n \
                -t "${TEST_DIR}/${WORKLOAD}-endpoint-test.jmx" \
                -Jtarget.host="${TARGET_HOST}" \
                -Jtarget.port="${TARGET_PORT}" \
                -Jthreads="${THREADS}" \
                -Jrampup="${WARMUP_DURATION}" \
                -Jduration="${TEST_DURATION}" \
                -l "${OUTPUT_FILE}.jtl" \
                -j "${OUTPUT_FILE}.log" \
                -e -o "${OUTPUT_FILE}_report"

            echo "Results saved to ${OUTPUT_FILE}"

            # Brief pause between iterations
            sleep 10
        done
    done
done

echo ""
echo "=== All benchmarks completed ==="
echo "Results directory: ${RESULT_DIR}"

# Generate summary
echo ""
echo "=== Generating Summary ==="
cat > "${RESULT_DIR}/summary.txt" << EOF
Research Benchmark Summary
==========================
Target: ${TARGET_HOST}:${TARGET_PORT}
Test Name: ${TEST_NAME}
Date: $(date)

Workloads tested: static (I/O-bound), compute (CPU-bound)
Concurrency levels: 50, 200, 500 users
Iterations per test: 5
Warmup duration: ${WARMUP_DURATION}s
Test duration: ${TEST_DURATION}s

Results files:
$(ls -la ${RESULT_DIR}/*.jtl 2>/dev/null || echo "No JTL files found")

To analyze results, use JMeter's report generation:
  jmeter -g <file>.jtl -o <output_directory>
EOF

cat "${RESULT_DIR}/summary.txt"
BENCHMARKSCRIPT

chmod +x /opt/benchmarks/run-benchmarks.sh

# ------------------------------------------------------------------------------
# Create Docker Startup Time Measurement Script
# Separate from VM measurement for consistency
# ------------------------------------------------------------------------------
cat > /opt/benchmarks/measure-docker-startup.sh << 'DOCKERSTARTUP'
#!/bin/bash
# Measure Docker container startup time until application is ready
# As per research methodology: time until HTTP health endpoint returns 200

DOCKER_HOST="${1:-localhost}"
TRIALS="${2:-30}"
OUTPUT_FILE="${3:-/opt/results/docker_startup_times.csv}"

echo "trial,startup_time_ms" > "$OUTPUT_FILE"

for i in $(seq 1 $TRIALS); do
    echo "Trial $i of $TRIALS"

    # Remove existing container
    ssh ubuntu@"$DOCKER_HOST" "docker rm -f research-app 2>/dev/null" || true
    sleep 1

    # Record start time in milliseconds
    START_TIME=$(date +%s%3N)

    # Start the container
    ssh ubuntu@"$DOCKER_HOST" "docker run -d --name research-app --cpus=4 --memory=8g -p 3000:3000 research-app:latest"

    # Wait for HTTP health endpoint to respond
    while ! curl -s --connect-timeout 1 "http://${DOCKER_HOST}:3000/health" > /dev/null 2>&1; do
        sleep 0.1
    done

    # Record end time
    END_TIME=$(date +%s%3N)

    # Calculate duration in milliseconds
    DURATION=$((END_TIME - START_TIME))

    echo "$i,$DURATION" >> "$OUTPUT_FILE"
    echo "Trial $i: ${DURATION}ms"

    # Stop container for next trial
    ssh ubuntu@"$DOCKER_HOST" "docker stop research-app" || true
    sleep 2
done

echo "Results saved to $OUTPUT_FILE"

# Calculate statistics
echo ""
echo "=== Startup Time Statistics ==="
awk -F',' 'NR>1 {
    sum += $2;
    sumsq += $2*$2;
    if (NR==2 || $2 < min) min = $2;
    if (NR==2 || $2 > max) max = $2;
    count++;
}
END {
    mean = sum/count;
    stddev = sqrt(sumsq/count - mean*mean);
    printf "Mean: %.2f ms\n", mean;
    printf "Std Dev: %.2f ms\n", stddev;
    printf "Min: %.2f ms\n", min;
    printf "Max: %.2f ms\n", max;
}' "$OUTPUT_FILE"
DOCKERSTARTUP

chmod +x /opt/benchmarks/measure-docker-startup.sh

# ------------------------------------------------------------------------------
# Create Results Aggregation Script
# ------------------------------------------------------------------------------
cat > /opt/benchmarks/aggregate-results.sh << 'AGGREGATE'
#!/bin/bash
# Aggregate JMeter results and calculate statistics
# Outputs CSV summary matching research paper metrics

RESULTS_DIR="${1:-/opt/results}"
OUTPUT_FILE="${2:-${RESULTS_DIR}/aggregated_results.csv}"

echo "environment,workload,users,avg_throughput,avg_response_time,p95_response_time,error_rate" > "$OUTPUT_FILE"

for ENV_DIR in "$RESULTS_DIR"/docker_* "$RESULTS_DIR"/vm_*; do
    if [ -d "$ENV_DIR" ]; then
        ENV_NAME=$(basename "$ENV_DIR" | cut -d'_' -f1)

        for JTL_FILE in "$ENV_DIR"/*.jtl; do
            if [ -f "$JTL_FILE" ]; then
                FILENAME=$(basename "$JTL_FILE" .jtl)
                WORKLOAD=$(echo "$FILENAME" | cut -d'_' -f1)
                USERS=$(echo "$FILENAME" | grep -oE '[0-9]+users' | grep -oE '[0-9]+')

                # Calculate metrics from JTL file
                # Note: JTL files are CSV format with headers
                awk -F',' 'NR>1 {
                    total_time += $2;
                    count++;
                    times[count] = $2;
                    if ($8 != "true") errors++;
                }
                END {
                    if (count > 0) {
                        avg_time = total_time / count;
                        n = asort(times);
                        p95_idx = int(n * 0.95);
                        p95_time = times[p95_idx];
                        error_rate = (errors / count) * 100;
                        # Throughput calculated as requests per second
                        # Assuming timestamps are in milliseconds
                        throughput = count / (DURATION * 1000);
                        printf "%s,%s,%s,%.2f,%.2f,%.2f,%.2f\n",
                            ENV, WORKLOAD, USERS, throughput, avg_time, p95_time, error_rate;
                    }
                }' ENV="$ENV_NAME" WORKLOAD="$WORKLOAD" USERS="$USERS" DURATION=300 "$JTL_FILE" >> "$OUTPUT_FILE"
            fi
        done
    fi
done

echo "Aggregated results saved to $OUTPUT_FILE"
AGGREGATE

chmod +x /opt/benchmarks/aggregate-results.sh

chown -R ubuntu:ubuntu /opt/benchmarks
chown -R ubuntu:ubuntu /opt/results
chown -R ubuntu:ubuntu /opt/jmeter-tests

echo "=== Load Generator Setup Complete at $(date) ==="
echo "JMeter version: $($JMETER_HOME/bin/jmeter --version 2>&1 | head -5)"
echo "Java version: $(java -version 2>&1 | head -1)"
echo ""
echo "Usage:"
echo "  Run benchmarks against Docker host:"
echo "    /opt/benchmarks/run-benchmarks.sh <docker-host-ip> 3000 docker"
echo ""
echo "  Run benchmarks against VM:"
echo "    /opt/benchmarks/run-benchmarks.sh <vm-ip> 3000 vm"
echo ""
echo "  Measure Docker startup time:"
echo "    /opt/benchmarks/measure-docker-startup.sh <docker-host-ip> 30"
