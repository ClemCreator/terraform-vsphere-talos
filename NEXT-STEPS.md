# 🚀 Next Steps - Actions requises

## ⚠️ Actions CRITIQUES avant déploiement

### 1. 📝 Mettre à jour les URLs Git

Les ArgoCD Applications pointent actuellement vers un placeholder. Mettez à jour avec votre repository:

```bash
# Remplacer clemcreator par votre organisation/username
find manifests/apps -name "*.yaml" -exec sed -i 's|clemcreator/terraform-vsphere-talos|YOUR_ORG/YOUR_REPO|g' {} +
find manifests/bootstrap -name "*.yaml" -exec sed -i 's|clemcreator/terraform-vsphere-talos|YOUR_ORG/YOUR_REPO|g' {} +
```

**Fichiers concernés**:
- `manifests/bootstrap/app-root.yaml`
- `manifests/apps/cilium.yaml`
- `manifests/apps/cert-manager.yaml`
- `manifests/apps/argocd.yaml`
- `manifests/apps/gitea.yaml`
- `manifests/apps/trust-manager.yaml`
- `manifests/apps/reloader.yaml`

### 2. 🌐 Mettre à jour les domaines

Remplacer `example.test` par votre domaine réel:

```bash
# Remplacer example.test par votre domaine
find manifests -name "*.yaml" -type f -exec sed -i 's|example\.test|your-domain.com|g' {} +
```

**Fichiers concernés**:
- `manifests/gitea/certificate.yaml`
- `manifests/gitea/values.yaml`
- `manifests/cert-manager-argocd/certificate-ingress.yaml`
- `manifests/argocd-managed/certificate.yaml`
- `manifests/argocd-managed/values.yaml`

### 3. 🌍 Ajuster les IPs du LoadBalancer

Si nécessaire, adapter la plage d'IPs dans:

```bash
vim manifests/cilium/lb-ip-pool.yaml
```

```yaml
spec:
  blocks:
    - start: 10.17.3.130  # ← Adapter à votre réseau
      stop: 10.17.3.230   # ← Adapter à votre réseau
```

### 4. ✅ Validation

Exécuter le script de validation:

```bash
./validate.sh
```

**Vérifications**:
- ✓ Structure des directories
- ✓ Fichiers manifests existants
- ✓ URLs Git configurées
- ✓ Domaines configurés
- ✓ Syntaxe YAML valide

## 📦 Workflow de déploiement

### Option A: Nouveau cluster (déploiement complet)

```bash
# 1. Vérifier la configuration
./validate.sh

# 2. Initialiser Terraform (si première fois)
terraform init

# 3. Planifier
terraform plan -out=tfplan

# 4. Vérifier le plan (important!)
less tfplan

# 5. Appliquer
terraform apply tfplan

# 6. Vérifier le cluster
export KUBECONFIG=$(pwd)/kubeconfig.yml

# Vérifier les composants inline (bootstrap)
kubectl get pods -n kube-system      # Cilium
kubectl get pods -n cert-manager     # cert-manager  
kubectl get pods -n argocd           # ArgoCD

# Vérifier app-root
kubectl get application app-root -n argocd

# Vérifier toutes les applications
kubectl get applications -n argocd
```

### Option B: Cluster existant (mise à jour)

```bash
# ⚠️ ATTENTION: Cette opération peut nécessiter la recréation du cluster
# car les inlineManifests font partie de la configuration Talos

# 1. Backup des configurations
cp talosconfig.yml talosconfig.yml.backup
cp kubeconfig.yml kubeconfig.yml.backup

# 2. Vérifier les changements
terraform plan

# 3. Identifier si recréation cluster nécessaire
# Si "must be replaced" sur talos_machine_configuration -> cluster sera recréé

# 4. Appliquer avec précaution
terraform apply

# 5. Récupérer nouveaux kubeconfig si cluster recréé
export KUBECONFIG=$(pwd)/kubeconfig.yml
```

## 🔍 Post-déploiement checks

### 1. Vérifier les inline manifests

```bash
# Cilium (CNI - critique!)
kubectl get pods -n kube-system -l k8s-app=cilium
kubectl get ciliuml2announcementpolicies -n kube-system
kubectl get ciliumloadbalanceripools -n kube-system

# cert-manager
kubectl get pods -n cert-manager
kubectl get clusterissuers
kubectl get certificates -A

# ArgoCD
kubectl get pods -n argocd
kubectl get application app-root -n argocd
```

### 2. Vérifier ArgoCD Applications

```bash
# Toutes les applications
kubectl get applications -n argocd

# Détails d'une application
kubectl describe application gitea -n argocd

# Status via CLI
argocd app list
argocd app get app-root
```

### 3. Accéder à ArgoCD UI

```bash
# Port-forward
kubectl port-forward -n argocd svc/argocd-server 8080:443

# Dans un autre terminal, récupérer le mot de passe
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo

# Ouvrir https://localhost:8080
# User: admin
# Password: celui récupéré ci-dessus
```

### 4. Tester un changement via GitOps

```bash
# 1. Modifier une application
vim manifests/gitea/values.yaml
# Exemple: changer replicaCount: 2

# 2. Commit et push
git add manifests/gitea/values.yaml
git commit -m "test: increase Gitea replicas to 2"
git push origin main

# 3. Observer dans ArgoCD UI ou CLI
argocd app sync gitea
argocd app wait gitea

# 4. Vérifier
kubectl get pods -n gitea
```

## 🔧 Troubleshooting rapide

### ArgoCD ne sync pas

```bash
# Vérifier le repository
argocd repo list

# Forcer une sync
argocd app sync app-root --prune

# Vérifier les logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller
```

### Inline manifests non appliqués

```bash
# Vérifier la config Talos
talosctl -n <CONTROLLER_IP> get machineconfig -o yaml | grep -A 100 inlineManifests

# Vérifier les manifests générés
cat output/inline-manifests.yaml

# Redémarrer le controller si nécessaire
talosctl -n <CONTROLLER_IP> reboot
```

### Erreurs de certificats

```bash
# Vérifier cert-manager
kubectl get certificates -A
kubectl describe certificate ingress -n cert-manager

# Vérifier les logs cert-manager
kubectl logs -n cert-manager -l app=cert-manager
```

### Cilium networking issues

```bash
# Status Cilium
kubectl exec -n kube-system ds/cilium -- cilium status

# Connectivity test
kubectl exec -n kube-system ds/cilium -- cilium connectivity test
```

## 📚 Documentation

- **Architecture complète**: `TPL-MIGRATION-COMPLETE.md`
- **Guide manifests**: `manifests/README.md`
- **Guide migration**: `MIGRATION-GUIDE.md`
- **Changelog**: `CHANGELOG.md`
- **Summary**: `SUMMARY.md`

## 🎯 Checklist finale

Avant de considérer le déploiement complet:

- [ ] URLs Git mises à jour dans tous les manifests
- [ ] Domaines mis à jour dans tous les certificats
- [ ] IPs LoadBalancer ajustées si nécessaire
- [ ] Script `./validate.sh` exécuté avec succès
- [ ] Terraform plan vérifié
- [ ] Backup talosconfig.yml et kubeconfig.yml
- [ ] Cluster déployé avec Terraform apply
- [ ] Inline manifests vérifiés (Cilium, cert-manager, ArgoCD)
- [ ] app-root déployé et healthy
- [ ] Toutes les applications ArgoCD synced
- [ ] ArgoCD UI accessible
- [ ] Test GitOps workflow (commit → sync → deploy)
- [ ] Documentation mise à jour si nécessaire

## 🎉 Success criteria

Le déploiement est réussi quand:

✅ **Cluster Talos** opérationnel  
✅ **Cilium** (CNI) running et healthy  
✅ **cert-manager** issuing certificates  
✅ **ArgoCD** running et accessible  
✅ **app-root** synced  
✅ **Toutes les applications** healthy et synced  
✅ **GitOps workflow** fonctionnel (commit → auto-sync)  
✅ **Ingress** accessible avec TLS  
✅ **LoadBalancer** IPs assignées  

## 💡 Pro Tips

1. **Utilisez Lens ou k9s** pour observabilité en temps réel
2. **Configurez ArgoCD notifications** (Slack, Discord, etc.)
3. **Activez ArgoCD Image Updater** pour auto-update des images
4. **Utilisez Sealed Secrets** pour secrets dans Git
5. **Configurez Renovate** pour auto-update des versions
6. **Backup régulier** de talosconfig et kubeconfig
7. **Monitoring** avec Prometheus + Grafana via ArgoCD
8. **GitOps everything** - évitez kubectl apply manuel

## 🆘 Besoin d'aide?

1. Consulter les logs: `kubectl logs -n <namespace> <pod>`
2. Vérifier events: `kubectl get events -n <namespace>`
3. ArgoCD UI pour status visuel
4. Documentation complète dans `manifests/README.md`
5. Terraform state: `terraform show`

---

**Bon déploiement! 🚀**
