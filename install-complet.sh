#!/bin/bash

# --- Couleurs ---
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${GREEN}--- Installation du Lab GitOps Complet ---${NC}"

# 1. K3s
curl -sfL https://get.k3s.io | sh -s - --disable servicelb
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
sleep 20

# 2. Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# 3. Repos
helm repo add metallb https://metallb.github.io/metallb
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# 4. MetalLB + Config IP
helm install metallb metallb/metallb -n metallb-system --create-namespace
sleep 30
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

# 5. Ingress-Nginx
helm install ingress-nginx ingress-nginx/ingress-nginx -n ingress-nginx --create-namespace

# 6. ArgoCD + Insecure Mode (pour l'Ingress)
helm install argocd argo/argo-cd -n argocd --create-namespace \
  --set server.extraArgs={--insecure}

# 7. Ingress pour ArgoCD (argo.lab)
echo -e "${GREEN}Création de l'accès argo.lab...${NC}"
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server-ingress
  namespace: argocd
spec:
  ingressClassName: nginx
  rules:
  - host: argo.lab
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: argocd-server
            port:
              number: 80
EOF

echo -e "${GREEN}--- TERMINE ! ---${NC}"
echo "1. Ajoute '192.168.1.200 argo.lab app.lab blog.lab' à ton /etc/hosts"
echo "2. Accède à : http://argo.lab"
echo "3. Pass admin :"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo
