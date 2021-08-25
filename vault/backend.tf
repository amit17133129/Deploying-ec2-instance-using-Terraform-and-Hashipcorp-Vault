terraform {
  backend "s3" {
    bucket = "terraformbackend1"
    key    = "dev/terraform.tfstate"
    region = "ap-south-1"
  }
}
