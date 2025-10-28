#!/usr/bin/env bash
# Pre-deployment Validation Script
# Vérifie que tout est prêt avant le déploiement

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ERRORS=0
WARNINGS=0

function error() {
  echo -e "${RED}❌ ERROR: $1${NC}"
  ((ERRORS++))
}

function warning() {
  echo -e "${YELLOW}⚠️  WARNING: $1${NC}"
  ((WARNINGS++))
}

function success() {
  echo -e "${GREEN}✅ $1${NC}"
}

function info() {
  echo -e "ℹ️  $1"
}

echo "🔍 Pre-deployment Validation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check 1: Structure des dossiers
info "Checking directory structure..."
required_dirs=(
  "manifests/apps"
  "manifests/bootstrap"
  "manifests/gitea"
  "manifests/trust-manager"
  "manifests/reloader"
)

for dir in "${required_dirs[@]}"; do
  if [[ -d "$dir" ]]; then
    success "Directory exists: $dir"
  else
    error "Missing directory: $dir"
  fi
done
echo ""

# Check 2: Fichiers manifests
info "Checking manifest files..."
required_files=(
  "manifests/bootstrap/app-root.yaml"
  "manifests/apps/gitea.yaml"
  "manifests/apps/trust-manager.yaml"
  "manifests/apps/reloader.yaml"
  "manifests/apps/kustomization.yaml"
  "manifests/gitea/kustomization.yaml"
  "manifests/gitea/values.yaml"
  "manifests/trust-manager/kustomization.yaml"
  "manifests/reloader/kustomization.yaml"
  "manifests-bootstrap.tf"
)

for file in "${required_files[@]}"; do
  if [[ -f "$file" ]]; then
    success "File exists: $file"
  else
    error "Missing file: $file"
  fi
done
echo ""

# Check 3: URLs Git configurées
info "Checking Git repository URLs..."

# Function to check if URL is placeholder
check_url() {
  local file=$1
  local url=$(grep -o 'repoURL:.*' "$file" | head -1 || echo "")
  
  if [[ "$url" == *"clemcreator"* ]] || [[ "$url" == *"YOUR-REPO"* ]]; then
    warning "Placeholder URL in $file: $url"
    echo "         Update with your real Git repository URL"
  else
    success "Git URL configured in $file"
  fi
}

if [[ -f "manifests/bootstrap/app-root.yaml" ]]; then
  check_url "manifests/bootstrap/app-root.yaml"
fi

for app in manifests/apps/*.yaml; do
  if [[ -f "$app" ]] && [[ "$app" != *"kustomization.yaml" ]]; then
    check_url "$app"
  fi
done
echo ""

# Check 4: Domaines configurés
info "Checking domain configuration..."

check_domain() {
  local file=$1
  if [[ -f "$file" ]]; then
    if grep -q "example.test" "$file"; then
      warning "Placeholder domain in $file"
      echo "         Update with your real domain"
    else
      success "Domain configured in $file"
    fi
  fi
}

check_domain "manifests/gitea/certificate.yaml"
check_domain "manifests/gitea/values.yaml"
echo ""

# Check 5: Fichiers Terraform
info "Checking Terraform files..."
tf_files=(
  "talos.tf"
  "manifests-bootstrap.tf"
  "argocd.tf"
  "gitea.tf"
  "trust-manager.tf"
  "reloader.tf"
)

for file in "${tf_files[@]}"; do
  if [[ -f "$file" ]]; then
    success "Terraform file exists: $file"
  else
    error "Missing Terraform file: $file"
  fi
done
echo ""

# Check 6: Yaml validity
info "Validating YAML syntax..."

for yamlfile in $(find manifests -name "*.yaml" -o -name "*.yml"); do
  if command -v yamllint &> /dev/null; then
    if yamllint -d relaxed "$yamlfile" &> /dev/null; then
      success "Valid YAML: $yamlfile"
    else
      error "Invalid YAML: $yamlfile"
    fi
  else
    warning "yamllint not installed, skipping YAML validation"
    break
  fi
done
echo ""

# Check 7: Git status
info "Checking Git status..."

if git rev-parse --git-dir > /dev/null 2>&1; then
  if git diff --quiet HEAD; then
    success "No uncommitted changes"
  else
    warning "You have uncommitted changes"
    echo "         Run: git add . && git commit -m 'feat: GitOps migration'"
  fi
  
  if git diff --quiet origin/$(git branch --show-current)..HEAD 2>/dev/null; then
    warning "Local changes not pushed to remote"
    echo "         Run: git push origin main"
  else
    success "All changes pushed to remote"
  fi
else
  warning "Not a git repository"
fi
echo ""

# Check 8: Prerequisites
info "Checking prerequisites..."

commands=(
  "terraform:Terraform"
  "kubectl:Kubernetes CLI"
  "talosctl:Talos CLI"
)

for cmd_pair in "${commands[@]}"; do
  IFS=':' read -r cmd name <<< "$cmd_pair"
  if command -v "$cmd" &> /dev/null; then
    version=$($cmd version 2>&1 | head -1 || echo "unknown")
    success "$name installed: $version"
  else
    warning "$name not found in PATH"
  fi
done
echo ""

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Validation Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ $ERRORS -eq 0 ]] && [[ $WARNINGS -eq 0 ]]; then
  echo -e "${GREEN}🎉 All checks passed! Ready to deploy.${NC}"
  echo ""
  echo "Next steps:"
  echo "  1. Review your configuration"
  echo "  2. Run: ./do plan"
  echo "  3. Run: ./do apply"
  exit 0
elif [[ $ERRORS -eq 0 ]]; then
  echo -e "${YELLOW}⚠️  $WARNINGS warning(s) found${NC}"
  echo ""
  echo "You can proceed, but review the warnings above."
  echo ""
  echo "Next steps:"
  echo "  1. Fix warnings (recommended)"
  echo "  2. Run: ./do plan"
  echo "  3. Run: ./do apply"
  exit 0
else
  echo -e "${RED}❌ $ERRORS error(s) and $WARNINGS warning(s) found${NC}"
  echo ""
  echo "Please fix the errors above before deploying."
  exit 1
fi
