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
  source = "github.com/Jnig/terraform-kubernetes-aws?ref=v0.10"
  name = "devops-dev-cluster"

  ssh_key = "${aws_key_pair.ssh.key_name}"

  master_instance_type = "t2.medium"

  node_instance_type = "t2.large"
  node_asg_min = 1
  node_asg_max = 2
  node_asg_desired = 2

  #aws ec2 describe-vpcs
  vpc = "<vpc>"

  # aws ec2 describe-subnets --filters Name=vpc-id,Values=<vpc>
  # tag all subnets with the name of the cluster: kubernetes.io/cluster/<name>
  subnets = ["subnet1", "subnet2", "subnet3"]

  proxy_servers = "<proxy with port>"
  
  # optional add additional certificates to the nodes
  # useful if you have private docker repositories
  additional_certificates = <<EOF
-----BEGIN CERTIFICATE-----
....
-----END CERTIFICATE-----    
EOF

  # optional add common tags, e.g. for corporate billing
  additional_tags = {
    Application = ""
    Billing_ID = ""
    Owner = ""
  }

  # optionnal change network plugin: flannel(default) / weave
}
```

Known limitations
------------
* backups are missing

Get kubernetes dashboard secret
------
```
kubectl describe secret dashboard-admin -n kube-system
```

