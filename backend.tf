terraform {
  required_version = ">= 1.3, <= 1.7.5"

  backend "gcs" {
    bucket = "your-bucket-name"
    key    = "terraform-lambda/terraform.tfstate"
    region = "us-central1"  # Update with your region
  }

  required_providers {
    random = {
      version = "~> 3.0"
    }

    google = {
      source  = "hashicorp/google"
      version = "~> 4.65"
    }
  }
}

provider "google" {
  region = var.gcp_region
}