# This file generates inline manifests for Talos bootstrap
# using Helm charts with dynamic configuration
# 
# IMPORTANT: Only critical bootstrap components are included here.
# Additional configurations (LoadBalancers, ClusterIssuers, Certificates)
# are managed by ArgoCD via manifests/apps/ to avoid duplication.

locals {
  # KubePrism port from Talos configuration
  kubeprism_port = local.common_machine_config.machine.features.kubePrism.port

  # ArgoCD configuration
  argocd_domain    = "argocd.${var.ingress_domain}"
  argocd_namespace = "argocd"

  # Cilium Helm values - loaded from file to avoid duplication
  cilium_values = file("${path.module}/manifests/cilium/values.yaml")

  # cert-manager Helm values
  cert_manager_values = yamlencode({
    crds = { enabled = true }
    global = { leaderElection = { namespace = "cert-manager" } }
  })

  # ArgoCD Helm values
  argocd_values = yamlencode({
    global = {
      domain = local.argocd_domain
    }
    configs = {
      params = {
        "server.insecure" = true
      }
      cm = {
        "kustomize.buildOptions" = "--enable-helm"
      }
    }
  })
}


# Generate inline manifests using Helm templates
# These will be embedded in Talos machine configuration

# Cilium manifest with Helm
# see https://www.talos.dev/v1.7/kubernetes-guides/network/deploying-cilium/#method-4-helm-manifests-inline-install
# see https://docs.cilium.io/en/stable/helm-reference/
# see https://github.com/cilium/cilium/releases
data "helm_template" "cilium_inline" {
  namespace    = "kube-system"
  name         = "cilium"
  repository   = "https://helm.cilium.io"
  chart        = "cilium"
  version      = var.cilium_version
  kube_version = var.kubernetes_version
  api_versions = []
  
  values = [local.cilium_values]
}

# cert-manager manifest with Helm
# see https://artifacthub.io/packages/helm/cert-manager/cert-manager
# see https://cert-manager.io/docs/installation/supported-releases/
data "helm_template" "cert_manager_inline" {
  namespace    = "cert-manager"
  name         = "cert-manager"
  repository   = "https://charts.jetstack.io"
  chart        = "cert-manager"
  version      = var.cert_manager_version
  kube_version = var.kubernetes_version
  api_versions = []
  
  values = [local.cert_manager_values]
}

# ArgoCD manifest with Helm
# see https://artifacthub.io/packages/helm/argo/argo-cd
# see https://argo-cd.readthedocs.io/en/stable/operator-manual/installation/#helm
data "helm_template" "argocd_inline" {
  namespace    = local.argocd_namespace
  name         = "argocd"
  repository   = "https://argoproj.github.io/argo-helm"
  chart        = "argo-cd"
  version      = var.argocd_version
  kube_version = var.kubernetes_version
  api_versions = []
  
  values = [local.argocd_values]
}

# Export generated inline manifests for debugging/inspection
# Only the core Helm charts are exported here.
# Additional resources (LoadBalancers, ClusterIssuers, Certificates) are managed by ArgoCD.
resource "local_file" "export_inline_manifests" {
  filename = "${path.module}/output/inline-manifests.yaml"
  content = join("---\n", [
    "# Source: Cilium CNI (network plugin)",
    data.helm_template.cilium_inline.manifest,
    "# Source: cert-manager (certificate controller)",
    data.helm_template.cert_manager_inline.manifest,
    "# Source: ArgoCD (GitOps controller)",
    data.helm_template.argocd_inline.manifest,
  ])

    lifecycle {
    ignore_changes = all
  }
}

