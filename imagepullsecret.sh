#!/bin/bash

# Set the ImagePullSecret name
IMAGE_PULL_SECRET="fmk-cfg"

# Set the excluded namespaces
EXCLUDED_NAMESPACES=("kube-system" "kube-public" "kube-node-lease" "nsx-system" "pks-system")

# Get the list of namespaces
NAMESPACES=$(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}')

# Iterate over each namespace
for NAMESPACE in $NAMESPACES; do
    # Check if the namespace is in the excluded list
    if [[ " ${EXCLUDED_NAMESPACES[@]} " =~ " ${NAMESPACE} " ]]; then
        echo "Skipping excluded namespace: $NAMESPACE"
        continue
    fi

    # Apply the ImagePullSecret to the namespace
    kubectl apply -f  image-pull-secret.yaml --namespace="$NAMESPACE"
done
