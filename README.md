AWS Kubernetes behind a corporate proxy
=======================================
Terraform module create a kubernetes cluster in an AWS VPC which has only internet access through a corporate proxy

Usage
-----

```hcl
provider "aws" {
  region = "eu-central-1"
}

resource "aws_key_pair" "ssh" {
  key_name   = "<name>"
  public_key = "<key>"
}

module "kubernetes" {
    source = "github.com/Jnig/terraform-kubernetes-aws?ref=v0.1"
    name = "devops-dev-cluster"

    ssh_key = "${aws_key_pair.ssh.key_name}"

    master_instance_type = "t2.medium"

    node_instance_type = "t2.large"
    node_asg_min = 1
    node_asg_max = 2
    node_asg_desired = 2

    vpc = "<vpc>"
    ntp_servers = "<comma seperated list>"
    proxy_servers = "<proxy with port>"
}
```

Known limitations
------------
* master is hardcoded in eu-central-1a
* backups are missing

