
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

variable "ccloud_create_api_keys" {
    type = bool
    default = false
    description = "If set to true, creates api keys and roles"
}
