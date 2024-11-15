terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "4.7.0"
    }
  }
}

provider "azurerm" {
  features {
  }
  subscription_id = var.azure_subscription_id
  tenant_id       = var.azure_tenant_id
}
