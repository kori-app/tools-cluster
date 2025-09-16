#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Setting up Tools Kubernetes Cluster${NC}"
echo ""

# Check prerequisites
echo "🔍 Checking prerequisites..."

if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ kubectl is not installed${NC}"
    exit 1
fi

if ! command -v helm &> /dev/null; then
    echo -e "${RED}❌ helm is not installed${NC}"
    exit 1
fi

if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}❌ Cannot access Kubernetes cluster${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Prerequisites check passed${NC}"
echo ""

# Install NGINX Ingress Controller
echo "🔧 Installing NGINX Ingress Controller..."
helm upgrade --install ingress-nginx ingress-nginx \
  --repo https://kubernetes.github.io/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --wait

echo -e "${GREEN}✅ NGINX Ingress Controller installed${NC}"

# Install Cert-Manager
echo "🔐 Installing Cert-Manager..."
helm upgrade --install cert-manager cert-manager \
  --repo https://charts.jetstack.io \
  --namespace cert-manager --create-namespace \
  --set installCRDs=true \
  --wait

# Create Let's Encrypt ClusterIssuer
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@your-domain.com # Change this
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF

echo -e "${GREEN}✅ Cert-Manager installed${NC}"

# Create namespaces
echo "📁 Creating namespaces..."
kubectl apply -f ../k8s/namespaces/

# Deploy Backstage
echo "🎭 Deploying Backstage..."
kubectl apply -f ../k8s/backstage/

# Deploy monitoring stack
echo "📊 Setting up monitoring..."

# Add Prometheus Helm repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install Prometheus + Grafana
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --set grafana.ingress.enabled=true \
  --set grafana.ingress.ingressClassName=nginx \
  --set grafana.ingress.hosts[0]=grafana.your-domain.com \
  --set grafana.ingress.tls[0].secretName=grafana-tls \
  --set grafana.ingress.tls[0].hosts[0]=grafana.your-domain.com \
  --set grafana.ingress.annotations."cert-manager\.io/cluster-issuer"=letsencrypt-prod \
  --wait

echo -e "${GREEN}✅ Monitoring stack deployed${NC}"

# Deploy ArgoCD
echo "🔄 Deploying ArgoCD..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# Install ArgoCD
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  --set server.ingress.enabled=true \
  --set server.ingress.ingressClassName=nginx \
  --set server.ingress.hosts[0]=argocd.your-domain.com \
  --set server.ingress.tls[0].secretName=argocd-tls \
  --set server.ingress.tls[0].hosts[0]=argocd.your-domain.com \
  --set server.ingress.annotations."cert-manager\.io/cluster-issuer"=letsencrypt-prod \
  --set server.ingress.annotations."nginx\.ingress\.kubernetes\.io/force-ssl-redirect"="true" \
  --set server.ingress.annotations."nginx\.ingress\.kubernetes\.io/ssl-passthrough"="true" \
  --wait

echo -e "${GREEN}✅ ArgoCD deployed${NC}"

# Wait for deployments
echo "⏳ Waiting for deployments to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/backstage -n backstage
kubectl wait --for=condition=available --timeout=300s deployment/postgres -n backstage

# Get ArgoCD admin password
echo ""
echo "🔐 Getting ArgoCD admin password..."
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

# Get load balancer IP
echo "🌐 Getting load balancer IP..."
INGRESS_IP=$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Display results
echo ""
echo -e "${GREEN}🎉 Tools cluster setup complete!${NC}"
echo ""
echo -e "${YELLOW}📋 Important Information:${NC}"
echo ""
echo -e "${BLUE}Load Balancer IP:${NC} ${INGRESS_IP}"
echo -e "${BLUE}DNS Configuration:${NC} Point your domain records to ${INGRESS_IP}"
echo ""
echo -e "${BLUE}Services:${NC}"
echo "• Backstage: https://backstage.your-domain.com"
echo "• ArgoCD: https://argocd.your-domain.com"
echo "• Grafana: https://grafana.your-domain.com"
echo ""
echo -e "${BLUE}Credentials:${NC}"
echo "• ArgoCD admin password: ${ARGOCD_PASSWORD}"
echo "• Grafana: admin/prom-operator"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Update your DNS records to point to ${INGRESS_IP}"
echo "2. Run: ./configure-google-oauth.sh (if not done already)"
echo "3. Wait for SSL certificates to be issued (5-10 minutes)"
echo "4. Access your services!"
echo ""
echo -e "${GREEN}✅ Setup complete!${NC}"