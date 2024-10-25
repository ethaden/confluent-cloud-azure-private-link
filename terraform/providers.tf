terraform {
  required_providers {
    confluent = {
      source = "confluentinc/confluent"
      version = "2.7.0"
    }
    azurerm = {
      source = "hashicorp/azurerm"
      version = "4.7.0"
    }
  }
}

provider "confluent" {
  cloud_api_key    = local.confluent_creds.api_key
  cloud_api_secret = local.confluent_creds.api_secret
}

provider "azurerm" {
  features {
  }
  subscription_id = var.azure_subscription_id
  tenant_id       = var.azure_tenant_id
}
