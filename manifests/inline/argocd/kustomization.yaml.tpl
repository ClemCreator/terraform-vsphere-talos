apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: argocd

resources:
  - namespace.yaml

helmCharts:
  - name: argo-cd
    repo: https://argoproj.github.io/argo-helm
    version: ${argocd_version}
    releaseName: argocd
    namespace: argocd
    includeCRDs: true
    valuesFile: values.yaml
