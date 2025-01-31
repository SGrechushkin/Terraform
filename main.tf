provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "test" {
  name     = "Grechushkin-resources"
  location = "East US"
}

resource "azurerm_virtual_network" "vnet" {
  name                = "Grechushkin-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.test.location
  resource_group_name = azurerm_resource_group.test.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "Grechushkin-subnet"
  resource_group_name  = azurerm_resource_group.test.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_availability_set" "availability_set" {
  name                = "Grechushkin-availability-set"
  location            = azurerm_resource_group.test.location
  resource_group_name = azurerm_resource_group.test.name
  managed             = true
}

#Public IP for Load Balancer
resource "azurerm_public_ip" "example_lb_public_ip" {
  name                = "example-lb-public-ip"
  location            = azurerm_resource_group.test.location
  resource_group_name = azurerm_resource_group.test.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_lb" "load_balancer" {
  name                = "Grechushkin-lb"
  location            = azurerm_resource_group.test.location
  resource_group_name = azurerm_resource_group.test.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name               = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.example_lb_public_ip.id
  }
}

resource "azurerm_lb_probe" "Grechushkin" {
  name            = "Grechushkin-probe"
  loadbalancer_id = azurerm_lb.load_balancer.id
  protocol        = "Tcp"
  port            = 22
  interval_in_seconds = 5
  number_of_probes     = 2
}

resource "azurerm_lb_backend_address_pool" "Grechushkin" {
  name            = "Grechushkin-backend-pool"
  loadbalancer_id = azurerm_lb.load_balancer.id
}

resource "azurerm_lb_rule" "Grechushkin" {
  name                           = "http-rule"
  loadbalancer_id                = azurerm_lb.load_balancer.id
  protocol                       = "Tcp"
  frontend_ip_configuration_name = "PublicIPAddress"
  frontend_port                  = 22
  backend_port                   = 22
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.Grechushkin.id]
  probe_id                       = azurerm_lb_probe.Grechushkin.id
}

resource "azurerm_network_interface" "nic" {
  count               = 2
  name                = "nic-${count.index}"
  location            = azurerm_resource_group.test.location
  resource_group_name = azurerm_resource_group.test.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_security_group" "nsg" {
  name                = "Grechushkin-nsg"
  location            = azurerm_resource_group.test.location
  resource_group_name = azurerm_resource_group.test.name

  security_rule {
    name                       = "Allow-SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface_security_group_association" "nsg_association" {
  count                 = 2
  network_interface_id  = azurerm_network_interface.nic[count.index].id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_linux_virtual_machine" "vm" {
  count               = 2
  name                = "vm-${count.index}"
  location            = azurerm_resource_group.test.location
  resource_group_name = azurerm_resource_group.test.name
  size                = "Standard_B1ls"
  admin_username      = "azureuser"
  availability_set_id = azurerm_availability_set.availability_set.id
  network_interface_ids = [azurerm_network_interface.nic[count.index].id]
  disable_password_authentication = false

  admin_password = "P@ssw0rd123!"

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
}
output "load_balancer_ip" {
  value = azurerm_public_ip.example_lb_public_ip.ip_address
}
#Git