# Configure the AWS Provider
provider "aws" {
  region  = "us-east-1"
  profile = "default"
}

# 1. Create VPC
resource "aws_vpc" "linux-vpc" {
  cidr_block = "10.0.0.0/16"
  
  tags = {
    Name = "Linux-VPC"
  }
}

# 2. Create Internet Gateway 
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.linux-vpc.id

  tags = {
    Name = "Linux-IG"
  }
}

# 3. Create Custom Route Table 
resource "aws_route_table" "linux-route-table" {
  vpc_id = aws_vpc.linux-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "Linux-Route-Table"
  }
}

# 4. Create a Subnet 
resource "aws_subnet" "linux-webserver" {
  vpc_id     = aws_vpc.linux-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "Linux-Webserver"
  }
}

# 5. Associate Subnet with Route Table 
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.linux-webserver.id
  route_table_id = aws_route_table.linux-route-table.id
}

# 6. Create Security Group to allow port 22, 80, 443
resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow web inbound traffic"
  vpc_id      = aws_vpc.linux-vpc.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_Web"
  }
}

# 7. Create a network interface with an ip in the subnet that was created in step 4 
resource "aws_network_interface" "linux-webserver-nic" {
  subnet_id       = aws_subnet.linux-webserver.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]

  
}

# 8. Assign an elastic IP to the Linux Webserver
resource "aws_eip" "lb" {
  instance = aws_instance.linux-webserver.id
  domain   = "vpc"
  depends_on = [ aws_internet_gateway.gw ]
}

# 9. Create Linux Webserver and install/enable apache2
resource "aws_instance" "linux-webserver" {
  ami           = "ami-0a3c3a20c09d6f377"
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"
  key_name = "my-key-pair"

 network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.linux-webserver-nic.id
  }
  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install apache2 -y 
              sudo systemctl start apache2
              sudo bash -c 'echo your very first webserver > /var/www/html/index.html'
              EOF
       

  tags = {
    Name = "Linux-Webserver"
  }
  
}