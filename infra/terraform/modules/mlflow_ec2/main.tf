provider "aws" {
  region = var.aws_region
}

# ---------- IAM role for MLflow EC2 instance ----------
resource "aws_iam_role" "mlflow_instance_role" {
  name = "mlflow-instance-role-${var.env}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "ec2.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

# Build an IAM policy document with S3 access + optional KMS permissions
data "aws_iam_policy_document" "mlflow_s3_policy_doc" {
  statement {
    sid    = "S3Access"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:ListBucket",
      "s3:PutObjectAcl"
    ]

    resources = [
      "arn:aws:s3:::${var.bucket_name}",
      "arn:aws:s3:::${var.bucket_name}/*"
    ]
  }

  # Add KMS statement only if a KMS ARN was provided
  dynamic "statement" {
    for_each = var.kms_key_arn != "" ? [var.kms_key_arn] : []
    content {
      sid     = "KMSAccess"
      effect  = "Allow"
      actions = [
        "kms:GenerateDataKey*",
        "kms:Encrypt",
        "kms:Decrypt"
      ]
      resources = [statement.value]
    }
  }
}

resource "aws_iam_policy" "mlflow_s3_policy" {
  name   = "mlflow-s3-policy-${var.env}"
  policy = data.aws_iam_policy_document.mlflow_s3_policy_doc.json
}

resource "aws_iam_role_policy_attachment" "attach_mlflow" {
  role       = aws_iam_role.mlflow_instance_role.name
  policy_arn = aws_iam_policy.mlflow_s3_policy.arn
}

resource "aws_iam_instance_profile" "mlflow_profile" {
  name = "mlflow-instance-profile-${var.env}"
  role = aws_iam_role.mlflow_instance_role.name
}

# ---------- Security Group ----------
# IMPORTANT: ensure var.allowed_cidr is not 0.0.0.0/0 in production.
resource "aws_security_group" "mlflow_sg" {
  name   = "mlflow-sg-${var.env}"
  vpc_id = data.aws_vpc.default.id

  ingress {
    description = "MLflow UI (restricted)"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "mlflow-sg-${var.env}"
    Environment = var.env
  }
}

# ---------- EC2 Instance for MLflow (dev/smoke) ----------
# NOTE: For production consider ECS/EKS or an ASG + private subnet + ALB.
resource "aws_instance" "mlflow" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  iam_instance_profile   = aws_iam_instance_profile.mlflow_profile.name
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.mlflow_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              set -euo pipefail
              apt-get update -y
              apt-get install -y python3 python3-pip python3-venv jq
              mkdir -p /mlflow/data
              chown -R ubuntu:ubuntu /mlflow
              su - ubuntu -c "python3 -m venv /home/ubuntu/mlflow-venv || true"
              su - ubuntu -c "/home/ubuntu/mlflow-venv/bin/pip install --upgrade pip"
              su - ubuntu -c "/home/ubuntu/mlflow-venv/bin/pip install mlflow"
              su - ubuntu -c "nohup /home/ubuntu/mlflow-venv/bin/mlflow server \
                --host 0.0.0.0 \
                --port 5000 \
                --backend-store-uri sqlite:////mlflow/data/mlflow.db \
                --default-artifact-root s3://${var.bucket_name}/mlflow-artifacts/${var.env} \
                > /var/log/mlflow.log 2>&1 &"
              EOF

  tags = {
    Name        = "mlflow-${var.env}"
    Environment = var.env
    Project     = "rehab-saas"
  }
}

# Ensure the following data sources exist in your root module:
# data "aws_vpc" "default" { default = true }
# data "aws_ami" "ubuntu" {
#   most_recent = true
#   filter {
#     name   = "name"
#     values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"] # example AMI
#   }
#   owners = ["099720109477"] # Canonical
# }
