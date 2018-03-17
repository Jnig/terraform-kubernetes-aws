data "template_file" "certificate" {
  template = "${file("${path.module}/certs/certificate_crt.tpl")}"

  vars {
    certificate = "${var.additional-certificates}"
  }
}

resource "aws_s3_bucket_object" "certificate" {
  count                  = "${var.additional-certificates == "" ? 0 : 1}"
  bucket                 = "${aws_s3_bucket.cluster.id}"
  key                    = "scripts/installation/additional.crt"
  content                = "${data.template_file.certificate.rendered}"
  server_side_encryption = "AES256"
}
