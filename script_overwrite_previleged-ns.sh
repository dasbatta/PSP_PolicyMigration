#!/bin/bash

# List of namespaces to exclude
excluded_namespaces=("kube-system" "default" "kube-public" "dynatrace" "kube-node-lease" "nsx-system")

# Get list of namespaces
namespaces=$(kubectl get namespaces -o=jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')

# Iterate over namespaces
for namespace in $namespaces; do
    # Check if the namespace is excluded
    if [[ " ${excluded_namespaces[@]} " =~ " ${namespace} " ]]; then
        echo "Skipping namespace: $namespace"
    else
        # Apply label to the namespace
        kubectl label --overwrite namespace $namespace pod-security.kubernetes.io/enforce=privileged 
        echo "Label applied to namespace: $namespace"
    fi
done
