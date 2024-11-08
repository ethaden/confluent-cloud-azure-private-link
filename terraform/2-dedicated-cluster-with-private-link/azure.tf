data "azurerm_resource_group" "rg" {
  name     = var.azure_resource_group_name
}

data "azurerm_virtual_network" "vnet" {
  name                = "${local.resource_prefix}_network"
  resource_group_name = data.azurerm_resource_group.rg.name
}

data "azurerm_subnet" "subnet" {
  name                 = "default"
  virtual_network_name = data.azurerm_virtual_network.vnet.name
  resource_group_name  = data.azurerm_resource_group.rg.name
}

# resource "azurerm_lb" "intra_vnet_lb" {
#   name                = "${local.resource_prefix}_intra_vnet_lb"
#   location            = azurerm_resource_group.rg.location
#   resource_group_name = azurerm_resource_group.rg.name

#   frontend_ip_configuration {
#     name                 = "PublicIPAddress"
#     public_ip_address_id = azurerm_public_ip.example.id
#   }
# }


# resource "azurerm_lb_backend_address_pool" "example" {
#   loadbalancer_id = azurerm_lb.example.id
#   name            = "BackEndAddressPool"
# }
