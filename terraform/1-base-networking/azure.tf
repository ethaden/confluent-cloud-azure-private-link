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

# Azure VPN, required for creating point-to-net connection which is a pre-condition for setting up CCloud resources
# This means, terraform needs to run at least twice and setting up any cluster-specific resources will fail during the first run.
# Make sure you connected your machine to the VPN when running terraform the second time
resource "azurerm_virtual_wan" "vpn" {
  name                = "${local.resource_prefix}_vwan"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
}

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

resource "azurerm_public_ip" "vpngw" {
  name                = "${local.resource_prefix}_vpngw_public_ip"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1"]
  tags = local.confluent_tags
}

resource "local_sensitive_file" "openvpn_config_files" {
  for_each = toset(local.vpn_client_names)

  content = templatefile("${path.module}/templates/openvpn-config.tpl",
  {
    client_cert_pem = module.terraform_pki.client_certs[each.key].cert_pem,
    client_key_pem = module.terraform_pki.client_keys[each.key].private_key_pem
    dns_resolver_ip = var.dns_resolver_ip
  }
  )
  filename = "${var.generated_files_path}/openvpn_config_files/openvpn-config-${each.key}.ovpn"
}

data "external" "ca_der" {
  program = ["${path.module}/convert-pem-to-der.sh", "${local.cert_path}/ca_crt.pem"]
}
