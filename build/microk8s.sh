#!/bin/bash -e

CONSUL_VERSION=1.4.4
CONSUL_CLI_VERSION=${CONSUL_VERSION}

K8S_VERSION=1.12

#############################################################################
# Install prerequisites
#############################################################################

export DEBIAN_FRONTEND=noninteractive

apt-get update 
apt-get install -y apt-transport-https ca-certificates curl gnupg2 software-properties-common 

apt-get update 
apt-get install -y unzip git jq
# apt-get install -y nginx supervisor 

# # Install supervisord config to keep kubectl proxies running
# systemctl stop supervisor
# systemctl enable supervisor
# install -c -m 0755 /tmp/supervisord/*.sh /usr/local/bin
# install -c -m 0644 /tmp/supervisord/*.conf /etc/supervisor/conf.d

# # Set up nginx to reverse-proxy inbound traffic to Ambassador
# systemctl stop nginx 
# systemctl disable nginx 
# install -c -m 0644 /tmp/nginx/proxy-* /etc/nginx/sites-available
# rm /etc/nginx/sites-enabled/default
# ln -sf /etc/nginx/sites-available/proxy-8080 /etc/nginx/sites-enabled/proxy-8080
# ln -sf /etc/nginx/sites-available/proxy-8500 /etc/nginx/sites-enabled/proxy-8500
# ln -sf /etc/nginx/sites-available/proxy-8877 /etc/nginx/sites-enabled/proxy-8877

#############################################################################
# Install Consul binary
#############################################################################

consul_arch=linux_amd64
consul_zip=consul_${CONSUL_CLI_VERSION}_${consul_arch}.zip

echo "Downloading and installing Consul..."
cd /tmp
curl -fsSLO https://releases.hashicorp.com/consul/${CONSUL_CLI_VERSION}/${consul_zip}
unzip ${consul_zip}
install -c -m 0755 consul /usr/local/bin 

#############################################################################
# Install microk8s
#############################################################################

echo "Installing microk8s via snap..."
mkdir $HOME/.kube
snap install microk8s --channel=${K8S_VERSION}/stable --classic
snap alias microk8s.kubectl kubectl && ln -sf /snap/bin/kubectl /usr/bin
microk8s.config > $HOME/.kube/config
microk8s.status --wait-ready
microk8s.enable dns storage

# Allow traffic to be forwarded between interfaces. Very important for microk8s!
iptables -P FORWARD ACCEPT
iptables -L FORWARD
microk8s.inspect

#############################################################################
# Install Helm and create service account
#############################################################################

snap install helm --classic
kubectl create serviceaccount --namespace kube-system tiller
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller

#############################################################################
# Download images we'll need
#############################################################################

# Output from `microk8s.docker images --format 'microk8s.docker pull {{.Repository}}:{{.Tag}}'`:
microk8s.docker pull mongo:latest
microk8s.docker pull redis:alpine
microk8s.docker pull rabbitmq:3.6.8
microk8s.docker pull envoyproxy/envoy-alpine:v1.8.0
microk8s.docker pull consul:1.4.4
microk8s.docker pull hashicorp/consul-k8s:0.7.0
microk8s.docker pull securefab/openssl:latest
microk8s.docker pull tutum/curl:latest
microk8s.docker pull quay.io/datawire/ambassador:0.60.2
microk8s.docker pull quay.io/datawire/ambassador_pro:consul_connect_integration-0.4.0
microk8s.docker pull datawire/qotm:1.7
microk8s.docker pull hashicorp/http-echo:latest
microk8s.docker pull tradel/front-end:0.3.14
microk8s.docker pull weaveworksdemos/load-test:latest
microk8s.docker pull weaveworksdemos/catalogue:0.3.5
microk8s.docker pull weaveworksdemos/payment:0.4.3
microk8s.docker pull weaveworksdemos/carts:0.4.8
microk8s.docker pull weaveworksdemos/orders:0.4.7
microk8s.docker pull weaveworksdemos/catalogue-db:0.3.0
microk8s.docker pull weaveworksdemos/user-db:0.3.0

#############################################################################
# Clean up before shutting down
#############################################################################

# Stop microk8s
microk8s.stop 

# Disable swap
swapoff -a
install -c -m 0644 /tmp/grub/grub.conf /etc/default/grub 
update-grub 

# Create a general user account 
useradd -c "Interactive Login Account" -m -r -s /bin/bash demo 
usermod -a -G google-sudoers demo 
cp -Rv /tmp/kube /home/demo 

# Fill the demo user's homedir with interesting toys
cd /tmp
git clone https://github.com/hashicorp/consul-helm.git
cp -Rv /tmp/consul-helm /home/demo/consul-helm 
cp /tmp/kube/consul-service.yaml /home/demo/consul-helm 

git clone https://github.com/tradel/microservices-demo.git
cp -Rv microservices-demo/deploy/kubernetes/helm-chart /home/demo/sockshop-helm
cp -v /tmp/kube/weaveworks-service.yaml /home/demo/sockshop-helm
rm -f /home/demo/sockshop-helm/requirements.yaml 

mkdir /home/demo/ambassador 
cp -v /tmp/kube/ambassador-*.yaml /tmp/kube/qotm.yaml /home/demo/ambassador

mkdir /home/demo/simple-service 
cp -v /tmp/kube/echo-client.yaml /tmp/kube/echo-server.yaml /home/demo/simple-service 

# Set up the environment variables to talk to Consul
echo "export CONSUL_HTTP_ADDR=localhost:30085" >> /etc/profile.d/consul.sh
