# Backstage namespace
resource "kubernetes_namespace" "backstage" {
  metadata {
    name = "backstage"
  }
  depends_on = [google_container_node_pool.primary_nodes]
}

# Note: PostgreSQL is now provided by Cloud SQL (see cloudsql.tf)

# Backstage secrets
resource "kubernetes_secret" "backstage_secrets" {
  metadata {
    name      = "backstage-secrets"
    namespace = kubernetes_namespace.backstage.metadata[0].name
  }

  data = {
    POSTGRES_HOST     = google_sql_database_instance.backstage_db.private_ip_address
    POSTGRES_PORT     = "5432"
    POSTGRES_USER     = google_sql_user.backstage_user.name
    POSTGRES_PASSWORD = google_sql_user.backstage_user.password
    POSTGRES_DB       = google_sql_database.backstage.name
    BACKEND_SECRET    = "your-backend-secret-here"
    # These will be updated with actual values during OAuth configuration
    GOOGLE_CLIENT_ID     = "your-google-client-id"
    GOOGLE_CLIENT_SECRET = "your-google-client-secret"
    GITHUB_TOKEN         = "your-github-token"
  }

  type = "Opaque"
}

# Backstage ConfigMap
resource "kubernetes_config_map" "backstage_config" {
  metadata {
    name      = "backstage-config"
    namespace = kubernetes_namespace.backstage.metadata[0].name
  }

  data = {
    "app-config.yaml" = <<EOF
app:
  title: DataTechSolutions Developer Portal
  baseUrl: https://backstage.${var.base_domain}
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
  baseUrl: https://backstage.${var.base_domain}
  listen:
    port: 7007
    host: 0.0.0.0
  csp:
    connect-src: ["'self'", 'http:', 'https:']
  cors:
    origin: https://backstage.${var.base_domain}
    methods: [GET, HEAD, PATCH, POST, PUT, DELETE]
    credentials: true
  database:
    client: pg
    connection:
      host: $${POSTGRES_HOST}
      port: $${POSTGRES_PORT}
      user: $${POSTGRES_USER}
      password: $${POSTGRES_PASSWORD}
      database: $${POSTGRES_DB}

integrations:
  github:
    - host: github.com
      token: $${GITHUB_TOKEN}

auth:
  providers:
    google:
      development:
        clientId: $${GOOGLE_CLIENT_ID}
        clientSecret: $${GOOGLE_CLIENT_SECRET}
      production:
        clientId: $${GOOGLE_CLIENT_ID}
        clientSecret: $${GOOGLE_CLIENT_SECRET}

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
          name: ${var.cluster_name}
          authProvider: 'serviceAccount'
          skipTLSVerify: false
          skipMetricsLookup: false

techdocs:
  builder: 'local'
  generator:
    runIn: 'docker'
  publisher:
    type: 'local'

proxy:
  '/api-docs':
    target: 'https://api.seller-project.com.br'
    changeOrigin: true
    headers:
      X-Custom-Source: 'backstage'

apiDocs:
  apiDocsModule: true

catalog:
  providers:
    github:
      - organization: 'kori-app'
        catalogPath: '/catalog-info.yaml'
        filters:
          branch: 'main'
          repository: '.*'

enabled:
  kubernetes: true
  techdocs: true
  apiDocs: true
  costInsights: false
EOF
  }
}

# Backstage Service Account
resource "kubernetes_service_account" "backstage" {
  metadata {
    name      = "backstage"
    namespace = kubernetes_namespace.backstage.metadata[0].name
    annotations = {
      "iam.gke.io/gcp-service-account" = google_service_account.backstage_gsa.email
    }
  }
}

# GCP Service Account for Backstage
resource "google_service_account" "backstage_gsa" {
  account_id   = "backstage-sa"
  display_name = "Backstage Service Account"
}

# IAM binding for Workload Identity
resource "google_service_account_iam_member" "backstage_workload_identity" {
  service_account_id = google_service_account.backstage_gsa.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${kubernetes_namespace.backstage.metadata[0].name}/${kubernetes_service_account.backstage.metadata[0].name}]"
}

# Backstage ClusterRole
resource "kubernetes_cluster_role" "backstage" {
  metadata {
    name = "backstage"
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "services", "configmaps", "secrets"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["apps"]
    resources  = ["deployments", "replicasets"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["networking.k8s.io"]
    resources  = ["ingresses"]
    verbs      = ["get", "list", "watch"]
  }
}

# Backstage ClusterRoleBinding
resource "kubernetes_cluster_role_binding" "backstage" {
  metadata {
    name = "backstage"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.backstage.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.backstage.metadata[0].name
    namespace = kubernetes_namespace.backstage.metadata[0].name
  }
}

# Backstage Deployment
resource "kubernetes_deployment" "backstage" {
  metadata {
    name      = "backstage"
    namespace = kubernetes_namespace.backstage.metadata[0].name
    labels = {
      app = "backstage"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "backstage"
      }
    }

    template {
      metadata {
        labels = {
          app = "backstage"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.backstage.metadata[0].name

        container {
          name  = "backstage"
          image = "spotify/backstage:latest"

          port {
            container_port = 7007
          }

          env_from {
            secret_ref {
              name = kubernetes_secret.backstage_secrets.metadata[0].name
            }
          }

          volume_mount {
            name       = "app-config"
            mount_path = "/app/app-config.yaml"
            sub_path   = "app-config.yaml"
          }

          liveness_probe {
            http_get {
              path = "/healthcheck"
              port = 7007
            }
            initial_delay_seconds = 60
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/healthcheck"
              port = 7007
            }
            initial_delay_seconds = 30
            period_seconds        = 5
          }

          resources {
            limits = {
              cpu    = "200m"
              memory = "256Mi"
            }
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
          }
        }

        volume {
          name = "app-config"
          config_map {
            name = kubernetes_config_map.backstage_config.metadata[0].name
          }
        }
      }
    }
  }

  depends_on = [google_sql_database_instance.backstage_db]
}

# Backstage Service
resource "kubernetes_service" "backstage" {
  metadata {
    name      = "backstage"
    namespace = kubernetes_namespace.backstage.metadata[0].name
  }

  spec {
    selector = {
      app = "backstage"
    }

    port {
      port        = 80
      target_port = 7007
      node_port   = 30007
    }

    type = "NodePort"
  }
}