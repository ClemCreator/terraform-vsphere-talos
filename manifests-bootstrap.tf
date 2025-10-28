# Bootstrap manifests deployed after the cluster is ready.
# This file manages the deployment of ArgoCD's app-root application,
# which implements the "App of Apps" pattern to manage all other applications.

# Wait for the cluster to be fully ready before deploying bootstrap manifests
resource "terraform_data" "cluster_ready" {
  depends_on = [
    talos_machine_bootstrap.talos,
    talos_cluster_kubeconfig.talos,
  ]
}

# Deploy the app-root application that manages all other ArgoCD applications
# This implements the "App of Apps" pattern
resource "null_resource" "deploy_app_root" {
  depends_on = [terraform_data.cluster_ready]

  # Trigger redeployment when the app-root manifest changes
  triggers = {
    manifest_sha = filesha256("${path.module}/manifests/bootstrap/app-root.yaml")
  }

  provisioner "local-exec" {
    command = <<-EOT
      # Wait for ArgoCD to be ready (deployed as inline manifest)
      echo "Waiting for ArgoCD to be ready..."
      until kubectl --kubeconfig ${path.module}/kubeconfig.yml \
        -n argocd get deployment argocd-server -o jsonpath='{.status.availableReplicas}' | grep -q "1"; do
        echo "Waiting for ArgoCD server..."
        sleep 5
      done
      
      # Deploy the app-root application
      echo "Deploying app-root ArgoCD application..."
      kubectl --kubeconfig ${path.module}/kubeconfig.yml apply -f ${path.module}/manifests/bootstrap/app-root.yaml
      
      # Wait for app-root to be synced
      echo "Waiting for app-root to sync..."
      sleep 10
    EOT
  }

  # Cleanup: remove app-root when destroying
  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      kubectl --kubeconfig ${path.module}/kubeconfig.yml delete -f ${path.module}/manifests/bootstrap/app-root.yaml --ignore-not-found=true || true
    EOT
  }
}

# Output to track bootstrap status
output "bootstrap_status" {
  value = "ArgoCD app-root deployed. Check ArgoCD UI for application status."
  depends_on = [
    null_resource.deploy_app_root,
  ]
}
