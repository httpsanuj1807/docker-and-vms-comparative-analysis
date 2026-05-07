# =============================================================================
# Security Groups
# Research: Comparative Analysis of Docker Containers vs Virtual Machines
# =============================================================================
# Security groups configured to allow necessary traffic for benchmarks
# while maintaining reasonable security boundaries
# =============================================================================

# ------------------------------------------------------------------------------
# Common Security Group - SSH Access
# ------------------------------------------------------------------------------
resource "aws_security_group" "ssh_access" {
  name        = "${var.project_name}-ssh-access"
  description = "Allow SSH access for management"
  vpc_id      = aws_vpc.research_vpc.id

  ingress {
    description = "SSH from allowed CIDR blocks"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidr
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-ssh-access"
  }
}

# ------------------------------------------------------------------------------
# Docker Host Security Group
# ------------------------------------------------------------------------------
resource "aws_security_group" "docker_host" {
  name        = "${var.project_name}-docker-host"
  description = "Security group for Docker host"
  vpc_id      = aws_vpc.research_vpc.id

  # Application port access from within VPC
  ingress {
    description = "Application port from VPC"
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Allow all traffic from load generator (for benchmark traffic)
  ingress {
    description     = "All traffic from load generator"
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.load_generator.id]
  }

  # ICMP for ping/latency testing
  ingress {
    description = "ICMP from VPC"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-docker-host-sg"
  }
}

# ------------------------------------------------------------------------------
# VM Host Security Group
# ------------------------------------------------------------------------------
resource "aws_security_group" "vm_host" {
  name        = "${var.project_name}-vm-host"
  description = "Security group for KVM/VM host"
  vpc_id      = aws_vpc.research_vpc.id

  # Application port access from within VPC
  ingress {
    description = "Application port from VPC"
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Allow all traffic from load generator (for benchmark traffic)
  ingress {
    description     = "All traffic from load generator"
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.load_generator.id]
  }

  # ICMP for ping/latency testing
  ingress {
    description = "ICMP from VPC"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.vpc_cidr]
  }

  # VNC access for VM console (optional, for debugging)
  ingress {
    description = "VNC access from VPC"
    from_port   = 5900
    to_port     = 5910
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-vm-host-sg"
  }
}

# ------------------------------------------------------------------------------
# Load Generator Security Group
# ------------------------------------------------------------------------------
resource "aws_security_group" "load_generator" {
  name        = "${var.project_name}-load-generator"
  description = "Security group for JMeter load generator"
  vpc_id      = aws_vpc.research_vpc.id

  # JMeter distributed testing ports (if needed)
  ingress {
    description = "JMeter RMI from VPC"
    from_port   = 1099
    to_port     = 1099
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # ICMP for ping testing
  ingress {
    description = "ICMP from VPC"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-load-generator-sg"
  }
}

# ------------------------------------------------------------------------------
# Internal Communication Security Group
# Allows all traffic between research hosts for maximum benchmark flexibility
# ------------------------------------------------------------------------------
resource "aws_security_group" "internal_communication" {
  name        = "${var.project_name}-internal"
  description = "Allow all internal communication between research hosts"
  vpc_id      = aws_vpc.research_vpc.id

  ingress {
    description = "All traffic from within security group"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-internal-sg"
  }
}
