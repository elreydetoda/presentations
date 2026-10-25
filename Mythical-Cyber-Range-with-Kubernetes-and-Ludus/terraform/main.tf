terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
}

variable "location" {
  type    = string
  default = "eastus2"
}

variable "resource_group_name" {
  type    = string
  default = "rg-ludus-workshop"
}

variable "vm_name" {
  type    = string
  default = "ludus-server"
}

variable "admin_username" {
  type    = string
  default = "azureuser"
}

variable "ssh_public_key" {
  type        = string
  description = "The student's SSH public key"
}

variable "ssh_source_cidr" {
  type        = string
  description = "Student's public IPv4 address in CIDR notation, e.g. 203.0.113.10/32"
}

resource "azurerm_resource_group" "ludus" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    Project     = "Ludus"
    Environment = "Workshop"
  }
}

resource "azurerm_virtual_network" "ludus" {
  name                = "ludus-vnet"
  address_space       = ["10.40.0.0/16"]
  location            = azurerm_resource_group.ludus.location
  resource_group_name = azurerm_resource_group.ludus.name
}

resource "azurerm_subnet" "ludus" {
  name                 = "ludus-subnet"
  resource_group_name  = azurerm_resource_group.ludus.name
  virtual_network_name = azurerm_virtual_network.ludus.name
  address_prefixes     = ["10.40.1.0/24"]
}

resource "azurerm_network_security_group" "ludus" {
  name                = "ludus-nsg"
  location            = azurerm_resource_group.ludus.location
  resource_group_name = azurerm_resource_group.ludus.name

  # Restrict SSH to the student's current public IP.
  security_rule {
    name                       = "Allow-SSH"
    priority                   = 300
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.ssh_source_cidr
    destination_address_prefix = "*"
  }

  # WireGuard must accept connections from student clients.
  security_rule {
    name                       = "Allow-WireGuard"
    priority                   = 310
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = "51820"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_public_ip" "ludus" {
  name                = "ludus-public-ip"
  location            = azurerm_resource_group.ludus.location
  resource_group_name = azurerm_resource_group.ludus.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "ludus" {
  name                = "ludus-nic"
  location            = azurerm_resource_group.ludus.location
  resource_group_name = azurerm_resource_group.ludus.name

  # Accelerated networking is required for this VM family.
  enable_accelerated_networking = true

  ip_configuration {
    name                          = "primary"
    subnet_id                     = azurerm_subnet.ludus.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.ludus.id
  }
}

resource "azurerm_network_interface_security_group_association" "ludus" {
  network_interface_id      = azurerm_network_interface.ludus.id
  network_security_group_id = azurerm_network_security_group.ludus.id
}

resource "azurerm_linux_virtual_machine" "ludus" {
  name                = var.vm_name
  computer_name       = var.vm_name
  resource_group_name = azurerm_resource_group.ludus.name
  location            = azurerm_resource_group.ludus.location

  size                  = "Standard_E4bs_v5"
  admin_username        = var.admin_username
  network_interface_ids = [azurerm_network_interface.ludus.id]

  disable_password_authentication = true
  disk_controller_type             = "NVMe"

  admin_ssh_key {
    username   = var.admin_username
    public_key = trimspace(var.ssh_public_key)
  }

  os_disk {
    name                 = "ludus-os-disk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 256
  }

  source_image_reference {
    publisher = "debian"
    offer     = "debian-12"
    sku       = "12-gen2"
    version   = "latest"
  }

  tags = {
    Project = "Ludus"
  }
}

output "public_ip" {
  value = azurerm_public_ip.ludus.ip_address
}

output "ssh_command" {
  value = "ssh ${var.admin_username}@${azurerm_public_ip.ludus.ip_address}"
}
