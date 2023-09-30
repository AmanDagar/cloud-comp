terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "selected_subnet" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name   = "availability-zone"
    values = ["us-east-1a", "us-east-1b", "us-east-1c", "us-east-1d"]
  }
}

resource "tls_private_key" "flask_app_keypair" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "flask_app_keypair" {
  key_name   = "flask-app-keypair"
  public_key = tls_private_key.flask_app_keypair.public_key_openssh
  provisioner "local-exec" {
    command = <<-EOT
      echo '${tls_private_key.flask_app_keypair.private_key_pem}' > aws_key.pem
      chmod 400 aws_key.pem
    EOT
  }
}

resource "aws_security_group" "flask_app_sg" {
  name_prefix = "flask-app-sg"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound rules
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # All protocols
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# standalone instance for testing (not part of autoscaling group)
resource "aws_instance" "flask_app" {
  ami           = "ami-0261755bbcb8c4a84" # Ubuntu 20.04 LTS image in us-east-1
  instance_type = "t2.micro"
  key_name      = aws_key_pair.flask_app_keypair.key_name

  tags = {
    Name = "FlaskAppInstance"
  }

  user_data = <<-EOF
              #!/bin/bash
              apt update
              apt install -y docker.io
              service docker start
              usermod -aG docker ubuntu

              # Fetch your Flask app code
              git clone https://github.com/KeshavUpadhyaya/cloud-comp.git /home/ubuntu/flask-app

              # Build and run the Flask app Docker container
              cd /home/ubuntu/flask-app
              docker build -t flask-app .
              docker run -d -p 80:80 flask-app
              EOF
}

# Define an Auto Scaling Group with a default launch configuration.
resource "aws_autoscaling_group" "flask_app_asg" {
  name                 = "flask-app-asg"
  min_size             = 2
  max_size             = 5
  desired_capacity     = 2
  availability_zones   = ["us-east-1a", "us-east-1b", "us-east-1c", "us-east-1d"]
  launch_configuration = aws_launch_configuration.flask_app.name
  target_group_arns    = [aws_lb_target_group.flask_app.arn]
  health_check_type    = "ELB"
}

# Define a launch configuration for the Auto Scaling Group.
resource "aws_launch_configuration" "flask_app" {
  name_prefix                 = "flask-app-"
  image_id                    = "ami-0261755bbcb8c4a84"
  instance_type               = "t2.micro"
  key_name                    = aws_key_pair.flask_app_keypair.key_name
  associate_public_ip_address = true
  security_groups             = [aws_security_group.flask_app_sg.id]
  user_data                   = <<-EOF
              #!/bin/bash
              apt update
              apt install -y docker.io
              service docker start
              usermod -aG docker ubuntu

              # Fetch your Flask app code
              git clone https://github.com/KeshavUpadhyaya/cloud-comp.git /home/ubuntu/flask-app

              # Build and run the Flask app Docker container
              cd /home/ubuntu/flask-app
              docker build -t flask-app .
              docker run -d -p 80:80 flask-app
              EOF
}

# Define a load balancer.
resource "aws_lb" "flask_app_lb" {
  name                       = "flask-app-lb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.flask_app_sg.id]
  enable_deletion_protection = false
  subnets                    = data.aws_subnets.selected_subnet.ids
}

# Define a target group for the load balancer.
resource "aws_lb_target_group" "flask_app" {
  name        = "flask-app-target-group"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = data.aws_vpc.default.id
}

# Create a listener for the load balancer.
resource "aws_lb_listener" "flask_app" {
  load_balancer_arn = aws_lb.flask_app_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      status_code  = "200"
    }
  }
}

resource "aws_lb_listener_rule" "flask_app" {
  listener_arn = aws_lb_listener.flask_app.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.flask_app.arn
  }

  condition {
    path_pattern {
      values = ["/", "/api/v1/users", "/api/v1/users/*"]
    }
  }
}

# Setting up autoscaling alaram
resource "aws_cloudwatch_metric_alarm" "requests_up_alarm" {
  alarm_name          = "requests-up-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 3
  metric_name         = "RequestCount"       # The metric name for an ELB request count
  namespace           = "AWS/ApplicationELB" # The default namespace for ELB metrics
  period              = 60                   # 1-minute period
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "Scale up when requests exceed 10 per minute for 1 minute"
  actions_enabled     = true
  alarm_actions       = [aws_autoscaling_policy.scale_up_policy.arn]
  dimensions = {
    LoadBalancer = element(split("loadbalancer/", aws_lb.flask_app_lb.arn), 1)
  }
}

resource "aws_cloudwatch_metric_alarm" "requests_down_alarm" {
  alarm_name          = "requests-down-alarm"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 3
  metric_name         = "RequestCount"       # The metric name for an ELB request count
  namespace           = "AWS/ApplicationELB" # The default namespace for ELB metrics
  period              = 60                   # 1-minute period
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "Scale down when requests go below 10 per minute for 1 minute"
  actions_enabled     = true
  alarm_actions       = [aws_autoscaling_policy.scale_down_policy.arn]
  dimensions = {
    LoadBalancer = element(split("loadbalancer/", aws_lb.flask_app_lb.arn), 1)
  }
}

resource "aws_autoscaling_policy" "scale_up_policy" {
  name                   = "scale-up-policy"
  scaling_adjustment     = 1 # Increase desired capacity by 1 instance/container
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300 # Cooldown period in seconds
  autoscaling_group_name = aws_autoscaling_group.flask_app_asg.name
}

resource "aws_autoscaling_policy" "scale_down_policy" {
  name                   = "scale-down-policy"
  scaling_adjustment     = -1 # Decrease desired capacity by 1 instance/container
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300 # Cooldown period in seconds
  autoscaling_group_name = aws_autoscaling_group.flask_app_asg.name
}


resource "aws_s3_bucket" "flask_bucket" {
  bucket = "s3-bucket-flask-app"  # Change to your desired bucket name
  
}

resource "aws_s3_bucket_ownership_controls" "flask_bucket" {
  bucket = aws_s3_bucket.flask_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "flask_bucket" {
  depends_on = [
    aws_s3_bucket_ownership_controls.flask_bucket,
    aws_s3_bucket_public_access_block.access_block,
    ]

  bucket = aws_s3_bucket.flask_bucket.id
  acl    = "public-read-write"
}

resource "aws_s3_bucket_public_access_block" "access_block" {
  bucket = aws_s3_bucket.flask_bucket.id

  block_public_acls   = false
  block_public_policy = false
  ignore_public_acls  = false
  restrict_public_buckets = false
}


resource "aws_s3_object" "flask_bucket" {
  bucket = aws_s3_bucket.flask_bucket.bucket
  key    = "users-db"  # Name of the file in the bucket
  source = "./users.db"  # Local path to the user.db file
}

resource "aws_s3_bucket_cors_configuration" "flask_bucket" {
  bucket = aws_s3_bucket.flask_bucket.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT", "POST","GET", "DELETE"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }

  cors_rule {
    allowed_methods = ["GET"]
    allowed_origins = ["*"]
  }
}

output "bucket_url" {
  value = aws_s3_bucket.flask_bucket.bucket_domain_name
}


output "load_balancer_public_ip" {
  value = aws_lb.flask_app_lb.dns_name
}