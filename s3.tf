resource "aws_s3_bucket" "cluster" {
  bucket_prefix = "${var.name}-"
  acl    = "private"

  force_destroy = true

  versioning {
    enabled = true
  }
}


resource "aws_s3_bucket_object" "prepare" {
  bucket = "${aws_s3_bucket.cluster.id}"
  key    = "scripts/installation/1_prepare.sh"
  content = "${file("${path.module}/scripts/1_prepare.sh")}"
  server_side_encryption = "AES256"
}

resource "aws_s3_bucket_object" "prepare2" {
  bucket = "${aws_s3_bucket.cluster.id}"
  key    = "scripts/installation/2_setup_kubernetes.sh"
  content = "${file("${path.module}/scripts/2_setup_kubernetes.sh")}"
  server_side_encryption = "AES256"
}


resource "aws_s3_bucket_object" "maint1" {
  bucket = "${aws_s3_bucket.cluster.id}"
  key    = "scripts/maintenance/9_verify_network.sh"
  content = "${file("${path.module}/scripts/9_verify_network.sh")}"
  server_side_encryption = "AES256"
}

resource "aws_s3_bucket_object" "kill" {
  bucket = "${aws_s3_bucket.cluster.id}"
  key    = "scripts/maintenance/10_kill.sh"
  content = "${file("${path.module}/scripts/10_kill.sh")}"
  server_side_encryption = "AES256"
}

resource "aws_s3_bucket_object" "example_nginx" {
  bucket = "${aws_s3_bucket.cluster.id}"
  key    = "scripts/examples/nginx.yaml"
  content = "${file("${path.module}/scripts/examples/nginx.yaml")}"
  server_side_encryption = "AES256"
}