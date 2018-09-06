variable "name" {
  description = "The cluster name"
}

variable "ssh_key" {
  description = "The name of SSH key to use"
}

variable "cluster_network_plugin" {
  description = "The Pod networking CNI network plugin : flannel(default) / weave"
  default     = "flannel"
}

variable "master_instance_type" {
  description = "The Master instance type"
  default     = "t2.small"
}

variable "node_instance_type" {
  description = "The node instance type"
  default     = "t2.large"
}

variable "node_asg_min" {
  description = "The minimal size of the node autoscaling group"
}

variable "node_asg_max" {
  description = "The maximum size of the node autoscaling group"
}

variable "node_asg_desired" {
  description = "The initial size of the node autoscaling group"
}

variable "vpc" {
  description = "The ID of the VPC containing the cluster"
}

variable "proxy_servers" {
  description = "The DNS name of the proxy server with port <ip>:port"
  default     = ""
}

variable "subnets" {
  description = "An array containing the subnets to spawn the cluster members in."
  default     = []
}

variable "kubernetes_version" {
  description = "The kubernetes version"
  default     = "1.8.7"
}

variable "kubernetes_dashboard_version" {
  description = "The Kubernetes Dashboard version"
  default     = "1.8.2"
}

variable "additional_iam_policy" {
  description = "The content of an additionnal IAM policy"
  default     = ""
}

variable "additional_certificates" {
  description = "Additional certificates put on the nodes, useful if you have private docker repositories"
  default     = ""
}

variable "additional_tags" {
  description = "Additionnal custom tags, e.g. for corporate billing"
  default     = {}
}

variable "enable_kube2iam" {
  description = "Enable Kube2IAM to add security to AWS API access from pods"
  default     = true
}

variable "disable_security_group_limit" {
  description = "use cloud config to set DisableSecurityGroupIngress to true, this will allow more than 50 Load Balancer Service in the cluster"
  default     = false
}
