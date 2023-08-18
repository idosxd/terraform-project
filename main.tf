resource "azurerm_resource_group" "rg" {
  name     = "rg-${var.project_name}-${var.environment_name}"
  location = var.location_name
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-${var.environment_name}-${var.location_name}"
  address_space       = ["10.0.0.0/16"]
  location            = var.location_name
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "web_snet" {
  name                 = "snet-web-${var.location_name}"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_subnet" "db_snet" {
  name                 = "snet-db-${var.location_name}"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_network_security_group" "web_nsg" {
  name                = "nsg-web"
  location            = var.location_name
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.my_ip
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Flask"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5000"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "db_nsg" {
  name                = "nsg-db"
  location            = var.location_name
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.my_ip
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "web_nsg_assoc" {
  subnet_id                 = azurerm_subnet.web_snet.id
  network_security_group_id = azurerm_network_security_group.web_nsg.id
}

resource "azurerm_subnet_network_security_group_association" "db_nsg_assoc" {
  subnet_id                 = azurerm_subnet.db_snet.id
  network_security_group_id = azurerm_network_security_group.db_nsg.id
}

resource "azurerm_public_ip" "web_pip" {
  name                = "pip-web-${var.environment_name}-${var.location_name}"
  location            = var.location_name
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
}

resource "azurerm_public_ip" "db_pip" {
  name                = "pip-db-${var.environment_name}-${var.location_name}"
  location            = var.location_name
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
}

resource "azurerm_network_interface" "web_nic" {
  name                = "nic-web-${var.environment_name}"
  location            = var.location_name
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.web_snet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.web_pip.id
  }
}

resource "azurerm_network_interface" "db_nic" {
  name                = "nic-db-${var.environment_name}"
  location            = var.location_name
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.db_snet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.db_pip.id
  }
}

resource "azurerm_virtual_machine" "web_vm" {
  name                  = "vm-web-${var.environment_name}"
  location              = var.location_name
  resource_group_name   = azurerm_resource_group.rg.name
  vm_size               = "Standard_B1s"
  network_interface_ids = [azurerm_network_interface.web_nic.id]

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "osdisk-vm-web-${var.environment_name}"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
    disk_size_gb      = 30
  }

  os_profile {
    computer_name  = "vm-web-${var.environment_name}"
    admin_username = "adminuser"
    admin_password = var.db_password
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }
}

resource "azurerm_virtual_machine" "db_vm" {
  name                  = "vm-db-${var.environment_name}"
  location              = var.location_name
  resource_group_name   = azurerm_resource_group.rg.name
  vm_size               = "Standard_B1s"
  network_interface_ids = [azurerm_network_interface.db_nic.id]

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "osdisk-vm-db-${var.environment_name}"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
    disk_size_gb      = 30
  }

  storage_data_disk {
    name              = "datadisk-vm-db-${var.environment_name}"
    managed_disk_type = "Standard_LRS"
    create_option     = "Empty"
    lun               = "1"
    disk_size_gb      = 5
  }

  os_profile {
    computer_name  = "vm-db-${var.environment_name}"
    admin_username = "adminuser"
    admin_password = var.db_password
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }
}

resource "null_resource" "install_postgresql" {
  depends_on = [azurerm_virtual_machine.db_vm]

  connection {
    type        = "ssh"
    host        = azurerm_public_ip.db_pip.ip_address
    user        = "adminuser"
    password    = var.db_password
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install postgresql -y",

      "sudo umount /dev/sdc1",
      "yes | sudo mkfs -t ext4 /dev/sdc",
      "sudo mkdir /mnt/data",
      "sudo mount /dev/sdc /mnt/data",

      "sudo service postgresql stop",
      
      "sudo mv /var/lib/postgresql /mnt/data",
      "sudo ln -s /mnt/data/postgresql /var/lib/postgresql",
      "sudo sed -i 's|/var/lib/postgresql/10/main|/mnt/data/postgresql/10/main|g' /etc/postgresql/10/main/postgresql.conf",
      "sudo chown -R postgres:postgres /mnt/data/postgresql",

      "sudo sed -i \"s/^#listen_addresses = 'localhost'/listen_addresses = '*'/\" /etc/postgresql/10/main/postgresql.conf",
      "echo 'host    all             all             10.0.2.0/24               md5' | sudo tee -a /etc/postgresql/10/main/pg_hba.conf",

      "sudo service postgresql start",

      "sudo -u postgres psql -c \"CREATE USER web_vm WITH SUPERUSER PASSWORD '${var.postgresql_password}';\"",
      "sudo -u postgres psql -c \"CREATE DATABASE users;\"",
      "sudo -u postgres psql -d users -c \"CREATE TABLE users (id SERIAL PRIMARY KEY, username VARCHAR(50) NOT NULL, password VARCHAR(100) NOT NULL, water_consumption INTEGER DEFAULT 0);\"",
      "sudo -u postgres psql -d users -c \"INSERT INTO users (username, password, water_consumption) VALUES ('idosxd', 'a1a1a1', 0);\"",
    ]
  }
}

resource "null_resource" "install_application" {
  depends_on = [azurerm_virtual_machine.web_vm]

  connection {
    type        = "ssh"
    host        = azurerm_public_ip.web_pip.ip_address
    user        = "adminuser"
    password    = var.web_password
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y git python3 python3-pip libpq-dev",

      "git clone https://github.com/idosxd/app-for-terraform-project.git",
      "cd application",

      "pip3 install --user -r requirements.txt",

      "cat <<EOF > .env",
      "AQUATRACK_SECRET_KEY=${var.secret_key_py}",
      "AQUATRACK_DB_HOST=10.0.1.4",
      "AQUATRACK_DB_PORT=5432",
      "AQUATRACK_DB_USERNAME=web_vm",
      "AQUATRACK_DB_PASSWORD=${var.postgresql_password}",
      "AQUATRACK_DB_NAME=users",
      "EOF",

      "pip3 install gunicorn",
      
      "echo '[Unit]\nDescription=AquaTrack Web Application\nAfter=network.target\n\n[Service]\nUser=adminuser\nWorkingDirectory=/home/adminuser/application\nExecStart=/home/adminuser/.local/bin/gunicorn -b 0.0.0.0:5000 app:app\nRestart=always\n\n[Install]\nWantedBy=multi-user.target' | sudo tee /etc/systemd/system/aquatrack.service",

      "sudo systemctl daemon-reload",
      "sudo systemctl enable aquatrack.service",
      "sudo systemctl start aquatrack.service"
    ]
  }
}
