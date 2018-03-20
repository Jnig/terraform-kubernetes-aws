
resource "aws_s3_bucket_object" "certificate" {
  count                  = "${var.additional_certificates == "" ? 0 : 1}"
  bucket                 = "${aws_s3_bucket.cluster.id}"
  key                    = "scripts/installation/additional.crt"
  content                = "${var.additional_certificates}"
  server_side_encryption = "AES256"

  tags = "${var.additional_tags}"
}
