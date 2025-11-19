# provider do AWS

provider "aws" {
  access_key = var.access_key
  secret_key = var.secret_key
  region     = var.region
}

/*
Data source for AZs
*/
data "aws_availability_zones" "available" {
  state = "available"
}
