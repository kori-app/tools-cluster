# DataTechSolutions Tools Cluster Setup

Complete setup guide for the DataTechSolutions Kubernetes tools cluster with Backstage and Google OAuth.

## 🎯 **Domains**
- **Backstage**: `backstage.tools.datatechsolutions.com.br`
- **Grafana**: `grafana.tools.datatechsolutions.com.br`
- **ArgoCD**: `argocd.tools.datatechsolutions.com.br`

## 🚀 **Quick Setup**

### **Option 1: Using Existing Kubernetes Cluster**

If you already have a Kubernetes cluster:

```bash
cd tools-cluster/scripts

# Deploy everything with DataTechSolutions domains
./setup-datatechsolutions-domains.sh

# Configure Google OAuth
./configure-google-oauth-datatechsolutions.sh
```

### **Option 2: Create New GKE Cluster**

If you need to create a new cluster:

```bash
# 1. Create GKE cluster with Terraform
cd tools-cluster/terraform
terraform init
terraform apply

# 2. Configure kubectl
gcloud container clusters get-credentials datatechsolutions-tools --zone us-central1-a --project YOUR_PROJECT_ID

# 3. Deploy tools
cd ../scripts
./setup-datatechsolutions-domains.sh

# 4. Configure OAuth
./configure-google-oauth-datatechsolutions.sh
```

## 📋 **Prerequisites**

### **Required Tools**
```bash
# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

# Install helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install gcloud (for GKE)
curl https://sdk.cloud.google.com | bash
```

### **DNS Configuration**
You'll need to add these A records to your `datatechsolutions.com.br` DNS:

```
backstage.tools.datatechsolutions.com.br → [LOAD_BALANCER_IP]
grafana.tools.datatechsolutions.com.br   → [LOAD_BALANCER_IP]
argocd.tools.datatechsolutions.com.br    → [LOAD_BALANCER_IP]
```

## 🔐 **Google OAuth Setup**

### **Step 1: Create Google Cloud Project**
1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Create a new project: "DataTechSolutions Tools"
3. Enable APIs: Container API, Compute API

### **Step 2: Configure OAuth**
1. Navigate to APIs & Services > Credentials
2. Create OAuth 2.0 Client ID:
   - **Application type**: Web application
   - **Name**: DataTechSolutions Backstage
   - **Authorized JavaScript origins**:
     ```
     https://backstage.tools.datatechsolutions.com.br
     ```
   - **Authorized redirect URIs**:
     ```
     https://backstage.tools.datatechsolutions.com.br/api/auth/google/handler/frame
     ```

### **Step 3: Run Configuration Script**
```bash
./configure-google-oauth-datatechsolutions.sh
```

This will prompt you for:
- Google Client ID
- Google Client Secret
- GitHub Token (optional)

## 🏗️ **Architecture**

```
┌─────────────────────────────────────────────────────────────┐
│                DataTechSolutions Tools Cluster              │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────────┐ │
│  │ NGINX Ingress Controller + Let's Encrypt SSL           │ │
│  └─────────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐ │
│  │    Backstage    │ │     Grafana     │ │     ArgoCD      │ │
│  │ (Developer      │ │  (Monitoring)   │ │   (GitOps)      │ │
│  │   Portal)       │ │                 │ │                 │ │
│  │ Google OAuth    │ │ Brazilian       │ │ App Deploy      │ │
│  │ + GitHub        │ │ E-commerce      │ │ Automation      │ │
│  │ Integration     │ │ Dashboards      │ │                 │ │
│  └─────────────────┘ └─────────────────┘ └─────────────────┘ │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐ │
│  │   PostgreSQL    │ │   Prometheus    │ │   AlertManager  │ │
│  │  (Backstage     │ │   (Metrics)     │ │   (Alerting)    │ │
│  │   Database)     │ │                 │ │                 │ │
│  └─────────────────┘ └─────────────────┘ └─────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## 📊 **Features Included**

### **Backstage Developer Portal**
- ✅ Google OAuth authentication
- ✅ Service catalog with seller-project services
- ✅ Kubernetes plugin for cluster visibility
- ✅ GitHub integration for repositories
- ✅ Software templates for new services
- ✅ Technical documentation (TechDocs)
- ✅ API explorer

### **Monitoring Stack**
- ✅ Prometheus metrics collection
- ✅ Grafana dashboards
- ✅ AlertManager for notifications
- ✅ Brazilian e-commerce specific metrics
- ✅ Custom dashboards for seller-project

### **GitOps with ArgoCD**
- ✅ Automated deployments
- ✅ Multi-environment support
- ✅ Rollback capabilities
- ✅ Sync policies
- ✅ Application health monitoring

## 🔧 **Post-Setup Configuration**

### **1. Verify Services**
```bash
# Check all pods are running
kubectl get pods -A

# Check ingress
kubectl get ingress -A

# Check certificates
kubectl get certificates -A
```

### **2. Access Services**
After DNS propagation (5-10 minutes):
- **Backstage**: https://backstage.tools.datatechsolutions.com.br
- **Grafana**: https://grafana.tools.datatechsolutions.com.br
- **ArgoCD**: https://argocd.tools.datatechsolutions.com.br

### **3. Default Credentials**
- **Grafana**: `admin` / `datatechsolutions2024`
- **ArgoCD**: `admin` / `[auto-generated password shown in setup]`

## 🏢 **Team Access**

### **Backstage Access**
Users can sign in with their Google accounts. To restrict access:

1. Set up Google Workspace domain restrictions
2. Configure OAuth consent screen for internal use only
3. Add team members to the Google Cloud project

### **Grafana Access**
- Default admin access with password
- Can be integrated with Google OAuth if needed
- Role-based access control available

### **ArgoCD Access**
- Default admin access
- Can be integrated with Google OAuth
- RBAC policies for team permissions

## 🚨 **Troubleshooting**

### **Common Issues**

1. **DNS not resolving**
   ```bash
   # Check DNS propagation
   nslookup backstage.tools.datatechsolutions.com.br
   ```

2. **SSL certificate pending**
   ```bash
   # Check certificate status
   kubectl describe certificate backstage-tls -n backstage
   ```

3. **Backstage not starting**
   ```bash
   # Check logs
   kubectl logs -f deployment/backstage -n backstage
   ```

4. **OAuth errors**
   - Verify redirect URLs in Google Cloud Console
   - Check client ID/secret in Kubernetes secrets

### **Support**
- **Documentation**: Check logs and events in Kubernetes
- **GitHub Issues**: Create issues in the seller-project repository
- **Team Chat**: Use internal DataTechSolutions channels

## 🔄 **Updates and Maintenance**

### **Updating Services**
```bash
# Update Backstage
kubectl set image deployment/backstage backstage=backstage:latest -n backstage

# Update monitoring stack
helm upgrade kube-prometheus-stack prometheus-community/kube-prometheus-stack -n monitoring

# Update ArgoCD
helm upgrade argocd argo/argo-cd -n argocd
```

### **Backup Strategy**
- Backstage database (PostgreSQL) should be backed up regularly
- Grafana dashboards can be exported and stored in Git
- ArgoCD configurations are stored in Git repositories

---

**🎉 Your DataTechSolutions tools cluster is ready for development!**

Access your services at:
- https://backstage.tools.datatechsolutions.com.br
- https://grafana.tools.datatechsolutions.com.br
- https://argocd.tools.datatechsolutions.com.br