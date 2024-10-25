resource "azurerm_resource_group" "rg" {
  name     = var.azure_resource_group_name
  location = var.azure_region

  lifecycle {
    prevent_destroy = true
  }

  tags = local.confluent_tags
}

resource "azurerm_virtual_network" "vnet" {
  name                = "${local.resource_prefix}_network"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  address_space       = ["10.0.0.0/16"]

  lifecycle {
    prevent_destroy = true
  }
  tags = local.confluent_tags
}

resource "azurerm_subnet" "subnet" {
  for_each = var.subnet_name_by_zone

  address_prefixes = ["10.0.${each.key}.0/24"]

  name                 = each.value
  virtual_network_name = azurerm_virtual_network.vnet.name
  resource_group_name  = azurerm_resource_group.rg.name
}

locals {
  dns_domain = confluent_network.private-link.dns_domain
  network_id = split(".", local.dns_domain)[0]
}

resource "azurerm_private_dns_zone" "hz" {
  resource_group_name = azurerm_resource_group.rg.name

  name = local.dns_domain
  tags = local.confluent_tags
}

resource "azurerm_private_endpoint" "endpoint" {
  for_each = var.subnet_name_by_zone

  name                = "confluent-${local.network_id}-${each.key}"
  location            = var.azure_region
  resource_group_name = azurerm_resource_group.rg.name

  subnet_id = azurerm_subnet.subnet[each.key].id

  private_service_connection {
    name                              = "confluent-${local.network_id}-${each.key}"
    is_manual_connection              = true
    private_connection_resource_alias = lookup(confluent_network.private-link.azure[0].private_link_service_aliases, each.key, "\n\nerror: ${each.key} subnet is missing from CCN's Private Link service aliases")
    request_message                   = "PL"
  }
  tags = local.confluent_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "hz" {
  name                  = azurerm_virtual_network.vnet.name
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.hz.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  tags = local.confluent_tags
}

resource "azurerm_private_dns_a_record" "rr" {
  name                = "*"
  zone_name           = azurerm_private_dns_zone.hz.name
  resource_group_name = azurerm_resource_group.rg.name
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
  resource_group_name = azurerm_resource_group.rg.name
  ttl                 = 60
  records = [
    azurerm_private_endpoint.endpoint[each.key].private_service_connection[0].private_ip_address,
  ]
  tags = local.confluent_tags
}
