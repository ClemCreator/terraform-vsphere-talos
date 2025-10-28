# 🎯 Migration complète vers Architecture GitOps avec TPL Templates

**Date**: 28 octobre 2025  
**Inspiration**: [roeldev/iac-talos-cluster](https://github.com/roeldev/iac-talos-cluster)  
**Pattern**: App of Apps (ArgoCD) + TPL Templates (Terraform)

## 📋 Résumé des changements

Cette migration transforme le projet d'une architecture monolithique vers une architecture GitOps moderne avec **fichiers TPL pour le templating dynamique**, inspirée du projet roeldev/iac-talos-cluster.

### ✅ Ce qui a été fait

1. **Structure TPL pour manifests inline** ✅
   - Création de `manifests/inline/{cilium,cert-manager,argocd}/`
   - Fichiers `.tpl` avec variables Terraform (`${cilium_version}`, `${kubeprism_port}`, etc.)
   - Pattern identique à roeldev/iac-talos-cluster

2. **Applications ArgoCD pour composants bootstrap** ✅
   - Ajout de `manifests/apps/{cilium,cert-manager,argocd}.yaml`
   - Gestion optionnelle post-bootstrap via ArgoCD
   - Permet updates sans recréer le cluster

3. **Fichier manifests-inline.tf** ✅
   - Utilise `templatefile()` pour générer YAML depuis TPL
   - Utilise `data.helm_template` pour rendre les charts Helm
   - Génère `output/inline-manifests.yaml` pour inspection
   - Centralise toute la génération des manifests inline

4. **Variables Terraform pour versions** ✅
   - Ajout de `cilium_version = "1.16.4"`
   - Ajout de `cert_manager_version = "1.19.1"`
   - Ajout de `argocd_version = "9.0.3"`
   - Annotations Renovate pour updates automatiques

5. **Refactoring talos.tf** ✅
   - Utilise maintenant les outputs de `manifests-inline.tf`
   - Références claires vers les fichiers TPL sources
   - Commentaires explicatifs

6. **Manifests Kustomize pour ArgoCD** ✅
   - Structure complète pour Cilium avec L2 announcements
   - Structure complète pour cert-manager avec ClusterIssuers
   - Structure complète pour ArgoCD avec certificat TLS
   - Tous prêts pour gestion via ArgoCD

7. **Documentation complète** ✅
   - README exhaustif dans `manifests/README.md`
   - Explications détaillées du pattern TPL
   - Workflows complets
   - Troubleshooting guides

8. **Nettoyage** ✅
   - Suppression des anciens fichiers `{cilium,cert-manager,argocd,gitea,trust-manager,reloader}.tf`
   - Tout consolidé dans `manifests-inline.tf`

## 🏗️ Architecture

### Avant (Monolithique)

```
Terraform
  ├── cilium.tf
  ├── cert-manager.tf
  ├── argocd.tf
  ├── gitea.tf
  ├── trust-manager.tf
  └── reloader.tf
      ↓
  Tous deployés comme inlineManifests
  Pas de GitOps
  Difficile à maintenir
```

### Après (GitOps + TPL)

```
Terraform
  ├── manifests-inline.tf (génère inline manifests depuis TPL)
  │   └── templatefile(manifests/inline/*/kustomization.yaml.tpl)
  │       └── data.helm_template (render Helm charts)
  │           └── inlineManifests (Talos)
  │
  └── manifests-bootstrap.tf (deploy app-root)
      └── app-root.yaml (ArgoCD App of Apps)
          └── manifests/apps/*.yaml (Applications)
              └── manifests/{app}/ (Kustomize + Helm)

Dual Strategy:
  1. Inline (bootstrap): Cilium, cert-manager, ArgoCD
  2. ArgoCD (managed): Toutes les apps (y compris optionnellement bootstrap)
```

## 📁 Structure des fichiers

### Nouveaux fichiers créés

```
manifests/
├── inline/                          # 🆕 TPL templates pour bootstrap
│   ├── cilium/
│   │   ├── kustomization.yaml.tpl
│   │   └── values.yaml.tpl
│   ├── cert-manager/
│   │   ├── kustomization.yaml.tpl
│   │   ├── values.yaml.tpl
│   │   └── namespace.yaml
│   └── argocd/
│       ├── kustomization.yaml.tpl
│       ├── values.yaml.tpl
│       └── namespace.yaml
│
├── apps/                            # 🆕 ArgoCD Apps pour composants bootstrap
│   ├── cilium.yaml
│   ├── cert-manager.yaml
│   └── argocd.yaml
│
├── cilium/                          # 🆕 Kustomize pour Cilium ArgoCD-managed
│   ├── kustomization.yaml
│   ├── values.yaml
│   ├── l2-announcement-policy.yaml
│   └── lb-ip-pool.yaml
│
├── cert-manager-argocd/             # 🆕 Kustomize pour cert-manager ArgoCD-managed
│   ├── kustomization.yaml
│   ├── namespace.yaml
│   ├── values.yaml
│   ├── cluster-issuer-selfsigned.yaml
│   ├── certificate-ingress.yaml
│   └── cluster-issuer-ingress.yaml
│
└── argocd-managed/                  # 🆕 Kustomize pour ArgoCD ArgoCD-managed
    ├── kustomization.yaml
    ├── namespace.yaml
    ├── values.yaml
    └── certificate.yaml

Terraform:
├── manifests-inline.tf              # 🆕 Génération manifests inline avec TPL
└── variables.tf                     # 🔄 Modifié (ajout cilium_version, etc.)
```

### Fichiers modifiés

```
talos.tf                             # 🔄 Utilise maintenant manifests-inline.tf
manifests/README.md                  # 🔄 Documentation complète mise à jour
```

### Fichiers supprimés

```
cilium.tf                            # ❌ Consolidé dans manifests-inline.tf
cert-manager.tf                      # ❌ Consolidé dans manifests-inline.tf
argocd.tf                            # ❌ Consolidé dans manifests-inline.tf
gitea.tf                             # ❌ Supprimé (plus d'inline manifest)
trust-manager.tf                     # ❌ Supprimé (plus d'inline manifest)
reloader.tf                          # ❌ Supprimé (plus d'inline manifest)
```

## 🔥 Innovation clé : Fichiers TPL

### Concept

Inspiré de roeldev/iac-talos-cluster, utilisation de **template files (.tpl)** avec la fonction Terraform `templatefile()`.

### Exemple : Cilium

**Avant** (hard-coded):
```hcl
# cilium.tf
data "helm_template" "cilium" {
  version = "1.16.4"  # ← Version hard-coded
  # ...
}
```

**Après** (TPL):
```yaml
# manifests/inline/cilium/kustomization.yaml.tpl
helmCharts:
  - name: cilium
    version: ${cilium_version}  # ← Variable Terraform
```

```hcl
# manifests-inline.tf
resource "local_file" "cilium_kustomization" {
  content = templatefile("manifests/inline/cilium/kustomization.yaml.tpl", {
    cilium_version = var.cilium_version  # ← Depuis variables.tf
  })
}
```

```hcl
# variables.tf
variable "cilium_version" {
  default = "1.16.4"
  # renovate: datasource=helm depName=cilium registryUrl=https://helm.cilium.io
}
```

### Avantages

1. **DRY**: Une seule source de vérité pour les versions
2. **Type Safety**: Validation Terraform
3. **Renovate**: Updates automatiques avec annotations
4. **Environnements**: Différentes valeurs par environment
5. **Lisibilité**: Séparation template/logique

## 🎯 Dual Strategy : Inline + ArgoCD

### 1. Inline Manifests (Bootstrap)

**Quoi**: Cilium, cert-manager, ArgoCD  
**Quand**: Création du cluster Talos  
**Comment**: inlineManifests dans machine config  
**Pourquoi**: Chicken-and-egg problem (CNI requis pour networking)

### 2. ArgoCD Applications (Ongoing)

**Quoi**: Toutes les apps (gitea, trust-manager, reloader) + optionnellement bootstrap  
**Quand**: Après cluster ready  
**Comment**: GitOps via ArgoCD sync depuis Git  
**Pourquoi**: GitOps workflow, auto-sync, self-healing

### Bootstrap Components en double ?

**Oui !** Les composants bootstrap (Cilium, cert-manager, ArgoCD) peuvent être gérés par:
1. **Inline** (requis): Version initiale déployée au bootstrap
2. **ArgoCD** (optionnel): Gestion ongoing, updates sans recreate cluster

**Use case**:
- Inline assure disponibilité même si ArgoCD fail
- ArgoCD permet updates de config via Git
- Best of both worlds

## 🚀 Workflow de déploiement

### Déploiement initial

```bash
# 1. Configurer les versions
vim variables.tf
# cilium_version = "1.16.4"
# cert_manager_version = "1.19.1"
# argocd_version = "9.0.3"

# 2. Terraform plan/apply
terraform plan
terraform apply

# Résultat:
# ✅ Cluster Talos créé
# ✅ Cilium, cert-manager, ArgoCD déployés (inline depuis TPL)
# ✅ app-root déployé (ArgoCD App of Apps)
# ✅ Toutes les apps synchronisées par ArgoCD
```

### Update version d'un composant inline

```bash
# 1. Modifier variables.tf
vim variables.tf
# cilium_version = "1.16.5"

# 2. Régénérer et appliquer
terraform plan
terraform apply

# Résultat:
# ✅ TPL régénérés avec nouvelle version
# ✅ Nouveaux manifests générés
# ✅ Talos config updated (peut nécessiter recréation cluster)
```

### Update application ArgoCD-managed

```bash
# 1. Modifier manifest
vim manifests/gitea/kustomization.yaml
# version: 11.0.1

# 2. Commit et push
git add manifests/gitea/kustomization.yaml
git commit -m "feat: upgrade Gitea to 11.0.1"
git push

# Résultat:
# ✅ ArgoCD détecte changement
# ✅ Sync automatique (ou manuel via UI)
# ✅ Application mise à jour
```

## 📊 Comparaison Avant/Après

| Aspect | Avant | Après |
|--------|-------|-------|
| **Architecture** | Monolithique | GitOps + TPL |
| **Gestion versions** | Hard-coded dans TF | Variables + TPL |
| **Updates apps** | Recréer cluster | Git commit → ArgoCD sync |
| **Observabilité** | kubectl only | ArgoCD UI + kubectl |
| **Rollback** | Compliqué | Git revert |
| **Self-healing** | Non | Oui (ArgoCD) |
| **Separation of Concerns** | Non | Oui (inline vs managed) |
| **Templating** | Non | Oui (TPL files) |
| **Renovate** | Partiel | Complet avec annotations |

## 🎓 Inspirations et références

### Projet source : roeldev/iac-talos-cluster

**Ce qu'on a adopté**:
- ✅ Fichiers TPL avec `templatefile()`
- ✅ Structure `manifests/inline/` pour bootstrap
- ✅ Génération Kustomize depuis TPL
- ✅ Pattern `manifests-inline.tf`

**Ce qu'on a adapté**:
- 🔄 vSphere au lieu de Proxmox
- 🔄 App of Apps pattern renforcé
- 🔄 Dual strategy (inline + ArgoCD pour bootstrap)
- 🔄 Documentation exhaustive en français

### Liens

- [roeldev/iac-talos-cluster](https://github.com/roeldev/iac-talos-cluster)
- [Talos Linux](https://www.talos.dev/)
- [ArgoCD](https://argo-cd.readthedocs.io/)
- [Kustomize](https://kustomize.io/)
- [Terraform templatefile](https://www.terraform.io/language/functions/templatefile)

## ⚠️ Points d'attention

### Avant déploiement

1. **URLs Git**: Mettre à jour les `repoURL` dans `manifests/apps/*.yaml`
   ```bash
   find manifests/apps -name "*.yaml" -exec sed -i 's|clemcreator|YOUR_ORG|g' {} +
   ```

2. **Domaines**: Mettre à jour `example.test` dans certificats et values
   ```bash
   find manifests -name "*.yaml" -exec sed -i 's|example.test|your.domain|g' {} +
   ```

3. **IPs LoadBalancer**: Ajuster dans `manifests/cilium/lb-ip-pool.yaml`
   ```yaml
   spec:
     blocks:
       - start: 10.17.3.130  # ← Adapter à votre réseau
         stop: 10.17.3.230
   ```

4. **Validation**: Exécuter le script de validation
   ```bash
   ./validate.sh
   ```

### Après déploiement

1. **Vérifier inline manifests**:
   ```bash
   kubectl get pods -n kube-system      # Cilium
   kubectl get pods -n cert-manager     # cert-manager
   kubectl get pods -n argocd           # ArgoCD
   ```

2. **Vérifier ArgoCD**:
   ```bash
   kubectl get applications -n argocd
   # Tous les apps doivent être "Healthy" et "Synced"
   ```

3. **Accéder à ArgoCD UI**:
   ```bash
   kubectl port-forward -n argocd svc/argocd-server 8080:443
   # https://localhost:8080
   # user: admin
   # pass: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
   ```

## 🏆 Résultat final

Une architecture **moderne**, **maintenable** et **scalable**:

✅ **Fichiers TPL** pour configuration dynamique (comme roeldev)  
✅ **Dual strategy** inline + ArgoCD pour robustesse  
✅ **GitOps workflow** avec synchronisation automatique  
✅ **Self-healing** via ArgoCD  
✅ **Versioning centralisé** dans Terraform variables  
✅ **Documentation exhaustive** pour maintenance  
✅ **Separation of Concerns** claire  
✅ **Renovate-ready** avec annotations  
✅ **Production-ready** avec best practices  

## 📞 Support

Pour toute question ou problème:
1. Consulter `manifests/README.md` pour workflows détaillés
2. Vérifier les logs: `kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller`
3. Inspecter les manifests générés: `cat output/inline-manifests.yaml`
4. Exécuter validation: `./validate.sh`

---

**Auteur**: Clément  
**Date**: 28 octobre 2025  
**Version**: 1.0.0  
**Status**: ✅ Production Ready
