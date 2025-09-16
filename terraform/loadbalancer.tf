# Google-managed SSL certificates
resource "google_compute_managed_ssl_certificate" "backstage_ssl" {
  name = "backstage-ssl-cert"

  managed {
    domains = ["backstage.${var.base_domain}"]
  }
}

resource "google_compute_managed_ssl_certificate" "argocd_ssl" {
  name = "argocd-ssl-cert"

  managed {
    domains = ["argocd.${var.base_domain}"]
  }
}

# Backend service for Backstage
resource "google_compute_backend_service" "backstage_backend" {
  name                  = "backstage-backend"
  protocol              = "HTTP"
  port_name             = "http"
  load_balancing_scheme = "EXTERNAL"
  timeout_sec           = 10

  backend {
    group           = google_compute_instance_group.gke_instance_group.id
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }

  health_checks = [google_compute_health_check.backstage_health_check.id]
}

# Backend service for ArgoCD
resource "google_compute_backend_service" "argocd_backend" {
  name                  = "argocd-backend"
  protocol              = "HTTP"
  port_name             = "http"
  load_balancing_scheme = "EXTERNAL"
  timeout_sec           = 10

  backend {
    group           = google_compute_instance_group.gke_instance_group.id
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }

  health_checks = [google_compute_health_check.argocd_health_check.id]
}

# Health checks
resource "google_compute_health_check" "backstage_health_check" {
  name               = "backstage-health-check"
  timeout_sec        = 1
  check_interval_sec = 1

  http_health_check {
    port         = 30007  # NodePort for Backstage
    request_path = "/healthcheck"
  }
}

resource "google_compute_health_check" "argocd_health_check" {
  name               = "argocd-health-check"
  timeout_sec        = 1
  check_interval_sec = 1

  http_health_check {
    port         = 30008  # NodePort for ArgoCD
    request_path = "/healthz"
  }
}

# URL map for routing
resource "google_compute_url_map" "main_lb" {
  name            = "main-load-balancer"
  default_service = google_compute_backend_service.backstage_backend.id

  host_rule {
    hosts        = ["backstage.${var.base_domain}"]
    path_matcher = "backstage-paths"
  }

  host_rule {
    hosts        = ["argocd.${var.base_domain}"]
    path_matcher = "argocd-paths"
  }

  path_matcher {
    name            = "backstage-paths"
    default_service = google_compute_backend_service.backstage_backend.id
  }

  path_matcher {
    name            = "argocd-paths"
    default_service = google_compute_backend_service.argocd_backend.id
  }
}

# HTTPS proxy
resource "google_compute_target_https_proxy" "main_https_proxy" {
  name             = "main-https-proxy"
  url_map          = google_compute_url_map.main_lb.id
  ssl_certificates = [
    google_compute_managed_ssl_certificate.backstage_ssl.id,
    google_compute_managed_ssl_certificate.argocd_ssl.id
  ]
}

# HTTP to HTTPS redirect
resource "google_compute_url_map" "http_redirect" {
  name = "http-redirect"

  default_url_redirect {
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
    strip_query            = false
    https_redirect         = true
  }
}

resource "google_compute_target_http_proxy" "http_redirect" {
  name    = "http-redirect-proxy"
  url_map = google_compute_url_map.http_redirect.id
}

# Global forwarding rules
resource "google_compute_global_forwarding_rule" "https" {
  name                  = "https-forwarding-rule"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL"
  port_range            = "443"
  target                = google_compute_target_https_proxy.main_https_proxy.id
  ip_address            = google_compute_global_address.ingress_ip.id
}

resource "google_compute_global_forwarding_rule" "http" {
  name                  = "http-forwarding-rule"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL"
  port_range            = "80"
  target                = google_compute_target_http_proxy.http_redirect.id
  ip_address            = google_compute_global_address.ingress_ip.id
}

# Instance group for GKE nodes
resource "google_compute_instance_group" "gke_instance_group" {
  name        = "gke-instance-group"
  description = "Instance group for GKE nodes"
  zone        = var.zone

  named_port {
    name = "http"
    port = 30007  # NodePort for Backstage
  }

  named_port {
    name = "argocd"
    port = 30008  # NodePort for ArgoCD
  }

  # Note: instances will be automatically populated by GKE
  lifecycle {
    ignore_changes = [instances]
  }

  depends_on = [google_container_node_pool.primary_nodes]
}

# Firewall rule for health checks
resource "google_compute_firewall" "health_check" {
  name    = "allow-health-check"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["30007", "30008"]  # NodePorts
  }

  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]  # Google health check IPs
  target_tags   = ["gke-node"]
}