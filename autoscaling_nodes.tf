
data "template_file" "nodes" {
  template = "${file("${path.module}/scripts/userdata.tpl")}"

  vars {
    s3_id = "${aws_s3_bucket.cluster.id}"
    role = "node"
    ntp_servers = "${replace("${var.ntp_servers}", ",", " ")}"

    proxy = "${replace("${var.proxy_servers}", ",", " ")}"
    volume = ""

    load_balancer_dns = "${aws_elb.master.dns_name}"
  }

}



resource "aws_security_group" "nodes" {
  name        = "${var.name}-nodes"
  description = "${var.name}-nodes"
  vpc_id      = "${var.vpc}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}

resource "aws_security_group_rule" "master-node-communication" {
  type            = "ingress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  source_security_group_id = "${aws_security_group.master.id}"

  security_group_id = "${aws_security_group.nodes.id}"
}

resource "aws_launch_configuration" "nodes" {
  name_prefix      = "${var.name}-nodes-"
  image_id         = "${data.aws_ami.ubuntu.id}"
  instance_type    = "${var.node_instance_type}"
  security_groups  = ["${aws_security_group.nodes.id}"]
  key_name         = "${var.ssh_key}"
  user_data        = "${data.template_file.nodes.rendered}"
  iam_instance_profile = "${aws_iam_instance_profile.cluster.id}"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "nodes" {
  name_prefix               = "${var.name}-nodes-"
  max_size                  = 1
  min_size                  = 1
  health_check_grace_period = 300
  health_check_type         = "EC2"
  desired_capacity          = 1
  force_delete              = true
  launch_configuration      = "${aws_launch_configuration.nodes.name}"
  vpc_zone_identifier       = ["${data.aws_subnet_ids.vpc.ids}"]

  tags = [
    {
      key                 = "Name"
      value               = "${var.name}-node"
      propagate_at_launch = true
    },
    {
      key                 = "KubernetesCluster"
      value               = "${var.name}"
      propagate_at_launch = true
    },
    {
      key                 = "k8s.io/role/node"
      value               = 1 
      propagate_at_launch = true
    },
  ]

  lifecycle {
    create_before_destroy = true
  }
}