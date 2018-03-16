output "security_group_nodes_id" {
   value = "${aws_security_group.nodes.id}"
}

output "security_group_master_id" {
   value = "${aws_security_group.master.id}"
}

