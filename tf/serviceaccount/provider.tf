# https://registry.terraform.io/providers/hashicorp/google/latest/docs/guides/provider_reference
  
terraform {

  required_version = ">= 0.14.0"

  required_providers {
    google = {
      source = "hashicorp/google"
      version = "4.11.0"
    }
  }

  # local backend state
}

provider "google" {
      # prereq: gcloud auth application-default login

      project     = var.project
      region      = var.region
      zone        = var.zone
}

provider "google-beta" {
      # prereq: gcloud auth application-default login

      project     = var.project
      region      = var.region
      zone        = var.zone
}



