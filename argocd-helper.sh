#!/usr/bin/env bash
# ArgoCD Helper Script
# Provides convenient commands to manage ArgoCD applications

set -euo pipefail

export KUBECONFIG=${KUBECONFIG:-$PWD/kubeconfig.yml}

function usage() {
  cat <<EOF
ArgoCD Helper Script

Usage: $0 <command>

Commands:
  status          Show all ArgoCD applications status
  sync <app>      Force sync an application
  sync-all        Force sync all applications
  diff <app>      Show diff between Git and cluster
  logs <app>      Show application logs
  ui              Open ArgoCD UI (port-forward)
  password        Get ArgoCD admin password
  list            List all applications
  watch           Watch applications status in real-time

Examples:
  $0 status
  $0 sync gitea
  $0 ui
  $0 password

EOF
  exit 1
}

function check_kubeconfig() {
  if [[ ! -f "$KUBECONFIG" ]]; then
    echo "❌ Error: kubeconfig not found at $KUBECONFIG"
    echo "Run: ./do apply"
    exit 1
  fi
}

function status() {
  check_kubeconfig
  echo "📊 ArgoCD Applications Status"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  kubectl -n argocd get applications -o wide
}

function sync_app() {
  local app=$1
  check_kubeconfig
  echo "🔄 Syncing application: $app"
  kubectl -n argocd patch application "$app" \
    --type merge \
    -p '{"operation":{"sync":{"syncStrategy":{"hook":{},"apply":{"force":true}}}}}'
  echo "✅ Sync triggered for $app"
}

function sync_all() {
  check_kubeconfig
  echo "🔄 Syncing all applications..."
  
  apps=$(kubectl -n argocd get applications -o jsonpath='{.items[*].metadata.name}')
  
  for app in $apps; do
    echo "  → Syncing $app..."
    kubectl -n argocd patch application "$app" \
      --type merge \
      -p '{"operation":{"sync":{"syncStrategy":{"hook":{},"apply":{"force":true}}}}}' || true
  done
  
  echo "✅ All applications synced"
}

function diff_app() {
  local app=$1
  check_kubeconfig
  echo "📝 Diff for application: $app"
  kubectl -n argocd get application "$app" -o yaml | grep -A 50 "status:"
}

function logs_app() {
  local app=$1
  check_kubeconfig
  echo "📋 Logs for application: $app"
  
  # Get namespace and pods for the app
  namespace=$(kubectl -n argocd get application "$app" -o jsonpath='{.spec.destination.namespace}')
  
  echo "Application: $app"
  echo "Namespace: $namespace"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  
  kubectl -n "$namespace" get pods
  
  echo ""
  echo "Select a pod to view logs (or Ctrl+C to exit):"
  kubectl -n "$namespace" get pods -o name
}

function open_ui() {
  check_kubeconfig
  echo "🌐 Opening ArgoCD UI..."
  echo ""
  echo "ArgoCD UI will be available at: https://localhost:8080"
  echo "Username: admin"
  echo -n "Password: "
  kubectl -n argocd get secret argocd-initial-admin-secret \
    -o jsonpath="{.data.password}" 2>/dev/null | base64 -d
  echo ""
  echo ""
  echo "Opening browser..."
  
  # Start port-forward in background
  kubectl port-forward -n argocd svc/argocd-server 8080:443 &
  PF_PID=$!
  
  # Wait a bit for port-forward to start
  sleep 2
  
  # Try to open browser
  if command -v xdg-open &> /dev/null; then
    xdg-open https://localhost:8080 2>/dev/null || true
  elif command -v open &> /dev/null; then
    open https://localhost:8080 2>/dev/null || true
  fi
  
  echo "Press Ctrl+C to stop port-forwarding"
  wait $PF_PID
}

function get_password() {
  check_kubeconfig
  echo -n "ArgoCD Admin Password: "
  kubectl -n argocd get secret argocd-initial-admin-secret \
    -o jsonpath="{.data.password}" 2>/dev/null | base64 -d
  echo ""
}

function list_apps() {
  check_kubeconfig
  echo "📦 ArgoCD Applications"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  kubectl -n argocd get applications -o custom-columns=\
NAME:.metadata.name,\
SYNC:.status.sync.status,\
HEALTH:.status.health.status,\
NAMESPACE:.spec.destination.namespace
}

function watch_apps() {
  check_kubeconfig
  echo "👁️  Watching ArgoCD Applications (press Ctrl+C to exit)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  watch -n 2 "kubectl -n argocd get applications -o custom-columns=\
NAME:.metadata.name,\
SYNC:.status.sync.status,\
HEALTH:.status.health.status,\
NAMESPACE:.spec.destination.namespace"
}

# Main
case ${1:-} in
  status)
    status
    ;;
  sync)
    if [[ -z "${2:-}" ]]; then
      echo "❌ Error: application name required"
      echo "Usage: $0 sync <app-name>"
      exit 1
    fi
    sync_app "$2"
    ;;
  sync-all)
    sync_all
    ;;
  diff)
    if [[ -z "${2:-}" ]]; then
      echo "❌ Error: application name required"
      echo "Usage: $0 diff <app-name>"
      exit 1
    fi
    diff_app "$2"
    ;;
  logs)
    if [[ -z "${2:-}" ]]; then
      echo "❌ Error: application name required"
      echo "Usage: $0 logs <app-name>"
      exit 1
    fi
    logs_app "$2"
    ;;
  ui)
    open_ui
    ;;
  password)
    get_password
    ;;
  list)
    list_apps
    ;;
  watch)
    watch_apps
    ;;
  *)
    usage
    ;;
esac
