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

    # Get the list of service accounts within the namespace
    SERVICE_ACCOUNTS=$(kubectl -n "$NAMESPACE" get serviceaccounts -o jsonpath='{.items[*].metadata.name}')

    # Iterate over each service account
    for SERVICE_ACCOUNT in $SERVICE_ACCOUNTS; do
        # Patch the service account with the ImagePullSecret
        kubectl patch serviceaccount "$SERVICE_ACCOUNT" -n "$NAMESPACE" \
            -p '{"imagePullSecrets":[{"name":"'"$IMAGE_PULL_SECRET"'"}]}'
    done
done
