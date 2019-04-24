#!/bin/bash

export K8S_VERSION=1.12
export DIND_K8S_VERSION=${K8S_VERSION}
export SKIP_DASHBOARD=true 
export SKIP_SNAPSHOT=true
export NUM_NODES=3
export CNI_PLUGIN=flannel

cd $HOME/dind
./dind-cluster.sh restore

supervisorctl start all 
