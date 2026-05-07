# =============================================================================
# Terraform Variables
# Research: Comparative Analysis of Docker Containers vs Virtual Machines
# =============================================================================

variable "aws_region" {
  description = "AWS region for infrastructure deployment"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "docker-vm-research"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR block for private subnet"
  type        = string
  default     = "10.0.2.0/24"
}

# ------------------------------------------------------------------------------
# EC2 Instance Configuration
# Based on research paper testbed: high-performance compute instances
# Target specs: 16+ cores, 64GB RAM, NVMe storage, 10Gbps networking
# ------------------------------------------------------------------------------

variable "docker_host_instance_type" {
  description = "EC2 instance type for Docker host (compute optimized with high network)"
  type        = string
  default     = "c6i.4xlarge" # 16 vCPUs, 32GB RAM, up to 12.5 Gbps network
}

variable "vm_host_instance_type" {
  description = "EC2 instance type for KVM/VM host (metal for nested virtualization)"
  type        = string
  default     = "c6i.metal" # 128 vCPUs, 256GB RAM, bare metal for KVM
}

variable "load_generator_instance_type" {
  description = "EC2 instance type for JMeter load generator"
  type        = string
  default     = "c6i.2xlarge" # 8 vCPUs, 16GB RAM
}

variable "root_volume_size" {
  description = "Root EBS volume size in GB"
  type        = number
  default     = 100
}

variable "data_volume_size" {
  description = "Additional data EBS volume size in GB for workloads"
  type        = number
  default     = 200
}

variable "allowed_ssh_cidr" {
  description = "CIDR blocks allowed for SSH access"
  type        = list(string)
  default     = ["0.0.0.0/0"] # Restrict this in production
}

variable "key_name" {
  description = "Name for the SSH key pair"
  type        = string
  default     = "docker-vm-research-key"
}

# ------------------------------------------------------------------------------
# Application Configuration
# Based on research paper: Node.js 18 LTS with Express 4.18
# ------------------------------------------------------------------------------

variable "nodejs_version" {
  description = "Node.js version to install"
  type        = string
  default     = "18"
}

variable "app_port" {
  description = "Application port for the web server"
  type        = number
  default     = 3000
}

# ------------------------------------------------------------------------------
# Test Configuration
# Based on research paper methodology
# ------------------------------------------------------------------------------

variable "jmeter_version" {
  description = "Apache JMeter version"
  type        = string
  default     = "5.6.3"
}

variable "enable_enhanced_monitoring" {
  description = "Enable detailed CloudWatch monitoring"
  type        = bool
  default     = true
}
