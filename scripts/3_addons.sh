function install_helm {
 cd /tmp
 wget https://storage.googleapis.com/kubernetes-helm/helm-v2.8.0-linux-amd64.tar.gz 
 tar xfz helm-v2.8.0-linux-amd64.tar.gz
 mv linux-amd64/helm /usr/local/bin
}

function setup_helm {
  kubectl create serviceaccount tiller --namespace kube-system
cat <<EOF > /tmp/tiller.yml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: tiller
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: tiller
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: tiller
    namespace: kube-system

EOF
  kubectl apply -f /tmp/tiller.yml

  helm init --service-account tiller

  until kubectl rollout status deployment/tiller-deploy -n kube-system
  do
    echo "waiting for tiller deployment"
    sleep 5
  done
}

function setup_dashboard {
  helm upgrade -i kubernetes-dashboard stable/kubernetes-dashboard --namespace kube-system --set image.tag=v${kubernetes_dashboard_version},tolerations[0].effect=NoSchedule,tolerations[0].key=node-role.kubernetes.io/master,tolerations[0].operator=Exists,nodeSelector."node-role\.kubernetes\.io/master"=""
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
  name: system:aggregate-to-view
subjects:
- kind: ServiceAccount
  name: kubernetes-dashboard
  namespace: kube-system
EOF
  su ubuntu -c "kubectl apply -f /tmp/dashboard_admin.yaml"
}

function setup_autoscaler {
  cat <<EOF > /tmp/autoscaler.yml
autoscalingGroups:
  - name: ${node_asg_name}
    maxSize: ${node_asg_max}
    minSize: ${node_asg_min}
tolerations:
  - effect: NoSchedule
    key: node-role.kubernetes.io/master
    operator: Exists
rbac:
    create: true
nodeSelector:
    node-role.kubernetes.io/master: ""
awsRegion: eu-central-1
EOF
  if [ -n "$http_proxy" ]; then
    echo "extraEnv:" >> /tmp/autoscaler.yml
    echo "  HTTP_PROXY: \"$(cat /etc/terraform/load_balancer_dns):3128\"" >> /tmp/autoscaler.yml
    echo "  HTTPS_PROXY: \"$(cat /etc/terraform/load_balancer_dns):3128\"" >> /tmp/autoscaler.yml
  fi

  helm upgrade -i autoscaler stable/cluster-autoscaler --namespace kube-system -f /tmp/autoscaler.yml
}

function setup_external_dns {
  helm install --name external-dns stable/external-dns --set rbac.create=true,tolerations[0].effect=NoSchedule,tolerations[0].key=node-role.kubernetes.io/master,tolerations[0].operator=Exists,nodeSelector."node-role\.kubernetes\.io/master"="" --namespace kube-system
}

function setup_heapster {
  helm install --name heapster stable/heapster --set rbac.create=true --namespace kube-system
}

function setup_kube2iam {
  if [ "${enable_kube2iam}" == "true" ]; then
    helm install --name kube2iam stable/kube2iam --set=extraArgs.auto-discover-base-arn=true,rbac.create=true,host.iptables=true,host.interface=cni0 --namespace kube-system
  fi
}


install_helm
setup_helm
setup_dashboard
setup_autoscaler
setup_external_dns
setup_heapster
setup_kube2iam
