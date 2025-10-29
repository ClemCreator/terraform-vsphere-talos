#!/bin/bash
set -euo pipefail

# Deploy CA Secret for cert-manager
# This script creates a Kubernetes Secret containing the CA certificate and private key
# used by cert-manager to issue certificates for ingress resources.

# Source the secrets (contains CA cert and key)
source ./secrets.sh


echo "==================================================================="
echo "Deploying CA Secret to cert-manager namespace"
echo "==================================================================="

# Create cert-manager namespace if it doesn't exist
kubectl create namespace cert-manager --dry-run=client -o yaml | kubectl apply -f -

# Create the CA Secret
kubectl create secret tls ingress-tls \
  --namespace=cert-manager \
  --cert=<(echo "$TF_VAR_ca_cert") \
  --key=<(echo "$TF_VAR_ca_key") \
  --dry-run=client -o yaml | kubectl apply -f -

echo "✅ CA Secret 'ingress-tls' created in 'cert-manager' namespace"
echo ""
echo "The ClusterIssuer 'ingress' will use this CA to sign certificates."
