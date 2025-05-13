terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.10.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

variable "project_id" {
  description = "The Google Cloud project ID."
  type        = string
}

variable "region" {
  description = "The Google Cloud region to deploy resources."
  type        = string
  default     = "us-central1"
}

variable "service_name" {
  description = "Name for the Cloud Run service."
  type        = string
  default     = "comfyui-go-api-service" # Updated name
}

variable "container_image_url" {
  description = "The full URL of the pre-built ComfyUI+Go container image (e.g., from GAR)."
  type        = string
  # Example: "us-central1-docker.pkg.dev/YOUR_PROJECT/YOUR_REPO/comfyui-go-api:latest"
}

variable "gpu_type" {
  description = "The type of GPU to attach."
  type        = string
  default     = "nvidia-tesla-t4"
}

variable "gpu_count" {
  description = "Number of GPUs to attach."
  type        = number
  default     = 1
}

variable "service_account_email" {
  description = "Optional service account email for the Cloud Run service. Defaults to Compute Engine default SA."
  type        = string
  default     = null
}

variable "allow_unauthenticated" {
  description = "Set to true to allow public access to the Cloud Run service."
  type        = bool
  default     = false
}

# Variables for the Go Gin application's OAuth and configuration
variable "go_app_google_client_id" {
  description = "Google Client ID for the Go Gin API service."
  type        = string
  # Example: "YOUR_GOOGLE_OAUTH_CLIENT_ID.apps.googleusercontent.com"
}

variable "go_app_allowed_auth_domain" {
  description = "Optional: GSuite domain to restrict access for the Go Gin API."
  type        = string
  default     = ""
}

variable "go_app_server_port" {
  description = "Port the Go Gin API service will listen on inside the container."
  type        = string
  default     = "8080" # This is the port Cloud Run will forward to
}

# Enable necessary APIs
resource "google_project_service" "run_api" {
  project            = var.project_id
  service            = "run.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "artifactregistry_api" {
  project            = var.project_id
  service            = "artifactregistry.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "compute_api" {
  project            = var.project_id
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "iam_api" {
  project = var.project_id
  service = "iam.googleapis.com"
  disable_on_destroy = false
}


# Cloud Run Service Definition
resource "google_cloud_run_v2_service" "comfyui_go_api_service" {
  project  = var.project_id
  location = var.region
  name     = var.service_name

  depends_on = [
    google_project_service.run_api,
    google_project_service.compute_api,
    google_project_service.artifactregistry_api,
    google_project_service.iam_api,
  ]

  template {
    service_account = var.service_account_email
    scaling {
      min_instance_count = 0
      max_instance_count = 5
    }
    execution_environment = "EXECUTION_ENVIRONMENT_GEN2"

    containers {
      image = var.container_image_url

      ports {
        # This port must match the port your Go Gin service listens on (defined by SERVER_PORT env var)
        container_port = tonumber(var.go_app_server_port)
      }

      resources {
        limits = {
          "cpu"    = "4"
          "memory" = "16Gi"
          "gpu"    = var.gpu_count # This GPU is primarily for ComfyUI
        }
        startup_cpu_boost = true
      }

      gpu {
        type  = var.gpu_type
        count = var.gpu_count
      }

      env {
        name  = "GIN_MODE"
        value = "release"
      }
      env {
        name  = "SERVER_PORT" # For the Go Gin app
        value = var.go_app_server_port
      }
      env {
        name  = "COMFYUI_BASE_URL" # For the Go Gin app to find ComfyUI
        value = "http://127.0.0.1:8188" # ComfyUI listens locally
      }
      env {
        name  = "GOOGLE_CLIENT_ID" # For Go Gin app's OAuth middleware
        value = var.go_app_google_client_id
      }
      env {
        name  = "ALLOWED_AUTH_DOMAIN" # For Go Gin app's OAuth middleware
        value = var.go_app_allowed_auth_domain
      }
      # Add any other environment variables needed by ComfyUI or your Go app
    }
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }
}

# IAM binding to allow invocation for the Go Gin API service
resource "google_cloud_run_v2_service_iam_member" "invoker" {
  count    = var.allow_unauthenticated ? 1 : 0
  project  = google_cloud_run_v2_service.comfyui_go_api_service.project
  location = google_cloud_run_v2_service.comfyui_go_api_service.location
  name     = google_cloud_run_v2_service.comfyui_go_api_service.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

output "service_url" {
  description = "URL of the deployed ComfyUI Go API Cloud Run service."
  value       = google_cloud_run_v2_service.comfyui_go_api_service.uri
}

output "service_name_output" {
  description = "Name of the deployed ComfyUI Go API Cloud Run service."
  value       = google_cloud_run_v2_service.comfyui_go_api_service.name
}