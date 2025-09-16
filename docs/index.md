# DataTechSolutions Tools Cluster

Welcome to the DataTechSolutions DevOps Tools Cluster documentation. This minimal GKE setup provides a complete developer platform for the seller-project ecosystem.

## 🎯 Overview

The tools cluster is a cost-optimized Kubernetes environment running on Google Cloud Platform, designed to support the entire development lifecycle for DataTechSolutions' Brazilian e-commerce platform.

**Monthly Cost: ~$9-15** (95% reduction from original OKD setup)

## 🏗️ Architecture

### Core Components

- **GKE Cluster**: Single e2-micro node with preemptible instances
- **Backstage**: Developer portal with Google OAuth integration
- **ArgoCD**: GitOps deployment automation
- **Cloud SQL**: Managed PostgreSQL database
- **Google Cloud Load Balancer**: Managed SSL and traffic routing
- **Cloud Monitoring**: Managed metrics and dashboards (replaces Prometheus/Grafana)
- **Cloud Logging**: Centralized log management (replaces Elasticsearch/Kibana)

### Services Available

| Service | URL | Description |
|---------|-----|-------------|
| Backstage | https://backstage.tools.datatechsolutions.com.br | Developer Portal & Service Catalog |
| ArgoCD | https://argocd.tools.datatechsolutions.com.br | GitOps Deployment Platform |
| Cloud Monitoring | https://console.cloud.google.com/monitoring | Metrics, Dashboards & Alerting |
| Cloud Logging | https://console.cloud.google.com/logs | Centralized Log Management |

## 🚀 Features

### Developer Portal (Backstage)
- **Service Catalog**: Complete inventory of seller-project services
- **API Documentation**: OpenAPI specs with interactive explorer
- **Team Ownership**: Service ownership and team management
- **TechDocs**: Integrated documentation platform
- **GitHub Integration**: Automated discovery and updates

### GitOps Platform (ArgoCD)
- **Automated Deployments**: GitHub → Container Registry → Kubernetes
- **Multi-Environment**: Support for dev, staging, and production
- **Rollback Capabilities**: Easy rollback to previous versions
- **Sync Policies**: Automated or manual deployment workflows

### CI/CD Pipeline
```
GitHub Actions → Google Container Registry → ArgoCD → GKE Cluster
```

## 🛠️ Technologies

- **Infrastructure**: Terraform, Google Cloud Platform
- **Kubernetes**: Google Kubernetes Engine (GKE)
- **CI/CD**: GitHub Actions, ArgoCD
- **Monitoring**: Google Cloud Monitoring & Logging (fully managed)
- **Security**: Google OAuth, Workload Identity, SSL certificates

## 📊 Cost Optimization

| Component | Configuration | Monthly Cost |
|-----------|---------------|--------------|
| GKE Cluster | 1 e2-micro preemptible node | ~$3-5 |
| Cloud SQL | db-f1-micro PostgreSQL | ~$4-7 |
| Load Balancer | HTTP(S) LB with SSL | ~$1-2 |
| Storage | 20GB SSD total | ~$1-2 |
| Cloud Monitoring | Metrics & dashboards | ~$0.25/metric |
| Cloud Logging | Log ingestion & storage | ~$0.50/GB |
| **Total** | | **~$9-15** |

## 🔗 Quick Links

- [Getting Started Guide](getting-started/quick-start.md)
- [Architecture Overview](architecture/overview.md)
- [Deployment Instructions](getting-started/deployment.md)
- [Operations Guide](operations/backstage.md)

## 📞 Support

For issues and questions:
- **GitHub Issues**: [kori-app/tools-cluster](https://github.com/kori-app/tools-cluster/issues)
- **Email**: team@datatechsolutions.com.br
- **Documentation**: This site via Backstage TechDocs