provider "aws" { region = var.aws_region }

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

# Allow S3 artifact read/write to artifact prefix and KMS encrypt/generateDataKey for the key
resource "aws_iam_policy" "mlflow_s3_policy" {
  name = "mlflow-s3-policy-${var.env}"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:PutObjectAcl"
        ],
        Resource = [
          "arn:aws:s3:::${var.bucket_name}",
          "arn:aws:s3:::${var.bucket_name}/*"
        ]
      },
      # KMS permissions for using the CMK with S3
      {
        Effect = "Allow",
        Action = [
          "kms:GenerateDataKey*",
          "kms:Encrypt"
        ],
        Resource = var.kms_key_arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_mlflow" {
  role       = aws_iam_role.mlflow_instance_role.name
  policy_arn = aws_iam_policy.mlflow_s3_policy.arn
}

resource "aws_iam_instance_profile" "mlflow_profile" {
  name = "mlflow-instance-profile-${var.env}"
  role = aws_iam_role.mlflow_instance_role.name
}

resource "aws_security_group" "mlflow_sg" {
  name   = "mlflow-sg-${var.env}"
  vpc_id = data.aws_vpc.default.id # or your VPC
  ingress {
    description = "MLflow UI"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }
  egress { from_port = 0; to_port = 0; protocol = "-1"; cidr_blocks = ["0.0.0.0/0"] }
}

resource "aws_instance" "mlflow" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  iam_instance_profile   = aws_iam_instance_profile.mlflow_profile.name
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.mlflow_sg.id]
  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y docker.io jq
              systemctl start docker
              mkdir -p /mlflow
              chown ubuntu:ubuntu /mlflow || true
              # run MLflow server: sqlite backend, S3 artifact root
              docker run -d --name mlflow \
                -p 5000:5000 \
                -v /mlflow:/mlflow \
                -e AWS_REGION=${var.aws_region} \
                mlflow:latest \
                mlflow server \
                  --host 0.0.0.0 \
                  --port 5000 \
                  --backend-store-uri sqlite:////mlflow/mlflow.db \
                  --default-artifact-root s3://${var.bucket_name}/mlflow-artifacts/${var.env}
              EOF
  tags = { Name = "mlflow-${var.env}" }
}