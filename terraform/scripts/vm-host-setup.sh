#!/bin/bash
# =============================================================================
# KVM/VM Host Setup Script
# Research: Comparative Analysis of Docker Containers vs Virtual Machines
# =============================================================================
# This script sets up the KVM host environment as per research methodology
# Ubuntu 22.04 LTS with KVM/QEMU 7.x for virtual machine management
# =============================================================================

set -e

exec > >(tee /var/log/vm-host-setup.log) 2>&1
echo "=== Starting KVM/VM Host Setup at $(date) ==="

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
    wget

# ------------------------------------------------------------------------------
# KVM/QEMU Installation
# As specified in research paper: KVM/QEMU 7.0 for VM management
# ------------------------------------------------------------------------------
echo "=== Installing KVM/QEMU ==="

apt-get install -y \
    qemu-kvm \
    qemu-utils \
    libvirt-daemon-system \
    libvirt-clients \
    bridge-utils \
    virtinst \
    virt-manager \
    cloud-image-utils \
    genisoimage

# Enable and start libvirtd
systemctl enable libvirtd
systemctl start libvirtd

# Add ubuntu user to required groups
usermod -aG libvirt ubuntu
usermod -aG kvm ubuntu

# Verify KVM is available
if [ -e /dev/kvm ]; then
    echo "KVM acceleration is available"
else
    echo "WARNING: KVM acceleration not available - will use software emulation"
fi

# Check QEMU version
qemu-system-x86_64 --version

# ------------------------------------------------------------------------------
# Node.js 18 LTS Installation (for running app directly for comparison)
# ------------------------------------------------------------------------------
echo "=== Installing Node.js 18 LTS ==="

curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs

node --version
npm --version

# ------------------------------------------------------------------------------
# Performance Monitoring Tools Setup
# ------------------------------------------------------------------------------
echo "=== Setting up monitoring tools ==="

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
# System Tuning for KVM Performance
# ------------------------------------------------------------------------------
echo "=== Applying system performance tuning ==="

# Increase file descriptor limits
cat >> /etc/security/limits.conf << EOF
* soft nofile 65535
* hard nofile 65535
* soft nproc 65535
* hard nproc 65535
EOF

# Network tuning
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

# KVM performance tuning
vm.swappiness = 10
net.bridge.bridge-nf-call-iptables = 0
net.bridge.bridge-nf-call-arptables = 0
net.bridge.bridge-nf-call-ip6tables = 0
EOF

sysctl -p || true

# ------------------------------------------------------------------------------
# Create Research Directories
# ------------------------------------------------------------------------------
echo "=== Creating directory structure ==="

mkdir -p /opt/research-app
mkdir -p /opt/benchmarks
mkdir -p /opt/results
mkdir -p /var/lib/libvirt/images/research
mkdir -p /opt/vm-images

chown -R ubuntu:ubuntu /opt/research-app
chown -R ubuntu:ubuntu /opt/benchmarks
chown -R ubuntu:ubuntu /opt/results

# ------------------------------------------------------------------------------
# Download Ubuntu 22.04 Cloud Image for VM Creation
# ------------------------------------------------------------------------------
echo "=== Downloading Ubuntu 22.04 cloud image ==="

cd /opt/vm-images

# Download Ubuntu 22.04 cloud image
if [ ! -f ubuntu-22.04-server-cloudimg-amd64.img ]; then
    wget -q https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img \
        -O ubuntu-22.04-server-cloudimg-amd64.img
fi

# ------------------------------------------------------------------------------
# Create VM Setup Script
# As per research paper: 4 vCPUs, 8GB RAM, 40GB virtio disk
# ------------------------------------------------------------------------------
echo "=== Creating VM provisioning scripts ==="

cat > /opt/benchmarks/create-research-vm.sh << 'VMSCRIPT'
#!/bin/bash
# Create a KVM VM for research benchmarks
# Configuration as per research paper: 4 vCPUs, 8GB RAM, 40GB disk

VM_NAME="${1:-research-vm}"
VCPUS="${2:-4}"
MEMORY="${3:-8192}"
DISK_SIZE="${4:-40G}"

VM_IMAGE_DIR="/var/lib/libvirt/images/research"
CLOUD_IMAGE="/opt/vm-images/ubuntu-22.04-server-cloudimg-amd64.img"

# Create VM disk from cloud image
echo "Creating VM disk image..."
qemu-img create -f qcow2 -F qcow2 -b "$CLOUD_IMAGE" "$VM_IMAGE_DIR/${VM_NAME}.qcow2" "$DISK_SIZE"

# Create cloud-init configuration
echo "Creating cloud-init configuration..."
cat > /tmp/${VM_NAME}-cloud-init.yaml << EOF
#cloud-config
hostname: ${VM_NAME}
users:
  - name: ubuntu
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys:
      - $(cat /home/ubuntu/.ssh/authorized_keys 2>/dev/null || echo "ssh-rsa PLACEHOLDER")
packages:
  - nodejs
  - npm
  - htop
  - sysstat
  - iotop
  - net-tools
runcmd:
  - curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
  - apt-get install -y nodejs
  - mkdir -p /opt/research-app
  - chown ubuntu:ubuntu /opt/research-app
  - sed -i 's/ENABLED="false"/ENABLED="true"/' /etc/default/sysstat
  - systemctl enable sysstat
  - systemctl start sysstat
EOF

# Create cloud-init ISO
cloud-localds /tmp/${VM_NAME}-cloud-init.iso /tmp/${VM_NAME}-cloud-init.yaml

# Create the VM with CPU pinning for consistent benchmarks
echo "Creating VM with virt-install..."
virt-install \
    --name "$VM_NAME" \
    --memory "$MEMORY" \
    --vcpus "$VCPUS" \
    --disk "$VM_IMAGE_DIR/${VM_NAME}.qcow2",device=disk,bus=virtio \
    --disk /tmp/${VM_NAME}-cloud-init.iso,device=cdrom \
    --os-variant ubuntu22.04 \
    --network network=default,model=virtio \
    --graphics none \
    --console pty,target_type=serial \
    --import \
    --noautoconsole \
    --cpu host-passthrough

echo "VM '$VM_NAME' created successfully!"
echo "To check status: virsh list --all"
echo "To get IP address: virsh domifaddr $VM_NAME"
echo "To connect: virsh console $VM_NAME"
VMSCRIPT

chmod +x /opt/benchmarks/create-research-vm.sh

# ------------------------------------------------------------------------------
# Create VM Startup Time Measurement Script
# As per research methodology: measure time until HTTP health endpoint returns 200
# ------------------------------------------------------------------------------
cat > /opt/benchmarks/measure-vm-startup.sh << 'STARTUPMEASURE'
#!/bin/bash
# Measure VM startup time until application is ready
# As per research methodology: time until HTTP health endpoint returns 200

VM_NAME="${1:-research-vm}"
TRIALS="${2:-30}"
OUTPUT_FILE="${3:-/opt/results/vm_startup_times.csv}"

echo "trial,startup_time_seconds" > "$OUTPUT_FILE"

for i in $(seq 1 $TRIALS); do
    echo "Trial $i of $TRIALS"

    # Destroy existing VM if it exists
    virsh destroy "$VM_NAME" 2>/dev/null || true
    sleep 2

    # Record start time
    START_TIME=$(date +%s.%N)

    # Start the VM
    virsh start "$VM_NAME"

    # Wait for VM to get an IP address
    VM_IP=""
    while [ -z "$VM_IP" ]; do
        sleep 1
        VM_IP=$(virsh domifaddr "$VM_NAME" 2>/dev/null | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1)
    done

    # Wait for HTTP health endpoint to respond
    while ! curl -s --connect-timeout 1 "http://${VM_IP}:3000/health" > /dev/null 2>&1; do
        sleep 0.5
    done

    # Record end time
    END_TIME=$(date +%s.%N)

    # Calculate duration
    DURATION=$(echo "$END_TIME - $START_TIME" | bc)

    echo "$i,$DURATION" >> "$OUTPUT_FILE"
    echo "Trial $i: ${DURATION}s"

    # Stop VM for next trial
    virsh destroy "$VM_NAME" 2>/dev/null || true
    sleep 5
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
    printf "Mean: %.3f seconds\n", mean;
    printf "Std Dev: %.3f seconds\n", stddev;
    printf "Min: %.3f seconds\n", min;
    printf "Max: %.3f seconds\n", max;
}' "$OUTPUT_FILE"
STARTUPMEASURE

chmod +x /opt/benchmarks/measure-vm-startup.sh

# ------------------------------------------------------------------------------
# Create Node.js Application for VM
# Same application as Docker for fair comparison
# ------------------------------------------------------------------------------
echo "=== Creating research application for VM ==="

cat > /opt/research-app/package.json << 'EOF'
{
  "name": "docker-vm-research-app",
  "version": "1.0.0",
  "description": "Research web application for Docker vs VM comparison",
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
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
 */

const express = require('express');
const os = require('os');

const app = express();
const PORT = process.env.PORT || 3000;

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

const fibonacci = (n) => {
  if (n <= 1) return n;
  return fibonacci(n - 1) + fibonacci(n - 2);
};

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
  console.log(`Hostname: ${os.hostname()}`);
  console.log(`CPUs: ${os.cpus().length}`);
  console.log(`Total Memory: ${Math.round(os.totalmem() / 1024 / 1024)} MB`);
});
EOF

cd /opt/research-app
npm install

chown -R ubuntu:ubuntu /opt/research-app
chown -R ubuntu:ubuntu /opt/benchmarks

# ------------------------------------------------------------------------------
# Create Metrics Collection Script for VM Host
# ------------------------------------------------------------------------------
cat > /opt/benchmarks/collect-vm-metrics.sh << 'EOF'
#!/bin/bash
# Metrics collection for KVM VM benchmarks
# Collects both host-level and VM-level metrics

OUTPUT_DIR="${1:-/opt/results}"
VM_NAME="${2:-research-vm}"
DURATION="${3:-300}"
INTERVAL="${4:-1}"

mkdir -p "$OUTPUT_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "Starting VM metrics collection for $DURATION seconds"

# Host-level metrics
sar -u -r $INTERVAL $((DURATION/INTERVAL)) > "$OUTPUT_DIR/host_cpu_memory_${TIMESTAMP}.log" &
iostat -x $INTERVAL $((DURATION/INTERVAL)) > "$OUTPUT_DIR/host_disk_io_${TIMESTAMP}.log" &
sar -n DEV $INTERVAL $((DURATION/INTERVAL)) > "$OUTPUT_DIR/host_network_${TIMESTAMP}.log" &

# VM-specific metrics via virsh
while true; do
    virsh domstats "$VM_NAME" --cpu-total --balloon --interface --block >> "$OUTPUT_DIR/vm_stats_${TIMESTAMP}.log" 2>/dev/null
    sleep $INTERVAL
done &
VMSTATS_PID=$!

# Set up cleanup
trap "kill $VMSTATS_PID 2>/dev/null" EXIT

sleep $DURATION

echo "Metrics collection completed"
EOF

chmod +x /opt/benchmarks/collect-vm-metrics.sh

echo "=== KVM/VM Host Setup Complete at $(date) ==="
echo "QEMU version: $(qemu-system-x86_64 --version | head -1)"
echo "Libvirt version: $(virsh --version)"
echo "Node.js version: $(node --version)"
echo ""
echo "To create a research VM:"
echo "  /opt/benchmarks/create-research-vm.sh research-vm 4 8192 40G"
echo ""
echo "To measure VM startup time:"
echo "  /opt/benchmarks/measure-vm-startup.sh research-vm 30"
