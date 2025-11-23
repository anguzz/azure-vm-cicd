########################################
# Terraform Backend and Provider
########################################
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "anguzzdevopsdemo"
    container_name       = "tfstate"
    key                  = "rg-devops-demo.tfstate"
    
    use_oidc             = true
    use_azuread_auth     = true 
  }
 
  required_version = ">=0.12"

  required_providers {
    azapi = {
      source  = "azure/azapi"
      version = "~>1.5"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.0"
    }
  }
}

provider "azurerm" {
  features {}
  use_oidc = true
}