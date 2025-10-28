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
    kubeconfig   = talos_cluster_kubeconfig.talos.kubeconfig_raw
  }

  provisioner "local-exec" {
    command = <<-EOT
      # Create kubeconfig file from Terraform output
      cat > ${path.module}/kubeconfig.yml <<'KUBECONFIG'
${talos_cluster_kubeconfig.talos.kubeconfig_raw}
KUBECONFIG
      
      # Wait for ArgoCD to be ready (deployed as inline manifest)
      echo "Waiting for ArgoCD to be ready..."
      max_attempts=60
      attempt=0
      until kubectl --kubeconfig ${path.module}/kubeconfig.yml \
        -n argocd get deployment argocd-server -o jsonpath='{.status.availableReplicas}' 2>/dev/null | grep -q "1"; do
        attempt=$((attempt + 1))
        if [ $attempt -ge $max_attempts ]; then
          echo "ERROR: ArgoCD server did not become ready after $max_attempts attempts"
          exit 1
        fi
        echo "Waiting for ArgoCD server... (attempt $attempt/$max_attempts)"
        sleep 5
      done
      
      # Deploy the app-root application
      echo "Deploying app-root ArgoCD application..."
      kubectl --kubeconfig ${path.module}/kubeconfig.yml apply -f ${path.module}/manifests/bootstrap/app-root.yaml
      
      # Wait for app-root to be synced
      echo "Waiting for app-root to sync..."
      sleep 10
      
      echo "✅ app-root deployed successfully!"
    EOT
  }

  # Cleanup: remove app-root when destroying
  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      if [ -f ${path.module}/kubeconfig.yml ]; then
        kubectl --kubeconfig ${path.module}/kubeconfig.yml delete -f ${path.module}/manifests/bootstrap/app-root.yaml --ignore-not-found=true || true
      fi
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
