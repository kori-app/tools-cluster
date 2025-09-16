# Enable Cloud SQL API
resource "google_project_service" "sqladmin" {
  service            = "sqladmin.googleapis.com"
  disable_on_destroy = false
}

# Cloud SQL PostgreSQL instance (minimal configuration)
resource "google_sql_database_instance" "backstage_db" {
  name             = "backstage-db"
  database_version = "POSTGRES_15"
  region           = var.region

  settings {
    tier              = "db-f1-micro"  # Smallest/cheapest tier
    availability_type = "ZONAL"       # Single zone for cost savings
    disk_type         = "PD_SSD"
    disk_size         = 10            # Minimal disk size (10GB)

    backup_configuration {
      enabled    = true
      start_time = "02:00"            # Backup at 2 AM
    }

    ip_configuration {
      ipv4_enabled       = false       # No public IP for security
      private_network    = google_compute_network.vpc.id
      enable_private_path_for_google_cloud_services = true
    }

    database_flags {
      name  = "log_checkpoints"
      value = "on"
    }

    database_flags {
      name  = "log_connections"
      value = "on"
    }

    database_flags {
      name  = "log_disconnections"
      value = "on"
    }

    maintenance_window {
      day          = 7    # Sunday
      hour         = 3    # 3 AM
      update_track = "stable"
    }
  }

  deletion_protection = false  # Allow deletion via Terraform

  depends_on = [
    google_project_service.sqladmin,
    google_compute_network.vpc,
    google_service_networking_connection.private_vpc_connection
  ]
}

# Private VPC connection for Cloud SQL
resource "google_compute_global_address" "private_ip_address" {
  name          = "private-ip-address"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc.id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]

  depends_on = [google_project_service.sqladmin]
}

# Database for Backstage
resource "google_sql_database" "backstage" {
  name     = "backstage_plugin_catalog"
  instance = google_sql_database_instance.backstage_db.name
}

# Database user for Backstage
resource "google_sql_user" "backstage_user" {
  name     = "backstage"
  instance = google_sql_database_instance.backstage_db.name
  password = "backstage-secure-password-2024"  # In production, use random password
}

# Output database connection details
output "database_connection_name" {
  description = "Cloud SQL connection name"
  value       = google_sql_database_instance.backstage_db.connection_name
}

output "database_private_ip" {
  description = "Cloud SQL private IP address"
  value       = google_sql_database_instance.backstage_db.private_ip_address
}