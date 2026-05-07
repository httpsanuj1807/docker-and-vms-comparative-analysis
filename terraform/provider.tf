# =============================================================================
# Terraform Provider Configuration
# Research: Comparative Analysis of Docker Containers vs Virtual Machines
# =============================================================================

terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "docker-vm-comparison-research"
      Environment = "research"
      ManagedBy   = "terraform"
      Authors     = "Arham-Jain,Ansh-Mittal,Anuj-Kumar"
      University  = "Chitkara-University"
    }
  }
}
