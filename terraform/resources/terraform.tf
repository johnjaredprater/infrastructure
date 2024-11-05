terraform {

  backend "s3" {
    bucket = "eks-terraform-state-gym-track"
    key    = "resources/terraform.tfstate"
    region = "eu-west-2"
  }

  required_providers {

    random = {
      source  = "hashicorp/random"
      version = "~> 3.6.1"
    }

    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0.5"
    }

    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = "~> 2.3.4"
    }
  }

  required_version = "~> 1.3"
}

