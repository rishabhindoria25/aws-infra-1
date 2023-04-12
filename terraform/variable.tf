variable "vpc_cidr_block" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}


variable "region" {
  type    = string
  default = "us-east-1"
}
variable "profile" {
  type    = string
  default = "dev"
}
data "aws_availability_zones" "available" {
  state = "available"
}
variable "subnet_private_count" {
  type    = number
  default = 3
}
variable "subnet_public_count" {
  type    = number
  default = 3
}
variable "ami_id" {
  type    = string
  default = "ami-02dc719e76b0f603f"
}

variable "ssh_key_name" {
  type    = string
  default = "ec2"
}

variable "domain_name" {
  default = "dev.rishabhindoria.me"
}

variable "zone_id" {
  default = "abc"
}



