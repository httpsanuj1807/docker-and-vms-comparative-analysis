# Docker vs Virtual Machines: Comparative Analysis

## Research Paper

**"Comparative Analysis of Resource Utilization Between Docker Containers and Virtual Machines Under Web Application Workloads"**

### Authors
- Arham Jain - arham1337.be22@chitkara.edu.in
- Ansh Mittal - ansh1297.be22@chitkara.edu.in
- Anuj Kumar - anuj1316.be22@chitkara.edu.in

### Institution
Department of Computer Science (CUIET), Chitkara University, Punjab, India

---

## Abstract

This research presents a systematic comparative analysis of resource utilization between Docker containers and KVM-based Virtual Machines under web application workloads. Five key metrics are evaluated:

1. **CPU Utilization** - Docker shows 12-18% reduction in overhead
2. **Memory Consumption** - Up to 40% less memory usage with Docker
3. **Disk I/O Performance** - 22-38% improvement with containers
4. **Network Throughput** - ~23% better throughput with Docker
5. **Startup Time** - ~123x faster container startup

## Repository Structure

```
docker-and-vms-comparative-analysis/
├── app/                       # Web Application
│   ├── server.js             # Express.js application
│   ├── package.json          # Node.js dependencies
│   ├── Dockerfile            # Container image definition
│   ├── docker-compose.yml    # Local development setup
│   └── tests/                # Application tests
├── benchmarks/                # Benchmark Automation
│   ├── scripts/              # Automation scripts
│   │   ├── run-full-benchmark.sh
│   │   ├── measure-startup-time.sh
│   │   ├── collect-metrics.sh
│   │   └── parse-jmeter-results.sh
│   ├── jmeter/               # JMeter test plans
│   │   ├── static-test.jmx
│   │   └── compute-test.jmx
│   └── results/              # Test results (gitignored)
├── terraform/                 # AWS Infrastructure as Code
│   ├── provider.tf           # AWS provider configuration
│   ├── variables.tf          # Input variables
│   ├── vpc.tf                # VPC and networking
│   ├── security_groups.tf    # Security rules
│   ├── ec2_instances.tf      # EC2 instances
│   ├── outputs.tf            # Output values
│   ├── terraform.tfvars.example
│   ├── README.md             # Terraform documentation
│   └── scripts/
│       ├── docker-host-setup.sh
│       ├── vm-host-setup.sh
│       └── load-generator-setup.sh
└── README.md                  # This file
```

## Getting Started

### Prerequisites

- AWS Account with appropriate permissions
- AWS CLI configured
- Terraform >= 1.0.0

### Deploy Infrastructure

```bash
# Navigate to terraform directory
cd terraform

# Initialize and apply
terraform init
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars as needed
terraform apply
```

### Run Benchmarks

1. **Start Docker Application**
   ```bash
   ssh -i docker-vm-research-key.pem ubuntu@<docker_host_ip>
   docker run -d --name research-app --cpus=4 --memory=8g -p 3000:3000 research-app:latest
   ```

2. **Create and Start VM**
   ```bash
   ssh -i docker-vm-research-key.pem ubuntu@<vm_host_ip>
   /opt/benchmarks/create-research-vm.sh research-vm 4 8192 40G
   ```

3. **Run Load Tests**
   ```bash
   ssh -i docker-vm-research-key.pem ubuntu@<load_generator_ip>
   /opt/benchmarks/run-benchmarks.sh <docker_host_private_ip> 3000 docker
   /opt/benchmarks/run-benchmarks.sh <vm_ip> 3000 vm
   ```

## Testbed Configuration

As per research paper methodology:

| Component | Specification |
|-----------|---------------|
| Host CPU | Intel Core i9-12900K (16 cores) |
| Host RAM | 64GB DDR5 |
| Storage | NVMe SSD |
| Network | 10Gbps |
| Host OS | Ubuntu 22.04 LTS |
| Docker | Engine 24.x |
| KVM | QEMU 7.x |
| Application | Node.js 18 + Express 4.18 |
| Load Testing | Apache JMeter 5.6 |

## Research Methodology

### Test Configuration
- **VM Configuration**: 4 vCPUs, 8GB RAM, 40GB virtio disk
- **Container Configuration**: `--cpus=4 --memory=8g`
- **Concurrency Levels**: 50, 200, 500 concurrent users
- **Test Duration**: 60s warmup + 300s test
- **Iterations**: 5 runs per configuration

### Workloads
1. **Static/I/O-bound**: 50KB JSON payload endpoint
2. **Compute/CPU-bound**: Fibonacci(35) calculation

## Key Findings

| Metric | Docker Advantage |
|--------|-----------------|
| CPU Overhead | 12-18% reduction |
| Memory Footprint | ~40% reduction |
| Disk I/O Latency | 38% improvement |
| Network Throughput | 23% improvement |
| Startup Time | 123x faster |

## License

This project is for educational and research purposes.

## References

See the full paper for complete bibliography including works by Felter et al., Morabito et al., Merkel, and others in the field of container and VM performance analysis.
