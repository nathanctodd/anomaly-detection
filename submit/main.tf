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

data "aws_ssm_parameter" "ubuntu_ami" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

resource "aws_s3_bucket" "bucket" {
  bucket = "ygu6ax-anomaly-detection"
}

resource "aws_sns_topic" "topic" {
  name = "ds5220-dp1"
}

resource "aws_sns_topic_policy" "topic_policy" {
  arn = aws_sns_topic.topic.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action   = "sns:Publish"
        Resource = aws_sns_topic.topic.arn
        Condition = {
          ArnLike = {
            "aws:SourceArn" = aws_s3_bucket.bucket.arn
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.bucket.id

  topic {
    topic_arn = aws_sns_topic.topic.arn
    events    = ["s3:ObjectCreated:*"]

    filter_prefix = "raw/"
    filter_suffix = ".csv"
  }
}

resource "aws_security_group" "sg" {
  name        = "anomaly-detection-sg"
  description = "Allow SSH and API"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["76.123.19.70/32"]
  }

  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "ec2_role" {
  name = "anomaly-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "s3_policy" {
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["s3:ListBucket"]
        Resource = aws_s3_bucket.bucket.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.bucket.arn}/*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "instance_profile" {
  name = "anomaly-instance-profile"
  role = aws_iam_role.ec2_role.name
}

resource "aws_instance" "ec2" {
  ami           = data.aws_ssm_parameter.ubuntu_ami.value
  instance_type = "t3.micro"
  key_name      = "ds5220"

  vpc_security_group_ids = [aws_security_group.sg.id]

  iam_instance_profile = aws_iam_instance_profile.instance_profile.name

  root_block_device {
    volume_size = 16
    volume_type = "gp3"
  }

  user_data = <<-EOF
    #!/bin/bash
    set -e
    apt-get update
    apt-get upgrade -y
    apt-get install -y curl wget git python3-pip python3-venv

    export BUCKET_NAME='${aws_s3_bucket.bucket.bucket}'
    echo "BUCKET_NAME='${aws_s3_bucket.bucket.bucket}'" >> /etc/environment

    git clone https://github.com/nathanctodd/anomaly-detection.git
    cd anomaly-detection

    python3 -m venv venv
    source venv/bin/activate

    pip install --upgrade pip
    pip install -r requirements.txt

    nohup fastapi run app.py &
  EOF
}

resource "aws_eip" "eip" {
  domain = "vpc"
}

resource "aws_eip_association" "eip_assoc" {
  instance_id   = aws_instance.ec2.id
  allocation_id = aws_eip.eip.id
}

resource "aws_sns_topic_subscription" "http_sub" {
  topic_arn = aws_sns_topic.topic.arn
  protocol  = "http"
  endpoint  = "http://${aws_eip.eip.public_ip}:8000/notify"
}

output "instance_id" {
  value = aws_instance.ec2.id
}

output "public_ip" {
  value = aws_eip.eip.public_ip
}

output "bucket_name" {
  value = aws_s3_bucket.bucket.bucket
}
