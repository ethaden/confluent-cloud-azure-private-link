module "terraform_pki" {
    source = "github.com/ethaden/terraform-local-pki.git"

    cert_path = local.cert_path
    organization = "Confluent Inc"
    ca_common_name = var.vpn_ca_common_name
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

resource "azurerm_virtual_network_dns_servers" "vnet_dns" {
  virtual_network_id = azurerm_virtual_network.vnet.id
  dns_servers        = [var.dns_resolver_ip]
}

resource "azurerm_subnet" "subnet" {
  address_prefixes = ["10.0.1.0/24"]

  name                 = "default"
  virtual_network_name = azurerm_virtual_network.vnet.name
  resource_group_name  = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "vpngwsubnet" {
  address_prefixes = ["10.0.253.0/24"]

  name                 = "GatewaySubnet"
  virtual_network_name = azurerm_virtual_network.vnet.name
  resource_group_name  = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "resolversubnet" {
  address_prefixes = [var.dns_resolver_subnet]

  name                 = "ResolverSubnet"
  virtual_network_name = azurerm_virtual_network.vnet.name
  resource_group_name  = azurerm_resource_group.rg.name

  delegation {
    name = "Microsoft.Network.dnsResolvers"
    service_delegation {
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      name    = "Microsoft.Network/dnsResolvers"
    }
  }
}
resource "azurerm_private_dns_resolver" "resolver" {
  name                = "${local.resource_prefix}_dns_resolver"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  virtual_network_id  = azurerm_virtual_network.vnet.id
}

resource "azurerm_private_dns_resolver_inbound_endpoint" "resolver_inbound" {
  name                    = "${local.resource_prefix}_dns_resolver_inbound"
  private_dns_resolver_id = azurerm_private_dns_resolver.resolver.id
  location                = azurerm_private_dns_resolver.resolver.location
  ip_configurations {
    private_ip_allocation_method = "Static"
    private_ip_address           = var.dns_resolver_ip
    subnet_id                    = azurerm_subnet.resolversubnet.id
  }
  tags = {
    key = "value"
  }
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

  subnet_id = azurerm_subnet.subnet.id

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

# resource "azurerm_virtual_hub" "vpn" {
#   name                = "${local.resource_prefix}_hub"
#   resource_group_name = azurerm_resource_group.rg.name
#   location            = azurerm_resource_group.rg.location
#   virtual_wan_id      = azurerm_virtual_wan.vpn.id
#   hub_routing_preference = "VpnGateway"
#   address_prefix      = "10.0.253.0/24"
# }

# resource "azurerm_vpn_server_configuration" "vpn_config" {
#   name                     = "${local.resource_prefix}-vpn-config"
#   resource_group_name      = azurerm_resource_group.rg.name
#   location                 = azurerm_resource_group.rg.location
#   vpn_authentication_types = ["Certificate"]
#   vpn_protocols = ["OpenVPN"]

#   client_root_certificate {
#     #name             = "${local.resource_prefix}_VPNGW_RootCA"
#     name = var.vpn_ca_common_name
#     #public_cert_data = module.terraform_pki.server_certs["vpn-gateway"].cert_pem
#     public_cert_data = data.external.ca_der.result["CERT_DER"]
#   }
# }

# The following is not working as no public IP can be configured
# resource "azurerm_point_to_site_vpn_gateway" "vpn_gw" {
#   name                = "${local.resource_prefix}_vpngw"
#   location            = azurerm_resource_group.rg.location
#   resource_group_name = azurerm_resource_group.rg.name
#   virtual_hub_id      = azurerm_virtual_hub.vpn.id
#   vpn_server_configuration_id = azurerm_vpn_server_configuration.vpn_config.id
#   # We route through public internet. Be careful!
#   routing_preference_internet_enabled = true
#   scale_unit                  = 1
#   connection_configuration {
#     name = "${local.resource_prefix}-gateway-config"

#     vpn_client_address_pool {
#       address_prefixes = [
#         "10.0.254.0/24"
#       ]
#     }
#   }
# }

# Instead, a virtual network gateway is used
resource "azurerm_virtual_network_gateway" "vpngw" {
  name                = "${local.resource_prefix}_vpngw"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  type     = "Vpn"
  vpn_type = "RouteBased"

  active_active = false
  enable_bgp    = false
  sku           = "VpnGw1AZ"
  remote_vnet_traffic_enabled = true
  

  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.vpngw.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.vpngwsubnet.id

  }
  
  vpn_client_configuration {
    address_space = ["10.254.0.0/24"]
    vpn_client_protocols = ["OpenVPN"]
    vpn_auth_types = ["Certificate"]

    root_certificate {
      name = var.vpn_ca_common_name
      public_cert_data = data.external.ca_der.result["CERT_DER"]
    }
  }
}

# resource "azurerm_subnet" "vpngw_firewall" {
#   name                 = "AzureFirewallSubnet"
#   resource_group_name  = azurerm_resource_group.rg.name
#   virtual_network_name = azurerm_virtual_network.vnet.name
#   address_prefixes     = ["10.0.254.0/24"]
# }

resource "azurerm_public_ip" "vpngw" {
  name                = "${local.resource_prefix}_vpngw_public_ip"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1"]
  tags = local.confluent_tags
}

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

resource "local_sensitive_file" "openvpn_config_files" {
  for_each = toset(local.vpn_client_names)

  content = templatefile("${path.module}/templates/openvpn-config.tpl",
  {
    vpn_gateway_endpoint = "${var.dns_vpngw_record}.${var.dns_vpngw_zone}",
    ca_cert_pem = "${module.terraform_pki.ca_cert.cert_pem}",
    client_cert_pem = module.terraform_pki.client_certs[each.key].cert_pem,
    client_key_pem = module.terraform_pki.client_keys[each.key].private_key_pem
  }
  )
  filename = "${var.generated_files_path}/openvpn_config_files/openvpn-config-${each.key}.ovpn"
}

data "external" "ca_der" {
  program = ["${path.module}/convert-pem-to-der.sh", "${local.cert_path}/ca_crt.pem"]
}

data "azurerm_dns_zone" "vpngw_zone" {
  name = var.dns_vpngw_zone
  resource_group_name = var.dns_vpngw_resource_group
}
resource "azurerm_dns_a_record" "vpngw_record" {
  name                = var.dns_vpngw_record
  resource_group_name = var.dns_vpngw_resource_group
  zone_name           = var.dns_vpngw_zone
  ttl                 = var.dns_vpngw_ttl
  target_resource_id = azurerm_public_ip.vpngw.id
}

resource "azurerm_lb" "intra_vnet_lb" {
  name                = "${local.resource_prefix}_intra_vnet_lb"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.example.id
  }
}

resource "azurerm_lb_backend_address_pool" "example" {
  loadbalancer_id = azurerm_lb.example.id
  name            = "BackEndAddressPool"
}