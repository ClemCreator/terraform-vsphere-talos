# 📁 Manifests Directory

This directory contains all Kubernetes manifests managed through a GitOps approach using ArgoCD.

## 📂 Structure

```
manifests/
├── apps/                    # ArgoCD Application definitions
│   ├── kustomization.yaml   # List of all applications
│   ├── gitea.yaml          # Gitea application
│   ├── trust-manager.yaml  # Trust-manager application
│   └── reloader.yaml       # Reloader application
│
├── bootstrap/              # Bootstrap manifests
│   ├── app-root.yaml       # Root ArgoCD app (App of Apps pattern)
│   └── argocd/            # ArgoCD configuration (future)
│
├── inline/                # Inline manifests (deployed in Talos config)
│   └── cilium/           # Cilium CNI configuration (future)
│
├── gitea/                # Gitea Helm chart configuration
│   ├── kustomization.yaml
│   ├── values.yaml
│   └── certificate.yaml
│
├── trust-manager/        # Trust-manager Helm chart configuration
│   ├── kustomization.yaml
│   └── values.yaml
│
└── reloader/            # Reloader Helm chart configuration
    ├── kustomization.yaml
    └── values.yaml
```

## 🎯 Deployment Flow

### 1. **Inline Manifests** (Critical System Components)
Deployed directly in Talos configuration via `inlineManifests`:
- **Cilium**: CNI plugin (must be first for networking)
- **cert-manager**: Certificate management
- **ArgoCD**: GitOps controller

### 2. **Bootstrap** (Post-Cluster Creation)
Deployed by Terraform after cluster is ready:
- **app-root**: ArgoCD Application that manages all other applications

### 3. **Applications** (Managed by ArgoCD)
Automatically deployed and synced by ArgoCD from Git:
- **gitea**: Git server
- **trust-manager**: CA bundle distribution
- **reloader**: ConfigMap/Secret auto-reloader

## 🔄 App of Apps Pattern

The `bootstrap/app-root.yaml` implements the "App of Apps" pattern:

```
app-root (ArgoCD Application)
    ↓
    Points to: manifests/apps/
    ↓
    Deploys:
    ├── gitea
    ├── trust-manager
    └── reloader
```

## ✨ Benefits

1. **GitOps-Ready**: All changes tracked in Git
2. **Automatic Sync**: ArgoCD keeps cluster in sync with Git
3. **Easy Rollback**: Git history = deployment history
4. **Declarative**: Desired state defined in YAML
5. **Self-Healing**: ArgoCD automatically fixes drift
6. **Easy to Add**: New app = new YAML in `apps/`

## 🚀 Adding a New Application

1. Create application directory: `manifests/my-app/`
2. Add `kustomization.yaml` and Helm values
3. Create ArgoCD Application: `manifests/apps/my-app.yaml`
4. Add to `manifests/apps/kustomization.yaml`
5. Commit and push to Git
6. ArgoCD syncs automatically ✅

## 📝 Important Notes

- **Repository URL**: Update the `repoURL` in ArgoCD applications to match your Git repository
- **Domain**: Update domain names in certificates and ingresses to match your environment
- **Secrets**: Consider using Sealed Secrets or External Secrets for sensitive data
- **Kustomize**: All applications use Kustomize for flexibility

## 🔍 Monitoring

Check ArgoCD UI to see application status:
```bash
kubectl port-forward -n argocd svc/argocd-server 8080:443
# Visit: https://localhost:8080
```

## 🛠️ Troubleshooting

```bash
# Check app-root status
kubectl -n argocd get application app-root

# Check all applications
kubectl -n argocd get applications

# View application details
kubectl -n argocd describe application gitea

# Force sync an application
argocd app sync gitea

# View ArgoCD logs
kubectl -n argocd logs -l app.kubernetes.io/name=argocd-application-controller
```

---

**Created**: 28 October 2025  
**Pattern**: App of Apps (ArgoCD)  
**Stack**: Talos Linux + vSphere + ArgoCD + Kustomize
