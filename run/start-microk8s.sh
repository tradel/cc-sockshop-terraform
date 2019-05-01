#!/bin/bash

microk8s.start
microk8s.status --wait-ready
microk8s.kubectl get nodes -o name | grep packer | xargs kubectl delete

iptables -P FORWARD ACCEPT
iptables -L FORWARD

microk8s.enable dns storage
microk8s.kubectl -n kube-system wait --for=condition=Ready pods -l k8s-app=kube-dns
microk8s.kubectl -n kube-system wait --for=condition=Ready pods -l k8s-app=hostpath-provisioner

helm init --service-account tiller
microk8s.kubectl -n kube-system wait --for=condition=Ready pods -l app=helm,name=tiller

mkdir -p $HOME/.kube
microk8s.config > $HOME/.kube/config 
