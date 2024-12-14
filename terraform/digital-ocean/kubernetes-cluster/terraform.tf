terraform {

  backend "s3" {
    endpoints = {
      s3 = "https://lon1.digitaloceanspaces.com"
    }
    region                      = "lon1"
    bucket                      = "gym-track"
    key                         = "infrastructure/terraform.tfstate"
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_s3_checksum            = true
  }

  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }

  required_version = "~> 1.9"
}

