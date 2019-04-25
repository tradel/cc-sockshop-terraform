#! /bin/bash -e

CONSUL_VERSION=1.4.4
CONSUL_CLI_VERSION=${CONSUL_VERSION}

K8S_VERSION=1.12 
UTIL_VERSION=${K8S_VERSION}.7-00

#############################################################################
# Install prerequisites
#############################################################################

export DEBIAN_FRONTEND=noninteractive

apt-get update 
apt-get install -y apt-transport-https ca-certificates curl gnupg2 \
    software-properties-common unzip git nginx supervisor

# Install supervisord config to keep kubectl proxies running
systemctl stop supervisor
systemctl enable supervisor
install -c -m 0755 /tmp/supervisord/*.sh /usr/local/bin
install -c -m 0644 /tmp/supervisord/*.conf /etc/supervisor/conf.d

# Set up nginx to reverse-proxy inbound traffic to Ambassador
systemctl stop nginx 
systemctl enable nginx 
install -c -m 0644 /tmp/nginx/proxy-* /etc/nginx/sites-available
rm /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/proxy-8080 /etc/nginx/sites-enabled/proxy-8080
ln -sf /etc/nginx/sites-available/proxy-8500 /etc/nginx/sites-enabled/proxy-8500
ln -sf /etc/nginx/sites-available/proxy-8877 /etc/nginx/sites-enabled/proxy-8877

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
# Set up DIND (Docker-in-Docker)
#############################################################################

DIND=dind-cluster.sh

export DIND_K8S_VERSION=${K8S_VERSION}
export SKIP_DASHBOARD=true 
export SKIP_SNAPSHOT=true
export NUM_NODES=3
export CNI_PLUGIN=weave

curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add -
curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian stretch stable"
add-apt-repository "deb https://apt.kubernetes.io/ kubernetes-xenial main" 
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io
apt-get install -y kubectl=${UTIL_VERSION} kubeadm=${UTIL_VERSION}

apt-get install liblz4-tool
git clone https://github.com/kubernetes-sigs/kubeadm-dind-cluster.git ~/dind
cd ~/dind 

. build/buildconf.sh 
export KUBEADM_URL=${KUBEADM_URL:-${KUBEADM_URL_1_12}}
export KUBEADM_SHA1=${KUBEADM_SHA1:-${KUBEADM_SHA1_1_12}}
export HYPERKUBE_URL=${HYPERKUBE_URL:-${HYPERKUBE_URL_1_12}}
export HYPERKUBE_SHA1=${HYPERKUBE_SHA1:-${HYPERKUBE_SHA1_1_12}}
export KUBECTL_LINUX_URL=${KUBECTL_LINUX_URL:-${KUBECTL_LINUX_URL_1_12}}
export KUBECTL_LINUX_SHA1=${KUBECTL_LINUX_SHA1:-${KUBECTL_LINUX_SHA1_1_12}}
export KUBECTL_DARWIN_URL=${KUBECTL_DARWIN_URL:-${KUBECTL_DARWIN_URL_1_12}}
export KUBECTL_DARWIN_SHA1=${KUBECTL_DARWIN_SHA1:-${KUBECTL_DARWIN_SHA1_1_12}}
export K8S_VERSIONS="${K8S_VERSION}"
./build/build-local.sh 
./dind-cluster.sh up 

# Create a k8s secret containing a Consul gossip key
gossip_key=$(consul keygen)
kubectl create secret generic consul-gossip-key --from-literal=key=${gossip_key}

#############################################################################
# Install Helm and deploy Tiller
#############################################################################

HELM_VER=2.13.1

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

kubectl create serviceaccount --namespace kube-system tiller
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
helm init --service-account tiller 

echo ""
echo "Waiting for Tiller pod to start..."
while [[ $( kubectl -n kube-system get pods -l app=helm,name=tiller -o jsonpath='{.items[0].status.containerStatuses[0].ready}' ) != "true" ]]
do
    sleep 1
done

#############################################################################
# Deploy Consul with Helm chart
#############################################################################

for node in kube-node-1 kube-node-2 kube-node-3
do
    docker exec ${node} mkdir -p /data/consul-server-0 /data/consul-server-1 /data/consul-server-2
done 
kubectl create -f /tmp/kube/consul-pv.yaml

echo "Deploying Consul helm chart..."
helm repo add consul https://consul-helm-charts.storage.googleapis.com
helm install --wait --name=consul consul/consul \
    --set global.image="consul:${CONSUL_VERSION}" \
    --set global.gossipEncryption.secretName=consul-gossip-key \
    --set global.gossipEncryption.secretKey=key \
    --set server.replicas=1 \
    --set server.bootstrapExpect=1 \
    --set server.storage=10Gi \
    --set client.grpc=true \
    --set ui.service.type=NodePort \
    --set syncCatalog.enabled=false \
    --set connectInject.enabled=true 

kubectl port-forward service/consul-server 8500:8500 &
proxy_pid=$!

echo "Waiting for Consul to start..."
while [[ -z $(curl -fsSL localhost:8500/v1/status/leader) ]]
do
    sleep 5
done 

echo "Creating intentions..."
consul intention create -replace -deny '*' '*'
consul intention create -replace -allow '*' http-echo 
consul intention create -replace -allow '*' qotm
consul intention create -replace -allow load-test front-end
consul intention create -replace -allow front-end carts 
consul intention create -replace -allow front-end orders
consul intention create -replace -allow front-end catalogue
consul intention create -replace -allow front-end user 
consul intention create -replace -allow carts carts-db
consul intention create -replace -allow orders orders-db 
consul intention create -replace -allow catalogue catalogue-db 
consul intention create -replace -allow user user-db
consul intention create -replace -allow queue-master rabbitmq
consul intention create -replace -allow ambassador '*'

kill ${proxy_pid}

#############################################################################
# Deploy Ambassador proxy
#############################################################################

echo "Deploying Ambassador..."
kubectl apply -f /tmp/kube/ambassador-rbac.yaml
kubectl apply -f /tmp/kube/ambassador-consul-connector.yaml
kubectl apply -f /tmp/kube/ambassador-service.yaml
kubectl apply -f /tmp/kube/qotm.yaml

echo "Waiting for Ambassador pod to start..."
while [[ $( kubectl get pods -l service=ambassador -o jsonpath='{.items[0].status.containerStatuses[0].ready}' ) != "true" ]]
do
    sleep 1
done

echo "Waiting for Ambassador Connect pod to start..."
while [[ $( kubectl get pods -l app=ambassador,component=consul-connect -o jsonpath='{.items[0].status.containerStatuses[0].ready}' ) != "true" ]]
do
    sleep 1
done

#############################################################################
# Deploy Simple Echo service
#############################################################################

echo "Deploying echo server and client..."
kubectl create -f /tmp/kube/echo-server.yaml 
kubectl create -f /tmp/kube/echo-client.yaml 

#############################################################################
# Deploy Sock Shop
#############################################################################

echo "Deploying Sock Shop..."
helm install --wait --name=sockshop consul/microservices-demo \
    --set zipkin.enabled=false \
    --set loadtest.enabled=true \
    --set loadtest.replicas=1
kubectl apply -f /tmp/kube/weaveworks-service.yaml

#############################################################################
# Shut down and take a backup of the cluster
#############################################################################

echo "Taking snapshot..."
cd $HOME/dind 
./dind-cluster.sh snapshot
./dind-cluster.sh down

# Disable swap
swapoff -a
install -c -m 0644 /tmp/grub/grub.conf /etc/default/grub 
update-grub 

# Create a general user account 
useradd -c "Interactive Login Account" -m -r -s /bin/bash demo 
usermod -a -G google-sudoers demo 
