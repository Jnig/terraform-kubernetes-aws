data "aws_subnet" "region_1a" {
  id = "${var.subnets[0]}"
}

data "template_file" "master" {
  template = "${file("${path.module}/scripts/userdata.tpl")}"

  vars {
    s3_id = "${aws_s3_bucket.cluster.id}"
    role = "master"

    proxy = "${replace("${var.proxy_servers}", ",", " ")}"
    volume = "${aws_ebs_volume.master.id}"
    load_balancer_dns = "${aws_elb.master.dns_name}"
  }
}

resource "aws_ebs_volume" "master" {
    availability_zone = "${data.aws_subnet.region_1a.availability_zone}"
    size = 40
    encrypted = true
    type = "gp2"
    tags {
        Name = "${var.name}-master"
    }
}

resource "aws_security_group" "master" {
  name        = "${var.name}-master"
  description = "${var.name}-master"
  vpc_id      = "${var.vpc}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    security_groups = ["${aws_security_group.nodes.id}"]
  }


  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}
resource "aws_launch_configuration" "master" {
  name_prefix      = "${var.name}-master-"
  image_id         = "${data.aws_ami.ubuntu.id}"
  instance_type    = "${var.master_instance_type}"
  security_groups  = ["${aws_security_group.master.id}"]
  key_name         = "${var.ssh_key}"
  user_data        = "${data.template_file.master.rendered}"
  iam_instance_profile = "${aws_iam_instance_profile.cluster.id}"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "master" {
  name_prefix               = "${var.name}-master-"
  max_size                  = 1
  min_size                  = 1
  health_check_grace_period = 300
  health_check_type         = "EC2"
  desired_capacity          = 1
  force_delete              = true
  launch_configuration      = "${aws_launch_configuration.master.name}"
  vpc_zone_identifier       = ["${data.aws_subnet.region_1a.id}"]

  load_balancers  = ["${aws_elb.master.id}"]

  tags = [
    {
      key                 = "Name"
      value               = "${var.name}-master"
      propagate_at_launch = true
    },
    {
      key                 = "KubernetesCluster"
      value               = "${var.name}"
      propagate_at_launch = true
    },
    {
      key                 = "k8s.io/role/master"
      value               = 1 
      propagate_at_launch = true
    },
  ]

  lifecycle {
    create_before_destroy = true
  }
}


resource "aws_elb" "master" {
  name = "${var.name}-master"
  internal        = true
  subnets         = ["${data.aws_subnet.region_1a.id}"]
  security_groups = ["${aws_security_group.master.id}"]

  listener {
    instance_port     = 443
    instance_protocol = "tcp"
    lb_port           = 443
    lb_protocol       = "tcp"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTPS:443/healthz"
    interval            = 30
  }

  tags = {
    Name = "${var.name}-master"
  }

}
