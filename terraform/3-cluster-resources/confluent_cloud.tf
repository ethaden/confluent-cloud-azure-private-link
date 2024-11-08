# Confluent Cloud Kafka Cluster
data "confluent_environment" "env" {
  display_name = var.ccloud_environment_name
}

# Set up a basic cluster (or a standard cluster, see below)
data "confluent_kafka_cluster" "example_dedicated_cluster" {
  display_name = var.ccloud_cluster_name
  environment {
    id = data.confluent_environment.env.id
  }
}

# Topic with configured name
resource "confluent_kafka_topic" "example_dedicated_topic_test" {
  kafka_cluster {
    id = data.confluent_kafka_cluster.example_dedicated_cluster.id
  }
  topic_name         = var.ccloud_cluster_topic
  rest_endpoint      = data.confluent_kafka_cluster.example_dedicated_cluster.rest_endpoint
  partitions_count = 1
  credentials {
    key    = confluent_api_key.example_dedicated_api_key_sa_cluster_admin.id
    secret = confluent_api_key.example_dedicated_api_key_sa_cluster_admin.secret
  }

  # Required to make sure the role binding is created before trying to create a topic using these credentials
  depends_on = [ confluent_role_binding.example_dedicated_role_binding_cluster_admin ]

  lifecycle {
    prevent_destroy = false
  }
}

# Service Account, API Key and role bindings for the cluster admin
resource "confluent_service_account" "example_dedicated_sa_cluster_admin" {
  display_name = "${local.resource_prefix}_example_dedicated_sa_cluster_admin"
  description  = "Service Account mTLS Example Cluster Admin"
}

# An API key with Cluster Admin access. Required for provisioning the cluster-specific resources such as our topic
resource "confluent_api_key" "example_dedicated_api_key_sa_cluster_admin" {
  display_name = "${local.resource_prefix}_example_dedicated_api_key_sa_cluster_admin"
  description  = "Kafka API Key that is owned by '${local.resource_prefix}_example_dedicated_sa_cluster_admin' service account"
  owner {
    id          = confluent_service_account.example_dedicated_sa_cluster_admin.id
    api_version = confluent_service_account.example_dedicated_sa_cluster_admin.api_version
    kind        = confluent_service_account.example_dedicated_sa_cluster_admin.kind
  }

  managed_resource {
    id          = data.confluent_kafka_cluster.example_dedicated_cluster.id
    api_version = data.confluent_kafka_cluster.example_dedicated_cluster.api_version
    kind        = data.confluent_kafka_cluster.example_dedicated_cluster.kind

    environment {
      id = data.confluent_environment.env.id
    }
  }

  lifecycle {
    prevent_destroy = false
  }
}

# Assign the CloudClusterAdmin role to the cluster admin service account
resource "confluent_role_binding" "example_dedicated_role_binding_cluster_admin" {
  principal   = "User:${confluent_service_account.example_dedicated_sa_cluster_admin.id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern = data.confluent_kafka_cluster.example_dedicated_cluster.rbac_crn
  lifecycle {
    prevent_destroy = false
  }
}

# Service Account, API Key and role bindings for the producer
resource "confluent_service_account" "example_dedicated_sa_producer" {
  display_name = "${local.resource_prefix}_example_dedicated_sa_producer"
  description  = "Service Account mTLS Example Producer"
}

resource "confluent_api_key" "example_dedicated_api_key_producer" {
  display_name = "${local.resource_prefix}_example_dedicated_api_key_producer"
  description  = "Kafka API Key that is owned by '${local.resource_prefix}_example_dedicated_sa' service account"
  owner {
    id          = confluent_service_account.example_dedicated_sa_producer.id
    api_version = confluent_service_account.example_dedicated_sa_producer.api_version
    kind        = confluent_service_account.example_dedicated_sa_producer.kind
  }

  managed_resource {
    id          = data.confluent_kafka_cluster.example_dedicated_cluster.id
    api_version = data.confluent_kafka_cluster.example_dedicated_cluster.api_version
    kind        = data.confluent_kafka_cluster.example_dedicated_cluster.kind

    environment {
      id = data.confluent_environment.env.id
    }
  }

  lifecycle {
    prevent_destroy = false
  }
}

# For role bindings such as DeveloperRead and DeveloperWrite at least a standard cluster type would be required. We use ACLs instead for basic clusters
resource "confluent_role_binding" "example_dedicated_role_binding_producer" {
  # Instaniciate this block only if the cluster type is NOT basic
  principal   = "User:${confluent_service_account.example_dedicated_sa_producer.id}"
  role_name   = "DeveloperWrite"
  crn_pattern = "${data.confluent_kafka_cluster.example_dedicated_cluster.rbac_crn}/kafka=${data.confluent_kafka_cluster.example_dedicated_cluster.id}/topic=${confluent_kafka_topic.example_dedicated_topic_test.topic_name}"
  lifecycle {
    prevent_destroy = false
  }
}

# Service Account, API Key and role bindings for the consumer
resource "confluent_service_account" "example_dedicated_sa_consumer" {
  display_name = "${local.resource_prefix}_example_dedicated_sa_consumer"
  description  = "Service Account mTLS Lambda Example Consumer"
}


resource "confluent_api_key" "example_dedicated_api_key_consumer" {
  display_name = "${local.resource_prefix}_example_dedicated_api_key_consumer"
  description  = "Kafka API Key that is owned by '${local.resource_prefix}_example_dedicated_sa' service account"
  owner {
    id          = confluent_service_account.example_dedicated_sa_consumer.id
    api_version = confluent_service_account.example_dedicated_sa_consumer.api_version
    kind        = confluent_service_account.example_dedicated_sa_consumer.kind
  }

  managed_resource {
    id          = data.confluent_kafka_cluster.example_dedicated_cluster.id
    api_version = data.confluent_kafka_cluster.example_dedicated_cluster.api_version
    kind        = data.confluent_kafka_cluster.example_dedicated_cluster.kind

    environment {
      id = data.confluent_environment.env.id
    }
  }

  lifecycle {
    prevent_destroy = false
  }
}

# For role bindings such as DeveloperRead and DeveloperWrite at least a standard cluster type would be required. Let's use ACLs instead
resource "confluent_role_binding" "example_dedicated_role_binding_consumer" {
  # Instaniciate this block only if the cluster type is NOT basic
  principal   = "User:${confluent_service_account.example_dedicated_sa_consumer.id}"
  role_name   = "DeveloperRead"
  crn_pattern = "${data.confluent_kafka_cluster.example_dedicated_cluster.rbac_crn}/kafka=${data.confluent_kafka_cluster.example_dedicated_cluster.id}/topic=${confluent_kafka_topic.example_dedicated_topic_test.topic_name}"
  lifecycle {
    prevent_destroy = false
  }
}
resource "confluent_role_binding" "example_dedicated_role_binding_consumer_group" {
  # Instaniciate this block only if the cluster type is NOT basic
  principal   = "User:${confluent_service_account.example_dedicated_sa_consumer.id}"
  role_name   = "DeveloperRead"
  crn_pattern = "${data.confluent_kafka_cluster.example_dedicated_cluster.rbac_crn}/kafka=${data.confluent_kafka_cluster.example_dedicated_cluster.id}/group=${var.ccloud_cluster_consumer_group_prefix}*"
  lifecycle {
    prevent_destroy = false
  }
}

output "cluster_bootstrap_server" {
   value = data.confluent_kafka_cluster.example_dedicated_cluster.bootstrap_endpoint
}
output "cluster_rest_endpoint" {
    value = data.confluent_kafka_cluster.example_dedicated_cluster.rest_endpoint
}

# The next entries demonstrate how to output the generated API keys to the console even though they are considered to be sensitive data by Terraform
# Uncomment these lines if you want to generate that output
# output "cluster_api_key_admin" {
#     value = nonsensitive("Key: ${confluent_api_key.example_dedicated_api_key_sa_cluster_admin.id}\nSecret: ${confluent_api_key.example_dedicated_api_key_sa_cluster_admin.secret}")
# }

# output "cluster_api_key_producer" {
#     value = nonsensitive("Key: ${confluent_api_key.example_dedicated_api_key_producer.id}\nSecret: ${confluent_api_key.example_dedicated_api_key_producer.secret}")
# }

# output "cluster_api_key_consumer" {
#     value = nonsensitive("Key: ${confluent_api_key.example_dedicated_api_key_consumer.id}\nSecret: ${confluent_api_key.example_dedicated_api_key_consumer.secret}")
# }

# Generate console client configuration files for testing in subfolder "generated/client-configs"
# PLEASE NOTE THAT THESE FILES CONTAIN SENSITIVE CREDENTIALS
resource "local_sensitive_file" "client_config_files" {
  # Do not generate any files if var.ccloud_cluster_generate_client_config_files is false
  for_each = var.ccloud_cluster_generate_client_config_files ? {
    "admin" = confluent_api_key.example_dedicated_api_key_sa_cluster_admin,
    "producer" = confluent_api_key.example_dedicated_api_key_producer,
    "consumer" = confluent_api_key.example_dedicated_api_key_consumer} : {}

  content = templatefile("${path.module}/templates/client.conf.tpl",
  {
    client_name = "${each.key}"
    cluster_bootstrap_server = trimprefix("${data.confluent_kafka_cluster.example_dedicated_cluster.bootstrap_endpoint}", "SASL_SSL://")
    api_key = "${each.value.id}"
    api_secret = "${each.value.secret}"
    topic = var.ccloud_cluster_topic
    consumer_group_prefix = var.ccloud_cluster_consumer_group_prefix
  }
  )
  filename = "${var.generated_files_path}/client-${each.key}.conf"
}
