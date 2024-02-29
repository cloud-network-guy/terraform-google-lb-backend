terraform {
  required_version = ">= 1.3.4"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.84.0, < 6.0"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.1.0"
    }
  }
}
