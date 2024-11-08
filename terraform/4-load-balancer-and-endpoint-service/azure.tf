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

resource "azurerm_lb" "intra_vnet_lb" {
  name                = "${local.resource_prefix}_intra_vnet_lb"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  frontend_ip_configuration {
    name                 = "frontend-ip"
    subnet_id = data.azurerm_subnet.subnet.id
    # Multiple required?
    private_ip_address = var.azure_internal_load_balancer_frontend_ip
    private_ip_address_allocation = "Static"
  }
}


# resource "azurerm_lb_backend_address_pool" "example" {
#   loadbalancer_id = azurerm_lb.example.id
#   name            = "BackEndAddressPool"
# }
