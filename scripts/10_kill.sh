#!/bin/bash

kubeadm reset
rm -rf /mnt/volume/*
aws s3 rm s3://devops-dev-cluster-20171030081920102300000001/join --region eu-central-1