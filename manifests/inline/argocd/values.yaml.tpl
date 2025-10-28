# ArgoCD Helm values
# see https://github.com/argoproj/argo-helm/tree/main/charts/argo-cd

global:
  domain: ${argocd_domain}

configs:
  params:
    # Disable TLS between ArgoCD components (internal cluster traffic)
    # TLS is only used at the ingress level
    server.insecure: "true"
    server.repo.server.plaintext: "true"
    server.dex.server.plaintext: "true"
    controller.repo.server.plaintext: "true"
    applicationsetcontroller.repo.server.plaintext: "true"
    reposerver.disable.tls: "true"
    dexserver.disable.tls: "true"
  
  # Configure repository server to enable Helm with Kustomize
  cm:
    kustomize.buildOptions: --enable-helm

server:
  ingress:
    enabled: true
    tls: true
