# data "aws_ami" "webapp_ami"{
#   # executable_users = ["self"]
#   most_recent = true
#   # name_regex       = "csye6225_*"
#   owners = ["061920653777"]

#   filter {
#     name   = "name"
#     values = ["csye6225_*"]
#   }

#   filter {
#     name   = "root-device-type"
#     values = ["ebs"]
#   }

#   filter {
#     name   = "virtualization-type"
#     values = ["hvm"]
#   }
# }

data "template_file" "user_data" {
  template = <<EOF
    #!/bin/bash
    echo "ENVIRONMENT=DEV
    PORT=1324
    HOSTNAME=${aws_db_instance.database.address}
    DATABASE=${aws_db_instance.database.db_name}
    DBUSER=${aws_db_instance.database.username}
    DBPASSWORD=${aws_db_instance.database.password}
    AWS_REGION=${var.region}
    AWS_S3_BUCKET_NAME=${aws_s3_bucket.bucket.bucket}" >> /home/ec2-user/webapp/.env
    
    sudo systemctl daemon-reload
    sudo systemctl enable nodeserver
    sudo systemctl start nodeserver
  EOF

}
resource "aws_vpc" "cloud_vpc" {
  cidr_block = var.vpc_cidr_block

  tags = {
    Name = "cloud-vpc"
  }
}
locals {
  vpc_id = aws_vpc.cloud_vpc.id
}
resource "aws_subnet" "public_subnet" {

  count                   = var.subnet_public_count
  vpc_id                  = local.vpc_id
  cidr_block              = cidrsubnet(aws_vpc.cloud_vpc.cidr_block, 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[(count.index % length(data.aws_availability_zones.available.names))]
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-${data.aws_availability_zones.available.names[(count.index % length(data.aws_availability_zones.available.names))]}"
  }
}


resource "aws_subnet" "private_subnet" {
  count                   = var.subnet_private_count
  vpc_id                  = local.vpc_id
  cidr_block              = cidrsubnet(aws_vpc.cloud_vpc.cidr_block, 8, count.index + var.subnet_private_count)
  availability_zone       = data.aws_availability_zones.available.names[(count.index % length(data.aws_availability_zones.available.names))]
  map_public_ip_on_launch = false

  tags = {
    Name = "private-subnet-${data.aws_availability_zones.available.names[(count.index % length(data.aws_availability_zones.available.names))]}"
  }
}



resource "aws_internet_gateway" "cloud_gateway" {
  vpc_id = local.vpc_id

  tags = {
    Name = "cloud_gateway"
  }
}
resource "aws_route_table" "public_route_table" {
  vpc_id = local.vpc_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.cloud_gateway.id
  }

  tags = {
    Name = "public-route-table"
  }
}

resource "aws_route_table_association" "public_subnet_a_association" {
  count          = var.subnet_public_count
  subnet_id      = aws_subnet.public_subnet[count.index].id
  route_table_id = aws_route_table.public_route_table.id
}
resource "aws_route_table" "private" {
  vpc_id = local.vpc_id

  tags = {
    Name = "private-route-table"
  }
}

resource "aws_route_table_association" "private_subnet" {
  count          = var.subnet_private_count
  subnet_id      = aws_subnet.private_subnet[count.index].id
  route_table_id = aws_route_table.private.id
}
resource "aws_security_group" "ami-ec2-sg" {
  name_prefix = "ami-ec2-sg"
  description = "ec2 security group"
  vpc_id      = local.vpc_id

  # ingress {
  #   from_port   = 80
  #   to_port     = 80
  #   protocol    = "tcp"
  #   cidr_blocks = ["0.0.0.0/0"]
  # }

  # ingress {
  #   from_port   = 22
  #   to_port     = 22
  #   protocol    = "tcp"
  #   cidr_blocks = ["0.0.0.0/0"]
  # }

  # ingress {
  #   from_port   = 5432
  #   to_port     = 5432
  #   protocol    = "tcp"
  #   cidr_blocks = ["0.0.0.0/0"]
  # }

  ingress {
    from_port       = 1324
    to_port         = 1324
    protocol        = "tcp"
    security_groups = [aws_security_group.loadb_sg.id]
  }

  # ingress {
  #   from_port   = 443
  #   to_port     = 443
  #   protocol    = "tcp"
  #   cidr_blocks = ["0.0.0.0/0"]
  # }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment = "dev"
  }
}

resource "aws_launch_template" "lt" {
  name     = "autosche_launch_config"
  image_id = var.ami_id
  # data.aws_ami.webapp_ami.id
  instance_initiated_shutdown_behavior = "terminate"
  instance_type                        = "t2.micro"
  key_name                             = var.ssh_key_name
  disable_api_termination              = false

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_s3_profile.name
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      delete_on_termination = true
      volume_size           = 50
      volume_type           = "gp2"
    }
  }

  network_interfaces {
    associate_public_ip_address = true
    delete_on_termination       = true
    # using vpc_security_group_ids instead
    security_groups = [aws_security_group.ami-ec2-sg.id]
  }

  # vpc_security_group_ids = [aws_security_group.vpc.id]

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "asg_launch_config"
    }
  }

  user_data = base64encode(data.template_file.user_data.rendered)
}


# resource "aws_instance" "cloud_instance" {
#   ami                  = var.ami_id
#   instance_type        = "t2.micro"
#   security_groups      = [aws_security_group.ami-ec2-sg.id]
#   subnet_id            = aws_subnet.public_subnet[0].id
#   key_name             = var.ssh_key_name
#   iam_instance_profile = aws_iam_instance_profile.ec2_s3_profile.name

#   user_data = <<EOF
#     #!/bin/bash
#     echo "ENVIRONMENT=DEV
#     PORT=1324
#     HOSTNAME=${aws_db_instance.database.address}
#     DATABASE=${aws_db_instance.database.db_name}
#     DBUSER=${aws_db_instance.database.username}
#     DBPASSWORD=${aws_db_instance.database.password}
#     AWS_REGION=${var.region}
#     AWS_S3_BUCKET_NAME=${aws_s3_bucket.bucket.bucket}" >> /home/ec2-user/webapp/.env

#     sudo systemctl daemon-reload
#     sudo systemctl enable nodeserver
#     sudo systemctl start nodeserver
#   EOF

#   tags = {
#     Name = "cloudami"
#   }
# }

resource "random_uuid" "uuid" {
}

resource "aws_s3_bucket" "bucket" {
  bucket        = random_uuid.uuid.result
  force_destroy = true
  tags = {
    Name        = "CSYE 6225 webapp"
    Environment = var.profile
  }
}

resource "aws_s3_bucket_acl" "bucket_acl" {
  bucket = aws_s3_bucket.bucket.id
  acl    = "private"
}

resource "aws_s3_bucket_lifecycle_configuration" "bucket_lifecycle_config" {
  bucket = aws_s3_bucket.bucket.id

  rule {
    id     = "move_to_IA"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "example" {
  bucket = aws_s3_bucket.bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}


resource "aws_iam_policy" "webapp_s3_policy" {
  name        = "webapp_s3_policy"
  path        = "/"
  description = "Allow webapp s3 access"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    Version : "2012-10-17",
    Statement : [
      {
        "Action" : [
          "s3:DeleteObject",
          "s3:GetObject",
          "s3:PutObject"
        ],
        "Effect" : "Allow",
        "Resource" : [
          "arn:aws:s3:::${aws_s3_bucket.bucket.bucket}",
          "arn:aws:s3:::${aws_s3_bucket.bucket.bucket}/*"
        ]
      }
    ]
  })
  # policy = jsonencode({
  #   Version : "2012-10-17",
  #   Statement : [
  #     {
  #       "Action" : [
  #         "s3:*"
  #       ],
  #       "Effect" : "Allow",
  #       "Resource" : [
  #         "arn:aws:s3:::${aws_s3_bucket.bucket.bucket}",
  #         "arn:aws:s3:::${aws_s3_bucket.bucket.bucket}/*"
  #       ]
  #     }
  #   ]
  # })
}

resource "aws_iam_role" "webapp_s3_access_role" {
  name = "webapp_s3_access_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_policy_attachment" "ec2_s3_policy_role" {
  name       = "webapp_s3_attachment"
  roles      = [aws_iam_role.webapp_s3_access_role.name]
  policy_arn = aws_iam_policy.webapp_s3_policy.arn
}

resource "aws_iam_instance_profile" "ec2_s3_profile" {
  # name = "webapp_s3_profile"
  role = aws_iam_role.webapp_s3_access_role.name
}


resource "random_password" "password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_db_parameter_group" "postgres_parameter_group" {
  name   = "postgres-pg"
  family = "postgres14"
}

resource "aws_db_instance" "database" {
  skip_final_snapshot = true
  allocated_storage   = 10
  db_name             = "csye6225"
  engine              = "postgres"
  # engine_version       = "5.7"
  instance_class = "db.t3.micro"
  username       = "csye6225"
  password       = random_password.password.result

  parameter_group_name = aws_db_parameter_group.postgres_parameter_group.id
  # skip_final_snapshot = true
  multi_az               = false
  vpc_security_group_ids = [aws_security_group.database_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.database.id
}


resource "aws_security_group" "database_sg" {
  name        = "database"
  description = "Allow inbound traffic to 3306 from VPC"
  vpc_id      = aws_vpc.cloud_vpc.id

  ingress {
    description     = "open port 5432 to vpc"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ami-ec2-sg.id]
  }

  tags = {
    Name = "database"
  }
}

resource "aws_db_subnet_group" "database" {
  name       = "database1"
  subnet_ids = [aws_subnet.private_subnet[0].id, aws_subnet.private_subnet[1].id]

  tags = {
    Name = "database subnet group"
  }
}



# resource "aws_route53_record" "server_mapping_record" {
#   zone_id = var.zone_id
#   name    = var.domain_name
#   type    = "A"
#   ttl     = "60"
#   records = [aws_instance.cloud_instance.public_ip]
# }

resource "aws_route53_record" "server_mapping_record" {
  zone_id = var.zone_id
  name    = var.domain_name
  type    = "A"
  # ttl     = "60"
  # records = [aws_instance.cloud_instance.public_ip]
  alias {
    name                   = aws_lb.loadb.dns_name
    zone_id                = aws_lb.loadb.zone_id
    evaluate_target_health = true
  }

}
data "aws_iam_policy" "webapp_cloudwatch_server_policy" {
  arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_policy_attachment" "ec2_cloudwatch_policy_role" {
  name       = "webapp_cloudwatch_policy"
  roles      = [aws_iam_role.webapp_s3_access_role.name]
  policy_arn = data.aws_iam_policy.webapp_cloudwatch_server_policy.arn
}

resource "aws_autoscaling_group" "asg" {
  name                = "csye6225-asg-spring2023"
  max_size            = 3
  min_size            = 1
  desired_capacity    = 1
  force_delete        = true
  default_cooldown    = 60
  vpc_zone_identifier = [for subnet in aws_subnet.public_subnet : subnet.id]

  tag {
    key                 = "Name"
    value               = "WebApp ASG Instance"
    propagate_at_launch = true
  }

  launch_template {
    id      = aws_launch_template.lt.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.aloadb_tg.arn]
}

# resource "aws_autoscaling_policy" "asg_cpu_policy" {
#   name                   = "csye6225-asg-cpu"
#   autoscaling_group_name = aws_autoscaling_group.asg.name
#   adjustment_type        = "ChangeInCapacity"
#   policy_type            = "TargetTrackingScaling"

#   # CPU Utilization is above 5%

#   target_tracking_configuration {
#     predefined_metric_specification {
#       predefined_metric_type = "ASGAverageCPUUtilization"
#     }
#     target_value = 5.0
#   }
# }

resource "aws_autoscaling_policy" "scale-out" {
  name                   = "csye6225-asg-scale-out"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 60
  autoscaling_group_name = aws_autoscaling_group.asg.name
}

resource "aws_cloudwatch_metric_alarm" "scale-out" {
  alarm_name          = "csye6225-asg-scale-out"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 5

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.asg.name
  }

  alarm_description = "This metric monitors ec2 cpu utilization"
  alarm_actions     = [aws_autoscaling_policy.scale-out.arn]
}

resource "aws_autoscaling_policy" "scale-in" {
  name                   = "csye6225-asg-scale-in"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 60
  autoscaling_group_name = aws_autoscaling_group.asg.name
}

resource "aws_cloudwatch_metric_alarm" "scale-in" {
  alarm_name          = "csye6225-asg-scale-in"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 3

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.asg.name
  }

  alarm_description = "This metric monitors ec2 cpu utilization"
  alarm_actions     = [aws_autoscaling_policy.scale-in.arn]
}


resource "aws_security_group" "loadb_sg" {
  name        = "load balancer"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.cloud_vpc.id

  ingress {
    description = "https from Anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    # cidr_blocks      = [aws_vpc.vpc.cidr_block]
  }

  ingress {
    description = "http from anywhere"
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
    Name = "load balancer"
  }
}

resource "aws_lb" "loadb" {
  name               = "csye6225-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.loadb_sg.id]
  subnets            = [for subnet in aws_subnet.public_subnet : subnet.id]

  enable_deletion_protection = false

  # access_logs {
  #   bucket  = aws_s3_bucket.lb_logs.id
  #   prefix  = "csye6225-lb"
  #   enabled = true
  # }

  tags = {
    Application = "WebApp"
  }
}

resource "aws_lb_target_group" "aloadb_tg" {
  name        = "csye6225-lb-aloadb-tg"
  port        = 1324
  protocol    = "HTTP"
  vpc_id      = aws_vpc.cloud_vpc.id
  target_type = "instance"

  health_check {
    enabled             = true
    path                = "/healthz"
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 6
    interval            = 30
  }
}

resource "aws_lb_listener" "loadb_listener" {
  load_balancer_arn = aws_lb.loadb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.aloadb_tg.arn
  }
}