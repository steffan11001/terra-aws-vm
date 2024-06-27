terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
  
  
}



# data "terraform_remote_state" "network" {
#   backend = "s3"

#   config = {
#     bucket = "dev-network1"
#     key    = "dev-network1/terraform.tfstate"
#     region = "eu-central-1"
#   }
# } 

provider "aws" {
  region = "eu-central-1"
  profile = "terraform"
}

variable "cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "az1" {
  type    = string
  default = "eu-central-1a"
}

variable "az2" {
  type    = string
  default = "eu-central-1b"
}

variable "cidr_subnet1" {
  type    = string
  default = "10.0.1.0/24"
}

variable "cidr_subnet2" {
  type    = string
  default = "10.0.2.0/24"
}

resource "aws_vpc" "dev_vpc" {
  cidr_block           = var.cidr
  enable_dns_hostnames = true

  tags = {
    Name = "Dev-VPC"
  }
}

resource "aws_subnet" "dev_public_subnet_1" {
  vpc_id            = aws_vpc.dev_vpc.id
  availability_zone = var.az1
  cidr_block        = var.cidr_subnet1

  tags = {
    Name = "Public Subnet1 for Dev"
  }
}

resource "aws_subnet" "dev_public_subnet_2" {
  vpc_id            = aws_vpc.dev_vpc.id
  availability_zone = var.az2
  cidr_block        = var.cidr_subnet2

  tags = {
    Name = "Public Subnet2 for Dev"
  }
}

resource "aws_internet_gateway" "dev_igw" {
  vpc_id = aws_vpc.dev_vpc.id

  tags = {
    Name = "IGW for DEV"
  }
}

resource "aws_route_table" "dev_rt" {
  vpc_id = aws_vpc.dev_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.dev_igw.id
  }

  tags = {
    Name = "RT for DEV"
  }
}

resource "aws_route_table_association" "dev_subnet1_association" {
  subnet_id      = aws_subnet.dev_public_subnet_1.id
  route_table_id = aws_route_table.dev_rt.id
}

resource "aws_route_table_association" "dev_subnet2_association" {
  subnet_id      = aws_subnet.dev_public_subnet_2.id
  route_table_id = aws_route_table.dev_rt.id
}

resource "aws_security_group" "lb_sg" {
  name        = "lb_sg"
  description = "Allow HTTP inbound traffic"
  vpc_id      = aws_vpc.dev_vpc.id

  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
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
    Name = "lb_sg"
  }
}

output "security_group_id" {
  value = aws_security_group.lb_sg.id
}

# resource "aws_instance" "blue_dotnet_app" {
#   ami                    = "ami-0f6fb2cc3ef5a9379" 
#   instance_type          = "t2.micro"
#   vpc_security_group_ids = [aws_security_group.lb_sg.id]  
#   subnet_id              = aws_subnet.dev_public_subnet_1.id
#   associate_public_ip_address = true
#   key_name = "terraform-key"
#   tags = {
#     Name = "blue-dotnet-app"
#   }
# }


# resource "aws_instance" "green_dotnet_app" {
#   ami           = "ami-0f6fb2cc3ef5a9379" 
#   instance_type = "t2.micro"
#   vpc_security_group_ids = [aws_security_group.lb_sg.id]  
#   subnet_id              = aws_subnet.dev_public_subnet_1.id
#   associate_public_ip_address = true
#   key_name = "terraform-key"
#   tags = {
#     Name = "green-dotnet-app"
#   }
# }


resource "aws_lb" "dev_elb" {
  name = "develb" 
  internal = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sg.id]
  subnets         = [aws_subnet.dev_public_subnet_1.id, aws_subnet.dev_public_subnet_2.id]
}

resource "aws_lb_listener" "dev_listener" {
  load_balancer_arn = aws_lb.dev_elb.arn
  port              = "5000"
  protocol          = "HTTP"


  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.dev_tg.arn
  }
} 

resource "aws_lb_target_group" "dev_tg" {
  name     = "develbtg"
  port     = 5000
  protocol = "HTTP" 
  vpc_id      = aws_vpc.dev_vpc.id
} 

resource "aws_autoscaling_attachment" "dev_attachment_tg" {
  autoscaling_group_name = aws_autoscaling_group.dev_asg.id
  lb_target_group_arn   = aws_lb_target_group.dev_tg.arn
}

# resource "aws_lb_target_group" "app_lb_tg" {
#   name     = "app-lb-tg"
#   port     = 5000
#   protocol = "HTTP"
#   vpc_id   = aws_vpc.dev_vpc.id

#   health_check {
#     healthy_threshold   = 2
#     unhealthy_threshold = 2
#     timeout             = 3
#     interval            = 30
#     path                = "/"
#     matcher             = "200"
#   }

#   tags = {
#     Name = "app-lb-tg"
#   }
# }

# resource "aws_lb_listener" "app_lb_listener" {
#   load_balancer_arn = aws_lb.app_lb.arn
#   port              = "5000"
#   protocol          = "HTTP"

#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.app_lb_tg.arn
#   }
# }

# resource "aws_lb_target_group_attachment" "blue_app_lb_tg_attachment" {
#   target_group_arn = aws_lb_target_group.app_lb_tg.arn
#   target_id        = aws_instance.blue_dotnet_app.id
#   port             = 5000
# }

# resource "aws_lb_target_group_attachment" "green_app_lb_tg_attachment" {
#   target_group_arn = aws_lb_target_group.app_lb_tg.arn
#   target_id        = aws_instance.green_dotnet_app.id
#   port             = 5000
# }

resource "aws_launch_configuration" "dev_launch" {
  name_prefix = "dev_launch"
  image_id    = "ami-0f6fb2cc3ef5a9379"
  instance_type = "t2.micro" 
  security_groups = [aws_security_group.lb_sg.id] 
  associate_public_ip_address = true 
  key_name = "terraform-key"
} 

resource "aws_autoscaling_group" "dev_asg" {
  name                 = "Dev AutoScaling Group"
  launch_configuration = aws_launch_configuration.dev_launch.name
  min_size             = 1
  max_size             = 3
  desired_capacity     = 2
  vpc_zone_identifier  = [aws_subnet.dev_public_subnet_1.id, aws_subnet.dev_public_subnet_2.id] 
  health_check_type = "EC2" 
  tag {
    key                 = "Name"
    value               = "Dev Instance ASG"
    propagate_at_launch = true
  }
} 

