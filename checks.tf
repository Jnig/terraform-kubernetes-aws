# This file contains assertions for variables based on the (horrible) workaround
# https://www.linkedin.com/pulse/devops-how-do-assertion-test-terraform-template-jamie-nelson/
locals {
  # The minimal desired kubernetes version

  kubernetes_minimal_major_version = 1
  kubernetes_minimal_minor_version = 9
  kubernetes_split_version         = "${split(".", var.kubernetes_version)}"
  kubernetes_major_version_OK      = "${element(local.kubernetes_split_version, 0) >= local.kubernetes_minimal_major_version ? 0 : 1}"
  kubernetes_minor_version_OK      = "${element(local.kubernetes_split_version, 1) >= local.kubernetes_minimal_minor_version ? 0 : 1}"
}

resource "null_resource" "test_version" {
  count = "${ max(local.kubernetes_major_version_OK, local.kubernetes_minor_version_OK)}"
  "ERROR: Kubernetes supported versions are over >= ${local.kubernetes_minimal_major_version}.${local.kubernetes_minimal_minor_version}" = true
}
