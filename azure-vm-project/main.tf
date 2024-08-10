# Create resource groups for each environment
resource "azurerm_resource_group" "rg" {
  for_each = var.environments

  name     = "${each.key}-rg"
  location = var.location
}

# Create virtual networks
resource "azurerm_virtual_network" "vnet" {
  for_each            = var.environments
  name                = "${each.key}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg[each.key].location
  resource_group_name = azurerm_resource_group.rg[each.key].name
}

# Create subnets
resource "azurerm_subnet" "subnet" {
  for_each             = var.environments
  name                 = "${each.key}-subnet"
  resource_group_name  = azurerm_resource_group.rg[each.key].name
  virtual_network_name = azurerm_virtual_network.vnet[each.key].name
  address_prefixes     = ["10.0.1.0/24"]
}

# Create Network Security Groups
resource "azurerm_network_security_group" "nsg" {
  for_each            = var.environments
  name                = "${each.key}-nsg"
  location            = azurerm_resource_group.rg[each.key].location
  resource_group_name = azurerm_resource_group.rg[each.key].name
}

# Define security rules for NSG (Allow SSH and outbound DNS, HTTP, HTTPS)
resource "azurerm_network_security_rule" "allow_ssh" {
  for_each = var.environments

  name                        = "allow-ssh"
  priority                    = 1001
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg[each.key].name
  network_security_group_name = azurerm_network_security_group.nsg[each.key].name
}

resource "azurerm_network_security_rule" "allow_outbound" {
  for_each = var.environments

  name                        = "allow-outbound"
  priority                    = 1002
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["53", "80", "443"]
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg[each.key].name
  network_security_group_name = azurerm_network_security_group.nsg[each.key].name
}

# Create public IPs
resource "azurerm_public_ip" "public_ip" {
  for_each            = var.environments
  name                = "${each.key}-public-ip"
  location            = azurerm_resource_group.rg[each.key].location
  resource_group_name = azurerm_resource_group.rg[each.key].name
  allocation_method   = "Dynamic"
}

# Create Network Interfaces
resource "azurerm_network_interface" "nic" {
  for_each            = var.environments
  name                = "${each.key}-nic"
  location            = azurerm_resource_group.rg[each.key].location
  resource_group_name = azurerm_resource_group.rg[each.key].name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet[each.key].id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip[each.key].id
  }
}

# Create Virtual Machines
resource "azurerm_linux_virtual_machine" "vm" {
  for_each            = var.environments
  name                = "${each.key}-vm"
  location            = azurerm_resource_group.rg[each.key].location
  resource_group_name = azurerm_resource_group.rg[each.key].name
  network_interface_ids = [azurerm_network_interface.nic[each.key].id]
  size                = "Standard_B1s"

  admin_username = "azureuser"
  admin_password = var.vm_admin_password

  os_disk {
    caching           = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
}

# Implement accidental deletion protection for all resources
resource "azurerm_management_lock" "lock" {
  for_each            = var.environments
  name                = "lock-${each.key}"
  scope               = azurerm_resource_group.rg[each.key].id
  lock_level          = "CanNotDelete"
  notes               = "This resource group is protected from deletion."
}

# Backup strategy - using Recovery Services Vault
module "backup" {
  source = "./backup"
  environments = var.environments
}
