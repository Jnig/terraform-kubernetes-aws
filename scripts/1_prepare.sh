#!/bin/bash

. /etc/environment

# curl -s http://169.254.169.254/latest/meta-data/hostname returns ip-10-68-72-215.u0.ww.conti.de
# aws console shows ip-10-68-73-123.eu-central-1.compute.internal
# something weird with conti dhcp set
function set_hostname {
    region=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq .region -r)
    hostname $(hostname).$region.compute.internal
    hostname > /etc/hostname
}


function setup_docker {
    apt -y install docker.io 
    
    mkdir /etc/systemd/system/docker.service.d/
    cat << EOF > /etc/systemd/system/docker.service.d/http-proxy.conf
[Service]
Environment="HTTP_PROXY=http://localhost:3128/" "HTTPS_PROXY=http://localhost:3128/" "NO_PROXY=localhost,127.0.0.1,.conti.de,.contiwan.com"
EOF
    systemctl daemon-reload
    systemctl restart docker
    usermod -a -G docker ubuntu
}


function setup_kubelet {
    apt-get update && apt-get install -y apt-transport-https

    https_proxy="localhost:3128" curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -

    cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb http://apt.kubernetes.io/ kubernetes-xenial main
EOF

    apt update
    apt install -y kubelet kubeadm kubectl
    
    ip="$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)"

    echo "Environment='HTTP_PROXY=http://$ip:3128/' 'HTTPS_PROXY=http://$ip:3128/' 'NO_PROXY=localhost,127.0.0.1,.conti.de,.contiwan.com'" >> /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
    echo "Environment='KUBELET_EXTRA_ARGS=--cloud-provider=aws'" >> /etc/systemd/system/kubelet.service.d/10-kubeadm.conf

    sed -i 's/10.96.0.10/100.64.0.10/g' /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
    systemctl daemon-reload
    
}

function setup_ntp {
    apt install -y ntp

    sed -i 's/^pool.*//' /etc/ntp.conf

    for line in $(cat /etc/terraform/ntp_servers)          
    do          
        echo "server $line" >> /etc/ntp.conf
    done

    systemctl restart ntp
}

function attach_volume {
    instanceId="$(curl -s http://169.254.169.254/latest/meta-data/instance-id)"
    
    until aws ec2 attach-volume --volume-id $(cat /etc/terraform/volume) --instance-id $instanceId --device /dev/xvdf --region eu-central-1 &> /dev/null
    do 
        echo "waiting for attach command to succeed" 
        sleep 5
    done

}

function mount_volume {
    if [ "$(cat /etc/terraform/role)" != "master" ]; then
        return 0 
    fi

    until [ -b /dev/xvdf ] 
    do 
        echo "waiting for volume" 
        sleep 5
    done

    # create filesystem if no existing found
    file -s /dev/xvdf | grep ext4 || mkfs -t ext4 /dev/xvdf

    mkdir /mnt/volume

    cp /etc/fstab /etc/fstab.bak
    sed -i '$ a/dev/xvdf /mnt/volume ext4 defaults,noatime 0 0' /etc/fstab
    mount /mnt/volume

    mkdir /mnt/volume/etcd
    mkdir /mnt/volume/kubernetes
    mkdir /mnt/volume/kubelet

    mkdir /var/lib/etcd
    mkdir /etc/kubernetes
    mkdir /var/lib/kubelet

    sed -i '$ a/mnt/volume/etcd /var/lib/etcd none bind 0 0' /etc/fstab
    sed -i '$ a/mnt/volume/kubernetes /etc/kubernetes none bind 0 0' /etc/fstab
    sed -i '$ a/mnt/volume/kubelet /var/lib/kubelet none bind 0 0' /etc/fstab

    mount -a
}

set_hostname

setup_ntp
setup_docker

attach_volume
mount_volume
setup_kubelet


