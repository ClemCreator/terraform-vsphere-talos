# This file generates inline manifests for Talos bootstrap
# using templatefile() for dynamic configuration and Helm charts

locals {
  # KubePrism port from Talos configuration
  kubeprism_port = local.common_machine_config.machine.features.kubePrism.port

  # Cilium external LoadBalancer configuration
  # see https://docs.cilium.io/en/stable/network/lb-ipam/
  # see https://docs.cilium.io/en/stable/network/l2-announcements/
  cilium_external_lb_manifests = [
    {
      apiVersion = "cilium.io/v2alpha1"
      kind       = "CiliumL2AnnouncementPolicy"
      metadata = {
        name = "external"
      }
      spec = {
        loadBalancerIPs = true
        interfaces = [
          "eth0",
        ]
        nodeSelector = {
          matchExpressions = [
            {
              key      = "node-role.kubernetes.io/control-plane"
              operator = "DoesNotExist"
            },
          ]
        }
      }
    },
    {
      apiVersion = "cilium.io/v2alpha1"
      kind       = "CiliumLoadBalancerIPPool"
      metadata = {
        name = "external"
      }
      spec = {
        blocks = [
          {
            start = cidrhost(var.cluster_node_network, var.cluster_node_network_load_balancer_first_hostnum)
            stop  = cidrhost(var.cluster_node_network, var.cluster_node_network_load_balancer_last_hostnum)
          },
        ]
      }
    },
  ]
  cilium_external_lb_manifest = join("---\n", [for d in local.cilium_external_lb_manifests : yamlencode(d)])

  # cert-manager ClusterIssuers and Certificate configuration
  cert_manager_ingress_ca_manifests = [
    {
      apiVersion = "cert-manager.io/v1"
      kind       = "ClusterIssuer"
      metadata = {
        name = "selfsigned"
      }
      spec = {
        selfSigned = {}
      }
    },
    {
      apiVersion = "cert-manager.io/v1"
      kind       = "Certificate"
      metadata = {
        name      = "ingress"
        namespace = "cert-manager"
      }
      spec = {
        isCA = true
        subject = {
          organizations = [
            var.ingress_domain,
          ]
          organizationalUnits = [
            "Kubernetes",
          ]
        }
        commonName = "Kubernetes Ingress"
        privateKey = {
          algorithm = "ECDSA"
          size      = 256
        }
        duration   = "4320h"
        secretName = "ingress-tls"
        issuerRef = {
          name  = "selfsigned"
          kind  = "ClusterIssuer"
          group = "cert-manager.io"
        }
      }
    },
    {
      apiVersion = "cert-manager.io/v1"
      kind       = "ClusterIssuer"
      metadata = {
        name = "ingress"
      }
      spec = {
        ca = {
          secretName = "ingress-tls"
        }
      }
    },
  ]
  cert_manager_ingress_ca_manifest = join("---\n", [for d in local.cert_manager_ingress_ca_manifests : yamlencode(d)])

  # ArgoCD configuration
  argocd_domain    = "argocd.${var.ingress_domain}"
  argocd_namespace = "argocd"
  argocd_manifests = [
    {
      apiVersion = "cert-manager.io/v1"
      kind       = "Certificate"
      metadata = {
        name      = "argocd-server"
        namespace = local.argocd_namespace
      }
      spec = {
        subject = {
          organizations = [
            var.ingress_domain,
          ]
          organizationalUnits = [
            "Kubernetes",
          ]
        }
        commonName = "Argo CD Server"
        dnsNames = [
          local.argocd_domain,
        ]
        privateKey = {
          algorithm = "ECDSA"
          size      = 256
        }
        duration   = "4320h"
        secretName = "argocd-server-tls"
        issuerRef = {
          kind = "ClusterIssuer"
          name = "ingress"
        }
      }
    },
  ]
  argocd_manifest = join("---\n", [for d in local.argocd_manifests : yamlencode(d)])
}

# Generate kustomization.yaml files from templates
resource "local_file" "cilium_kustomization" {
  filename = "${path.module}/manifests/inline/cilium/kustomization.yaml"
  content = templatefile("${path.module}/manifests/inline/cilium/kustomization.yaml.tpl", {
    cilium_version = var.cilium_version
  })
}

resource "local_file" "cilium_values" {
  filename = "${path.module}/manifests/inline/cilium/values.yaml"
  content = templatefile("${path.module}/manifests/inline/cilium/values.yaml.tpl", {
    kubeprism_port = local.kubeprism_port
  })
}

resource "local_file" "cert_manager_kustomization" {
  filename = "${path.module}/manifests/inline/cert-manager/kustomization.yaml"
  content = templatefile("${path.module}/manifests/inline/cert-manager/kustomization.yaml.tpl", {
    cert_manager_version = var.cert_manager_version
  })
}

resource "local_file" "cert_manager_values" {
  filename = "${path.module}/manifests/inline/cert-manager/values.yaml"
  content = templatefile("${path.module}/manifests/inline/cert-manager/values.yaml.tpl", {})
}

resource "local_file" "argocd_kustomization" {
  filename = "${path.module}/manifests/inline/argocd/kustomization.yaml"
  content = templatefile("${path.module}/manifests/inline/argocd/kustomization.yaml.tpl", {
    argocd_version = var.argocd_version
  })
}

resource "local_file" "argocd_values" {
  filename = "${path.module}/manifests/inline/argocd/values.yaml"
  content = templatefile("${path.module}/manifests/inline/argocd/values.yaml.tpl", {
    argocd_domain = local.argocd_domain
  })
}

# Generate inline manifests using Helm templates
# These will be embedded in Talos machine configuration

# Cilium manifest with Helm
# see https://www.talos.dev/v1.7/kubernetes-guides/network/deploying-cilium/#method-4-helm-manifests-inline-install
# see https://docs.cilium.io/en/stable/helm-reference/
# see https://github.com/cilium/cilium/releases
data "helm_template" "cilium_inline" {
  depends_on = [
    local_file.cilium_kustomization,
    local_file.cilium_values
  ]

  namespace  = "kube-system"
  name       = "cilium"
  repository = "https://helm.cilium.io"
  chart      = "cilium"
  version    = var.cilium_version
  kube_version = var.kubernetes_version
  api_versions = []
  
  values = [
    local_file.cilium_values.content
  ]
}

# cert-manager manifest with Helm
# see https://artifacthub.io/packages/helm/cert-manager/cert-manager
# see https://cert-manager.io/docs/installation/supported-releases/
data "helm_template" "cert_manager_inline" {
  depends_on = [
    local_file.cert_manager_kustomization,
    local_file.cert_manager_values
  ]

  namespace  = "cert-manager"
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = var.cert_manager_version
  kube_version = var.kubernetes_version
  api_versions = []
  
  values = [
    local_file.cert_manager_values.content
  ]
}

# ArgoCD manifest with Helm
# see https://artifacthub.io/packages/helm/argo/argo-cd
# see https://argo-cd.readthedocs.io/en/stable/operator-manual/installation/#helm
data "helm_template" "argocd_inline" {
  depends_on = [
    local_file.argocd_kustomization,
    local_file.argocd_values
  ]

  namespace  = local.argocd_namespace
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_version
  kube_version = var.kubernetes_version
  api_versions = []
  
  values = [
    local_file.argocd_values.content
  ]
}

# Export generated inline manifests for debugging/inspection
resource "local_file" "export_inline_manifests" {
  filename = "${path.module}/output/inline-manifests.yaml"
  content = join("---\n", [
    "# Source: inline Cilium",
    data.helm_template.cilium_inline.manifest,
    "# Source: Cilium external LB",
    local.cilium_external_lb_manifest,
    "# Source: inline cert-manager",
    data.helm_template.cert_manager_inline.manifest,
    "# Source: cert-manager ingress CA",
    local.cert_manager_ingress_ca_manifest,
    "# Source: inline ArgoCD",
    data.helm_template.argocd_inline.manifest,
    "# Source: ArgoCD certificate",
    local.argocd_manifest,
  ])
}
