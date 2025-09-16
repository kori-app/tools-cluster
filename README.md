# DataTechSolutions Tools Cluster - Minimal GKE Setup

Minimal cost GKE cluster with Backstage and ArgoCD for DataTechSolutions development tools.

## 🎯 Overview

This setup creates a ultra-minimal GKE cluster with:
- **GKE**: Single e2-micro node (1 vCPU, 1GB RAM)
- **Backstage**: Developer portal with Google OAuth
- **ArgoCD**: GitOps deployment automation
- **SSL/TLS**: Automatic certificate management via Let's Encrypt
- **DNS**: Custom domains on tools.datatechsolutions.com.br

## 💰 Cost Optimization

**Monthly Cost: ~$9-12**
- GKE cluster (1 node, e2-micro, preemptible): ~$3-5
- Load balancer: ~$5
- Persistent disks (12GB total): ~$1-2

**95% cost reduction** from original OKD setup!

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Tools Cluster                        │
├─────────────────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌─────────────────┐              │
│  │    Backstage    │  │     ArgoCD      │              │
│  │  (Developer     │  │   (GitOps)      │              │
│  │   Portal)       │  │  Port: 8080     │              │
│  │  Port: 7007     │  └─────────────────┘              │
│  └─────────────────┘                                   │
├─────────────────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌─────────────────┐              │
│  │   Prometheus    │  │     Grafana     │              │
│  │  (Metrics)      │  │  (Dashboards)   │              │
│  │  Port: 9090     │  │  Port: 3000     │              │
│  └─────────────────┘  └─────────────────┘              │
├─────────────────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌─────────────────┐              │
│  │  Elasticsearch  │  │     Kibana      │              │
│  │   (Logging)     │  │   (Log Viewer)  │              │
│  │  Port: 9200     │  │  Port: 5601     │              │
│  └─────────────────┘  └─────────────────┘              │
└─────────────────────────────────────────────────────────┘
```

## 📁 Structure

```
tools-cluster/
├── k8s/
│   ├── namespaces/
│   │   ├── backstage.yaml
│   │   ├── argocd.yaml
│   │   ├── monitoring.yaml
│   │   └── logging.yaml
│   ├── backstage/
│   │   ├── deployment.yaml
│   │   ├── configmap.yaml
│   │   ├── secrets.yaml
│   │   └── ingress.yaml
│   ├── argocd/
│   │   ├── install.yaml
│   │   └── ingress.yaml
│   ├── monitoring/
│   │   ├── prometheus.yaml
│   │   ├── grafana.yaml
│   │   └── dashboards/
│   ├── logging/
│   │   ├── elasticsearch.yaml
│   │   ├── kibana.yaml
│   │   └── filebeat.yaml
│   └── ingress/
│       └── nginx-controller.yaml
├── backstage/
│   ├── app-config.yaml
│   ├── catalog/
│   │   ├── seller-project.yaml
│   │   ├── seller-dashboard.yaml
│   │   └── seller-service.yaml
│   └── plugins/
├── scripts/
│   ├── setup-cluster.sh
│   ├── deploy-backstage.sh
│   └── configure-google-oauth.sh
└── terraform/
    ├── gke-cluster.tf
    ├── variables.tf
    └── outputs.tf
```

## 🚀 Quick Start

### 1. Create GKE Cluster
```bash
# Using Terraform
cd tools-cluster/terraform
terraform init
terraform apply

# Or using gcloud
gcloud container clusters create tools-cluster \
  --zone=us-central1-a \
  --num-nodes=3 \
  --machine-type=e2-standard-4 \
  --enable-autorepair \
  --enable-autoscaling \
  --min-nodes=1 \
  --max-nodes=6
```

### 2. Setup Google OAuth
```bash
# Run the setup script
./scripts/configure-google-oauth.sh

# This will guide you through:
# 1. Creating Google OAuth credentials
# 2. Configuring Backstage secrets
# 3. Setting up domain and SSL
```

### 3. Deploy Tools
```bash
# Deploy everything
./scripts/setup-cluster.sh

# Or deploy individually
kubectl apply -f k8s/namespaces/
kubectl apply -f k8s/backstage/
kubectl apply -f k8s/monitoring/
kubectl apply -f k8s/argocd/
```

### 4. Access Services
```bash
# Get ingress IP
kubectl get ingress -A

# Services will be available at:
# - Backstage: https://backstage.your-domain.com
# - ArgoCD: https://argocd.your-domain.com
# - Grafana: https://grafana.your-domain.com
# - Kibana: https://kibana.your-domain.com
```

## 🔐 Google OAuth Setup

### 1. Create Google OAuth Application
1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Navigate to APIs & Services > Credentials
3. Create OAuth 2.0 Client ID
4. Set authorized redirect URIs:
   ```
   https://backstage.your-domain.com/api/auth/google/handler/frame
   ```

### 2. Configure Environment Variables
```bash
export GOOGLE_CLIENT_ID="your-client-id"
export GOOGLE_CLIENT_SECRET="your-client-secret"
export BACKSTAGE_DOMAIN="backstage.your-domain.com"
```

## 📊 Features

### Backstage Developer Portal
- **Service Catalog**: All seller-project services
- **Software Templates**: Boilerplate for new services
- **Documentation**: Centralized technical docs
- **API Explorer**: Explore all APIs
- **Kubernetes Plugin**: View cluster resources

### Monitoring Stack
- **Prometheus**: Metrics collection
- **Grafana**: Dashboards and alerting
- **AlertManager**: Alert routing
- **Custom Dashboards**: Brazilian e-commerce metrics

### Logging Stack
- **Elasticsearch**: Log storage and search
- **Kibana**: Log visualization
- **Filebeat**: Log shipping
- **Brazilian Business Logs**: Custom parsing

### GitOps with ArgoCD
- **Application Deployment**: Automated deployments
- **Multi-Environment**: Dev, staging, prod
- **Rollback**: Easy rollback capabilities
- **Sync Policies**: Automated or manual sync