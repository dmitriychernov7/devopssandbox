# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0.2"
    }
  }

  required_version = ">= 1.1.0"
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "rg_task_2"
  location = "westus2"
}

# Create a virtual network
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet_task_2"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet_1" {
  name                 = "subnet_1"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_network_security_group" "nsg_public_1" {
  name                = "nsg_public_1"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "AllowICMP"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Icmp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowSSH"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowHTTP"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowHTTPS"
    priority                   = 1004
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowOutbound"
    priority                   = 1005
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_public_ip" "VM1_public_ip" {
  name                = "VM1_public_ip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
}

resource "azurerm_network_interface" "VM1_nic" {
  name                = "VM1_nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet_1.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.1.10"
    public_ip_address_id          = azurerm_public_ip.VM1_public_ip.id
  }
}

resource "azurerm_linux_virtual_machine" "VM1" {
  name                            = "VM1"
  location                        = azurerm_resource_group.rg.location
  resource_group_name             = azurerm_resource_group.rg.name
  size                            = "Standard_B1s"
  admin_username                  = "adminuser"
  admin_password                  = var.admin_password
  disable_password_authentication = false
  network_interface_ids = [
    azurerm_network_interface.VM1_nic.id,
  ]

  os_disk {
    caching              = "None"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt update",
      "sudo apt install -y nginx",
      "echo 'Hello World from Ubuntu $(lsb_release -d)' > /var/www/html/index.html",
      "sudo systemctl start nginx",
      "sudo apt install -y docker.io",
      "sudo systemctl enable docker",
      "sudo systemctl start docker"
    ]

    connection {
      type     = "ssh"
      user     = "adminuser"
      password = var.admin_password
      host     = azurerm_public_ip.VM1_public_ip.ip_address
      port     = 22
    }
  }

  depends_on = [azurerm_public_ip.VM1_public_ip]

  tags = {
    Name = "VM_1"
  }
}

data "azurerm_public_ip" "example" {
  name                = azurerm_public_ip.VM1_public_ip.name
  resource_group_name = azurerm_linux_virtual_machine.VM1.resource_group_name
}

output "public_ip_address" {
  value = data.azurerm_public_ip.example.ip_address
}

#
# # Resource Group
# resource "azurerm_resource_group" "example" {
#   name     = "example-resources"
#   location = "East US"
# }
#
# # Virtual Network
# resource "azurerm_virtual_network" "example" {
#   name                = "example-vnet"
#   address_space       = ["10.0.0.0/16"]
#   location            = azurerm_resource_group.example.location
#   resource_group_name = azurerm_resource_group.example.name
# }
#
# # Subnet
# resource "azurerm_subnet" "example" {
#   name                 = "example-subnet"
#   resource_group_name  = azurerm_resource_group.example.name
#   virtual_network_name = azurerm_virtual_network.example.name
#   address_prefixes     = ["10.0.1.0/24"]
# }
#
# # Network Security Group for Ubuntu VM (with internet access)
# resource "azurerm_network_security_group" "nsg_ubuntu" {
#   name                = "nsg-ubuntu"
#   location            = azurerm_resource_group.example.location
#   resource_group_name = azurerm_resource_group.example.name
#
#   security_rule {
#     name                       = "AllowSSH"
#     priority                   = 1001
#     direction                  = "Inbound"
#     access                     = "Allow"
#     protocol                   = "Tcp"
#     source_port_range          = "*"
#     destination_port_range     = "22"
#     source_address_prefix      = "*"
#     destination_address_prefix = "*"
#   }
#
#   security_rule {
#     name                       = "AllowHTTP"
#     priority                   = 1002
#     direction                  = "Inbound"
#     access                     = "Allow"
#     protocol                   = "Tcp"
#     source_port_range          = "*"
#     destination_port_range     = "80"
#     source_address_prefix      = "*"
#     destination_address_prefix = "*"
#   }
#
#   security_rule {
#     name                       = "AllowHTTPS"
#     priority                   = 1003
#     direction                  = "Inbound"
#     access                     = "Allow"
#     protocol                   = "Tcp"
#     source_port_range          = "*"
#     destination_port_range     = "443"
#     source_address_prefix      = "*"
#     destination_address_prefix = "*"
#   }
#
#   security_rule {
#     name                       = "AllowICMP"
#     priority                   = 1004
#     direction                  = "Inbound"
#     access                     = "Allow"
#     protocol                   = "Icmp"
#     source_port_range          = "*"
#     destination_port_range     = "*"
#     source_address_prefix      = "*"
#     destination_address_prefix = "*"
#   }
#
#   security_rule {
#     name                       = "AllowOutbound"
#     priority                   = 1005
#     direction                  = "Outbound"
#     access                     = "Allow"
#     protocol                   = "*"
#     source_port_range          = "*"
#     destination_port_range     = "*"
#     source_address_prefix      = "*"
#     destination_address_prefix = "*"
#   }
# }
#
# # Network Security Group for Amazon Linux VM (local network access only)
# resource "azurerm_network_security_group" "nsg_amazon" {
#   name                = "nsg-amazon"
#   location            = azurerm_resource_group.example.location
#   resource_group_name = azurerm_resource_group.example.name
#
#   security_rule {
#     name                       = "AllowSSH"
#     priority                   = 1001
#     direction                  = "Inbound"
#     access                     = "Allow"
#     protocol                   = "Tcp"
#     source_port_range          = "*"
#     destination_port_range     = "22"
#     source_address_prefix      = "10.0.1.0/24"
#     destination_address_prefix = "*"
#   }
#
#   security_rule {
#     name                       = "AllowHTTP"
#     priority                   = 1002
#     direction                  = "Inbound"
#     access                     = "Allow"
#     protocol                   = "Tcp"
#     source_port_range          = "*"
#     destination_port_range     = "80"
#     source_address_prefix      = "10.0.1.0/24"
#     destination_address_prefix = "*"
#   }
#
#   security_rule {
#     name                       = "AllowHTTPS"
#     priority                   = 1003
#     direction                  = "Inbound"
#     access                     = "Allow"
#     protocol                   = "Tcp"
#     source_port_range          = "*"
#     destination_port_range     = "443"
#     source_address_prefix      = "10.0.1.0/24"
#     destination_address_prefix = "*"
#   }
#
#   security_rule {
#     name                       = "AllowICMP"
#     priority                   = 1004
#     direction                  = "Inbound"
#     access                     = "Allow"
#     protocol                   = "Icmp"
#     source_address_prefix      = "10.0.1.0/24"
#     destination_address_prefix = "*"
#   }
#
#   security_rule {
#     name                       = "DenyOutboundInternet"
#     priority                   = 1005
#     direction                  = "Outbound"
#     access                     = "Deny"
#     protocol                   = "*"
#     source_port_range          = "*"
#     destination_port_range     = "*"
#     source_address_prefix      = "*"
#     destination_address_prefix = "0.0.0.0/0"
#   }
# }
#
# # Network Interface for Ubuntu VM
# resource "azurerm_network_interface" "ubuntu_nic" {
#   name                = "ubuntu-nic"
#   location            = azurerm_resource_group.example.location
#   resource_group_name = azurerm_resource_group.example.name
#
#   ip_configuration {
#     name                          = "internal"
#     subnet_id                     = azurerm_subnet.example.id
#     private_ip_address_allocation = "Dynamic"
#     public_ip_address_id          = azurerm_public_ip.ubuntu_public_ip.id
#   }
#
#   network_security_group_id = azurerm_network_security_group.nsg_ubuntu.id
# }
#
# # Network Interface for Amazon Linux VM
# resource "azurerm_network_interface" "amazon_nic" {
#   name                = "amazon-nic"
#   location            = azurerm_resource_group.example.location
#   resource_group_name = azurerm_resource_group.example.name
#
#   ip_configuration {
#     name                          = "internal"
#     subnet_id                     = azurerm_subnet.example.id
#     private_ip_address_allocation = "Dynamic"
#   }
#
#   network_security_group_id = azurerm_network_security_group.nsg_amazon.id
# }
#
# # Public IP for Ubuntu VM
# resource "azurerm_public_ip" "ubuntu_public_ip" {
#   name                = "ubuntu-public-ip"
#   location            = azurerm_resource_group.example.location
#   resource_group_name = azurerm_resource_group.example.name
#   allocation_method   = "Dynamic"
# }
#
# # Ubuntu VM with public access
# resource "azurerm_linux_virtual_machine" "ubuntu_vm" {
#   name                = "Ubuntu-VM"
#   resource_group_name = azurerm_resource_group.example.name
#   location            = azurerm_resource_group.example.location
#   size                = "Standard_B1ms"
#   admin_username      = "adminuser"
#   network_interface_ids = [azurerm_network_interface.ubuntu_nic.id]
#   admin_password      = "P@ssw0rd123!"
#
#   os_disk {
#     caching              = "ReadWrite"
#     storage_account_type = "Standard_LRS"
#   }
#
#   source_image_reference {
#     publisher = "Canonical"
#     offer     = "UbuntuServer"
#     sku       = "18.04-LTS"
#     version   = "latest"
#   }
#
#   tags = {
#     Name = "Ubuntu VM"
#   }
#
#   provisioner "remote-exec" {
#     inline = [
#       "sudo apt update",
#       "sudo apt install -y nginx",
#       "echo 'Hello World from Ubuntu $(lsb_release -d)' > /var/www/html/index.html",
#       "sudo systemctl start nginx",
#       "sudo apt install -y docker.io",
#       "sudo systemctl enable docker",
#       "sudo systemctl start docker"
#     ]
#
#     connection {
#       type     = "ssh"
#       user     = "adminuser"
#       password = "P@ssw0rd123!"
#       host     = azurerm_public_ip.ubuntu_public_ip.ip_address
#       port     = 22
#     }
#   }
# }
#
# # Amazon Linux VM (local network access only)
# resource "azurerm_linux_virtual_machine" "amazon_vm" {
#   name                = "Amazon-Linux-VM"
#   resource_group_name = azurerm_resource_group.example.name
#   location            = azurerm_resource_group.example.location
#   size                = "Standard_B1ms"
#   admin_username      = "adminuser"
#   network_interface_ids = [azurerm_network_interface.amazon_nic.id]
#   admin_password      = "P@ssw0rd123!"
#
#   os_disk {
#     caching              = "ReadWrite"
#     storage_account_type = "Standard_LRS"
#   }
#
#   source_image_reference {
#     publisher = "Amazon"
#     offer     = "Amazon-Linux"
#     sku       = "2"
#     version   = "latest"
#   }
#
#   tags = {
#     Name = "Amazon Linux VM"
#   }
# }
