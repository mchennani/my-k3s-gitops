#!/bin/bash

# --- Couleurs pour la visibilité ---
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${GREEN}--- Début de l'installation du Lab GitOps ---${NC}"

# 1. Installation de K3s (sans le LoadBalancer par défaut)
echo -e "${GREEN}1. Installation de K3s...${NC}"
curl -sfL https://get.k3s.io | sh -s - --disable servicelb
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# Attente que le noeud soit prêt
sleep 20

# 2. Installation de Helm
echo -e "${GREEN}2. Installation de Helm...${NC}"
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# 3. Ajout des dépôts Helm
echo -e "${GREEN}3. Ajout des dépôts Helm...${NC}"
helm repo add metallb https://metallb.github.io/metallb
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# 4. Installation de MetalLB
echo -e "${GREEN}4. Installation de MetalLB...${NC}"
helm install metallb metallb/metallb -n metallb-system --create-namespace

# --- 4b. CONFIGURATION AUTOMATIQUE DE L'IP ---
echo -e "${GREEN}4b. Configuration de l'IP 192.168.1.200...${NC}"
sleep 30 # On attend que MetalLB soit prêt à recevoir la config

cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: first-pool
  namespace: metallb-system
spec:
  addresses:
  - 192.168.1.200-192.168.1.200
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: advertisement
  namespace: metallb-system
EOF

# 5. Installation d'Ingress-Nginx
echo -e "${GREEN}5. Installation d'Ingress-Nginx...${NC}"
helm install ingress-nginx ingress-nginx/ingress-nginx -n ingress-nginx --create-namespace

# 6. Installation d'ArgoCD
echo -e "${GREEN}6. Installation d'ArgoCD...${NC}"
helm install argocd argo/argo-cd -n argocd --create-namespace

echo -e "${GREEN}--- Installation terminée ! ---${NC}"
echo "------------------------------------------------"
echo "Récupère le mot de passe admin ArgoCD avec :"
echo "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
echo "------------------------------------------------"
