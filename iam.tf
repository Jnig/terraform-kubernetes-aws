resource "aws_iam_role" "cluster" {
  name        = "${var.name}"
  description = "Kubernetes cluster master and worker nodes"
  path        = "/"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "cluster" {
  name = "${var.name}"
  role = "${aws_iam_role.cluster.name}"
}

data "template_file" "role_policy" {
  template = "${file("${path.module}/policies/iam.json")}"

  vars {
    s3_arn = "${aws_s3_bucket.cluster.arn}"
  }
}

resource "aws_iam_role_policy" "main" {
  name        = "${var.name}-main"
  role        = "${aws_iam_role.cluster.id}"
  policy      =  "${data.template_file.role_policy.rendered}"
}

resource "aws_iam_role_policy" "additional" {
  count       = "${var.additional_iam_policy == "" ? 0 : 1}"
  name        = "${var.name}-additional"
  role        = "${aws_iam_role.cluster.id}"
  policy      = "${var.additional_iam_policy}"
}
