# 🔧 Guide de résolution - Problèmes ArgoCD

## ✅ Problèmes corrigés

### 1. Kubeconfig inexistant pendant terraform apply
**✅ RÉSOLU** - Le script crée maintenant le kubeconfig depuis Terraform

### 2. Applications manquantes (cilium, cert-manager, argocd)
**✅ RÉSOLU** - Ajoutées dans `manifests/apps/kustomization.yaml`

### 3. Erreur "must specify --enable-helm"
**✅ RÉSOLU** - Configuration ArgoCD mise à jour

---

## 🚀 Actions à effectuer MAINTENANT

### Étape 1: Régénérer les manifests inline avec la nouvelle config

```bash
cd /home/clement/dev/terraform-vsphere-talos

# Régénérer les manifests ArgoCD avec --enable-helm
terraform apply -target=local_file.argocd_values -target=local_file.argocd_kustomization
```

### Étape 2: Mettre à jour ArgoCD dans le cluster

```bash
# Se connecter au cluster
export KUBECONFIG=$(pwd)/kubeconfig.yml

# Appliquer la nouvelle configuration ArgoCD
# Option A: Via Terraform (recommandé - recreate cluster)
terraform taint talos_machine_configuration_apply.controller[0]
terraform apply

# Option B: Via kubectl (patch à chaud - plus rapide)
kubectl patch configmap argocd-cm -n argocd \
  --type merge \
  -p '{"data":{"kustomize.buildOptions":"--enable-helm"}}'

# Redémarrer le repo-server pour prendre en compte la nouvelle config
kubectl rollout restart deployment argocd-repo-server -n argocd
kubectl rollout status deployment argocd-repo-server -n argocd

# Redémarrer aussi le application-controller
kubectl rollout restart statefulset argocd-application-controller -n argocd
kubectl rollout status statefulset argocd-application-controller -n argocd
```

### Étape 3: Forcer la re-synchronisation des applications

```bash
# Supprimer et recréer app-root pour forcer un refresh
kubectl delete -f manifests/bootstrap/app-root.yaml
sleep 5
kubectl apply -f manifests/bootstrap/app-root.yaml

# Ou forcer manuellement chaque app à sync
kubectl patch application gitea -n argocd \
  --type merge \
  -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'

kubectl patch application trust-manager -n argocd \
  --type merge \
  -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'

kubectl patch application reloader -n argocd \
  --type merge \
  -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
```

### Étape 4: Vérifier le statut

```bash
# Attendre quelques secondes pour la synchronisation
sleep 10

# Vérifier toutes les applications
kubectl get applications -n argocd

# Devrait afficher quelque chose comme:
# NAME            SYNC STATUS   HEALTH STATUS
# app-root        Synced        Healthy
# gitea           Synced        Healthy
# reloader        Synced        Healthy
# trust-manager   Synced        Healthy
```

---

## 🔍 Vérifications détaillées

### Vérifier la configuration ArgoCD

```bash
# Vérifier que --enable-helm est bien configuré
kubectl get configmap argocd-cm -n argocd -o yaml | grep -A2 kustomize

# Devrait afficher:
# kustomize.buildOptions: --enable-helm
```

### Vérifier une application spécifique

```bash
# Voir les détails d'une application
kubectl describe application gitea -n argocd

# Voir les logs du repo-server (pour debug)
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-repo-server --tail=50

# Voir les logs du application-controller
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller --tail=50
```

### Tester manuellement Kustomize avec Helm

```bash
# Aller dans un des manifests
cd manifests/gitea

# Tester la génération avec kustomize
kustomize build --enable-helm .

# Si ça fonctionne, c'est bon !
```

---

## 🎯 Solution rapide (Option B recommandée)

Si vous voulez éviter de recréer le cluster, voici la séquence complète:

```bash
#!/bin/bash
set -e

cd /home/clement/dev/terraform-vsphere-talos
export KUBECONFIG=$(pwd)/kubeconfig.yml

echo "=== Étape 1: Patcher la config ArgoCD ==="
kubectl patch configmap argocd-cm -n argocd \
  --type merge \
  -p '{"data":{"kustomize.buildOptions":"--enable-helm"}}'

echo "=== Étape 2: Redémarrer ArgoCD components ==="
kubectl rollout restart deployment argocd-repo-server -n argocd
kubectl rollout restart statefulset argocd-application-controller -n argocd
kubectl rollout restart deployment argocd-server -n argocd

echo "=== Étape 3: Attendre que tout soit prêt ==="
kubectl wait --for=condition=Ready pod -n argocd -l app.kubernetes.io/name=argocd-repo-server --timeout=120s
kubectl wait --for=condition=Ready pod -n argocd -l app.kubernetes.io/name=argocd-application-controller --timeout=120s

echo "=== Étape 4: Recréer app-root ==="
kubectl delete application app-root -n argocd --ignore-not-found
sleep 5
kubectl apply -f manifests/bootstrap/app-root.yaml

echo "=== Étape 5: Attendre la synchronisation ==="
sleep 15

echo "=== Étape 6: Vérifier le statut ==="
kubectl get applications -n argocd

echo ""
echo "✅ Configuration mise à jour !"
echo "Vérifiez que toutes les applications sont 'Synced' et 'Healthy'"
```

Copiez ce script dans un fichier et exécutez-le:

```bash
# Sauvegarder le script
cat > fix-argocd.sh << 'SCRIPT'
#!/bin/bash
set -e

cd /home/clement/dev/terraform-vsphere-talos
export KUBECONFIG=$(pwd)/kubeconfig.yml

echo "=== Étape 1: Patcher la config ArgoCD ==="
kubectl patch configmap argocd-cm -n argocd \
  --type merge \
  -p '{"data":{"kustomize.buildOptions":"--enable-helm"}}'

echo "=== Étape 2: Redémarrer ArgoCD components ==="
kubectl rollout restart deployment argocd-repo-server -n argocd
kubectl rollout restart statefulset argocd-application-controller -n argocd
kubectl rollout restart deployment argocd-server -n argocd

echo "=== Étape 3: Attendre que tout soit prêt ==="
kubectl wait --for=condition=Ready pod -n argocd -l app.kubernetes.io/name=argocd-repo-server --timeout=120s
kubectl wait --for=condition=Ready pod -n argocd -l app.kubernetes.io/name=argocd-application-controller --timeout=120s

echo "=== Étape 4: Recréer app-root ==="
kubectl delete application app-root -n argocd --ignore-not-found
sleep 5
kubectl apply -f manifests/bootstrap/app-root.yaml

echo "=== Étape 5: Attendre la synchronisation ==="
sleep 15

echo "=== Étape 6: Vérifier le statut ==="
kubectl get applications -n argocd

echo ""
echo "✅ Configuration mise à jour !"
echo "Vérifiez que toutes les applications sont 'Synced' et 'Healthy'"
SCRIPT

# Rendre exécutable
chmod +x fix-argocd.sh

# Exécuter
./fix-argocd.sh
```

---

## 📊 Statut attendu après correction

```
NAME            SYNC STATUS   HEALTH STATUS
app-root        Synced        Healthy
gitea           Synced        Healthy (ou Progressing pendant le déploiement)
reloader        Synced        Healthy
trust-manager   Synced        Healthy
```

---

## 🆘 Si ça ne fonctionne toujours pas

### Vérifier les logs en détail

```bash
# Logs du repo-server (celui qui fait kustomize build)
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-repo-server --tail=100 -f

# Logs du controller (celui qui applique les manifests)
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller --tail=100 -f
```

### Vérifier qu'une application peut être buildée

```bash
# Port-forward vers le repo-server
kubectl port-forward -n argocd svc/argocd-repo-server 8081:8081 &

# Tester manuellement (nécessite curl + jq)
# Vérifier que gitea peut être buildé
```

### Redéployer ArgoCD complètement

Si vraiment rien ne fonctionne, recréez le cluster avec la nouvelle config:

```bash
# Commit les changements
git add manifests/inline/argocd/values.yaml.tpl manifests/argocd-managed/values.yaml
git commit -m "fix: add --enable-helm to ArgoCD kustomize build options"
git push origin main

# Détruire et recréer
terraform destroy -auto-approve
./do init
./do plan-apply
```

---

## ✨ Résumé

**Problème**: ArgoCD ne pouvait pas builder les manifests Kustomize avec Helm charts

**Solution**: Ajouter `kustomize.buildOptions: --enable-helm` dans la configuration ArgoCD

**Action immédiate**: Exécuter le script `fix-argocd.sh` ci-dessus

---

**Exécutez le script fix-argocd.sh et tout devrait fonctionner ! 🎉**
