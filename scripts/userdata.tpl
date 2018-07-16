#!/bin/bash

cat <<EOF > /tmp/setup.sh

cd /opt/

function set_proxy {
    test -z "${proxy}" && return 
    echo 'Acquire::http::Proxy "http://${proxy}";' > /etc/apt/apt.conf
}

function install_packages {
    apt update
    apt -y install awscli jq
}

function setup_cntlm {
    test -z "${proxy}" && return 

    apt -y install cntlm 
    sed -i 's/^Proxy.*/Proxy ${proxy}/' /etc/cntlm.conf
    sed -i 's/^#Gateway.*/Gateway yes/' /etc/cntlm.conf

    k8ranges="$(for i in $(seq 64 127); do echo -n 100.$i.*, ; done)"

    sed -i "s#^NoProxy.*#NoProxy localhost, 127.0.0.*, 10.*, 192.168.*,169.254.169.254,\$k8ranges#" /etc/cntlm.conf
    systemctl restart cntlm

    ip="$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)"
    if [ "${role}" == "master" ]; then
      ip="\$(cat /etc/terraform/load_balancer_ip)"
    fi

    echo -e "export http_proxy=\$ip:3128\nexport https_proxy=\$ip:3128\nexport no_proxy=localhost,169.254.169.254,\$ip" >> /etc/environment
    . /etc/environment
     
    # restart proxy every 4h
    (crontab -l 2>/dev/null; echo "0 */4 * * * /opt/maintenance/proxy_healthcheck.sh ${proxy}") | crontab -

}

function copy_script_directory {
    aws s3 cp s3://${s3_id}/scripts . --region eu-central-1 --recursive
    chmod +x installation/*.sh
    chmod +x maintenance/*.sh
}

function setup {
   ./installation/1_prepare.sh 
   ./installation/2_setup_kubernetes.sh ${net_plugin}

   if [ "${role}" == "master" ]; then
     ./installation/3_addons.sh
   fi
}

function setup_terraform_directory {
    mkdir /etc/terraform/
    echo "${s3_id}" > /etc/terraform/s3_bucket
    echo "${role}" > /etc/terraform/role
    echo "${volume}" > /etc/terraform/volume
    echo "${load_balancer_dns}" > /etc/terraform/load_balancer_dns
    dig +short ${load_balancer_dns} | head -1 > /etc/terraform/load_balancer_ip
}

function setup_iptables {
  # aws nlb does direct routing
  # that means the packages are forwarded with the same source ip 
  # which doesn't work when sender and receiver are equal
  echo "#!/bin/sh -e" > /etc/rc.local
  echo "ip route add local \$(cat /etc/terraform/load_balancer_ip) dev eth0  proto kernel  scope host  src \$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)" >> /etc/rc.local
  echo "exit 0" >> /etc/rc.local

  /etc/rc.local
}

setup_terraform_directory
if [ "${role}" == "master" ]; then
  setup_iptables
fi

set_proxy
install_packages

setup_cntlm
copy_script_directory

setup

EOF

sudo su -c "bash -x /tmp/setup.sh"
