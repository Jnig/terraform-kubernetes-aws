#!/bin/bash

ps aux | grep cluster-dns
echo "cluster dns should be 100.64.0.10"

ps aux | grep cluster-cidr
echo "cluster cidr should be 100.96.0.0/11"

cat /var/run/flannel/subnet.env
echo "flannel network should be 100.96.0.0/11 and subnet 100.96.0.1/24 on master"