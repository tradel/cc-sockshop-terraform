#!/bin/bash

CONSUL_VERSION=1.4.4
CONSUL_CLI_VERSION=${CONSUL_VERSION}

K8S_VERSION=1.12.7
UTIL_VERSION=${K8S_VERSION}-00

HELM_VER=2.13.1

#############################################################################
# Install prerequisites
#############################################################################

export DEBIAN_FRONTEND=noninteractive
apt-get update 
apt-get install -y apt-transport-https ca-certificates curl gnupg2 \
    software-properties-common unzip git nginx supervisor \
    libvirt-clients libvirt-daemon-system qemu-kvm

systemctl enable libvirtd.service
systemctl start libvirtd.service

#############################################################################
# Install Docker CE, kubectl, and kubeadm
#############################################################################

curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add -
curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian stretch stable"
add-apt-repository "deb https://apt.kubernetes.io/ kubernetes-xenial main" 
apt-get update
apt-get install -y docker-ce=18.06.3~ce~3-0~debian containerd.io
apt-get install -y --allow-downgrades kubectl=${UTIL_VERSION} kubeadm=${UTIL_VERSION}

#############################################################################
# Install minikube and KVM2 driver
#############################################################################

cd /tmp
curl -fsLO https://storage.googleapis.com/minikube/releases/latest/docker-machine-driver-kvm2 
install -c -m 0755 docker-machine-driver-kvm2 /usr/local/bin/

curl -fsLO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
install -c -m 0755 minikube-linux-amd64 /usr/local/bin/minikube

#############################################################################
# Install Helm
#############################################################################

helm_arch=linux-amd64
helm_tar=helm-v${HELM_VER}-${helm_arch}.tar.gz

cd /tmp
curl -fsSLO https://storage.googleapis.com/kubernetes-helm/${helm_tar}
curl -fsSLO https://storage.googleapis.com/kubernetes-helm/${helm_tar}.sha256

if [[ "$(shasum -a 256 ${helm_tar} | awk '{print $1;}')" != "$(cat ${helm_tar}.sha256)" ]]; then
    echo "Checksums do not match for Helm" >&2
    exit 1
fi 

tar zxvf ${helm_tar}
install -c -m 0755 ${helm_arch}/helm /usr/local/bin

#############################################################################
# Download images we'll need
#############################################################################

kubeadm config images pull --kubernetes-version v${K8S_VERSION}
docker pull quay.io/datawire/ambassador:0.60.0 
docker pull quay.io/datawire/ambassador_pro:consul_connect_integration-0.4.0 
docker pull weaveworksdemos/carts:0.4.8 
docker pull envoyproxy/envoy-alpine:v1.8.0 
docker pull mongo 
docker pull redis:alpine 
docker pull rabbitmq:3.6.8 
docker pull consul:1.4.4 
docker pull hashicorp/consul-k8s:0.7.0 
docker pull datawire/qotm:1.7 
docker pull hashicorp/http-echo:latest 
docker pull tradel/front-end:0.3.14 
docker pull tutum/curl:latest 
docker pull securefab/openssl:latest 
docker pull weaveworksdemos/catalogue:0.3.5 
docker pull weaveworksdemos/catalogue-db:0.3.0 
docker pull weaveworksdemos/load-test 
docker pull weaveworksdemos/orders:0.4.7 
docker pull weaveworksdemos/payment:0.4.3 
docker pull weaveworksdemos/queue-master:0.3.1 
docker pull weaveworksdemos/shipping:0.4.8 
docker pull weaveworksdemos/user:0.4.4 
docker pull weaveworksdemos/user-db:0.3.0 
docker pull quay.io/coreos/etcd:v3.3.9 
docker pull quay.io/calico/kube-controllers:v3.2.7 
docker pull quay.io/calico/node:v3.2.7 
docker pull quay.io/calico/cni:v3.2.7 
docker pull k8s.gcr.io/kube-addon-manager:v9.0 
docker pull gcr.io/k8s-minikube/storage-provisioner:v1.8.1 
docker pull gcr.io/kubernetes-helm/tiller:v2.13.1

#############################################################################
# Install Consul binary
#############################################################################

consul_arch=linux_amd64
consul_zip=consul_${CONSUL_CLI_VERSION}_${consul_arch}.zip
cd /tmp
curl -fsSLO https://releases.hashicorp.com/consul/${CONSUL_CLI_VERSION}/${consul_zip}
unzip ${consul_zip}
install -c -m 0755 consul /usr/local/bin 

#############################################################################
# Disable swap
#############################################################################

swapoff -a
install -c -m 0644 /tmp/grub/grub.conf /etc/default/grub 
update-grub 

#############################################################################
# Create a general user account 
#############################################################################

useradd -c "Interactive Login Account" -m -r -s /bin/bash demo 
usermod -a -G google-sudoers demo 
usermod -a -G libvirt demo

#############################################################################
# Copy demo files to the user account
#############################################################################

cp -Rv /tmp/kube /home/demo 
cd /home/demo 
curl -fsLO https://storage.googleapis.com/minikube/iso/minikube-v1.0.0.iso
