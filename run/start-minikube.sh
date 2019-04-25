#!/bin/bash

export K8S_VERSION=1.12.7

minikube start -v 1 --vm-driver none --cache-images \
    --kubernetes-version v${K8S_VERSION} \
    --cpus 2 --memory 8192 --network-plugin cni \
    --iso-url=file:///home/packer/minikube-v1.0.0.iso \
    --extra-config kubelet.network-plugin=cni 

kubectl apply -f /home/demo/kube/calico-etcd.yaml
kubectl apply -f /home/demo/kube/calico-rbac.yaml
sed -i -e "s/10\.96\.232\.136/$(kubectl get service -o jsonpath='{.spec.clusterIP}' --namespace=kube-system calico-etcd)/" /home/demo/kube/calico.yaml
kubectl apply -f /home/demo/kube/calico.yaml

while [[ $( kubectl get nodes -o jsonpath='{$.items[*].status.conditions[?(@.type=="Ready")].status}' ) != "True" ]]
do
    sleep 1
done
