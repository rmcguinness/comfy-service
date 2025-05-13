terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.10.0" # Use a recent version supporting Cloud Run v2 features
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
  default     = "us-central1" # Choose a region supporting GPUs
}

variable "service_name" {
  description = "Name for the Cloud Run service."
  type        = string
  default     = "comfyui-service"
}

variable "container_image_url" {
  description = "The full URL of the pre-built ComfyUI container image (e.g., from GAR)."
  type        = string
  # Example: "us-central1-docker.pkg.dev/YOUR_PROJECT/YOUR_REPO/comfyui-cloudrun:latest"
}

variable "gpu_type" {
  description = "The type of GPU to attach."
  type        = string
  default     = "nvidia-tesla-t4" # Common choice, check availability in your region
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
  default     = false # Recommended to keep false and use authenticated requests (e.g., via IAP or direct auth)
}

# Enable necessary APIs
resource "google_project_service" "run_api" {
  project = var.project_id
  service = "run.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "artifactregistry_api" {
  project = var.project_id
  service = "artifactregistry.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "compute_api" {
  project = var.project_id
  service = "compute.googleapis.com" # Needed for GPU functionality & default SA
  disable_on_destroy = false
}

# Optional: Create Artifact Registry repository if you don't have one
/*
resource "google_artifact_registry_repository" "comfyui_repo" {
  project       = var.project_id
  location      = var.region
  repository_id = "comfyui-images" # Choose your repo name
  description   = "Docker repository for ComfyUI images"
  format        = "DOCKER"
}
*/

# Cloud Run Service Definition
resource "google_cloud_run_v2_service" "comfyui_service" {
  project  = var.project_id
  location = var.region
  name     = var.service_name

  # Ensure APIs are enabled before creating the service
  depends_on = [
    google_project_service.run_api,
    google_project_service.compute_api,
    google_project_service.artifactregistry_api,
    # google_artifact_registry_repository.comfyui_repo, # Uncomment if creating repo here
  ]

  template {
    # Use the default Compute Engine service account or specify one
    service_account = var.service_account_email

    # Increase scaling limits if needed for long-running jobs or higher traffic
    scaling {
      min_instance_count = 0 # Can scale down to 0 when idle
      max_instance_count = 5 # Adjust as needed
    }

    # Use Gen 2 execution environment for GPU support
    execution_environment = "EXECUTION_ENVIRONMENT_GEN2"

    containers {
      image = var.container_image_url

      ports {
        container_port = 8188 # Port exposed in Dockerfile and used by ComfyUI
      }

      resources {
        # Cloud Run requires CPU limit to be set when GPU is used
        limits = {
          "cpu"    = "4"       # Adjust based on workload (e.g., "1", "2", "4", "8")
          "memory" = "16Gi"    # Adjust based on models and workload (e.g., "4Gi", "8Gi", "16Gi", "32Gi")
          "gpu"    = var.gpu_count
        }
        # Set startup boost for faster cold starts (recommended for Gen 2)
        startup_cpu_boost = true
      }

      # Optional: Mount volumes (e.g., Cloud Storage for models)
      /*
      volume_mounts {
        name       = "models-volume"
        mount_path = "/ComfyUI/models" # Mount inside the container where ComfyUI expects models
      }
      */

      # Define the GPU type
      gpu {
        type = var.gpu_type
        count = var.gpu_count
      }

      # Optional: Environment variables for ComfyUI if needed
      /*
      env {
        name  = "COMFYUI_MODEL_DIR"
        value = "/ComfyUI/models" # Example if using volume mount
      }
      env {
        name = "ANOTHER_VAR"
        value = "some_value"
      }
      */
    }

    # Optional: Define volumes (e.g., Cloud Storage bucket)
    /*
    volumes {
      name = "models-volume"
      gcs {
        bucket = "your-comfyui-models-bucket-name" # Replace with your GCS bucket name
        read_only = false # Or true if only reading models
      }
    }
    */

    # Set timeout for requests (adjust as needed for long generations)
    timeout = "3600s" # Max allowed is 3600 seconds (1 hour)
  }

  # Traffic splitting (usually 100% to latest)
  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }
}

# IAM binding to allow invocation
resource "google_cloud_run_v2_service_iam_member" "invoker" {
  count    = var.allow_unauthenticated ? 1 : 0 # Only create if public access is desired
  project  = google_cloud_run_v2_service.comfyui_service.project
  location = google_cloud_run_v2_service.comfyui_service.location
  name     = google_cloud_run_v2_service.comfyui_service.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

output "service_url" {
  description = "URL of the deployed ComfyUI Cloud Run service."
  value       = google_cloud_run_v2_service.comfyui_service.uri
}

output "service_name_output" {
  description = "Name of the deployed ComfyUI Cloud Run service."
  value       = google_cloud_run_v2_service.comfyui_service.name
}