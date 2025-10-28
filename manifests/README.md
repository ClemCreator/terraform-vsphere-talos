# 📁 Manifests Directory - GitOps with TPL Templates

This directory contains all Kubernetes manifests using a **dual deployment strategy**: Inline manifests for bootstrap and ArgoCD for ongoing management, with **TPL (template) files** for dynamic configuration.

## 📂 Complete Structure

```
manifests/
├── inline/                          # 🔧 TPL files for bootstrap apps (Talos inlineManifests)
│   ├── cilium/
│   │   ├── kustomization.yaml.tpl   # Template with ${cilium_version}
│   │   └── values.yaml.tpl          # Template with ${kubeprism_port}
│   ├── cert-manager/
│   │   ├── kustomization.yaml.tpl
│   │   ├── values.yaml.tpl
│   │   └── namespace.yaml
│   └── argocd/
│       ├── kustomization.yaml.tpl
│       ├── values.yaml.tpl
│       └── namespace.yaml
│
├── apps/                            # 🎯 ArgoCD Application definitions
│   ├── cilium.yaml                  # Optional: ArgoCD management of Cilium
│   ├── cert-manager.yaml            # Optional: ArgoCD management of cert-manager
│   ├── argocd.yaml                  # Optional: ArgoCD management of ArgoCD itself
│   ├── gitea.yaml                   # Gitea application
│   ├── trust-manager.yaml           # Trust-manager application
│   └── reloader.yaml                # Reloader application
│
├── bootstrap/                       # 🚀 Bootstrap manifests
│   └── app-root.yaml                # Root ArgoCD app (App of Apps pattern)
│
├── cilium/                          # 📦 Kustomize manifests for Cilium (ArgoCD-managed)
│   ├── kustomization.yaml
│   ├── values.yaml
│   ├── l2-announcement-policy.yaml
│   └── lb-ip-pool.yaml
│
├── cert-manager-argocd/             # 📦 Kustomize manifests for cert-manager (ArgoCD-managed)
│   ├── kustomization.yaml
│   ├── namespace.yaml
│   ├── values.yaml
│   ├── cluster-issuer-selfsigned.yaml
│   ├── certificate-ingress.yaml
│   └── cluster-issuer-ingress.yaml
│
├── argocd-managed/                  # 📦 Kustomize manifests for ArgoCD (ArgoCD-managed)
│   ├── kustomization.yaml
│   ├── namespace.yaml
│   ├── values.yaml
│   └── certificate.yaml
│
├── gitea/                           # 📦 Gitea Helm chart configuration
│   ├── kustomization.yaml
│   ├── values.yaml
│   └── certificate.yaml
│
├── trust-manager/                   # 📦 Trust-manager Helm chart configuration
│   ├── kustomization.yaml
│   └── values.yaml
│
└── reloader/                        # 📦 Reloader Helm chart configuration
    ├── kustomization.yaml
    └── values.yaml
```

## 🎯 Two Deployment Methods

### 1. 🔧 Inline Manifests (Bootstrap - Critical Components)

**Purpose**: Deploy critical infrastructure during Talos cluster bootstrap

**Components**:
- **Cilium**: CNI (Container Network Interface) - required for pod networking
- **cert-manager**: TLS certificate management - required for ingress
- **ArgoCD**: GitOps controller - required for application management

**How it works**:
1. **TPL Files** in `manifests/inline/`: Templates with variables like `${cilium_version}`, `${kubeprism_port}`
2. **Terraform** (`manifests-inline.tf`):
   - Uses `templatefile()` to generate final YAML from TPL files
   - Uses `data.helm_template` to render Helm charts
   - Outputs complete manifests
3. **Talos** (`talos.tf`):
   - Embeds generated manifests in `inlineManifests` configuration
   - Talos applies these automatically during bootstrap

**File Flow**:
```
manifests/inline/cilium/kustomization.yaml.tpl
  └─[templatefile()]→ kustomization.yaml (with cilium_version)
    └─[data.helm_template]→ Cilium manifests
      └─[inlineManifests]→ Talos machine config
        └─[cluster bootstrap]→ Deployed immediately
```

### 2. 🎯 ArgoCD-Managed Applications (GitOps - All Applications)

**Purpose**: Continuous deployment and lifecycle management

**Components**:
- All applications from `manifests/apps/`: gitea, trust-manager, reloader
- Optional: cilium, cert-manager, argocd (for post-bootstrap updates)

**How it works**:
1. **App of Apps Pattern**: `manifests/bootstrap/app-root.yaml` manages all apps
2. **Application Definitions**: `manifests/apps/*.yaml` point to Kustomize directories
3. **Kustomize + Helm**: Each app directory contains Helm chart configuration
4. **ArgoCD Sync**: Automatically applies changes from Git

**Deployment Flow**:
```
Git repository
  └─[ArgoCD syncs]→ manifests/bootstrap/app-root.yaml
    └─[manages]→ manifests/apps/*.yaml
      └─[points to]→ manifests/{app}/
        └─[deployed to cluster]
```

## 🔥 TPL (Template) Files - Key Innovation

TPL files use Terraform's `templatefile()` function for **dynamic configuration**.

### Why TPL Files?

Inspired by [roeldev/iac-talos-cluster](https://github.com/roeldev/iac-talos-cluster), TPL files provide:

1. **Dynamic Versioning**: Chart versions from Terraform variables
2. **Environment-Specific Config**: Different values per environment
3. **DRY Principle**: Single source of truth
4. **Type Safety**: Terraform variable validation
5. **Integration**: Seamless Terraform workflow

### Example: Cilium TPL

**Template** (`manifests/inline/cilium/kustomization.yaml.tpl`):
```yaml
helmCharts:
  - name: cilium
    version: ${cilium_version}  # ← Template variable
    valuesFile: values.yaml
```

**Terraform** (`manifests-inline.tf`):
```hcl
resource "local_file" "cilium_kustomization" {
  content = templatefile("manifests/inline/cilium/kustomization.yaml.tpl", {
    cilium_version = var.cilium_version  # ← From variables.tf
  })
}
```

**Result** (generated `kustomization.yaml`):
```yaml
helmCharts:
  - name: cilium
    version: 1.16.4  # ← Actual value
    valuesFile: values.yaml
```

## 🔄 App of Apps Pattern

The `bootstrap/app-root.yaml` implements the "App of Apps" pattern:

```
app-root (ArgoCD Application)
    ↓
    Points to: manifests/apps/
    ↓
    Deploys:
    ├── cilium (optional)
    ├── cert-manager (optional)
    ├── argocd (optional)
    ├── gitea
    ├── trust-manager
    └── reloader
```

## ✨ Benefits of This Architecture

### Bootstrap (Inline) Benefits:
- ✅ Components available **immediately** after cluster creation
- ✅ No chicken-and-egg problem (Cilium needed for networking)
- ✅ Versioned in Terraform with TPL templates
- ✅ Idempotent and reproducible

### ArgoCD (GitOps) Benefits:
- ✅ GitOps workflow: all changes tracked in Git
- ✅ Automatic synchronization and healing
- ✅ Easy rollbacks (Git history = deployment history)
- ✅ Declarative configuration
- ✅ Self-healing: automatically fixes drift
- ✅ Unified observability (ArgoCD UI)

### TPL Files Benefits:
- ✅ Dynamic configuration with type safety
- ✅ Single source of truth for versions
- ✅ Terraform-native workflow
- ✅ Environment-specific customization
- ✅ Automated updates with Renovate

## 🚀 Workflow

### Initial Deployment

```bash
# 1. Configure versions in variables.tf
vim variables.tf  # cilium_version, cert_manager_version, argocd_version

# 2. Plan and apply Terraform
terraform plan
terraform apply

# Result:
# - Talos cluster created
# - Cilium, cert-manager, ArgoCD deployed (inline from TPL)
# - app-root deployed (by manifests-bootstrap.tf)
# - All applications synced by ArgoCD
```

### Update Inline Component Version

```bash
# 1. Update version in variables.tf
vim variables.tf  # Change cilium_version = "1.16.5"

# 2. Regenerate manifests and apply
terraform plan
terraform apply

# TPL files regenerated → New manifests → Talos config updated
```

### Update ArgoCD-Managed Application

```bash
# 1. Edit manifest in Git
vim manifests/gitea/kustomization.yaml  # Change version: 11.0.1

# 2. Commit and push
git add manifests/gitea/kustomization.yaml
git commit -m "feat: upgrade Gitea to 11.0.1"
git push

# 3. ArgoCD syncs automatically
# Or manually: kubectl argo app sync gitea -n argocd
```

### Add New Application

```bash
# 1. Create app manifests
mkdir -p manifests/myapp
cat > manifests/myapp/kustomization.yaml << EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
helmCharts:
  - name: myapp
    repo: https://charts.example.com
    version: 1.0.0
    namespace: myapp
    valuesFile: values.yaml
EOF

# 2. Create Helm values
cat > manifests/myapp/values.yaml << EOF
replicaCount: 2
EOF

# 3. Create ArgoCD Application
cat > manifests/apps/myapp.yaml << EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/YOUR_ORG/terraform-vsphere-talos
    targetRevision: HEAD
    path: manifests/myapp
  destination:
    server: https://kubernetes.default.svc
    namespace: myapp
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF

# 4. Commit and push
git add manifests/myapp/ manifests/apps/myapp.yaml
git commit -m "feat: add myapp application"
git push

# ArgoCD deploys automatically ✅
```

## 🛠️ Configuration Files

### For Inline Manifests (TPL-based)

- **`manifests-inline.tf`**: Generates inline manifests using TPL templates
- **`variables.tf`**: Defines versions (cilium_version, cert_manager_version, argocd_version)
- **`talos.tf`**: Embeds generated manifests in Talos machine config
- **`manifests/inline/*/`**: TPL template files

### For ArgoCD Applications

- **`manifests-bootstrap.tf`**: Deploys app-root.yaml after cluster bootstrap
- **`manifests/bootstrap/app-root.yaml`**: Root ArgoCD Application
- **`manifests/apps/*.yaml`**: Individual Application definitions
- **`manifests/{app}/`**: Per-application Kustomize + Helm configuration

## 🔍 Troubleshooting

### Inline Manifests Issues

```bash
# Check generated manifests
cat output/inline-manifests.yaml

# Verify TPL files generated correctly
ls -la manifests/inline/*/kustomization.yaml
ls -la manifests/inline/*/values.yaml

# Check Terraform plan
terraform plan

# Verify Talos config
talosctl -n $CONTROLLER_IP get machineconfig -o yaml | grep -A 50 inlineManifests

# Check if manifests were applied
kubectl get pods -n kube-system      # Cilium
kubectl get pods -n cert-manager     # cert-manager
kubectl get pods -n argocd           # ArgoCD
```

### ArgoCD Sync Issues

```bash
# Check ArgoCD Application status
kubectl get applications -n argocd

# View Application details
kubectl describe application gitea -n argocd

# Manual sync
kubectl argo app sync gitea -n argocd

# View sync status
kubectl argo app get gitea -n argocd

# Check ArgoCD logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller
```

### TPL Template Issues

```bash
# Regenerate templates
terraform apply -target=local_file.cilium_kustomization
terraform apply -target=local_file.cilium_values

# Check for template syntax errors
terraform validate
```

## 📝 Important Notes

- **Repository URL**: Update `repoURL` in ArgoCD applications to match your Git repository
- **Domain**: Update domain names in certificates to match your environment
- **Versions**: Use Renovate annotations for automated updates
- **Validation**: Run `./validate.sh` before committing changes
- **Bootstrap Components**: Can be managed by BOTH inline AND ArgoCD (optional)

## 🎓 Best Practices

1. **Version Pinning**: Always use specific versions, not `latest`
2. **Git Workflow**: All changes via commits, no manual kubectl edits
3. **Testing**: Test changes in dev environment first
4. **Documentation**: Update this README when adding applications
5. **Renovate**: Use Renovate bot for automated dependency updates
6. **Validation**: Validate YAML syntax before committing
7. **Backup**: Keep `talosconfig.yml` and `kubeconfig.yml` safe

## 📚 References

- [Talos Linux Documentation](https://www.talos.dev/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Kustomize Documentation](https://kustomize.io/)
- [Terraform templatefile Function](https://www.terraform.io/language/functions/templatefile)
- [roeldev/iac-talos-cluster](https://github.com/roeldev/iac-talos-cluster) - Inspiration for TPL pattern

---

**Created**: 28 October 2025  
**Updated**: 28 October 2025  
**Pattern**: App of Apps (ArgoCD) + TPL Templates (Terraform)  
**Stack**: Talos Linux + vSphere + ArgoCD + Kustomize + Terraform  
**Inspiration**: roeldev/iac-talos-cluster
