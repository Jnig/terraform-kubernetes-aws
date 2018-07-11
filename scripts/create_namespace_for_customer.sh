#!/bin/bash

## Parameters
USERNAME=$1
CERTDAYS=$2

if [ $# -eq 0 ]; then 
 echo "Usage: "
 echo "$0 <username> [days]"
 echo "username: name of namespace, role, binding which should be created"
 echo "days:     nr of days the certificate should be valid (optional, default 2048)"
 exit 1
fi

if [[ "$USERNAME" =~ [^a-zA-Z0-9] ]]; then
  echo "Parameter $USERNAME is invalid, only alpanumeric characters are allowed"
  exit 1
fi

if [ "xx${CERTDAYS}xx" != "xxxx" ] && [ $CERTDAYS =~ '^[0-9]+$']; then
  echo "Certicate will be valid $CERTDAYS days"
else
  CERTDAYS=2048
  echo "Certicate will be valid $CERTDAYS days"
fi
  
function checkcommand {

  MESSAGE=$1
  COMMAND=$2
  LOGFILE=$3

  echo -n "$MESSAGE"
  
  if [ "xx${LOGFILE}xx" !=  "xxxx" ] && [ -w $LOGFILE ]; then
    $COMMAND >> $LOGFILE 2>&1
    local status=$?
  else
    $COMMAND 
    local status=$?
  fi
  if [ $status -ne 0 ]; then
    echo "   ... failed" >&2
    exit 1
  fi
  echo "   ... success" >&2

  return 0
}

function cleanup {
  rm $KEYFILE >/dev/null  2>&1
  rm $CRSFILE >/dev/null  2>&1
  rm $CRTFILE >/dev/null  2>&1
}
trap cleanup EXIT



# gen tempfiles
# todo trap exit and remove it
KEYFILE=$(mktemp)
CRSFILE=$(mktemp)
CRTFILE=$(mktemp)

# set CA location
# check if it is there and it a valid CA
CA_LOCATION=/etc/kubernetes/pki

# generate key 
checkcommand "generating private key" "openssl genrsa -out $KEYFILE $CERTDAYS" "/dev/null"

# generate crs
checkcommand "generating siging request" "openssl req -new -key $KEYFILE  -out $CRSFILE -subj /CN=$USERNAME/O=$USERNAME" "/dev/null"



# generate namespace
# check if it already exitist:
kubectl describe namespace $USERNAME >/dev/null 2>&1 
if [ $? -eq 0 ]; then
  echo "kubernetes namespace already exists"
  exit 1
fi 

checkcommand "generating kubernetes namespace" "kubectl create namespace $USERNAME" "/dev/null"

# sign the request
checkcommand "signing the request" "sudo openssl x509 -req -in $CRSFILE -CA /etc/kubernetes/pki/ca.crt  -CAkey /etc/kubernetes/pki/ca.key  -CAcreateserial -out $CRTFILE -days $CERTDAYS" "/dev/null"

# create role
echo "creating role"
kubectl apply -f <(echo "
kind: Role
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  namespace: $USERNAME
  name: deployment-manager-$USERNAME
rules:
 - apiGroups: [\"\", \"extensions\", \"apps\", \"autoscaling\"]
   resources: [\"*\"]
   verbs: [\"*\"]
")

if [ $? -ne 0 ]; then
  echo "Create of kubernetes role deployment-manager-$USERNAME failed"
  exit 1
fi 




# create role binding
echo "create rolebinding"
kubectl apply -f <(echo "
 kind: RoleBinding
 apiVersion: rbac.authorization.k8s.io/v1beta1
 metadata:
   name: deployment-manager-binding-$USERNAME
   namespace: $USERNAME
 subjects:
 - kind: User
   name: $USERNAME
   apiGroup: \"\"
 roleRef:
   kind: Role
   name: deployment-manager-$USERNAME
   apiGroup: \"\"
")
if [ $? -ne 0 ]; then
  echo "Create of kubernetes rolebinding deployment-manager-binding-$USERNAME failed"
  exit 1
fi 



# generate kubeconf
echo "generating new kubeconfig file kubeconfig-$USERNAME.conf"
CERTIFICATE=$(sudo grep certificate-authority-data:   /etc/kubernetes/admin.conf  | cut -d: -f2)
SERVERNAME=$(sudo grep  server: /etc/kubernetes/admin.conf | tr -s ' ' '#' | cut -d "#" -f3)

echo "
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data:$CERTIFICATE
    server: $SERVERNAME
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    namespace: $USERNAME
    user: $USERNAME
  name: $USERNAME
current-context: $USERNAME
kind: Config
preferences: {}
users:
- name: $USERNAME
  user:
    as-user-extra: {}
    client-certificate: $USERNAME.crt
    client-key: $USERNAME.key
" > kubeconfig-$USERNAME.conf

# copy Key and crt to save location
mv $KEYFILE $USERNAME.key
mv $CRTFILE $USERNAME.crt

echo ""
echo "check if access to namespace $USERNAME if works"
kubectl --kubeconfig=kubeconfig-$USERNAME.conf get pods -n $USERNAME >/dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "Something went wrong, can't access the cluster with the generated configuration"
  echo "Error:"
  kubectl --kubeconfig=kubeconfig-$USERNAME.conf get pods -n $USERNAME
  exit 1
fi 
echo ""
echo "Success!!"
echo "you can now access the cluster using the provided configuration, example"
echo "kubectl --kubeconfig=kubeconfig-$USERNAME.conf get pods"
echo ""
echo "please ensure that you have the following files in your current working directory:"
echo " - Private Key: $USERNAME.key"
echo " - Signed Cert: $USERNAME.crt"
echo " - kubconfig  : kubeconfig-$USERNAME.conf"
echo ""
echo "have fun"
