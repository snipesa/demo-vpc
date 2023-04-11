# terraform {
#   required_providers {
#     aws = {
#       source  = "hashicorp/aws"
#       version = "~> 4.16"
#     }
#   }

#   required_version = ">= 1.2.0"
# }

# provider "aws" {
#   region  = "us-west-2"
# }

resource "aws_vpc" "myvpc" {
  cidr_block           = "10.1.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "proxy-vpc"
  }
}

resource "aws_subnet" "sub1" {
  vpc_id            = aws_vpc.myvpc.id
  cidr_block        = var.cidr_priv1
  availability_zone = var.az_sub1

  tags = {
    Name = "private1"
  }
}

resource "aws_subnet" "sub2" {
  vpc_id            = aws_vpc.myvpc.id
  cidr_block        = var.cidr_priv2
  availability_zone = var.az_sub2

  tags = {
    Name = "private2"
  }
}
resource "aws_subnet" "sub3" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = var.cidr_pub1
  availability_zone       = var.az_sub3
  map_public_ip_on_launch = true

  tags = {
    Name = "public1"
  }
}
resource "aws_subnet" "sub4" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = var.cidr_pub2
  availability_zone       = var.az_sub4
  map_public_ip_on_launch = true

  tags = {
    Name = "public2"
  }
}
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.myvpc.id

  tags = {
    Name = "my-igw"
  }
}

resource "aws_route_table" "pub_rt" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = {
    Name = "mypublic-rt"
  }
}

resource "aws_route_table_association" "public1-rt" {
  subnet_id      = aws_subnet.sub3.id
  route_table_id = aws_route_table.pub_rt.id
}
resource "aws_route_table_association" "public2-rt" {
  subnet_id      = aws_subnet.sub4.id
  route_table_id = aws_route_table.pub_rt.id
}

resource "aws_eip" "lb" {
  vpc = true
  tags = {
    Name = "my-eip"
  }
}
resource "aws_nat_gateway" "demo_nat" {
  allocation_id = aws_eip.lb.id
  subnet_id     = aws_subnet.sub3.id

  tags = {
    Name = "gw NAT"
  }
}

resource "aws_route_table" "demo-nat" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.demo_nat.id
  }
}
resource "aws_route_table_association" "private1-rt" {
  subnet_id      = aws_subnet.sub1.id
  route_table_id = aws_route_table.demo-nat.id
}
resource "aws_route_table_association" "private2-rt" {
  subnet_id      = aws_subnet.sub2.id
  route_table_id = aws_route_table.demo-nat.id
}

resource "aws_security_group" "sg_1" {
  name        = var.sg-web
  description = "Allow tcp and ssh"
  vpc_id      = aws_vpc.myvpc.id

  #allow http
  ingress {
    description = "port 80 vpc"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "port 22 vpc"
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
    ipv6_cidr_blocks = ["::/0"]
  }
 
}

# resource "aws_key_pair" "key_pair" {
#   key_name   = "cali"
#   public_key = file("cali.pem")
# }

resource "aws_instance" "webserver" {
  subnet_id       = aws_subnet.sub3.id
  ami             = var.ami-west-1 # us-west-1
  instance_type   = var.instance-type
  security_groups = [aws_security_group.sg_1.id]
  key_name        = var.key-name
  user_data       = file("strap.sh")
}
resource "aws_launch_configuration" "as_conf" {
  name_prefix   = "demo-launch config"
  image_id      = var.ami-west-1
  instance_type = var.instance-type
  security_groups = [aws_security_group.sg_1.id]
  user_data = file("strap.sh")
  key_name = var.key-name

  lifecycle {
    create_before_destroy = true
  }
}
resource "aws_autoscaling_group" "asg" {
  name                 = "terraform-asg-example"
  launch_configuration = aws_launch_configuration.as_conf.name
  min_size             = 1
  desired_capacity = 1
  max_size             = 2
  vpc_zone_identifier = [aws_subnet.sub3.id, aws_subnet.sub4.id]
  lifecycle {
    create_before_destroy = true
  }
}
resource "aws_lb" "test" {
  name               = "test-lb-tf"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.sg_1.id]
  subnets            = [aws_subnet.sub3.id, aws_subnet.sub4.id]

  enable_deletion_protection = true
}
resource "aws_lb_target_group" "my_lb_tg" {
  name = "load-balancer-tg"
  port = 80
  protocol = "HTTP"
  vpc_id = aws_vpc.myvpc.id
}
# Create a new ALB Target Group attachment
resource "aws_autoscaling_attachment" "asg_attachment_bar" {
  autoscaling_group_name = aws_autoscaling_group.asg.id
  lb_target_group_arn    = aws_lb_target_group.my_lb_tg.arn
}
resource "aws_lb_listener" "listener-web" {
  load_balancer_arn = aws_lb.test.arn
  port              = "80"
  protocol          = "HTTP"


  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.my_lb_tg.arn
  }
}

# data "aws_subnet_ids" "selected" {
#   filter {
#     name = "tag:Name"
#     values = ["demo"] #explains that take subnet ids with the tag value as demo
    
#   }
# }
# #practice on data sources. used to reference data sources to easily create resources with specifications
# resource "aws_instance" "pup" {
#   for_each = data.aws_subnet_ids.selected.ids
#   ami = ""
#   instance_type = ""
#   subnet_id = each.value
# }

# data "aws_ami" "my-ami" {
#   most_recent = true
#   owners = ["self"]

#   filter {
#     name = "tag:Name"
#     values = ""  #must be a list
#   }
# }