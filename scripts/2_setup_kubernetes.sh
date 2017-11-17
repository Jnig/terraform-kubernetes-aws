#!/bin/bash

. /etc/environment

function init_master {
cat <<EOF >/etc/kubeadm_config
apiVersion: kubeadm.k8s.io/v1alpha1
kind: MasterConfiguration
networking:
  serviceSubnet: 100.64.0.0/13
  podSubnet: 100.96.0.0/11
cloudProvider: aws
tokenTTL: "0"
api:
  advertiseAddress: "$(dig +short $(cat /etc/terraform/load_balancer_dns))"
  bindPort: 443
EOF

kubeadm init --config /etc/kubeadm_config &> /var/log/kubeadm_init
}

function setup_kubectl {
    mkdir -p /home/ubuntu/.kube
    cp -i /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
    chown ubuntu:ubuntu /home/ubuntu/.kube/config
}

function setup_network {
    curl -s https://raw.githubusercontent.com/coreos/flannel/v0.9.1/Documentation/kube-flannel.yml | sed -e 's#v0.9.0#v0.9.1#' | sed -e 's#10.244.0.0/16#100.96.0.0/11#' > /tmp/flannel.yaml
    su ubuntu -c "kubectl apply -f /tmp/flannel.yaml"
}
function setup_dashboard {
    su ubuntu -c "kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v1.7.1/src/deploy/recommended/kubernetes-dashboard.yaml"
    cat <<EOF >/tmp/dashboard_admin.yaml
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: kubernetes-dashboard
  labels:
    k8s-app: kubernetes-dashboard
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: kubernetes-dashboard
  namespace: kube-system
EOF
    su ubuntu -c "kubectl apply -f /tmp/dashboard_admin.yaml"
}
function upload_join_command {
    grep 'kubeadm join'  /var/log/kubeadm_init | aws s3 cp - s3://$(cat /etc/terraform/s3_bucket)/join --sse --region eu-central-1
}

function join_node {
    # s3api is limited to a certain amount of max attempts
    until aws s3api wait object-exists --bucket $(cat /etc/terraform/s3_bucket) --key join --region eu-central-1
    do 
        echo "waiting for join file" 
    done

    aws s3 cp s3://$(cat /etc/terraform/s3_bucket)/join installation/3_join.sh --sse --region eu-central-1
    chmod +x installation/3_join.sh
    ./installation/3_join.sh
}

function enable_completion {
    su ubuntu -c "echo 'source <(kubectl completion bash)' >> ~/.bashrc"
}

if [ "$(cat /etc/terraform/role)" == "master" ]; then
    init_master
    setup_kubectl
    setup_network
    setup_dashboard
    upload_join_command
    enable_completion
else
    join_node
fi

