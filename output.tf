output "security_group_nodes_id" {
  value = "${aws_security_group.nodes.id}"
}

output "security_group_master_id" {
  value = "${aws_security_group.master.id}"
}

output "cluster_role_name" {
  value = "${aws_iam_role.cluster.name}"
}
