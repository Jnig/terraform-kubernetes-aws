#!/bin/bash

ps aux | grep cluster-dns
echo "cluster dns should be 100.64.0.10"

ps aux | grep cluster-cidr
echo "cluster cidr should be 100.96.0.0/11"

if [ -f /var/run/flannel/subnet.env ];
then
cat /var/run/flannel/subnet.env
echo "flannel network should be 100.96.0.0/11 and subnet 100.96.0.1/24 on master"
else
kubectl exec -n kube-system $(kubectl get po -n kube-system -l name=weave-net -o jsonpath="{.items[*].metadata.name}" | cut -d" " -f1) -c weave -- /home/weave/weave --local status | tail -4
echo "Weave network should be 100.96.0.0/11"
fi