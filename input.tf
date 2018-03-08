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

variable "proxy_servers" {
    default = ""
}

variable "subnets" {
    default = []
}

variable "kubernetes_version" {
  default = "1.8.7"
}

variable "kubernetes_dashboard_version" {
  default = "1.8.2"
}

variable "iam_policy" {
   default =   ""
}
