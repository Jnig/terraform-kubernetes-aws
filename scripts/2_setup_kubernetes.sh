#!/bin/bash

. /etc/environment

function init_master {
# Create the file regarding the version of K8s
# in v1alpha1 if < kubeadm 1.11
# in v1alpha2 if >= kubeadm 1.11

# If we want to disable the 50 lb security group limit, we use SisableSecurityGroupIngress with cloud confg (setup later)
# otherwise , we let the cloud config file empty (only [global] tag )

if [ "${disable_security_group_limit}" == "true" ]; then

cat <<EOF > /etc/kubernetes/cloud-config
[global]
DisableSecurityGroupIngress = true
EOF

else

cat <<EOF > /etc/kubernetes/cloud-config
[global]
EOF

fi


# regarding the version of kubernetes, the setup for cloud config is different (unfortunatly)

if [ "`printf "$kubernetes_version\n1.11.0" | sort -V | head -n 1`" == "1.11.0" ]; then

cat <<EOF >/etc/kubeadm_config
apiVersion: kubeadm.k8s.io/v1alpha2
kind: MasterConfiguration
kubernetesVersion: ${kubernetes_version}
networking:
  serviceSubnet: 100.64.0.0/13
  podSubnet: 100.96.0.0/11
tokenTTL: "0"
api:
  advertiseAddress: "$(cat /etc/terraform/load_balancer_ip)"
  bindPort: 443
# See https://github.com/kubernetes/kubernetes/blob/888546c3252530c6a3f219363edae2b4b1057287/CHANGELOG-1.11.md#new-deprecations
apiServerExtraArgs:
  cloud-provider: "aws"
  cloud-config: "/etc/kubernetes/cloud-config"
apiServerExtraVolumes:
- name: cloud
  hostPath: "/etc/kubernetes/cloud-config"
  mountPath: "/etc/kubernetes/cloud-config"
controllerManagerExtraArgs:
  cloud-provider: "aws"
  cloud-config: "/etc/kubernetes/cloud-config"
controllerManagerExtraVolumes:
- name: cloud
  hostPath: "/etc/kubernetes/cloud-config"
  mountPath: "/etc/kubernetes/cloud-config"
apiServerCertSANs:
- $(cat /etc/terraform/load_balancer_dns)
EOF

else


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
  advertiseAddress: "$(cat /etc/terraform/load_balancer_ip)"
  bindPort: 443
apiServerCertSANs:
- $(cat /etc/terraform/load_balancer_dns)
EOF

fi

kubeadm init --config /etc/kubeadm_config &> /var/log/kubeadm_init
}

function setup_kubectl {
    mkdir -p /home/ubuntu/.kube

    cp -i /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
    chown ubuntu:ubuntu /home/ubuntu/.kube/config

    mkdir -p /root/.kube
    cp -i /etc/kubernetes/admin.conf /root/.kube/config

    aws s3 cp /etc/kubernetes/admin.conf s3://$(cat /etc/terraform/s3_bucket) --region eu-central-1

    kubectl create serviceaccount dashboard-admin -n kube-system
    kubectl create clusterrolebinding dashboard-admin --clusterrole=cluster-admin --serviceaccount=kube-system:dashboard-admin
}

function setup_network {
    plugin=$1
    case $plugin in
"weave")
  echo "Setting up Weave Net"
  curl -s "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')\&env.WEAVE_MTU=8912&env.IPALLOC_RANGE=100.96.0.0/11"  > /tmp/weave.yaml
  su ubuntu -c "kubectl apply -f /tmp/weave.yaml" 
  ;;
"flannel")
  echo "Setting up Flannel"
  curl -s "https://raw.githubusercontent.com/coreos/flannel/v0.9.1/Documentation/kube-flannel.yml" | sed -e 's#v0.9.0#v0.9.1#' | sed -e 's#10.244.0.0/16#100.96.0.0/11#' > /tmp/flannel.yaml
  su ubuntu -c "kubectl apply -f /tmp/flannel.yaml" 
  ;;
*)
  echo "Unknown or no Network plugin set"
  exit 1
;;
esac
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
    kubeadm alpha phase kubeconfig kubelet --apiserver-advertise-address "$(cat /etc/terraform/load_balancer_ip)" --apiserver-bind-port 443

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
    storageclass.kubernetes.io/is-default-class: "true"
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
        setup_network $1
        upload_join_command
        create_storage_class
    else
        generate_kubelet_config
        mark_master
        setup_kubectl
    fi

    enable_completion
else
    join_node
fi

