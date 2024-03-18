provider "aws" {
  region     = "us-east-1" # Change this to your desired region
  access_key = "{AWS_ACCESS_KEY}"
  secret_key = "{AWS_SECRET_KEY}"
}

# Create VPC
resource "aws_vpc" "aws_infra_as_code_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = {
    Name = "aws_infra_as_code_vpc"
  }
}

# Create an Internet Gateway
resource "aws_internet_gateway" "aws_infra_as_code_vpc_igw" {
  vpc_id = aws_vpc.aws_infra_as_code_vpc.id
  tags   = {
    Name = "Infra as Code IGW"
  }
}

# Create public subnet
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.aws_infra_as_code_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a" # Change this to your desired availability zone
  map_public_ip_on_launch = true
  tags                    = {
    Name = "aws_infra_as_code public_subnet"
  }
}

# Associate internet gateway with the public subnet
resource "aws_route_table" "public_subnet_route_table" {
  vpc_id = aws_vpc.aws_infra_as_code_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.aws_infra_as_code_vpc_igw.id
  }
  tags = {
    Name = "PublicSubnetRouteTable"
  }
}

# Associate the custom route table with the public subnet
resource "aws_route_table_association" "public_subnet_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_subnet_route_table.id
}

# Create private subnet
resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.aws_infra_as_code_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b" # Change this to your desired availability zone
  tags              = {
    Name = "aws_infra_as_code private_subnet"
  }
}

# Create security groups
resource "aws_security_group" "public_sg" {
  vpc_id = aws_vpc.aws_infra_as_code_vpc.id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "aws_infra_as_code public"
  }
}

# Define inbound rules for the public security group
resource "aws_security_group_rule" "public_sg_ingress_ssh" {
  security_group_id = aws_security_group.public_sg.id
  type              = "ingress"
  from_port         = 22 # Example: Allow SSH
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "public_sg_ingress_tcp" {
  security_group_id = aws_security_group.public_sg.id
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group" "private_sg" {
  vpc_id = aws_vpc.aws_infra_as_code_vpc.id

  # Define outbound rule for the private security group
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Define inbound rule to allow traffic only from the public security group
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    #    security_group_ids = [aws_security_group.public_sg.id]
  }
  tags = {
    Name = "aws_infra_as_code private"
  }
}

# Provision the public EC2 with Nginx, Docker, and configuration
# Note: This is a simplified example. You may need to customize this section based on your needs.
resource "aws_instance" "public_ec2" {
  ami                    = "ami-079db87dc4c10ac91" # Amazon Linux 2023 AMI ID
  instance_type          = "t2.micro" # Change this to your desired instance type
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.public_sg.id]
  key_name               = "aws_infra_as_code" # Change this to your key pair name
  tags                   = {
    Name = "aws_infra_as_code public"
  }
  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y nginx
              systemctl start nginx
              systemctl enable nginx
              yum install -y git
              # Add any additional configuration for Nginx here if needed
              EOF
}

# Provision the private EC2 with Docker and PHP application
resource "aws_instance" "private_ec2" {
  ami                    = "ami-079db87dc4c10ac91" # Amazon Linux 2023 AMI ID
  instance_type          = "t2.micro" # Change this to your desired instance type
  subnet_id              = aws_subnet.private_subnet.id
  vpc_security_group_ids = [aws_security_group.private_sg.id]
  key_name               = "aws_infra_as_code" # Change this to your key pair name
  tags                   = {
    Name = "aws_infra_as_code private"
  }
  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y git
              amazon-linux-extras install docker
              systemctl start docker
              systemctl enable docker
              # Pull and run your PHP Docker container here
              # docker run -d -p 80:80 your-php-container-image
              EOF
}

# Output the public and private EC2 public IP addresses
output "public_ec2_ip" {
  value = aws_instance.public_ec2.public_ip
}

output "private_ec2_ip" {
  value = aws_instance.private_ec2.private_ip
}
