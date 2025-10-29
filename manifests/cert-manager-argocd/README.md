# CA Configuration for cert-manager

This directory manages cert-manager configuration with an external CA.

## Overview

Instead of using self-signed certificates, we use an existing Certificate Authority (CA) to sign all ingress certificates.

## Setup

### 1. Configure your CA in `secrets.sh`

Add your CA certificate and private key:

```bash
export TF_VAR_ca_cert='-----BEGIN CERTIFICATE-----
YOUR_CA_CERTIFICATE_HERE
-----END CERTIFICATE-----'

export TF_VAR_ca_key='-----BEGIN PRIVATE KEY-----
YOUR_CA_PRIVATE_KEY_HERE
-----END PRIVATE KEY-----'
```

### 2. Deploy the CA Secret

The CA secret is automatically deployed during `./do apply`, or you can deploy it manually:

```bash
./deploy-ca-secret.sh
```

This creates a Kubernetes TLS Secret named `ingress-tls` in the `cert-manager` namespace.

### 3. ClusterIssuer

The `cluster-issuer-ingress` ClusterIssuer references this secret to sign certificates for ingress resources.

## Files

- `cluster-issuer-ingress.yaml` - ClusterIssuer that uses the external CA
- `values.yaml` - cert-manager Helm chart values
- `namespace.yaml` - cert-manager namespace

## Removed Files

- ~~`cluster-issuer-selfsigned.yaml`~~ - No longer needed (using external CA)
- ~~`certificate-ingress.yaml`~~ - No longer needed (CA provided externally)

## Verification

Check that the CA secret exists:

```bash
kubectl get secret -n cert-manager ingress-tls
kubectl get clusterissuer ingress
```

Export the CA certificate (for client trust):

```bash
kubectl get secret -n cert-manager ingress-tls -o jsonpath='{.data.tls\.crt}' | base64 -d > ca.crt
```
