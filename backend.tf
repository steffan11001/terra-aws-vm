terraform {
  backend "s3" {
    bucket         = "my-terraform-state-bucket"
    key            = "my-terraform-state-bucket/teterraform.tfstate"
    region         = "us-west-2"
  }
}