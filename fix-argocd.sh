#!/bin/bash
set -e

cd /home/clement/dev/terraform-vsphere-talos
export KUBECONFIG=$(pwd)/kubeconfig.yml

echo "=== Fix ArgoCD - Enable Helm support in Kustomize ==="
echo ""

echo "=== Étape 1: Patcher la config ArgoCD ==="
kubectl patch configmap argocd-cm -n argocd \
  --type merge \
  -p '{"data":{"kustomize.buildOptions":"--enable-helm"}}'
echo "✅ ConfigMap patché"
echo ""

echo "=== Étape 2: Redémarrer ArgoCD components ==="
kubectl rollout restart deployment argocd-repo-server -n argocd
kubectl rollout restart statefulset argocd-application-controller -n argocd
kubectl rollout restart deployment argocd-server -n argocd
echo "✅ Redémarrages lancés"
echo ""

echo "=== Étape 3: Attendre que tout soit prêt ==="
kubectl wait --for=condition=Ready pod -n argocd -l app.kubernetes.io/name=argocd-repo-server --timeout=120s
kubectl wait --for=condition=Ready pod -n argocd -l app.kubernetes.io/name=argocd-application-controller --timeout=120s
echo "✅ Pods prêts"
echo ""

echo "=== Étape 4: Recréer app-root ==="
kubectl delete application app-root -n argocd --ignore-not-found
echo "Attente 5 secondes..."
sleep 5
kubectl apply -f manifests/bootstrap/app-root.yaml
echo "✅ app-root recréé"
echo ""

echo "=== Étape 5: Attendre la synchronisation ==="
echo "Attente 15 secondes pour que les apps se synchronisent..."
sleep 15
echo ""

echo "=== Étape 6: Statut des applications ==="
kubectl get applications -n argocd
echo ""

echo "=============================================="
echo "✅ Configuration ArgoCD mise à jour !"
echo "=============================================="
echo ""
echo "Vérifiez que toutes les applications sont 'Synced' et 'Healthy'"
echo ""
echo "Pour voir les détails d'une application:"
echo "  kubectl describe application <app-name> -n argocd"
echo ""
echo "Pour accéder à l'UI ArgoCD:"
echo "  kubectl port-forward -n argocd svc/argocd-server 8080:443"
echo "  Password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
echo ""
