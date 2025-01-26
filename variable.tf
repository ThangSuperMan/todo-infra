variable "aws_region" {
  type    = string
  default = "ap-southeast-1"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "vpc_cidr" {
  type        = string
  default     = "10.0.0.0/16"
  description = "CIDR block of the vpc"
}

variable "public_subnets_cidr" {
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
  description = "CIDR block for Public Subnet"
}

variable "private_subnets_cidr" {
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
  description = "CIDR block for Private Subnet"
}

variable "trusted_subnets_cidr" {
  type        = list(string)
  default     = ["10.0.5.0/24", "10.0.6.0/24"]
  description = "CIDR block for Trusted Subnet"
}

variable "mgmt_subnets_cidr" {
  type        = list(string)
  default     = ["10.0.7.0/25", "10.0.7.128/25"]
  description = "CIDR block for Management Subnet"
}

variable "keypair_path" {
  type    = string
  default = "./keypair/operation.pub"
}

variable "instance_types" {
  type        = map(string)
  description = "Instance type based on environment"
  default = {
    "prod" : "t3.micro",
    "dev" : "t2.micro",
  }
}

variable "bastion_ami" {
  type    = string
  default = "ami-0c4e27b0c52857dd6"
}

variable "db_ami" {
  type    = string
  default = "ami-0672fd5b9210aa093"
}

variable "db_instance_types" {
  type = map(string)
  default = {
    "prod" : "t3.micro",
    "dev" : "t2.micro",
  }
}
