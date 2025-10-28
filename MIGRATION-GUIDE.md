# 🚀 Guide de Migration vers GitOps avec ArgoCD

## ✅ Ce qui a été fait

### 1. Structure des Manifests
Création de l'arborescence complète:
```
manifests/
├── apps/              # Définitions des applications ArgoCD
├── bootstrap/         # Manifests de bootstrap (app-root)
├── gitea/            # Configuration Helm de Gitea
├── trust-manager/    # Configuration Helm de trust-manager
└── reloader/         # Configuration Helm de reloader
```

### 2. Migration des Applications
Les applications suivantes ont été migrées vers ArgoCD:
- ✅ **Gitea**: Serveur Git
- ✅ **trust-manager**: Distribution des CA bundles
- ✅ **reloader**: Auto-reload des ConfigMaps/Secrets

### 3. Pattern "App of Apps"
- `manifests/bootstrap/app-root.yaml` implémente le pattern App of Apps
- Déployé par Terraform après le bootstrap du cluster
- Gère automatiquement toutes les applications dans `manifests/apps/`

### 4. Refactorisation Terraform
- **Nouveau**: `manifests-bootstrap.tf` pour déployer app-root
- **Modifié**: `talos.tf` pour retirer les apps migrées des inlineManifests
- **Conservé**: Cilium, cert-manager et ArgoCD restent en inline (critiques)

## 📋 Prochaines Étapes

### 1. ⚠️ IMPORTANT : Mettre à jour les URLs Git

Avant de déployer, vous DEVEZ mettre à jour les URLs de repository dans:

```bash
# Fichiers à modifier avec VOTRE URL GitHub/GitLab:
manifests/bootstrap/app-root.yaml
manifests/apps/gitea.yaml
manifests/apps/trust-manager.yaml
manifests/apps/reloader.yaml
```

Remplacez:
```yaml
repoURL: https://github.com/clemcreator/terraform-vsphere-talos
```

Par votre vrai repository Git.

### 2. 🔧 Ajuster les Domaines

Mettre à jour les domaines dans:
```bash
manifests/gitea/certificate.yaml  # gitea.example.test → votre domaine
manifests/gitea/values.yaml       # gitea.example.test → votre domaine
```

### 3. 🚀 Déploiement

#### Option A: Premier déploiement (nouveau cluster)
```bash
# 1. Détruire l'ancien cluster si existant
./do destroy

# 2. Commit et push des changements
git add manifests/
git add manifests-bootstrap.tf
git add talos.tf
git commit -m "feat: migrate to GitOps with ArgoCD App of Apps pattern"
git push origin main

# 3. Déployer le nouveau cluster
./do init
./do plan-apply

# 4. Vérifier ArgoCD
export KUBECONFIG=$PWD/kubeconfig.yml
kubectl -n argocd get applications
kubectl -n argocd get application app-root
```

#### Option B: Migration d'un cluster existant (ATTENTION)
```bash
# ⚠️ RISQUE: Cette approche peut causer des interruptions

# 1. Backup actuel
kubectl get all -A -o yaml > backup-before-migration.yaml

# 2. Commit et push
git add manifests/
git commit -m "feat: add GitOps manifests"
git push origin main

# 3. Apply Terraform
terraform apply

# 4. Supprimer manuellement les anciennes ressources si nécessaire
kubectl delete -n default deployment gitea
kubectl delete -n cert-manager deployment trust-manager
kubectl delete -n kube-system deployment reloader
```

## 🔍 Vérifications Post-Déploiement

### 1. Vérifier ArgoCD
```bash
export KUBECONFIG=$PWD/kubeconfig.yml

# App-root doit être synced
kubectl -n argocd get application app-root

# Toutes les apps doivent apparaître
kubectl -n argocd get applications

# Statut détaillé
kubectl -n argocd describe application gitea
kubectl -n argocd describe application trust-manager
kubectl -n argocd describe application reloader
```

### 2. Vérifier les Applications
```bash
# Gitea
kubectl -n default get pods -l app.kubernetes.io/name=gitea

# trust-manager
kubectl -n cert-manager get pods -l app.kubernetes.io/name=trust-manager

# reloader
kubectl -n kube-system get pods -l app=reloader-reloader
```

### 3. Accéder à ArgoCD UI
```bash
# Port-forward
kubectl port-forward -n argocd svc/argocd-server 8080:443

# Récupérer le mot de passe admin
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# Ouvrir https://localhost:8080
# User: admin
# Password: <from above>
```

## 🎯 Ajouter une Nouvelle Application

```bash
# 1. Créer le dossier de config
mkdir -p manifests/my-app

# 2. Créer kustomization.yaml
cat > manifests/my-app/kustomization.yaml <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
helmCharts:
  - name: my-app
    repo: https://charts.example.com
    version: 1.0.0
    releaseName: my-app
    namespace: default
    valuesFile: values.yaml
EOF

# 3. Créer values.yaml
cat > manifests/my-app/values.yaml <<EOF
replicas: 2
# ... your values
EOF

# 4. Créer l'application ArgoCD
cat > manifests/apps/my-app.yaml <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/YOUR-REPO/terraform-vsphere-talos
    targetRevision: main
    path: manifests/my-app
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      selfHeal: true
      prune: true
EOF

# 5. Ajouter au kustomization.yaml
echo "  - my-app.yaml" >> manifests/apps/kustomization.yaml

# 6. Commit et push
git add manifests/
git commit -m "feat: add my-app"
git push

# 7. ArgoCD sync automatiquement en quelques secondes ✨
```

## 🛠️ Troubleshooting

### App ne se synchronise pas
```bash
# Forcer le sync
kubectl -n argocd patch application my-app \
  --type merge -p '{"operation":{"sync":{}}}'

# Ou via CLI
argocd app sync my-app
```

### Problèmes avec Kustomize + Helm
```bash
# Tester localement
kubectl kustomize manifests/my-app/

# Vérifier les logs ArgoCD
kubectl -n argocd logs -l app.kubernetes.io/name=argocd-application-controller
```

### Repository non accessible
```bash
# Vérifier l'URL dans app-root
kubectl -n argocd get application app-root -o yaml | grep repoURL

# Ajouter un repository privé
kubectl -n argocd create secret generic my-repo \
  --from-literal=url=https://github.com/my/repo \
  --from-literal=username=git \
  --from-literal=password=token
```

## 📚 Références

- [ArgoCD Best Practices](https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/)
- [App of Apps Pattern](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/)
- [Kustomize + Helm](https://kubectl.docs.kubernetes.io/references/kustomize/builtins/#_helmchartinflationgenerator_)

## ✨ Avantages de cette Architecture

1. **GitOps**: Tout versionné dans Git
2. **Déclaratif**: État désiré vs état actuel
3. **Self-Healing**: ArgoCD corrige automatiquement les drifts
4. **Rollback facile**: `git revert` + ArgoCD sync
5. **Audit trail**: Historique Git = historique des déploiements
6. **Scalabilité**: Facile d'ajouter de nouvelles apps
7. **Multi-environnements**: Kustomize overlays pour dev/staging/prod

---

**Date**: 28 octobre 2025  
**Architecture**: Talos Linux + vSphere + ArgoCD + Kustomize  
**Pattern**: App of Apps
