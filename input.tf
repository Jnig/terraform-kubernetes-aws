variable "name" {}
variable "ssh_key" {}

variable "cluster_network_plugin" {
  description = "The Pod networking CNI network plugin : flannel(default) / weave"
  default     = "flannel"
}

variable "master_instance_type" {
  default = "t2.small"
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

variable "additional_iam_policy" {
  default = ""
}

variable "additional_certificates" {
  default = ""
}

variable "additional_tags" {
  default = {}
}

variable "enable_kube2iam" {
  default = true
}
