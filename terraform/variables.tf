
# Recommendation: Overwrite the default in tfvars or stick with the automatic default
variable "tf_last_updated" {
    type = string
    default = ""
    description = "Set this (e.g. in terraform.tfvars) to set the value of the tf_last_updated tag for all resources. If unset, the current date/time is used automatically."
}

variable "purpose" {
    type = string
    default = "Testing"
    description = "The purpose of this configuration, used e.g. as tags for AWS resources"
}

variable "username" {
    type = string
    default = ""
    description = "Username, used to define local.username if set here. Otherwise, the logged in username is used."
}

variable "owner" {
    type = string
    default = ""
    description = "All resources are tagged with an owner tag. If none is provided in this variable, a useful value is derived from the environment"
}

# The validator uses a regular expression for valid email addresses (but NOT complete with respect to RFC 5322)
variable "owner_email" {
    type = string
    default = ""
    description = "All resources are tagged with an owner_email tag. If none is provided in this variable, a useful value is derived from the environment"
    validation {
        condition = anytrue([
            var.owner_email=="",
            can(regex("^[a-zA-Z0-9_.+-]+@([a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9]+)*\\.)+[a-zA-Z]+$", var.owner_email))
        ])
        error_message = "Please specify a valid email address for variable owner_email or leave it empty"
    }
}

variable "owner_fullname" {
    type = string
    default = ""
    description = "All resources are tagged with an owner_fullname tag. If none is provided in this variable, a useful value is derived from the environment"
}

variable "resource_prefix" {
    type = string
    default = ""
    description = "This string will be used as prefix for generated resources. Default is to use the username"
}

variable "generated_files_path" {
    description = "The main path to write generated files to"
    type = string
    default = "./generated"
}

variable "ccloud_environment_name" {
    type = string
    description = "Name of the Confluent Cloud environment to use"
}

variable "ccloud_cluster_cloud_provider" {
    type = string
    default = "AZURE"
    description = "The cloud provider of the Confluent Cloud Kafka cluster"
    validation {
        condition = var.ccloud_cluster_cloud_provider=="AWS" || var.ccloud_cluster_cloud_provider=="AZURE" || var.ccloud_cluster_cloud_provider=="GCP"
        error_message = "The cloud provider of the Confluent Cloud cluster must either by \"AWS\", \"AZURE\" or \"GCP\""
    }
}

variable "ccloud_cluster_name" {
    type = string
    description = "Name of the cluster to be created"
}

variable "azure_subscription_id" {
    type = string
    description = "The Azure subscription ID"
}

variable "azure_tenant_id" {
    type = string
    description = "The Azure tenant ID"
}

variable "azure_region" {
    type = string
    default = "germanywestcentral"
    description = "The region used to deploy the Confluent Cloud Kafka cluster and all Azure resources"
}

variable "subnet_name_by_zone" {
  description = "A map of Zone to Subnet Name"
  type        = map(string)
}

variable "ccloud_cluster_type" {
    type = string
    default = "dedicated"
    description = "The cluster type of the Confluent Cloud Kafka cluster. Valid values are \"basic\", \"standard\", \"dedicated\", \"enterprise\", \"freight\""
    validation {
        condition = var.ccloud_cluster_type=="basic" || var.ccloud_cluster_type=="standard" || var.ccloud_cluster_type=="dedicated" || var.ccloud_cluster_type=="enterprise" || var.ccloud_cluster_type=="freight"
        error_message = "Valid Confluent Cloud cluster types are \"basic\", \"standard\", \"dedicated\", \"enterprise\""
    }
}

variable "ccloud_cluster_availability" {
    type = string
    default = "SINGLE_ZONE"
    description = "The availability of the Confluent Cloud Kafka cluster"
    validation {
        condition = var.ccloud_cluster_availability=="SINGLE_ZONE" || var.ccloud_cluster_availability=="MULTI_ZONE"
        error_message = "The availability of the Confluent Cloud cluster must either by \"SINGLE_ZONE\" or \"MULTI_ZONE\""
    }
}

variable "ccloud_cluster_ckus" {
    type = number
    default = 1
    description = "The number of CKUs to use if the Confluent Cloud Kafka cluster is \"dedicated\"."
    validation {
        condition = var.ccloud_cluster_ckus>=1
        error_message = "The minimum number of CKUs for a dedicated cluster is 1"
    }
}

variable "ccloud_cluster_topic" {
    type = string
    default = "test"
    description = "The name of the Kafka topic to create and to subscribe to"
}

variable "ccloud_cluster_consumer_group_prefix" {
    type = string
    default = "client-"
    description = "The name of the Kafka consumer group prefix to grant access to the Kafka consumer"
}

variable "ccloud_cluster_generate_client_config_files" {
    type = bool
    default = false
    description = "Set to true if you want to generate client configs with the created API keys under subfolder \"generated/client-configs\""
}

variable "azure_resource_group_name" {
    type = string
    description = "The name of the resource group to be created. Will NOT be suffixed"
}

variable "vpn_base_domain" {
    description = "The base domain used for creating the vpn gateway SSL certificate. Optional, does not have to be a valid domain"
    type = string
    default = "acme.invalid"
}

variable "vpn_ca_common_name" {
    type = string
    default = "Confluent_Inc_VPN_CA"
    description = "The common name of the generated CA used for VPN"
}

variable "vpn_client_names" {
    description = "List of client names (no whitespace allowed) to generate VPN client certificates for. If empty, generates just one certificate for the current username"
    type = list(string)
    default = []
}

variable "ccloud_create_api_keys" {
    type = bool
    default = false
    description = "If set to true, creates api keys and roles"
}
variable dns_resolver_ip {
    type = string
    default = "10.0.252.10"
    description = "IP address of the DNS resolver to be provisioned. Must be inside of var.dns_resolver_subnet."
}

variable dns_resolver_subnet {
    type = string
    default = "10.0.252.0/24"
    description = "The subnet of the DNS resolver to be provisioned. Do not use this subnet for anything else but the dns resolver"
}
