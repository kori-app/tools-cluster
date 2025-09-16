# DNS Zone for tools.datatechsolutions.com.br
resource "google_dns_managed_zone" "tools_zone" {
  name     = "tools-datatechsolutions-zone"
  dns_name = "tools.datatechsolutions.com.br."

  description = "DNS zone for DataTechSolutions tools"

  depends_on = [google_project_service.dns]
}

# Get external IP for ingress
resource "google_compute_global_address" "ingress_ip" {
  name = "${var.cluster_name}-ingress-ip"
}

# DNS records for services
resource "google_dns_record_set" "backstage" {
  name = "backstage.${google_dns_managed_zone.tools_zone.dns_name}"
  type = "A"
  ttl  = 300

  managed_zone = google_dns_managed_zone.tools_zone.name

  rrdatas = [google_compute_global_address.ingress_ip.address]
}

resource "google_dns_record_set" "argocd" {
  name = "argocd.${google_dns_managed_zone.tools_zone.dns_name}"
  type = "A"
  ttl  = 300

  managed_zone = google_dns_managed_zone.tools_zone.name

  rrdatas = [google_compute_global_address.ingress_ip.address]
}