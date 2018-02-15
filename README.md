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
    source = "github.com/Jnig/terraform-kubernetes-aws?ref=v0.6"
    name = "devops-dev-cluster"

    ssh_key = "${aws_key_pair.ssh.key_name}"

    master_instance_type = "t2.medium"

    node_instance_type = "t2.large"
    node_asg_min = 1
    node_asg_max = 2
    node_asg_desired = 2

    vpc = "<vpc>"
    subnets = ["subnet1", "subnet2", "subnet3"]
    proxy_servers = "<proxy with port>"
}
```

Known limitations
------------
* backups are missing

