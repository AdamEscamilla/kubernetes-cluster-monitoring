variable "private_key_path" {}
variable "public_key" {}

variable "master_port" {
  default = "8080"
}

variable "server_port" {
  default = "8080"
}

variable "region" {
  default = "us-east-1"
}

variable "env" {
  default = "demo"
}

variable "stack" {
  default = "test"
}

variable "key_name" {
  default = "admin"
}

variable "vpc_cidr" {
  default = "10.5.0.0/16"
}

variable "public_subnets" {
  default = ["10.5.69.0/24"]
}

variable "private_subnets" {
  default = ["10.5.4.0/24", "10.5.5.0/24"]
}

variable "enable_dns_hostnames" {
  default = true
}

variable "enable_dns_support" {
  default = true
}

variable "map_public_ip_on_launch" {
  default = true
}

variable "availability_zones" {
  default = ["a"]
}

variable "master_instance_count" {
  default = 1
}

variable "node_instance_count" {
  default = 1 # requires more testing
}

variable "ami" {
  default = {
    us-east-1 = "ami-a2577cb4"
  }
}

variable "instance_type" {
  default = "t2.micro"
}

variable "nat_instance_type" {
  default = "t2.micro"
}

variable "node_instance_type" {
  default = "t2.medium"
}

variable "nat_ami" {
  default = {
    "us-east-1" = "ami-293a183f"
  }
}

variable "bastion_instance_type" {
  default = "t2.micro"
}

variable "bastion_ami" {
  default = {
    "us-east-1" = "ami-f652979b"
  }
}

output "bastion_public_ip" {
  value = "${aws_instance.bastion.public_ip}"
}

output "master_private_ips" {
  value = ["${aws_instance.master.*.private_ip}"]
}

output "node_private_ips" {
  value = ["${aws_instance.node.*.private_ip}"]
}

output "nat_private_ips" {
  value = ["${aws_instance.nat.*.private_ip}"]
}

variable "instance_ips" {
  default = ["10.5.5.10", "10.5.5.11"]
}
