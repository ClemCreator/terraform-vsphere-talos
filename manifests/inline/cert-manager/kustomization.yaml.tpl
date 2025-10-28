apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: cert-manager

resources:
  - namespace.yaml

helmCharts:
  - name: cert-manager
    repo: https://charts.jetstack.io
    version: ${cert_manager_version}
    releaseName: cert-manager
    namespace: cert-manager
    includeCRDs: true
    valuesFile: values.yaml
