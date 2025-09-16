# Monitoring & Observability

The tools cluster uses Google Cloud's managed monitoring and logging services instead of self-hosted solutions like Prometheus, Grafana, Elasticsearch, and Kibana.

## 🎯 Monitoring Stack

### Google Cloud Monitoring
**Replaces**: Prometheus + Grafana
- **Automatic metric collection** from GKE clusters
- **Pre-built dashboards** for Kubernetes workloads
- **Custom dashboards** for application metrics
- **Alerting policies** with notification channels

### Google Cloud Logging
**Replaces**: Elasticsearch + Kibana
- **Centralized log aggregation** from all pods
- **Structured logging** with JSON parsing
- **Log-based metrics** for monitoring
- **Log retention** and archival policies

## 📊 Available Dashboards

### 1. GKE Cluster Overview
- **Node CPU & Memory utilization**
- **Pod count by namespace**
- **Network traffic metrics**
- **Storage usage patterns**

### 2. Application Metrics
- **Backstage response times**
- **ArgoCD sync status**
- **Database connection metrics**
- **Load balancer performance**

### 3. Cost Monitoring
- **Resource utilization trends**
- **Cost allocation by service**
- **Optimization recommendations**

## 🚨 Alerting Policies

### High Priority Alerts
- **Node resource exhaustion** (CPU > 80%, Memory > 85%)
- **Application error rate** (> 10 errors/minute)
- **Database connection failures**
- **SSL certificate expiration**

### Medium Priority Alerts
- **Pod restart loops**
- **High response latency**
- **Disk space warnings**
- **Backup failures**

## 📈 Key Metrics

### Infrastructure Metrics
```
- gke_node/cpu/utilization
- gke_node/memory/utilization
- k8s_pod/restart_count
- https_lb_rule/request_count
```

### Application Metrics
```
- k8s_container/cpu/usage_time
- k8s_container/memory/working_set_bytes
- sql_database/cpu/utilization
- sql_database/memory/usage
```

## 🔍 Log Analysis

### Application Logs
- **Backstage**: Authentication, API calls, errors
- **ArgoCD**: Deployment events, sync status
- **System**: Kubernetes events, node logs

### Log Retention
- **Application logs**: 30 days in hot storage
- **Audit logs**: 365 days with archival
- **Debug logs**: 7 days retention

## 💰 Cost Benefits

| Component | Self-Hosted Monthly | Managed Service | Savings |
|-----------|---------------------|----------------|---------|
| Monitoring | ~$8-12 | ~$1-2 | 75-85% |
| Logging | ~$10-15 | ~$2-3 | 80% |
| Maintenance | ~$0 (time cost) | $0 | 100% |
| **Total** | **~$18-27** | **~$3-5** | **~80%** |

## 🛠️ Access Links

### Monitoring Dashboards
- [GKE Overview](https://console.cloud.google.com/monitoring/dashboards)
- [Application Metrics](https://console.cloud.google.com/monitoring/dashboards)
- [Uptime Monitoring](https://console.cloud.google.com/monitoring/uptime)

### Logging
- [Application Logs](https://console.cloud.google.com/logs/query)
- [Audit Logs](https://console.cloud.google.com/logs/query)
- [Log Analytics](https://console.cloud.google.com/logs/analytics)

### Alerting
- [Alert Policies](https://console.cloud.google.com/monitoring/alerting)
- [Notification Channels](https://console.cloud.google.com/monitoring/settings)
- [Alert History](https://console.cloud.google.com/monitoring/alerting/incidents)

## 🔧 Configuration

The monitoring stack is fully configured via Terraform:
- **Dashboards**: Auto-created for cluster overview
- **Alert policies**: Pre-configured for common issues
- **Log sinks**: Automated archival to Cloud Storage
- **Metrics**: Custom application metrics collection

No manual setup required - everything is infrastructure as code!