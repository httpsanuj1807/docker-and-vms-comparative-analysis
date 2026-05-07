# =============================================================================
# EC2 Instances
# Research: Comparative Analysis of Docker Containers vs Virtual Machines
# =============================================================================
# Three dedicated instances for research testbed:
# 1. Docker Host - runs containerized workloads
# 2. VM Host - runs KVM-based virtual machines (bare metal for nested virt)
# 3. Load Generator - runs JMeter for load testing
# =============================================================================

# ------------------------------------------------------------------------------
# SSH Key Pair
# ------------------------------------------------------------------------------
resource "tls_private_key" "research_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "research_key" {
  key_name   = var.key_name
  public_key = tls_private_key.research_key.public_key_openssh

  tags = {
    Name = var.key_name
  }
}

resource "local_file" "private_key" {
  content         = tls_private_key.research_key.private_key_pem
  filename        = "${path.module}/${var.key_name}.pem"
  file_permission = "0400"
}

# ------------------------------------------------------------------------------
# IAM Role for EC2 Instances (for CloudWatch metrics)
# ------------------------------------------------------------------------------
resource "aws_iam_role" "research_instance_role" {
  name = "${var.project_name}-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-instance-role"
  }
}

resource "aws_iam_role_policy_attachment" "cloudwatch_policy" {
  role       = aws_iam_role.research_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.research_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "research_instance_profile" {
  name = "${var.project_name}-instance-profile"
  role = aws_iam_role.research_instance_role.name
}

# ------------------------------------------------------------------------------
# Docker Host Instance
# Compute-optimized for containerized workloads
# ------------------------------------------------------------------------------
resource "aws_instance" "docker_host" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.docker_host_instance_type
  key_name               = aws_key_pair.research_key.key_name
  subnet_id              = aws_subnet.public_subnet.id
  iam_instance_profile   = aws_iam_instance_profile.research_instance_profile.name

  vpc_security_group_ids = [
    aws_security_group.ssh_access.id,
    aws_security_group.docker_host.id,
    aws_security_group.internal_communication.id
  ]

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    iops                  = 3000
    throughput            = 125
    delete_on_termination = true
    encrypted             = true

    tags = {
      Name = "${var.project_name}-docker-host-root"
    }
  }

  # Additional NVMe-optimized storage for Docker images and workloads
  ebs_block_device {
    device_name           = "/dev/sdf"
    volume_type           = "gp3"
    volume_size           = var.data_volume_size
    iops                  = 16000
    throughput            = 1000
    delete_on_termination = true
    encrypted             = true

    tags = {
      Name = "${var.project_name}-docker-host-data"
    }
  }

  user_data = base64encode(file("${path.module}/scripts/docker-host-setup.sh"))

  monitoring = var.enable_enhanced_monitoring

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = {
    Name        = "${var.project_name}-docker-host"
    Role        = "docker-host"
    Environment = "research"
  }
}

# ------------------------------------------------------------------------------
# VM Host Instance
# Bare metal instance required for KVM/nested virtualization
# ------------------------------------------------------------------------------
resource "aws_instance" "vm_host" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.vm_host_instance_type
  key_name               = aws_key_pair.research_key.key_name
  subnet_id              = aws_subnet.public_subnet.id
  iam_instance_profile   = aws_iam_instance_profile.research_instance_profile.name

  vpc_security_group_ids = [
    aws_security_group.ssh_access.id,
    aws_security_group.vm_host.id,
    aws_security_group.internal_communication.id
  ]

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    iops                  = 3000
    throughput            = 125
    delete_on_termination = true
    encrypted             = true

    tags = {
      Name = "${var.project_name}-vm-host-root"
    }
  }

  # Large storage for VM disk images
  ebs_block_device {
    device_name           = "/dev/sdf"
    volume_type           = "gp3"
    volume_size           = 500  # Larger for VM images
    iops                  = 16000
    throughput            = 1000
    delete_on_termination = true
    encrypted             = true

    tags = {
      Name = "${var.project_name}-vm-host-data"
    }
  }

  user_data = base64encode(file("${path.module}/scripts/vm-host-setup.sh"))

  monitoring = var.enable_enhanced_monitoring

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = {
    Name        = "${var.project_name}-vm-host"
    Role        = "vm-host"
    Environment = "research"
  }
}

# ------------------------------------------------------------------------------
# Load Generator Instance
# Dedicated machine for running JMeter load tests
# ------------------------------------------------------------------------------
resource "aws_instance" "load_generator" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.load_generator_instance_type
  key_name               = aws_key_pair.research_key.key_name
  subnet_id              = aws_subnet.public_subnet.id
  iam_instance_profile   = aws_iam_instance_profile.research_instance_profile.name

  vpc_security_group_ids = [
    aws_security_group.ssh_access.id,
    aws_security_group.load_generator.id,
    aws_security_group.internal_communication.id
  ]

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    iops                  = 3000
    throughput            = 125
    delete_on_termination = true
    encrypted             = true

    tags = {
      Name = "${var.project_name}-load-generator-root"
    }
  }

  # Storage for test results
  ebs_block_device {
    device_name           = "/dev/sdf"
    volume_type           = "gp3"
    volume_size           = var.data_volume_size
    iops                  = 3000
    throughput            = 125
    delete_on_termination = true
    encrypted             = true

    tags = {
      Name = "${var.project_name}-load-generator-data"
    }
  }

  user_data = base64encode(file("${path.module}/scripts/load-generator-setup.sh"))

  monitoring = var.enable_enhanced_monitoring

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = {
    Name        = "${var.project_name}-load-generator"
    Role        = "load-generator"
    Environment = "research"
  }
}

# ------------------------------------------------------------------------------
# Elastic IPs for stable access
# ------------------------------------------------------------------------------
resource "aws_eip" "docker_host" {
  instance = aws_instance.docker_host.id
  domain   = "vpc"

  tags = {
    Name = "${var.project_name}-docker-host-eip"
  }
}

resource "aws_eip" "vm_host" {
  instance = aws_instance.vm_host.id
  domain   = "vpc"

  tags = {
    Name = "${var.project_name}-vm-host-eip"
  }
}

resource "aws_eip" "load_generator" {
  instance = aws_instance.load_generator.id
  domain   = "vpc"

  tags = {
    Name = "${var.project_name}-load-generator-eip"
  }
}
