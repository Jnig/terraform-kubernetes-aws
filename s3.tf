resource "aws_s3_bucket" "cluster" {
  bucket_prefix = "${var.name}-"
  acl    = "private"

  force_destroy = true

  versioning {
    enabled = true
  }

  tags {
    Application = "${var.tagging_common_Application}"
    Billing_ID  = "${var.tagging_common_Billing_ID}"
    Owner       = "${var.tagging_common_Owner}"
  }
}

data "template_file" "prepare" {
  template = "${file("${path.module}/scripts/1_prepare.sh")}"

  vars {
    kubernetes_version = "${var.kubernetes_version}"
  }
}

data "template_file" "prepare2" {
  template = "${file("${path.module}/scripts/2_setup_kubernetes.sh")}"

  vars {
    kubernetes_version = "${var.kubernetes_version}"
    kubernetes_dashboard_version = "${var.kubernetes_dashboard_version}"
  }
}

resource "aws_s3_bucket_object" "prepare" {
  bucket = "${aws_s3_bucket.cluster.id}"
  key    = "scripts/installation/1_prepare.sh"
  content = "${data.template_file.prepare.rendered}"
  server_side_encryption = "AES256"

  tags {
    Application = "${var.tagging_common_Application}"
    Billing_ID  = "${var.tagging_common_Billing_ID}"
    Owner       = "${var.tagging_common_Owner}"
  }
}

resource "aws_s3_bucket_object" "prepare2" {
  bucket = "${aws_s3_bucket.cluster.id}"
  key    = "scripts/installation/2_setup_kubernetes.sh"
  content = "${data.template_file.prepare2.rendered}"
  server_side_encryption = "AES256"

  tags {
    Application = "${var.tagging_common_Application}"
    Billing_ID  = "${var.tagging_common_Billing_ID}"
    Owner       = "${var.tagging_common_Owner}"
  }
}

resource "aws_s3_bucket_object" "maint1" {
  bucket = "${aws_s3_bucket.cluster.id}"
  key    = "scripts/maintenance/9_verify_network.sh"
  content = "${file("${path.module}/scripts/9_verify_network.sh")}"
  server_side_encryption = "AES256"

  tags {
    Application = "${var.tagging_common_Application}"
    Billing_ID  = "${var.tagging_common_Billing_ID}"
    Owner       = "${var.tagging_common_Owner}"
  }
}

resource "aws_s3_bucket_object" "createnamespace" {
  bucket = "${aws_s3_bucket.cluster.id}"
  key    = "scripts/maintenance/create_namespace_for_customer.sh"
  content = "${file("${path.module}/scripts/create_namespace_for_customer.sh")}"
  server_side_encryption = "AES256"

  tags {
    Application = "${var.tagging_common_Application}"
    Billing_ID  = "${var.tagging_common_Billing_ID}"
    Owner       = "${var.tagging_common_Owner}"
  }
}

resource "aws_s3_bucket_object" "kill" {
  bucket = "${aws_s3_bucket.cluster.id}"
  key    = "scripts/maintenance/10_kill.sh"
  content = "${file("${path.module}/scripts/10_kill.sh")}"
  server_side_encryption = "AES256"

  tags {
    Application = "${var.tagging_common_Application}"
    Billing_ID  = "${var.tagging_common_Billing_ID}"
    Owner       = "${var.tagging_common_Owner}"
  }
}

resource "aws_s3_bucket_object" "check_proxy" {
  bucket = "${aws_s3_bucket.cluster.id}"
  key    = "scripts/maintenance/proxy_healthcheck.sh"
  content = "${file("${path.module}/scripts/proxy_healthcheck.sh")}"
  server_side_encryption = "AES256"

  tags {
    Application = "${var.tagging_common_Application}"
    Billing_ID  = "${var.tagging_common_Billing_ID}"
    Owner       = "${var.tagging_common_Owner}"
  }
}

resource "aws_s3_bucket_object" "example_nginx" {
  bucket = "${aws_s3_bucket.cluster.id}"
  key    = "scripts/examples/nginx.yaml"
  content = "${file("${path.module}/scripts/examples/nginx.yaml")}"
  server_side_encryption = "AES256"

  tags {
    Application = "${var.tagging_common_Application}"
    Billing_ID  = "${var.tagging_common_Billing_ID}"
    Owner       = "${var.tagging_common_Owner}"
  }
}

data "template_file" "addons" {
  template = "${file("${path.module}/scripts/3_addons.sh")}"

  vars {
    node_asg_name = "${aws_autoscaling_group.nodes.name}"
    node_asg_min = "${var.node_asg_min}"
    node_asg_max = "${var.node_asg_max}"
  }

  tags {
    Application = "${var.tagging_common_Application}"
    Billing_ID  = "${var.tagging_common_Billing_ID}"
    Owner       = "${var.tagging_common_Owner}"
  }
}

resource "aws_s3_bucket_object" "addons" {
  bucket = "${aws_s3_bucket.cluster.id}"
  key    = "scripts/installation/3_addons.sh"
  content = "${data.template_file.addons.rendered}"
  server_side_encryption = "AES256"

  tags {
    Application = "${var.tagging_common_Application}"
    Billing_ID  = "${var.tagging_common_Billing_ID}"
    Owner       = "${var.tagging_common_Owner}"
  }
}
