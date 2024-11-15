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
    name                 = "broker1"
    subnet_id = data.azurerm_subnet.subnet.id
    private_ip_address = var.azure_internal_load_balancer_frontend_ip_broker1
    private_ip_address_allocation = "Static"
  }
  frontend_ip_configuration {
    name                 = "broker2"
    subnet_id = data.azurerm_subnet.subnet.id
    private_ip_address = var.azure_internal_load_balancer_frontend_ip_broker2
    private_ip_address_allocation = "Static"
  }
  frontend_ip_configuration {
    name                 = "broker3"
    subnet_id = data.azurerm_subnet.subnet.id
    private_ip_address = var.azure_internal_load_balancer_frontend_ip_broker3
    private_ip_address_allocation = "Static"
  }
}

resource "azurerm_lb_backend_address_pool" "intra_vnet_lb_backend_broker1" {
  loadbalancer_id = azurerm_lb.intra_vnet_lb.id
  name            = "broker1"
}

resource "azurerm_lb_backend_address_pool_address" "broker1" {
  name                                = "broker1"
  backend_address_pool_id             = azurerm_lb_backend_address_pool.intra_vnet_lb_backend_broker1.id
  virtual_network_id = data.azurerm_virtual_network.vnet.id
  ip_address = var.ccloud_private_endpoint_ip1
}

resource "azurerm_lb_nat_rule" "broker1_kafka" {
  resource_group_name            = data.azurerm_resource_group.rg.name
  loadbalancer_id                = azurerm_lb.intra_vnet_lb.id
  name                           = "broker1-kafka"
  protocol                       = "Tcp"
  frontend_port_start            = 9092
  frontend_port_end              = 9092
  backend_port                   = 9092
  frontend_ip_configuration_name = "broker1"
  backend_address_pool_id        = azurerm_lb_backend_address_pool.intra_vnet_lb_backend_broker1.id
}

resource "azurerm_lb_nat_rule" "broker1_rest" {
  resource_group_name            = data.azurerm_resource_group.rg.name
  loadbalancer_id                = azurerm_lb.intra_vnet_lb.id
  name                           = "broker1-rest"
  protocol                       = "Tcp"
  frontend_port_start            = 443
  frontend_port_end              = 443
  backend_port                   = 443
  frontend_ip_configuration_name = "broker1"
  backend_address_pool_id        = azurerm_lb_backend_address_pool.intra_vnet_lb_backend_broker1.id
}

resource "azurerm_lb_backend_address_pool" "intra_vnet_lb_backend_broker2" {
  loadbalancer_id = azurerm_lb.intra_vnet_lb.id
  name            = "broker2"
}

resource "azurerm_lb_backend_address_pool_address" "broker2" {
  name                                = "broker2"
  backend_address_pool_id             = azurerm_lb_backend_address_pool.intra_vnet_lb_backend_broker2.id
  virtual_network_id = data.azurerm_virtual_network.vnet.id
  ip_address = var.ccloud_private_endpoint_ip2
}

resource "azurerm_lb_nat_rule" "broker2_kafka" {
  resource_group_name            = data.azurerm_resource_group.rg.name
  loadbalancer_id                = azurerm_lb.intra_vnet_lb.id
  name                           = "broker2-kafka"
  protocol                       = "Tcp"
  frontend_port_start            = 9092
  frontend_port_end              = 9092
  backend_port                   = 9092
  frontend_ip_configuration_name = "broker2"
  backend_address_pool_id        = azurerm_lb_backend_address_pool.intra_vnet_lb_backend_broker2.id
}

resource "azurerm_lb_nat_rule" "broker2_rest" {
  resource_group_name            = data.azurerm_resource_group.rg.name
  loadbalancer_id                = azurerm_lb.intra_vnet_lb.id
  name                           = "broker2-rest"
  protocol                       = "Tcp"
  frontend_port_start            = 443
  frontend_port_end              = 443
  backend_port                   = 443
  frontend_ip_configuration_name = "broker2"
  backend_address_pool_id        = azurerm_lb_backend_address_pool.intra_vnet_lb_backend_broker2.id
}

resource "azurerm_lb_backend_address_pool" "intra_vnet_lb_backend_broker3" {
  loadbalancer_id = azurerm_lb.intra_vnet_lb.id
  name            = "broker3"
}

resource "azurerm_lb_backend_address_pool_address" "broker3" {
  name                                = "broker3"
  backend_address_pool_id             = azurerm_lb_backend_address_pool.intra_vnet_lb_backend_broker3.id
  virtual_network_id = data.azurerm_virtual_network.vnet.id
  ip_address = var.ccloud_private_endpoint_ip3
}

resource "azurerm_lb_nat_rule" "broker3_kafka" {
  resource_group_name            = data.azurerm_resource_group.rg.name
  loadbalancer_id                = azurerm_lb.intra_vnet_lb.id
  name                           = "broker3-kafka"
  protocol                       = "Tcp"
  frontend_port_start            = 9092
  frontend_port_end              = 9092
  backend_port                   = 9092
  frontend_ip_configuration_name = "broker3"
  backend_address_pool_id        = azurerm_lb_backend_address_pool.intra_vnet_lb_backend_broker3.id
}

resource "azurerm_lb_nat_rule" "broker3_rest" {
  resource_group_name            = data.azurerm_resource_group.rg.name
  loadbalancer_id                = azurerm_lb.intra_vnet_lb.id
  name                           = "broker3-rest"
  protocol                       = "Tcp"
  frontend_port_start            = 443
  frontend_port_end              = 443
  backend_port                   = 443
  frontend_ip_configuration_name = "broker3"
  backend_address_pool_id        = azurerm_lb_backend_address_pool.intra_vnet_lb_backend_broker3.id
}
