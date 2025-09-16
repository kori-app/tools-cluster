# ArgoCD namespace
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }
  depends_on = [google_container_node_pool.primary_nodes]
}

# ArgoCD Helm release
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "5.51.6"
  namespace  = kubernetes_namespace.argocd.metadata[0].name

  values = [
    <<EOF
global:
  domain: argocd.${var.base_domain}

server:
  config:
    url: https://argocd.${var.base_domain}
    oidc.config: |
      name: Google
      issuer: https://accounts.google.com
      clientId: $oidc.google.clientId
      clientSecret: $oidc.google.clientSecret
      requestedScopes: ["openid", "profile", "email"]
      requestedIDTokenClaims: {"groups": {"essential": true}}

  rbacConfig:
    policy.default: role:readonly
    policy.csv: |
      g, team@datatechsolutions.com.br, role:admin

  extraArgs:
    - --insecure

  service:
    type: NodePort
    nodePortHttp: 30008

configs:
  secret:
    extra:
      oidc.google.clientId: "your-google-client-id"
      oidc.google.clientSecret: "your-google-client-secret"

redis:
  enabled: true

repoServer:
  replicas: 1

applicationSet:
  enabled: true

notifications:
  enabled: false

dex:
  enabled: false
EOF
  ]

  depends_on = [kubernetes_namespace.argocd]
}