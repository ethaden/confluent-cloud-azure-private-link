module "terraform_pki" {
    source = "github.com/ethaden/terraform-local-pki.git"

    cert_path = "${var.generated_files_path}/client_vpn_pki"
    organization = "Confluent Inc"
    ca_common_name = "Confluent Inc ${local.username} Test CA"
    server_names = { "vpn-gateway": "vpn-gateway.${var.vpn_base_domain}" }
    client_names = local.vpn_client_names_to_domain
    # Unfortunately, AWS Client VPN Endpoints only support RSA with max. 2048 bits
    algorithm = "RSA"
    rsa_bits = 2048
}
resource "azurerm_resource_group" "rg" {
  name     = var.azure_resource_group_name
  location = var.azure_region

  lifecycle {
    prevent_destroy = false
  }

  tags = local.confluent_tags
}

resource "azurerm_virtual_network" "vnet" {
  name                = "${local.resource_prefix}_network"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  address_space       = ["10.0.0.0/16"]

  lifecycle {
    prevent_destroy = false
  }
  tags = {
    owner_email = local.confluent_tags["owner_email"]
  }
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

# Azure VPN, required for creating point-to-net connection which is a pre-condition for setting up CCloud resources
# This means, terraform needs to run at least twice and setting up any cluster-specific resources will fail during the first run.
# Make sure you connected your machine to the VPN when running terraform the second time
resource "azurerm_virtual_wan" "vpn" {
  name                = "${local.resource_prefix}_vwan"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
}

resource "azurerm_virtual_hub" "vpn" {
  name                = "${local.resource_prefix}_hub"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  virtual_wan_id      = azurerm_virtual_wan.vpn.id
  hub_routing_preference = "VpnGateway"
  address_prefix      = "10.0.253.0/24"
}

resource "azurerm_vpn_server_configuration" "vpn_config" {
  name                     = "${local.resource_prefix}-vpn-config"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  vpn_authentication_types = ["Certificate"]
  vpn_protocols = ["OpenVPN"]

  client_root_certificate {
    name             = "${local.resource_prefix}_VPNGW_RootCA"
    public_cert_data = module.terraform_pki.server_certs["vpn-gateway"].cert_pem
  }
}

resource "azurerm_point_to_site_vpn_gateway" "vpn_gw" {
  name                = "${local.resource_prefix}_vpngw"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  virtual_hub_id      = azurerm_virtual_hub.vpn.id
  vpn_server_configuration_id = azurerm_vpn_server_configuration.vpn_config.id
  # We route through public internet. Be careful!
  routing_preference_internet_enabled = true
  scale_unit                  = 1
  connection_configuration {
    name = "${local.resource_prefix}-gateway-config"

    vpn_client_address_pool {
      address_prefixes = [
        "10.0.254.0/24"
      ]
    }
  }
}

# resource "azurerm_subnet" "vpngw_firewall" {
#   name                 = "AzureFirewallSubnet"
#   resource_group_name  = azurerm_resource_group.rg.name
#   virtual_network_name = azurerm_virtual_network.vnet.name
#   address_prefixes     = ["10.0.254.0/24"]
# }

# resource "azurerm_public_ip" "vpngw" {
#   name                = "${local.resource_prefix}_vpngw_public_ip"
#   resource_group_name = azurerm_resource_group.rg.name
#   location            = azurerm_resource_group.rg.location
#   allocation_method   = "Static"
#   sku                 = "Standard"
#   tags = local.confluent_tags
# }

# resource "azurerm_firewall" "vpngw" {
#   name                = "${local.resource_prefix}_vpngw_firewall"
#   location            = azurerm_resource_group.gw.location
#   resource_group_name = azurerm_resource_group.gw.name
#   sku_name            = "AZFW_VNet"
#   sku_tier            = "Standard"

#   ip_configuration {
#     name                 = "configuration"
#     subnet_id            = azurerm_subnet.vpngw_firewall.id
#     public_ip_address_id = azurerm_public_ip.vpngw.id
#   }
# }

# resource "local_sensitive_file" "openvpn_config_files" {
#   for_each = toset(local.vpn_client_names)

#   content = templatefile("${path.module}/templates/openvpn-config.tpl",
#   {
#     vpn_gateway_endpoint = aws_ec2_client_vpn_endpoint.vpn.dns_name,
#     ca_cert_pem = "${module.terraform_pki.ca_cert.cert_pem}",
#     client_cert_pem = module.terraform_pki.client_certs[each.key].cert_pem,
#     client_key_pem = module.terraform_pki.client_keys[each.key].private_key_pem
#   }
#   )
#   filename = "${var.generated_files_path}/openvpn_config_files/openvpn-config-${each.key}.ovpn"
# }
