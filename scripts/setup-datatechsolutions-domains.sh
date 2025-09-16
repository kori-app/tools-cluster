#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# DataTechSolutions domains
BACKSTAGE_DOMAIN="backstage.tools.datatechsolutions.com.br"
GRAFANA_DOMAIN="grafana.tools.datatechsolutions.com.br"
ARGOCD_DOMAIN="argocd.tools.datatechsolutions.com.br"
ADMIN_EMAIL="admin@datatechsolutions.com.br"

echo -e "${BLUE}🚀 Setting up DataTechSolutions Tools Cluster${NC}"
echo ""
echo "Domains:"
echo "• Backstage: https://${BACKSTAGE_DOMAIN}"
echo "• Grafana: https://${GRAFANA_DOMAIN}"
echo "• ArgoCD: https://${ARGOCD_DOMAIN}"
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

# Create Let's Encrypt ClusterIssuer for DataTechSolutions
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: ${ADMIN_EMAIL}
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
kubectl create namespace backstage --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# Update Backstage ConfigMap with DataTechSolutions domains
echo "🎭 Creating Backstage configuration for DataTechSolutions..."

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: backstage-config
  namespace: backstage
data:
  app-config.yaml: |
    app:
      title: DataTechSolutions Developer Portal
      baseUrl: https://${BACKSTAGE_DOMAIN}
      support:
        url: https://github.com/kori-app/seller-project/issues
        items:
          - title: Issues
            icon: github
            links:
              - url: https://github.com/kori-app/seller-project/issues
                title: GitHub Issues

    organization:
      name: DataTechSolutions

    backend:
      baseUrl: https://${BACKSTAGE_DOMAIN}
      listen:
        port: 7007
        host: 0.0.0.0
      csp:
        connect-src: ["'self'", 'http:', 'https:']
      cors:
        origin: https://${BACKSTAGE_DOMAIN}
        methods: [GET, HEAD, PATCH, POST, PUT, DELETE]
        credentials: true
      database:
        client: pg
        connection:
          host: postgres
          port: 5432
          user: \${POSTGRES_USER}
          password: \${POSTGRES_PASSWORD}
          database: \${POSTGRES_DB}

    integrations:
      github:
        - host: github.com
          token: \${GITHUB_TOKEN}

    auth:
      providers:
        google:
          development:
            clientId: \${GOOGLE_CLIENT_ID}
            clientSecret: \${GOOGLE_CLIENT_SECRET}
          production:
            clientId: \${GOOGLE_CLIENT_ID}
            clientSecret: \${GOOGLE_CLIENT_SECRET}

    scaffolder:
      defaultAuthor:
        name: DataTechSolutions Team
        email: team@datatechsolutions.com.br
      defaultCommitMessage: 'Initial commit from Backstage template'

    catalog:
      import:
        entityFilename: catalog-info.yaml
        pullRequestBranchName: backstage-integration
      rules:
        - allow: [Component, System, API, Resource, Location, User, Group]
      locations:
        # Seller Project Services
        - type: url
          target: https://github.com/kori-app/seller-project/blob/main/backstage/catalog/seller-project.yaml
        - type: url
          target: https://github.com/kori-app/seller-project/blob/main/backstage/catalog/seller-dashboard.yaml
        - type: url
          target: https://github.com/kori-app/seller-project/blob/main/backstage/catalog/seller-service.yaml

    kubernetes:
      serviceLocatorMethod:
        type: 'multiTenant'
      clusterLocatorMethods:
        - type: 'config'
          clusters:
            - url: https://kubernetes.default.svc
              name: datatechsolutions-tools
              authProvider: 'serviceAccount'
              skipTLSVerify: false
              skipMetricsLookup: false

    proxy:
      '/prometheus/api':
        target: 'http://kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090/api/v1/'
        allowedMethods: ['GET']
      '/grafana/api':
        target: 'http://kube-prometheus-stack-grafana.monitoring.svc.cluster.local:80/'
        allowedMethods: ['GET']
      '/argocd/api':
        target: 'http://argocd-server.argocd.svc.cluster.local:80/'
        allowedMethods: ['GET']

    techdocs:
      builder: 'local'
      generator:
        runIn: 'docker'
      publisher:
        type: 'local'

    lighthouse:
      baseUrl: https://${BACKSTAGE_DOMAIN}/lighthouse-api

    enabled:
      kubernetes: true
      prometheus: true
      grafana: true
      argocd: true
      techdocs: true
EOF

# Deploy Backstage
echo "🎭 Deploying Backstage..."
kubectl apply -f ../k8s/backstage/deployment.yaml

# Create Backstage Ingress with DataTechSolutions domain
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: backstage-ingress
  namespace: backstage
  annotations:
    kubernetes.io/ingress.class: "nginx"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/proxy-body-size: "50m"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "3600"
spec:
  tls:
  - hosts:
    - ${BACKSTAGE_DOMAIN}
    secretName: backstage-tls
  rules:
  - host: ${BACKSTAGE_DOMAIN}
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: backstage
            port:
              number: 80
EOF

# Deploy monitoring stack with DataTechSolutions domain
echo "📊 Setting up monitoring for DataTechSolutions..."

# Add Prometheus Helm repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install Prometheus + Grafana with DataTechSolutions domain
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --set grafana.ingress.enabled=true \
  --set grafana.ingress.ingressClassName=nginx \
  --set grafana.ingress.hosts[0]=${GRAFANA_DOMAIN} \
  --set grafana.ingress.tls[0].secretName=grafana-tls \
  --set grafana.ingress.tls[0].hosts[0]=${GRAFANA_DOMAIN} \
  --set grafana.ingress.annotations."cert-manager\.io/cluster-issuer"=letsencrypt-prod \
  --set grafana.ingress.annotations."nginx\.ingress\.kubernetes\.io/ssl-redirect"="true" \
  --set grafana.adminPassword="datatechsolutions2024" \
  --wait

echo -e "${GREEN}✅ Monitoring stack deployed${NC}"

# Deploy ArgoCD with DataTechSolutions domain
echo "🔄 Deploying ArgoCD..."

# Install ArgoCD
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  --set server.ingress.enabled=true \
  --set server.ingress.ingressClassName=nginx \
  --set server.ingress.hosts[0]=${ARGOCD_DOMAIN} \
  --set server.ingress.tls[0].secretName=argocd-tls \
  --set server.ingress.tls[0].hosts[0]=${ARGOCD_DOMAIN} \
  --set server.ingress.annotations."cert-manager\.io/cluster-issuer"=letsencrypt-prod \
  --set server.ingress.annotations."nginx\.ingress\.kubernetes\.io/force-ssl-redirect"="true" \
  --set server.ingress.annotations."nginx\.ingress\.kubernetes\.io/ssl-passthrough"="true" \
  --wait

echo -e "${GREEN}✅ ArgoCD deployed${NC}"

# Wait for deployments
echo "⏳ Waiting for deployments to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/backstage -n backstage || true
kubectl wait --for=condition=available --timeout=300s deployment/postgres -n backstage || true

# Get ArgoCD admin password
echo ""
echo "🔐 Getting ArgoCD admin password..."
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d 2>/dev/null || echo "Password will be available after ArgoCD is ready")

# Get load balancer IP
echo "🌐 Getting load balancer IP..."
echo "Waiting for load balancer to be ready..."
sleep 30
INGRESS_IP=$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "IP will be available shortly")

# Display results
echo ""
echo -e "${GREEN}🎉 DataTechSolutions Tools cluster setup complete!${NC}"
echo ""
echo -e "${YELLOW}📋 Important Information:${NC}"
echo ""
echo -e "${BLUE}Load Balancer IP:${NC} ${INGRESS_IP}"
echo ""
echo -e "${BLUE}DNS Configuration Required:${NC}"
echo "Add these A records to your datatechsolutions.com.br DNS:"
echo "• backstage.tools.datatechsolutions.com.br → ${INGRESS_IP}"
echo "• grafana.tools.datatechsolutions.com.br → ${INGRESS_IP}"
echo "• argocd.tools.datatechsolutions.com.br → ${INGRESS_IP}"
echo ""
echo -e "${BLUE}Services (will be available after DNS propagation):${NC}"
echo "• Backstage: https://${BACKSTAGE_DOMAIN}"
echo "• Grafana: https://${GRAFANA_DOMAIN}"
echo "• ArgoCD: https://${ARGOCD_DOMAIN}"
echo ""
echo -e "${BLUE}Credentials:${NC}"
echo "• Grafana: admin / datatechsolutions2024"
echo "• ArgoCD: admin / ${ARGOCD_PASSWORD}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Configure DNS records as shown above"
echo "2. Run: ./configure-google-oauth-datatechsolutions.sh"
echo "3. Wait for SSL certificates (5-10 minutes after DNS propagation)"
echo "4. Access your services!"
echo ""
echo -e "${GREEN}✅ Setup complete!${NC}"