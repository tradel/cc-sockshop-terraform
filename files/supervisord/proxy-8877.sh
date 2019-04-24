#!/bin/bash

pod_id=`/usr/bin/kubectl --kubeconfig="/root/.kube/config" get pods -l service=ambassador -o jsonpath='{.items[0].metadata.name}'`
/usr/bin/kubectl --kubeconfig="/root/.kube/config" port-forward ${pod_id} 8878:8877

