#!/bin/bash
# =============================================================================
# Docker Host Setup Script
# Research: Comparative Analysis of Docker Containers vs Virtual Machines
# =============================================================================
# This script sets up the Docker host environment as per research methodology
# Ubuntu 22.04 LTS with Docker Engine 24.x and Node.js 18 LTS
# =============================================================================

set -e

exec > >(tee /var/log/docker-host-setup.log) 2>&1
echo "=== Starting Docker Host Setup at $(date) ==="

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
    unzip

# ------------------------------------------------------------------------------
# Docker Engine Installation (Version 24.x as per research paper)
# ------------------------------------------------------------------------------
echo "=== Installing Docker Engine ==="

# Add Docker's official GPG key
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

# Add Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Enable and start Docker
systemctl enable docker
systemctl start docker

# Add ubuntu user to docker group
usermod -aG docker ubuntu

# Verify Docker installation
docker --version

# ------------------------------------------------------------------------------
# Node.js 18 LTS Installation (as per research paper)
# ------------------------------------------------------------------------------
echo "=== Installing Node.js 18 LTS ==="

curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs

# Verify Node.js installation
node --version
npm --version

# ------------------------------------------------------------------------------
# Performance Monitoring Tools Setup
# Required for collecting CPU, memory, disk I/O, and network metrics
# ------------------------------------------------------------------------------
echo "=== Setting up monitoring tools ==="

# Install additional monitoring tools
apt-get install -y \
    dstat \
    nmon \
    collectl \
    linux-tools-common \
    linux-tools-generic \
    linux-tools-$(uname -r) || true

# Enable sysstat collection
sed -i 's/ENABLED="false"/ENABLED="true"/' /etc/default/sysstat
systemctl enable sysstat
systemctl start sysstat

# ------------------------------------------------------------------------------
# System Tuning for Research Benchmarks
# Optimize for consistent, reproducible measurements
# ------------------------------------------------------------------------------
echo "=== Applying system performance tuning ==="

# Increase file descriptor limits
cat >> /etc/security/limits.conf << EOF
* soft nofile 65535
* hard nofile 65535
* soft nproc 65535
* hard nproc 65535
EOF

# Network tuning for high-throughput testing
cat >> /etc/sysctl.conf << EOF
# Network performance tuning for benchmarks
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

# ------------------------------------------------------------------------------
# Create Research Application Directory
# ------------------------------------------------------------------------------
echo "=== Creating application directory structure ==="

mkdir -p /opt/research-app
mkdir -p /opt/benchmarks
mkdir -p /opt/results

chown -R ubuntu:ubuntu /opt/research-app
chown -R ubuntu:ubuntu /opt/benchmarks
chown -R ubuntu:ubuntu /opt/results

# ------------------------------------------------------------------------------
# Create Sample Node.js Application (as described in research paper)
# Express 4.18 with static and compute-intensive endpoints
# ------------------------------------------------------------------------------
echo "=== Creating research web application ==="

cat > /opt/research-app/package.json << 'EOF'
{
  "name": "docker-vm-research-app",
  "version": "1.0.0",
  "description": "Research web application for Docker vs VM comparison",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "node --watch server.js"
  },
  "dependencies": {
    "express": "^4.18.2"
  }
}
EOF

cat > /opt/research-app/server.js << 'EOF'
/**
 * Research Web Application
 * Comparative Analysis of Docker Containers vs Virtual Machines
 *
 * This application implements:
 * 1. Static file endpoint - serving 50KB JSON payload (I/O-bound)
 * 2. Compute-intensive endpoint - Fibonacci calculation n=35 (CPU-bound)
 */

const express = require('express');
const os = require('os');

const app = express();
const PORT = process.env.PORT || 3000;

// Generate a 50KB JSON payload for static endpoint testing
const generatePayload = () => {
  const items = [];
  for (let i = 0; i < 500; i++) {
    items.push({
      id: i,
      name: `Item ${i}`,
      description: `This is a sample item description for item number ${i}. It contains some text to increase the payload size.`,
      timestamp: new Date().toISOString(),
      metadata: {
        category: `category-${i % 10}`,
        tags: [`tag-${i % 5}`, `tag-${(i + 1) % 5}`, `tag-${(i + 2) % 5}`],
        score: Math.random() * 100
      }
    });
  }
  return items;
};

const staticPayload = generatePayload();

// Fibonacci calculation for CPU-bound testing
const fibonacci = (n) => {
  if (n <= 1) return n;
  return fibonacci(n - 1) + fibonacci(n - 2);
};

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    hostname: os.hostname(),
    platform: process.platform,
    nodeVersion: process.version,
    uptime: process.uptime()
  });
});

// Static endpoint - I/O-bound workload (50KB JSON payload)
app.get('/api/static', (req, res) => {
  res.json({
    success: true,
    data: staticPayload,
    metadata: {
      count: staticPayload.length,
      generatedAt: new Date().toISOString()
    }
  });
});

// Compute-intensive endpoint - CPU-bound workload (Fibonacci n=35)
app.get('/api/compute', (req, res) => {
  const n = parseInt(req.query.n) || 35;
  const startTime = process.hrtime.bigint();

  const result = fibonacci(n);

  const endTime = process.hrtime.bigint();
  const executionTimeMs = Number(endTime - startTime) / 1000000;

  res.json({
    success: true,
    input: n,
    result: result,
    executionTimeMs: executionTimeMs,
    hostname: os.hostname()
  });
});

// System info endpoint for verification
app.get('/api/system', (req, res) => {
  res.json({
    hostname: os.hostname(),
    platform: process.platform,
    arch: os.arch(),
    cpus: os.cpus().length,
    totalMemory: os.totalmem(),
    freeMemory: os.freemem(),
    uptime: os.uptime(),
    loadAverage: os.loadavg(),
    nodeVersion: process.version
  });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Research application running on port ${PORT}`);
  console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`Hostname: ${os.hostname()}`);
  console.log(`CPUs: ${os.cpus().length}`);
  console.log(`Total Memory: ${Math.round(os.totalmem() / 1024 / 1024)} MB`);
});
EOF

# Install dependencies
cd /opt/research-app
npm install

chown -R ubuntu:ubuntu /opt/research-app

# ------------------------------------------------------------------------------
# Create Dockerfile for the research application
# ------------------------------------------------------------------------------
echo "=== Creating Dockerfile ==="

cat > /opt/research-app/Dockerfile << 'EOF'
# Research Application Docker Image
# Based on official node:18-alpine as specified in the research paper
FROM node:18-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production

# Copy application code
COPY server.js ./

# Expose application port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/health || exit 1

# Run as non-root user for security
USER node

# Start the application
CMD ["node", "server.js"]
EOF

# Build the Docker image
cd /opt/research-app
docker build -t research-app:latest .

# ------------------------------------------------------------------------------
# Create Metrics Collection Script
# For collecting CPU, memory, disk I/O metrics during tests
# ------------------------------------------------------------------------------
echo "=== Creating metrics collection scripts ==="

cat > /opt/benchmarks/collect-metrics.sh << 'EOF'
#!/bin/bash
# Metrics collection script for research benchmarks
# Collects: CPU utilization, memory consumption, disk IOPS, network throughput

OUTPUT_DIR="${1:-/opt/results}"
DURATION="${2:-300}"
INTERVAL="${3:-1}"

mkdir -p "$OUTPUT_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "Starting metrics collection for $DURATION seconds at $INTERVAL second intervals"

# CPU and Memory metrics
sar -u -r $INTERVAL $((DURATION/INTERVAL)) > "$OUTPUT_DIR/cpu_memory_${TIMESTAMP}.log" &
SAR_PID=$!

# Disk I/O metrics
iostat -x $INTERVAL $((DURATION/INTERVAL)) > "$OUTPUT_DIR/disk_io_${TIMESTAMP}.log" &
IOSTAT_PID=$!

# Network metrics
sar -n DEV $INTERVAL $((DURATION/INTERVAL)) > "$OUTPUT_DIR/network_${TIMESTAMP}.log" &
NET_PID=$!

# Docker-specific metrics (if container is running)
if docker ps | grep -q research-app; then
  docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}" research-app > "$OUTPUT_DIR/docker_stats_${TIMESTAMP}.log" &
fi

echo "Metrics collection started. PIDs: SAR=$SAR_PID, IOSTAT=$IOSTAT_PID, NET=$NET_PID"
echo "Results will be saved to $OUTPUT_DIR"

# Wait for all collectors to finish
wait

echo "Metrics collection completed at $(date)"
EOF

chmod +x /opt/benchmarks/collect-metrics.sh
chown -R ubuntu:ubuntu /opt/benchmarks

# ------------------------------------------------------------------------------
# Create Systemd Service for Research App
# ------------------------------------------------------------------------------
cat > /etc/systemd/system/research-app.service << 'EOF'
[Unit]
Description=Research Web Application (Docker)
After=docker.service
Requires=docker.service

[Service]
Type=simple
User=ubuntu
ExecStartPre=-/usr/bin/docker stop research-app
ExecStartPre=-/usr/bin/docker rm research-app
ExecStart=/usr/bin/docker run --name research-app \
    --cpus=4 \
    --memory=8g \
    -p 3000:3000 \
    research-app:latest
ExecStop=/usr/bin/docker stop research-app
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload

echo "=== Docker Host Setup Complete at $(date) ==="
echo "Docker version: $(docker --version)"
echo "Node.js version: $(node --version)"
echo ""
echo "To start the application in Docker:"
echo "  docker run --cpus=4 --memory=8g -p 3000:3000 research-app:latest"
echo ""
echo "Or use systemd service:"
echo "  sudo systemctl start research-app"
