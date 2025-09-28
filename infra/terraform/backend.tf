terraform {
  backend "s3" {
    bucket         = "rehab-terraform-state" # replace with actual bucket
    key            = "dev/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "rehab-locks" # replace with actual table
    encrypt        = true
  }
}
