
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

variable "azure_internal_load_balancer_frontend_ip_bootstrap_server" {
    type = string
    default = "10.0.1.10"
    description = "The first frontend IP of the load balancer used to make the Kafka cluster available via private link service from a different vnet"
}

variable "azure_internal_load_balancer_frontend_ip_broker1" {
    type = string
    default = "10.0.1.11"
    description = "The first frontend IP of the load balancer used to make the Kafka cluster available via private link service from a different vnet"
}

variable "azure_internal_load_balancer_frontend_ip_broker2" {
    type = string
    default = "10.0.1.12"
    description = "The second frontend IP of the load balancer used to make the Kafka cluster available via private link service from a different vnet"
}

variable "azure_internal_load_balancer_frontend_ip_broker3" {
    type = string
    default = "10.0.1.13"
    description = "The second frontend IP of the load balancer used to make the Kafka cluster available via private link service from a different vnet"
}

variable "ccloud_private_endpoint_ip1" {
    type = string
    default = "10.0.1.4"
    description = "The IP address of the first endpoint to the Confluent Cloud dedicated cluster"
}

variable "ccloud_private_endpoint_ip2" {
    type = string
    default = "10.0.1.5"
    description = "The IP address of the second endpoint to the Confluent Cloud dedicated cluster"
}

variable "ccloud_private_endpoint_ip3" {
    type = string
    default = "10.0.1.6"
    description = "The IP address of the third endpoint to the Confluent Cloud dedicated cluster"
}
