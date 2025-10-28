# cert-manager Helm values
# see https://artifacthub.io/packages/helm/cert-manager/cert-manager

# Install CRDs
# NB: installCRDs is generally not recommended for production,
# BUT since this is a development cluster we YOLO it.
installCRDs: true
