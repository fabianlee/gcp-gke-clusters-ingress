# https://registry.terraform.io/providers/hashicorp/google/latest/docs/guides/provider_reference
  
terraform {

  required_version = ">= 0.14.0"

  required_providers {
    google = {
      source = "hashicorp/google"
      version = "3.67.0"
    }
  }

  # local backend state
}

provider "google" {
      # do not need json key if working using: gcloud auth application-default login
      credentials = file("${path.module}/../../tf-creator.json")

      project     = var.project
      region      = var.region
      zone        = var.zone
}

provider "google-beta" {
      # do not need json key if working using: gcloud auth application-default login
      credentials = file("${path.module}/../../tf-creator.json")

      project     = var.project
      region      = var.region
      zone        = var.zone
}



