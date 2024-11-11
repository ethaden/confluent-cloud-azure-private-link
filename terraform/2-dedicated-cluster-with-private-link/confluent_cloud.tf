# Confluent Cloud Kafka Cluster
resource "confluent_environment" "env" {
  display_name = var.ccloud_environment_name

  stream_governance {
    package = "ESSENTIALS"
  }
}

resource "confluent_network" "private-link" {
  display_name     = "Private Link Network"
  cloud            = "AZURE"
  region           = var.azure_region
  connection_types = ["PRIVATELINK"]
  environment {
    id = confluent_environment.env.id
  }
  dns_config {
    resolution = "PRIVATE"
  }
}

resource "confluent_private_link_access" "azure" {
  display_name = "Azure Private Link Access"
  azure {
    subscription = var.azure_subscription_id
  }
  environment {
    id = confluent_environment.env.id
  }
  network {
    id = confluent_network.private-link.id
  }
}

# Set up a basic cluster (or a standard cluster, see below)
resource "confluent_kafka_cluster" "example_dedicated_cluster" {
  display_name = var.ccloud_cluster_name
  availability = var.ccloud_cluster_availability
  cloud        = var.ccloud_cluster_cloud_provider
  region       = var.azure_region
  # Use standard if you want to have the ability to grant role bindings on topic scope
  # standard {}
  # For cost reasons, we use a basic cluster by default. However, you can choose a different type by setting the variable ccloud_cluster_type
  # As each different type is represented by a unique block in the cluster resource, we use dynamic blocks here.
  # Only exactly one can be active due to the way we've chosen the condition for "for_each"
  dynamic "basic" {
    for_each = var.ccloud_cluster_type=="basic" ? [true] : []
    content {
    }
  }
  dynamic "standard" {
    for_each = var.ccloud_cluster_type=="standard" ? [true] : []
    content {
    }
  }
  dynamic "enterprise" {
    for_each = var.ccloud_cluster_type=="enterprise" ? [true] : []
    content {
    }
  }
  dynamic "dedicated" {
    for_each = var.ccloud_cluster_type=="dedicated" ? [true] : []
    content {
        cku = var.ccloud_cluster_ckus
    }
  }
  dynamic "freight" {
    for_each = var.ccloud_cluster_type=="freight" ? [true] : []
    content {
    }
  }

  environment {
    id = confluent_environment.env.id
  }

  network {
    id = confluent_network.private-link.id
  }

  lifecycle {
    prevent_destroy = false
  }
}

locals {
  dns_domain = confluent_network.private-link.dns_domain
  network_id = split(".", local.dns_domain)[0]
}

resource "azurerm_private_dns_zone" "hz" {
  resource_group_name = data.azurerm_resource_group.rg.name

  name = local.dns_domain
  tags = local.confluent_tags
}

resource "azurerm_private_endpoint" "endpoint" {
  for_each = var.subnet_name_by_zone

  name                = "confluent-${local.network_id}-${each.key}"
  location            = var.azure_region
  resource_group_name = data.azurerm_resource_group.rg.name

  subnet_id = data.azurerm_subnet.subnet.id

  private_service_connection {
    name                              = "confluent-${local.network_id}-${each.key}"
    is_manual_connection              = true
    private_connection_resource_alias = lookup(confluent_network.private-link.azure[0].private_link_service_aliases, each.key, "\n\nerror: ${each.key} subnet is missing from CCN's Private Link service aliases")
    request_message                   = "PL"
  }
  ip_configuration {
    name = "confluent-${local.network_id}-${each.key}"
    private_ip_address = cidrhost(data.azurerm_subnet.subnet.address_prefix, each.key+3)
  }
  tags = local.confluent_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "hz" {
  name                  = data.azurerm_virtual_network.vnet.name
  resource_group_name   = data.azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.hz.name
  virtual_network_id    = data.azurerm_virtual_network.vnet.id
  tags = local.confluent_tags
}

resource "azurerm_private_dns_a_record" "rr" {
  name                = "*"
  zone_name           = azurerm_private_dns_zone.hz.name
  resource_group_name = data.azurerm_resource_group.rg.name
  ttl                 = 60
  records = [
    for _, ep in azurerm_private_endpoint.endpoint : ep.private_service_connection[0].private_ip_address
  ]
  tags = local.confluent_tags
}

resource "azurerm_private_dns_a_record" "zonal" {
  for_each = var.subnet_name_by_zone

  name                = "*.az${each.key}"
  zone_name           = azurerm_private_dns_zone.hz.name
  resource_group_name = data.azurerm_resource_group.rg.name
  ttl                 = 60
  records = [
    azurerm_private_endpoint.endpoint[each.key].private_service_connection[0].private_ip_address,
  ]
  tags = local.confluent_tags
}
