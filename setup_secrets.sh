#!/bin/bash
# This script ensures the Docker registry secret is present in the correct namespace.

# The unified namespace for the entire operator and its resources.
NAMESPACE="qwzhou-mysql-trae"
SECRET_NAME="aliyun-acr-secret"

# Ensure the namespace exists.
kubectl get namespace "$NAMESPACE" &> /dev/null || kubectl create namespace "$NAMESPACE"

# Check if the secret already exists in the namespace.
if kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" &> /dev/null; then
    echo "Secret '$SECRET_NAME' already exists in namespace '$NAMESPACE'. Skipping creation."
else
    echo "Secret '$SECRET_NAME' not found in namespace '$NAMESPACE'. Creating..."
    # NOTE: This uses hardcoded credentials from the aliyun_registory file.
    # For production, consider a more secure way to handle the password, like environment variables or a vault.
    kubectl create secret docker-registry "$SECRET_NAME" \
      --docker-server=crpi-oedkuzepm53hblsq.cn-shanghai.personal.cr.aliyuncs.com \
      --docker-username=aliyun9300206566 \
      --docker-password='Love9810@' \
      -n "$NAMESPACE"
    echo "Secret '$SECRET_NAME' created successfully in namespace '$NAMESPACE'."
fi

# Also patch the default service account in the new namespace
if kubectl get serviceaccount default -n "$NAMESPACE" &> /dev/null; then
    echo "Patching 'default' service account in namespace '$NAMESPACE' to use the secret."
    kubectl patch serviceaccount default -n "$NAMESPACE" -p "{\"imagePullSecrets\": [{\"name\": \"$SECRET_NAME\"}]}"
else
    echo "Warning: 'default' service account not found in namespace '$NAMESPACE'. Skipping patch."
fi

