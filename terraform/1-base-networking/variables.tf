
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
