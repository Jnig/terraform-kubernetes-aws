data "aws_subnet" "region_1b" {
  id = "${var.subnets[1]}"
}

data "aws_subnet" "region_1c" {
  id = "${var.subnets[2]}"
}

data "template_file" "nodes" {
  template = "${file("${path.module}/scripts/userdata.tpl")}"

  vars {
    s3_id             = "${aws_s3_bucket.cluster.id}"
    role              = "node"
    proxy             = "${replace("${var.proxy_servers}", ",", " ")}"
    volume            = ""
    load_balancer_dns = "${aws_lb.master.dns_name}"
    net_plugin        = "${var.cluster_network_plugin}"
  }
}

resource "aws_security_group" "nodes" {
  name_prefix = "${var.name}-nodes"
  description = "${var.name}-nodes"
  vpc_id      = "${var.vpc}"
  tags        = "${var.additional_tags}"
}

resource "aws_security_group_rule" "nodes-self" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  self              = true
  security_group_id = "${aws_security_group.nodes.id}"
}

resource "aws_security_group_rule" "nodes-ssh" {
  type        = "ingress"
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = "${aws_security_group.nodes.id}"
}

resource "aws_security_group_rule" "nodes-egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.nodes.id}"
}

resource "aws_security_group_rule" "master-node-communication" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = "${aws_security_group.master.id}"
  security_group_id        = "${aws_security_group.nodes.id}"
}

resource "aws_security_group_rule" "elb-node-communication" {
  # Allows elb created as LoadBalancer services to serve the nodes
  # if the per ELB security rule creation was disabled
  count = "${var.kubernetes_disable_elb_security_rule_creation == "true" ? 1 : 0}"
  type                     = "ingress"
  # Use kube-proxy ports
  from_port                = 30000
  to_port                  = 32767
  protocol                 = "-1"
  # Use the VPC cidr block
  cidr_blocks       = ["${data.aws_vpc.selected.cidr_block}"]
  security_group_id        = "${aws_security_group.nodes.id}"
}

resource "aws_launch_configuration" "nodes" {
  name_prefix          = "${var.name}-nodes-"
  image_id             = "${data.aws_ami.ubuntu.id}"
  instance_type        = "${var.node_instance_type}"
  security_groups      = ["${aws_security_group.nodes.id}"]
  key_name             = "${var.ssh_key}"
  user_data            = "${data.template_file.nodes.rendered}"
  iam_instance_profile = "${aws_iam_instance_profile.cluster.id}"

  root_block_device {
    volume_size = 60
    volume_type = "gp2"
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes        = ["image_id"]
  }
}

resource "aws_autoscaling_group" "nodes" {
  name_prefix               = "${var.name}-nodes-"
  max_size                  = "${var.node_asg_max}"
  min_size                  = "${var.node_asg_min}"
  health_check_grace_period = 300
  health_check_type         = "EC2"
  desired_capacity          = "${var.node_asg_desired}"
  force_delete              = true
  launch_configuration      = "${aws_launch_configuration.nodes.name}"
  vpc_zone_identifier       = ["${data.aws_subnet.region_1b.id}", "${data.aws_subnet.region_1c.id}"]

  tags = ["${concat(
      list(map("key", "Name", "value", "${var.name}-node", "propagate_at_launch", true),
        map("key", "KubernetesCluster", "value", "${var.name}", "propagate_at_launch", true),
        map("key", "k8s.io/role/node", "value", 1, "propagate_at_launch", true),
      ),
      local.tags_asg_format
   )}"]

  lifecycle {
    create_before_destroy = true
  }
}
