# ==============================================================================
# NexaRetail DevOps Platform — Terraform Providers
# ==============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.110.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.53.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.31.0"
    }
  }

  # Sauvegarde de l'etat Terraform dans Azure (qui possede quoi)
  backend "azurerm" {
    resource_group_name  = "nexaretail-tfstate-rg"
    storage_account_name = "nexaretailtfstate"
    container_name       = "tfstate"
    key                  = "prod/terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
}

provider "azuread" {}
