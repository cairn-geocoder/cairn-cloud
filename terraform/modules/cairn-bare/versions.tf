terraform {
  required_version = ">= 1.5.0"

  required_providers {
    nomad = {
      source  = "hashicorp/nomad"
      version = ">= 2.2.0, < 3.0.0"
    }
    consul = {
      source  = "hashicorp/consul"
      version = ">= 2.20.0, < 3.0.0"
    }
  }
}
