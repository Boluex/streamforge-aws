variable "aws_region" {
  type    = string
  default = "eu-west-2"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "project_name" {
  type    = string
  default = "streamforge"
}

variable "vpc_cidr" {
  type    = string
  default = "10.40.0.0/16"
}

variable "availability_zones" {
  type    = list(string)
  default = ["eu-west-2a", "eu-west-2b"]
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.40.1.0/24", "10.40.2.0/24"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.40.11.0/24", "10.40.12.0/24"]
}

variable "backend_image" {
  type = string
}

variable "frontend_image" {
  type = string
}

variable "use_local_emulator" {
  type    = bool
  default = false
}

variable "ec2_endpoint" {
  type    = string
  default = "http://localhost:5003"
}

variable "aws_endpoint" {
  type    = string
  default = "http://localhost:4566"
}


variable "allowed_cidrs" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}
