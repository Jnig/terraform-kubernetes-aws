#!/bin/bash

. /etc/environment

function init_master {
dig +short $(cat /etc/terraform/load_balancer_dns) | head -1 > /etc/kubernetes/load_balancer_ip

cat <<EOF >/etc/kubeadm_config
apiVersion: kubeadm.k8s.io/v1alpha1
kind: MasterConfiguration
kubernetesVersion: ${kubernetes_version}
networking:
  serviceSubnet: 100.64.0.0/13
  podSubnet: 100.96.0.0/11
cloudProvider: aws
tokenTTL: "0"
api:
  advertiseAddress: "$(cat /etc/kubernetes/load_balancer_ip)"
  bindPort: 443
apiServerCertSANs:
- $(cat /etc/terraform/load_balancer_dns)
EOF

kubeadm init --config /etc/kubeadm_config &> /var/log/kubeadm_init
}

function setup_kubectl {
    mkdir -p /home/ubuntu/.kube

    cp -i /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
    chown ubuntu:ubuntu /home/ubuntu/.kube/config

    mkdir -p /root/.kube
    cp -i /etc/kubernetes/admin.conf /root/.kube/config
}

function setup_network {
    curl -s https://raw.githubusercontent.com/coreos/flannel/v0.9.1/Documentation/kube-flannel.yml | sed -e 's#v0.9.0#v0.9.1#' | sed -e 's#10.244.0.0/16#100.96.0.0/11#' > /tmp/flannel.yaml
    su ubuntu -c "kubectl apply -f /tmp/flannel.yaml"
}
function setup_dashboard {
    su ubuntu -c "kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v${kubernetes_dashboard_version}/src/deploy/recommended/kubernetes-dashboard.yaml"
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

function join_exists {
    aws s3api head-object --bucket $(cat /etc/terraform/s3_bucket) --key join --region eu-central-1 &> /dev/null 
}


function enable_completion {
    su ubuntu -c "echo 'source <(kubectl completion bash)' >> ~/.bashrc"
}

function switch_to_new_proxy {
    old="$(grep 3128 /etc/kubernetes/manifests/kube-apiserver.yaml  | head -n 1 | awk '{ print $2}')"
    new="$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)"
    sed -i "s/$old/$new:3128/g" /etc/kubernetes/manifests/*	
}

function generate_kubelet_config {
    systemctl stop kubelet
    
    until ! systemctl status kubelet | grep -q running
    do
        echo "wait until kubelet is stopped"
        sleep 5
        systemctl stop kubelet
    done

    rm -rf /var/lib/kubelet/pki/*
    mv /etc/kubernetes/kubelet.conf /etc/kubernetes/kubelet.conf-$(date +%s)
    kubeadm alpha phase kubeconfig kubelet --apiserver-advertise-address "$(cat /etc/kubernetes/load_balancer_ip)" --apiserver-bind-port 443

    systemctl start kubelet
}

function mark_master {
    kubeadm alpha phase mark-master $(hostname)
}

function create_storage_class {
  cat <<EOF >/tmp/storage_class.yaml
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: standard
  annotations:
    storageclass.kubernetes.io/is-default-class: true
provisioner: kubernetes.io/aws-ebs
parameters:
  type: gp2
reclaimPolicy: Retain
mountOptions:
  - debug
EOF

  su ubuntu -c "kubectl apply -f /tmp/storage_class.yaml"
}

if [ "$(cat /etc/terraform/role)" == "master" ]; then

    join_exists
    if [ "$?" == "255" ]; then
      	init_master
        setup_kubectl
        setup_network
        setup_dashboard
        upload_join_command
        create_storage_class
    else
	      test -n "$http_proxy" && switch_to_new_proxy
        generate_kubelet_config
        mark_master
        setup_kubectl
    fi

    enable_completion
else
    join_node
fi

