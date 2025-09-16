#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Deploying DataTechSolutions Tools on GKE${NC}"
echo ""
echo "Services to deploy:"
echo "• GKE Cluster (minimal configuration)"
echo "• Backstage: https://backstage.tools.datatechsolutions.com.br"
echo "• ArgoCD: https://argocd.tools.datatechsolutions.com.br"
echo "• NGINX Ingress + Let's Encrypt SSL"
echo ""

# Check prerequisites
echo "🔍 Checking prerequisites..."

if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}❌ gcloud CLI not found. Please install Google Cloud SDK.${NC}"
    exit 1
fi

if ! command -v terraform &> /dev/null; then
    echo -e "${RED}❌ terraform not found. Please install Terraform.${NC}"
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ kubectl not found. Please install kubectl.${NC}"
    exit 1
fi

# Check if user is authenticated
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q @; then
    echo -e "${RED}❌ Not authenticated with gcloud. Please run 'gcloud auth login'${NC}"
    exit 1
fi

# Get current project
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
if [ -z "$PROJECT_ID" ]; then
    echo -e "${RED}❌ No active GCP project. Please set with: gcloud config set project YOUR_PROJECT_ID${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Prerequisites check passed${NC}"
echo "Project: $PROJECT_ID"
echo ""

# Change to terraform directory
cd terraform

# Initialize Terraform
echo "📋 Initializing Terraform..."
terraform init

# Plan deployment
echo ""
echo "📝 Planning deployment..."
terraform plan -var="project_id=$PROJECT_ID"

# Confirm deployment
echo ""
read -p "Do you want to proceed with the deployment? (y/n): " CONFIRM

if [[ $CONFIRM != "y" && $CONFIRM != "Y" ]]; then
    echo "Deployment cancelled."
    exit 0
fi

# Apply Terraform
echo ""
echo -e "${BLUE}🚀 Deploying infrastructure...${NC}"
terraform apply -var="project_id=$PROJECT_ID" -auto-approve

# Get outputs
echo ""
echo -e "${GREEN}🎉 Deployment completed!${NC}"
echo ""

# Display cluster information
CLUSTER_NAME=$(terraform output -raw cluster_name)
ZONE=$(terraform output -raw zone)
INGRESS_IP=$(terraform output -raw ingress_ip)
BACKSTAGE_URL=$(terraform output -raw backstage_url)
ARGOCD_URL=$(terraform output -raw argocd_url)
KUBECTL_CONFIG_CMD=$(terraform output -raw kubectl_config_command)

echo -e "${BLUE}📋 Cluster Information:${NC}"
echo "Cluster Name: $CLUSTER_NAME"
echo "Zone: $ZONE"
echo "Ingress IP: $INGRESS_IP"
echo ""

echo -e "${BLUE}🌐 Service URLs:${NC}"
echo "• Backstage: $BACKSTAGE_URL"
echo "• ArgoCD: $ARGOCD_URL"
echo ""

echo -e "${BLUE}🔧 Configure kubectl:${NC}"
echo "$KUBECTL_CONFIG_CMD"
echo ""

echo -e "${BLUE}📝 DNS Configuration:${NC}"
echo "Update your domain DNS to point tools.datatechsolutions.com.br to these name servers:"
terraform output dns_name_servers
echo ""

echo -e "${YELLOW}⏳ Next Steps:${NC}"
echo "1. Configure kubectl access:"
echo "   $KUBECTL_CONFIG_CMD"
echo ""
echo "2. Wait for SSL certificates to be issued (5-10 minutes)"
echo ""
echo "3. Configure Google OAuth credentials:"
echo "   - Go to https://console.cloud.google.com"
echo "   - Navigate to 'APIs & Services' > 'Credentials'"
echo "   - Create OAuth 2.0 Client ID for web application"
echo "   - Add authorized origins: $BACKSTAGE_URL"
echo "   - Add redirect URIs: $BACKSTAGE_URL/api/auth/google/handler/frame"
echo ""
echo "4. Update secrets with OAuth credentials:"
echo "   kubectl patch secret backstage-secrets -n backstage --type='merge' -p='{\"data\":{\"GOOGLE_CLIENT_ID\":\"<base64-encoded-client-id>\",\"GOOGLE_CLIENT_SECRET\":\"<base64-encoded-client-secret>\"}}'"
echo ""
echo "5. Restart Backstage deployment:"
echo "   kubectl rollout restart deployment/backstage -n backstage"
echo ""

echo -e "${GREEN}✅ GKE tools cluster is ready!${NC}"
echo ""
echo -e "${BLUE}💰 Estimated Monthly Cost:${NC}"
echo "• GKE cluster (1 node, e2-micro, preemptible): ~\$3-5"
echo "• Load balancer: ~\$5"
echo "• Persistent disks (12GB total): ~\$1-2"
echo "• Total: ~\$9-12/month"
echo ""