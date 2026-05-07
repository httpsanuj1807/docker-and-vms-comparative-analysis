# Terraform Infrastructure for Docker vs VM Research

This directory contains Terraform configuration for deploying the AWS infrastructure required for the research paper: **"Comparative Analysis of Resource Utilization Between Docker Containers and Virtual Machines Under Web Application Workloads"**

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                            AWS VPC (10.0.0.0/16)                        │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                    Public Subnet (10.0.1.0/24)                   │   │
│  │                                                                   │   │
│  │  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐        │   │
│  │  │  Docker Host  │  │   VM Host     │  │Load Generator │        │   │
│  │  │  (c6i.4xlarge)│  │  (c6i.metal)  │  │ (c6i.2xlarge) │        │   │
│  │  │               │  │               │  │               │        │   │
│  │  │ - Docker 24.x │  │ - KVM/QEMU    │  │ - JMeter 5.6  │        │   │
│  │  │ - Node.js 18  │  │ - libvirt     │  │ - Java 17     │        │   │
│  │  │ - Express 4.18│  │ - Node.js 18  │  │               │        │   │
│  │  └───────────────┘  └───────────────┘  └───────────────┘        │   │
│  │         │                   │                   │                │   │
│  │         └───────────────────┼───────────────────┘                │   │
│  │                             │                                    │   │
│  │                    Internal Network (10Gbps+)                    │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

## Prerequisites

1. **AWS CLI** configured with appropriate credentials
2. **Terraform** >= 1.0.0 installed
3. AWS account with permissions to create:
   - VPC and networking resources
   - EC2 instances (including metal instances)
   - IAM roles and policies
   - EBS volumes

## Quick Start

```bash
# 1. Navigate to terraform directory
cd terraform

# 2. Copy and customize variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your preferred settings

# 3. Initialize Terraform
terraform init

# 4. Review the plan
terraform plan

# 5. Apply the configuration
terraform apply

# 6. Note the output values for connecting to instances
```

## Infrastructure Components

### Docker Host (c6i.4xlarge)
- **Purpose**: Runs containerized workloads
- **Specs**: 16 vCPUs, 32GB RAM, up to 12.5 Gbps network
- **Software**: Docker Engine 24.x, Node.js 18, Express 4.18
- **Storage**: 100GB root + 200GB data volume

### VM Host (c6i.metal)
- **Purpose**: Runs KVM virtual machines
- **Specs**: 128 vCPUs, 256GB RAM, bare metal (required for KVM)
- **Software**: KVM/QEMU, libvirt, Node.js 18
- **Storage**: 100GB root + 500GB for VM images

### Load Generator (c6i.2xlarge)
- **Purpose**: Generates HTTP load using JMeter
- **Specs**: 8 vCPUs, 16GB RAM
- **Software**: Apache JMeter 5.6.3, Java 17
- **Storage**: 100GB root + 200GB for results

## Connecting to Instances

After `terraform apply`, connection instructions will be displayed:

```bash
# Docker Host
ssh -i docker-vm-research-key.pem ubuntu@<docker_host_public_ip>

# VM Host
ssh -i docker-vm-research-key.pem ubuntu@<vm_host_public_ip>

# Load Generator
ssh -i docker-vm-research-key.pem ubuntu@<load_generator_public_ip>
```

## Running Benchmarks

### 1. Start Docker Application

```bash
# SSH to Docker host
ssh -i docker-vm-research-key.pem ubuntu@<docker_host_ip>

# Start the containerized application
docker run -d --name research-app \
    --cpus=4 \
    --memory=8g \
    -p 3000:3000 \
    research-app:latest
```

### 2. Create and Start VM

```bash
# SSH to VM host
ssh -i docker-vm-research-key.pem ubuntu@<vm_host_ip>

# Create the research VM
/opt/benchmarks/create-research-vm.sh research-vm 4 8192 40G

# Start the VM and deploy application
# (See detailed instructions in vm-host)
```

### 3. Run Load Tests

```bash
# SSH to Load Generator
ssh -i docker-vm-research-key.pem ubuntu@<load_generator_ip>

# Run benchmarks against Docker
/opt/benchmarks/run-benchmarks.sh <docker_host_private_ip> 3000 docker

# Run benchmarks against VM
/opt/benchmarks/run-benchmarks.sh <vm_ip> 3000 vm
```

## Benchmark Test Plans

The infrastructure includes JMeter test plans for:

1. **Static Endpoint Test** (`/api/static`)
   - I/O-bound workload
   - 50KB JSON payload
   - Tests at 50, 200, 500 concurrent users

2. **Compute Endpoint Test** (`/api/compute?n=35`)
   - CPU-bound workload
   - Fibonacci calculation (n=35)
   - Tests at 50, 200, 500 concurrent users

## Metrics Collection

### During Tests
```bash
# On target host (Docker or VM host)
/opt/benchmarks/collect-metrics.sh /opt/results 300 1
```

### Startup Time Measurement
```bash
# Docker startup time
/opt/benchmarks/measure-docker-startup.sh <docker_host_ip> 30

# VM startup time
/opt/benchmarks/measure-vm-startup.sh research-vm 30
```

## Cost Considerations

| Component | Instance Type | Hourly Cost |
|-----------|---------------|-------------|
| Docker Host | c6i.4xlarge | ~$0.68 |
| VM Host | c6i.metal | ~$5.44 |
| Load Generator | c6i.2xlarge | ~$0.34 |
| **Total** | | **~$6.50/hour** |

**Tips to reduce costs:**
- Use smaller instances for initial testing
- Stop instances when not in use
- Consider spot instances for non-critical work

## Cleanup

```bash
# Destroy all resources when done
terraform destroy
```

## Directory Structure

```
terraform/
├── provider.tf           # AWS provider configuration
├── variables.tf          # Input variables
├── vpc.tf                # VPC and networking
├── security_groups.tf    # Security group rules
├── ec2_instances.tf      # EC2 instance definitions
├── outputs.tf            # Output values
├── terraform.tfvars.example  # Example variables file
├── README.md             # This file
└── scripts/
    ├── docker-host-setup.sh      # Docker host bootstrap
    ├── vm-host-setup.sh          # KVM host bootstrap
    └── load-generator-setup.sh   # JMeter setup
```

## Research Paper Reference

This infrastructure supports the methodology described in:

> "Comparative Analysis of Resource Utilization Between Docker Containers
> and Virtual Machines Under Web Application Workloads"
>
> Authors: Arham Jain, Ansh Mittal, Anuj Kumar
> Institution: Chitkara University, Punjab, India

### Metrics Measured
1. CPU Utilization
2. Memory Consumption
3. Disk I/O Performance
4. Network Throughput
5. Startup Time

## Troubleshooting

### KVM not available on VM host
Ensure you're using a `.metal` instance type. Regular EC2 instances don't support nested virtualization.

### JMeter out of memory
Increase heap size in `/opt/jmeter/bin/setenv.sh`:
```bash
export HEAP="-Xms4g -Xmx8g"
```

### Network performance issues
Ensure instances are in the same subnet and using placement groups for optimal network performance.

## License

This infrastructure code is part of the research project and is provided for educational and research purposes.
