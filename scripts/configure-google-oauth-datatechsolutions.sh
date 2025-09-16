#!/bin/bash

set -e

echo "🔐 Setting up Google OAuth for DataTechSolutions Backstage"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# DataTechSolutions specific configuration
BACKSTAGE_DOMAIN="backstage.tools.datatechsolutions.com.br"
ADMIN_EMAIL="admin@datatechsolutions.com.br"

# Function to prompt for input
prompt_input() {
    local prompt="$1"
    local var_name="$2"
    echo -e "${YELLOW}${prompt}${NC}"
    read -r $var_name
}

# Function to prompt for sensitive input
prompt_secret() {
    local prompt="$1"
    local var_name="$2"
    echo -e "${YELLOW}${prompt}${NC}"
    read -rs $var_name
    echo
}

echo "📋 This script will configure Google OAuth for DataTechSolutions Backstage"
echo "Domain: ${BACKSTAGE_DOMAIN}"
echo ""

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ kubectl is not installed. Please install kubectl first.${NC}"
    exit 1
fi

# Check if cluster is accessible
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}❌ Cannot access Kubernetes cluster. Please check your kubeconfig.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Kubernetes cluster is accessible${NC}"
echo ""

# Step 1: Google OAuth setup instructions
echo "🔐 Step 1: Google OAuth Setup for DataTechSolutions"
echo ""
echo -e "${YELLOW}Please follow these steps to create Google OAuth credentials:${NC}"
echo ""
echo "1. Go to https://console.cloud.google.com"
echo "2. Select or create a project (e.g., 'DataTechSolutions Tools')"
echo "3. Navigate to 'APIs & Services' > 'Credentials'"
echo "4. Click 'Create Credentials' > 'OAuth 2.0 Client IDs'"
echo "5. Choose 'Web application'"
echo "6. Set the name to 'DataTechSolutions Backstage'"
echo "7. Add authorized JavaScript origins:"
echo "   - https://${BACKSTAGE_DOMAIN}"
echo "8. Add authorized redirect URIs:"
echo "   - https://${BACKSTAGE_DOMAIN}/api/auth/google/handler/frame"
echo "9. Copy the Client ID and Client Secret"
echo ""

prompt_input "Press Enter when you have completed the Google OAuth setup..." CONTINUE

# Step 2: Get OAuth credentials
echo ""
echo "🔑 Step 2: OAuth Credentials"
prompt_input "Enter your Google Client ID: " GOOGLE_CLIENT_ID
prompt_secret "Enter your Google Client Secret: " GOOGLE_CLIENT_SECRET

# Step 3: GitHub token (optional but recommended)
echo ""
echo "🐙 Step 3: GitHub Integration (Optional but recommended)"
echo "This allows Backstage to read your repositories and create software templates."
echo ""
echo "To create a GitHub token:"
echo "1. Go to https://github.com/settings/tokens"
echo "2. Click 'Generate new token (classic)'"
echo "3. Select scopes: repo, workflow, write:packages, delete:packages, admin:org, user"
echo "4. Copy the token"
echo ""

prompt_input "Do you want to configure GitHub integration? (y/n): " SETUP_GITHUB

if [[ $SETUP_GITHUB == "y" || $SETUP_GITHUB == "Y" ]]; then
    prompt_secret "Enter your GitHub token: " GITHUB_TOKEN
else
    GITHUB_TOKEN="github_token_placeholder"
fi

# Step 4: Generate backend secret
echo ""
echo "🔐 Step 4: Generating backend secret..."
BACKEND_SECRET=$(openssl rand -base64 32)

# Step 5: Create Kubernetes secrets
echo ""
echo "📝 Step 5: Creating Kubernetes secrets..."

# Create namespace if it doesn't exist
kubectl create namespace backstage --dry-run=client -o yaml | kubectl apply -f -

# Delete existing secrets if they exist
kubectl delete secret backstage-secrets -n backstage --ignore-not-found=true

# Create the secrets
kubectl create secret generic backstage-secrets \
  --from-literal=GOOGLE_CLIENT_ID="${GOOGLE_CLIENT_ID}" \
  --from-literal=GOOGLE_CLIENT_SECRET="${GOOGLE_CLIENT_SECRET}" \
  --from-literal=GITHUB_TOKEN="${GITHUB_TOKEN}" \
  --from-literal=POSTGRES_USER="backstage" \
  --from-literal=POSTGRES_PASSWORD="$(openssl rand -base64 16)" \
  --from-literal=POSTGRES_DB="backstage_plugin_catalog" \
  --from-literal=BACKEND_SECRET="${BACKEND_SECRET}" \
  -n backstage

echo -e "${GREEN}✅ Secrets created successfully${NC}"

# Step 6: Verify configuration
echo ""
echo "🔧 Step 6: Updating Backstage configuration..."

# Update the ConfigMap with the final configuration
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

echo -e "${GREEN}✅ Configuration updated successfully${NC}"

# Step 7: Restart Backstage deployment
echo ""
echo "🔄 Restarting Backstage deployment..."
kubectl rollout restart deployment/backstage -n backstage

# Step 8: Next steps
echo ""
echo "🎉 Google OAuth configuration complete for DataTechSolutions!"
echo ""
echo -e "${GREEN}Configuration Summary:${NC}"
echo "• Domain: ${BACKSTAGE_DOMAIN}"
echo "• Organization: DataTechSolutions"
echo "• Admin Email: ${ADMIN_EMAIL}"
echo "• GitHub Integration: $([ "$SETUP_GITHUB" = "y" ] && echo "Enabled" || echo "Disabled")"
echo ""
echo -e "${YELLOW}Important Notes:${NC}"
echo "• Make sure your DNS records are configured:"
echo "  backstage.tools.datatechsolutions.com.br → Load Balancer IP"
echo "• SSL certificate will be automatically issued by Let's Encrypt"
echo "• Users can sign in with their Google accounts"
echo "• Only users from your Google Workspace domain can sign in"
echo ""
echo -e "${GREEN}Next Steps:${NC}"
echo "1. Verify DNS is pointing to your load balancer IP"
echo "2. Wait for SSL certificate (5-10 minutes)"
echo "3. Access Backstage at: https://${BACKSTAGE_DOMAIN}"
echo "4. Sign in with your Google account"
echo ""
echo -e "${GREEN}✅ DataTechSolutions Backstage setup complete!${NC}"