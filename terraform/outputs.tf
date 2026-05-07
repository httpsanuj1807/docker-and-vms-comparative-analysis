# =============================================================================
# Terraform Outputs
# Research: Comparative Analysis of Docker Containers vs Virtual Machines
# =============================================================================

# ------------------------------------------------------------------------------
# VPC Outputs
# ------------------------------------------------------------------------------
output "vpc_id" {
  description = "ID of the research VPC"
  value       = aws_vpc.research_vpc.id
}

output "public_subnet_id" {
  description = "ID of the public subnet"
  value       = aws_subnet.public_subnet.id
}

# ------------------------------------------------------------------------------
# Instance Outputs
# ------------------------------------------------------------------------------
output "docker_host_public_ip" {
  description = "Public IP of the Docker host"
  value       = aws_eip.docker_host.public_ip
}

output "docker_host_private_ip" {
  description = "Private IP of the Docker host"
  value       = aws_instance.docker_host.private_ip
}

output "docker_host_instance_id" {
  description = "Instance ID of the Docker host"
  value       = aws_instance.docker_host.id
}

output "vm_host_public_ip" {
  description = "Public IP of the VM host"
  value       = aws_eip.vm_host.public_ip
}

output "vm_host_private_ip" {
  description = "Private IP of the VM host"
  value       = aws_instance.vm_host.private_ip
}

output "vm_host_instance_id" {
  description = "Instance ID of the VM host"
  value       = aws_instance.vm_host.id
}

output "load_generator_public_ip" {
  description = "Public IP of the load generator"
  value       = aws_eip.load_generator.public_ip
}

output "load_generator_private_ip" {
  description = "Private IP of the load generator"
  value       = aws_instance.load_generator.private_ip
}

output "load_generator_instance_id" {
  description = "Instance ID of the load generator"
  value       = aws_instance.load_generator.id
}

# ------------------------------------------------------------------------------
# SSH Key Output
# ------------------------------------------------------------------------------
output "ssh_key_path" {
  description = "Path to the private SSH key"
  value       = local_file.private_key.filename
}

# ------------------------------------------------------------------------------
# Connection Instructions
# ------------------------------------------------------------------------------
output "connection_instructions" {
  description = "Instructions for connecting to instances"
  value       = <<-EOT

    =============================================================================
    Research Infrastructure - Connection Instructions
    =============================================================================

    SSH Key Location: ${local_file.private_key.filename}

    Connect to Docker Host:
      ssh -i ${local_file.private_key.filename} ubuntu@${aws_eip.docker_host.public_ip}

    Connect to VM Host:
      ssh -i ${local_file.private_key.filename} ubuntu@${aws_eip.vm_host.public_ip}

    Connect to Load Generator:
      ssh -i ${local_file.private_key.filename} ubuntu@${aws_eip.load_generator.public_ip}

    =============================================================================
    Internal IPs (for benchmarking - use these from load generator):
    =============================================================================

    Docker Host: ${aws_instance.docker_host.private_ip}
    VM Host:     ${aws_instance.vm_host.private_ip}

    =============================================================================
    Running Benchmarks:
    =============================================================================

    1. SSH into the load generator
    2. Run benchmarks against Docker host:
       /opt/benchmarks/run-benchmarks.sh ${aws_instance.docker_host.private_ip} 3000 docker

    3. Run benchmarks against VM (after VM is created on VM host):
       /opt/benchmarks/run-benchmarks.sh <vm-ip> 3000 vm

    =============================================================================
    Application Endpoints:
    =============================================================================

    Health Check: http://<host>:3000/health
    Static (I/O-bound): http://<host>:3000/api/static
    Compute (CPU-bound): http://<host>:3000/api/compute?n=35
    System Info: http://<host>:3000/api/system

    =============================================================================

  EOT
}

# ------------------------------------------------------------------------------
# Quick Reference
# ------------------------------------------------------------------------------
output "quick_reference" {
  description = "Quick reference for important values"
  value = {
    docker_host = {
      public_ip  = aws_eip.docker_host.public_ip
      private_ip = aws_instance.docker_host.private_ip
      type       = var.docker_host_instance_type
    }
    vm_host = {
      public_ip  = aws_eip.vm_host.public_ip
      private_ip = aws_instance.vm_host.private_ip
      type       = var.vm_host_instance_type
    }
    load_generator = {
      public_ip  = aws_eip.load_generator.public_ip
      private_ip = aws_instance.load_generator.private_ip
      type       = var.load_generator_instance_type
    }
    application_port = var.app_port
    ssh_key          = local_file.private_key.filename
  }
}
