# ════════════════════════════════════════════════════════════════
# Dinacharya Analyzer — Terraform Infrastructure as Code
# Provisions: AWS EC2, Security Groups, S3 for state, IAM roles
# Usage: terraform init && terraform plan && terraform apply
# ════════════════════════════════════════════════════════════════

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote state storage (prevents state file conflicts in team)
  backend "s3" {
    bucket         = "dinacharya-terraform-state"
    key            = "production/terraform.tfstate"
    region         = "ap-south-1"   # Mumbai (good for India)
    encrypt        = true
    dynamodb_table = "dinacharya-state-lock"  # Prevent concurrent applies
  }
}

# ── Provider ───────────────────────────────────────────────────────
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "dinacharya-analyzer"
      Environment = var.environment
      ManagedBy   = "terraform"
      Owner       = "kunal"
    }
  }
}

# ── Variables ──────────────────────────────────────────────────────
variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "ap-south-1"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "production"
  validation {
    condition     = contains(["development", "staging", "production"], var.environment)
    error_message = "Environment must be development, staging, or production."
  }
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"  # Free tier eligible
}

# ── Data Sources ───────────────────────────────────────────────────
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

data "aws_vpc" "default" {
  default = true
}

# ── Security Group ─────────────────────────────────────────────────
resource "aws_security_group" "dinacharya_sg" {
  name        = "dinacharya-${var.environment}-sg"
  description = "Security group for Dinacharya Analyzer"
  vpc_id      = data.aws_vpc.default.id

  # Allow HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP traffic"
  }

  # Allow HTTPS
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS traffic"
  }

  # Allow app port
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Application port"
  }

  # Allow SSH (restrict to your IP in production)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]   # Change to your IP: ["YOUR_IP/32"]
    description = "SSH access"
  }

  # Allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }
}

# ── IAM Role for EC2 ───────────────────────────────────────────────
resource "aws_iam_role" "ec2_role" {
  name = "dinacharya-ec2-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "dinacharya-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

# ── EC2 Instance ───────────────────────────────────────────────────
resource "aws_instance" "dinacharya_server" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.dinacharya_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  # User data: auto-install Docker and run the app on first boot
  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -e
    
    # Update system
    yum update -y
    
    # Install Docker
    yum install -y docker
    systemctl start docker
    systemctl enable docker
    usermod -aG docker ec2-user
    
    # Install Docker Compose
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
      -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    
    # Pull and run the app
    docker pull your-dockerhub-username/dinacharya-analyzer:latest
    docker run -d \
      --name dinacharya \
      --restart unless-stopped \
      -p 3000:3000 \
      -e ANTHROPIC_API_KEY="${var.anthropic_api_key}" \
      -e NODE_ENV=production \
      your-dockerhub-username/dinacharya-analyzer:latest
    
    echo "Dinacharya Analyzer deployed successfully!" > /var/log/dinacharya-deploy.log
  EOF
  )

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
  }

  tags = {
    Name = "dinacharya-${var.environment}"
  }
}

# ── Elastic IP (static public IP) ─────────────────────────────────
resource "aws_eip" "dinacharya_eip" {
  instance = aws_instance.dinacharya_server.id
  domain   = "vpc"
}

# ── Outputs ────────────────────────────────────────────────────────
output "instance_public_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_eip.dinacharya_eip.public_ip
}

output "app_url" {
  description = "Application URL"
  value       = "http://${aws_eip.dinacharya_eip.public_ip}:3000"
}

output "ssh_command" {
  description = "SSH command to connect"
  value       = "ssh -i your-key.pem ec2-user@${aws_eip.dinacharya_eip.public_ip}"
}

variable "anthropic_api_key" {
  description = "Anthropic API key (sensitive)"
  type        = string
  sensitive   = true  # Won't appear in logs or plan output
}
