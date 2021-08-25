variable "cidr_vpc" {
  description = "CIDR block for the VPC"
  default = "192.168.0.0/16"
}


variable "ami_id" {
  description = "ami_id_name"
  default = "ami-04db49c0fb2215364"
}


variable "instance_type" {
  default = "t2.micro"
}

variable "key_names" {
  default = "key000000"
}
variable "cidr_subnet1" {
  description = "CIDR block for the subnet"
  default = "192.168.1.0/24"
}

variable "availability_zone" {
  description = "availability zone to create subnet"
  default = "ap-south-1"
}
variable "environment_tag" {
  description = "Environment tag"
  default = "Production"

}


variable "key_name" {
  type = string
  default = "dev"
}
