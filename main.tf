#Specify the version of the AzureRM Provider to use
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.1"
    }
  }
  backend "http" {
  }
}

#Configure the AzureRM Provider
provider "azurerm" {
  features {
  }
}

#Configure data source
data "azurerm_client_config" "current" {
}

#Select resource group
resource "azurerm_resource_group" "vpn" {
  name     = "vpn"
  location = "West US"
}

#Create data resource for Azure Key Vault
data "azurerm_key_vault" "azurevpnkeyvault" {
  name                = "azurevpnkeyvault"
  resource_group_name = azurerm_resource_group.vpn.name
}

#Get secrets from Azure Key Vault
data "azurerm_key_vault_secret" "vmadminpw" {
  name         = "vmadminpw"
  key_vault_id = data.azurerm_key_vault.azurevpnkeyvault.id
}

data "azurerm_key_vault_secret" "gatewayaddress" {
  name         = "gatewayaddress"
  key_vault_id = data.azurerm_key_vault.azurevpnkeyvault.id
}

data "azurerm_key_vault_secret" "vpnsharedkey" {
  name         = "vpnsharedkey"
  key_vault_id = data.azurerm_key_vault.azurevpnkeyvault.id
}

#Create virtual network
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet"
  location            = azurerm_resource_group.vpn.location
  resource_group_name = azurerm_resource_group.vpn.name
  address_space       = ["10.67.0.0/16"]
}

#Create gateway subnet
resource "azurerm_subnet" "gatewaysubnet" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.vpn.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.67.252.0/28"]
}

#Create a server subnet
resource "azurerm_subnet" "serversubnet" {
  name                 = "ServerSubnet"
  resource_group_name  = azurerm_resource_group.vpn.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.67.2.0/24"]
}

#Create local network gateway
resource "azurerm_local_network_gateway" "onpremise" {
  name                = "onpremise"
  location            = azurerm_resource_group.vpn.location
  resource_group_name = azurerm_resource_group.vpn.name
  gateway_address     = data.azurerm_key_vault_secret.gatewayaddress.value
  address_space       = ["10.66.0.0/16"]
}

#Request public ip
resource "azurerm_public_ip" "publicip" {
  name                = "publicip"
  location            = azurerm_resource_group.vpn.location
  resource_group_name = azurerm_resource_group.vpn.name
  allocation_method   = "Dynamic"
}

#Create and configure virtual network gateway
resource "azurerm_virtual_network_gateway" "vng" {
  name                = "vng"
  location            = azurerm_resource_group.vpn.location
  resource_group_name = azurerm_resource_group.vpn.name

  type     = "Vpn"
  vpn_type = "RouteBased"

  active_active = false
  enable_bgp    = false
  sku           = "Basic"

  ip_configuration {
    public_ip_address_id          = azurerm_public_ip.publicip.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.gatewaysubnet.id
  }
}

#Create the connection
resource "azurerm_virtual_network_gateway_connection" "onpremise" {
  name                = "onpremise"
  location            = azurerm_resource_group.vpn.location
  resource_group_name = azurerm_resource_group.vpn.name

  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.vng.id
  local_network_gateway_id   = azurerm_local_network_gateway.onpremise.id

  shared_key = data.azurerm_key_vault_secret.vpnsharedkey.value
}

#Create a virtual nic for a test vm
resource "azurerm_network_interface" "nic" {
  name                = "nic"
  location            = azurerm_resource_group.vpn.location
  resource_group_name = azurerm_resource_group.vpn.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.serversubnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

#Create test vm
resource "azurerm_linux_virtual_machine" "vm" {
  name                            = "vm"
  resource_group_name             = azurerm_resource_group.vpn.name
  location                        = azurerm_resource_group.vpn.location
  size                            = "Standard_F2"
  admin_username                  = "adminuser"
  admin_password                  = data.azurerm_key_vault_secret.vmadminpw.value
  disable_password_authentication = false
  network_interface_ids = [
    azurerm_network_interface.nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }
}      