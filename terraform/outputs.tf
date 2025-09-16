output "cluster_name" {
  description = "GKE cluster name"
  value       = google_container_cluster.primary.name
}

output "cluster_endpoint" {
  description = "GKE cluster endpoint"
  value       = google_container_cluster.primary.endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "GKE cluster CA certificate"
  value       = google_container_cluster.primary.master_auth.0.cluster_ca_certificate
  sensitive   = true
}

output "project_id" {
  description = "GCP project ID"
  value       = var.project_id
}

output "region" {
  description = "GCP region"
  value       = var.region
}

output "zone" {
  description = "GCP zone"
  value       = var.zone
}

output "ingress_ip" {
  description = "External IP for ingress"
  value       = google_compute_global_address.ingress_ip.address
}

output "dns_name_servers" {
  description = "DNS name servers for tools.datatechsolutions.com.br"
  value       = google_dns_managed_zone.tools_zone.name_servers
}

output "backstage_url" {
  description = "Backstage URL"
  value       = "https://backstage.${var.base_domain}"
}

output "argocd_url" {
  description = "ArgoCD URL"
  value       = "https://argocd.${var.base_domain}"
}

output "kubectl_config_command" {
  description = "Command to configure kubectl"
  value       = "gcloud container clusters get-credentials ${google_container_cluster.primary.name} --zone=${var.zone} --project=${var.project_id}"
}