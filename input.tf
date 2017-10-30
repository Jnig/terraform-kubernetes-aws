variable "name" {}
variable "ssh_key" {}

variable "master_instance_type" {
    default = "t2.medium"
} 

variable "node_instance_type" {
    default = "t2.large"
}

variable "node_asg_min" {}
variable "node_asg_max" {}
variable "node_asg_desired" {}
variable "vpc" {}

variable "ntp_servers" {}

variable "proxy_servers" {}