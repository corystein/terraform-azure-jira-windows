resource "random_string" "rand" {
  length      = 4
  number      = false
  lower       = true
  upper       = false
  special     = false
  min_special = 0
}

resource "azurerm_public_ip" "vm-pip" {
  name                         = "vm-pip"
  location                     = "${azurerm_resource_group.res_group.location}"
  resource_group_name          = "${azurerm_resource_group.res_group.name}"
  public_ip_address_allocation = "static"
  domain_name_label            = "${random_string.rand.result}-win-jra-vm1"
}

resource "azurerm_network_interface" "vm-nic" {
  name                = "vm-nic"
  resource_group_name = "${azurerm_resource_group.res_group.name}"
  location            = "${azurerm_resource_group.res_group.location}"

  ip_configuration {
    name = "ipconfig1"

    #private_ip_address_allocation = "static"
    private_ip_address_allocation = "dynamic"
    subnet_id                     = "${azurerm_subnet.subnet1.id}"
    public_ip_address_id          = "${azurerm_public_ip.vm-pip.id}"

    #load_balancer_backend_address_pools_ids = ["${azurerm_lb_backend_address_pool.jenkins_lb_backend.id}"]

    #load_balancer_inbound_nat_rules_ids     = ["${azurerm_lb_rule.lb_rule.id}"]

    #private_ip_address            = "${var.config["jenkins_master_primary_ip_address"]}"
  }
}

resource "azurerm_virtual_machine" "vm-1" {
  name                = "vm-1"
  resource_group_name = "${azurerm_resource_group.res_group.name}"
  location            = "${azurerm_resource_group.res_group.location}"

  #availability_set_id   = "${azurerm_availability_set.avset.id}"
  network_interface_ids = ["${azurerm_network_interface.vm-nic.id}"]
  vm_size               = "${var.config["vm_size"]}"

  # Uncomment this line to delete the OS disk automatically when deleting the VM
  delete_os_disk_on_termination = true

  # Uncomment this line to delete the data disks automatically when deleting the VM
  delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "${var.config["vm_image_publisher"]}"
    offer     = "${var.config["vm_image_offer"]}"
    sku       = "${var.config["vm_image_sku"]}"
    version   = "${var.config["vm_image_version"]}"
  }

  storage_os_disk {
    name              = "${var.config["vm_name"]}-os-disk"
    caching           = "ReadWrite"
    managed_disk_type = "Standard_LRS"
    create_option     = "FromImage"
    disk_size_gb      = "128"
  }

  storage_data_disk {
    name              = "${var.config["vm_name"]}-data-disk"
    managed_disk_type = "Standard_LRS"
    create_option     = "Empty"
    lun               = 0
    disk_size_gb      = "512"
  }

  os_profile {
    computer_name  = "${var.config["vm_name"]}"
    admin_username = "${var.config["vm_username"]}"
    admin_password = "${var.config["vm_password"]}"

    # Base64 encoded Deploy.ps1 to install/configure WinRM
    custom_data = "${base64encode( file( "${path.module}/files/Deploy.ps1" ) )}"
  }

  os_profile_windows_config {
    provision_vm_agent        = true
    enable_automatic_upgrades = true

    # Enable auto logon (1 time only)
    additional_unattend_config {
      pass         = "oobeSystem"
      component    = "Microsoft-Windows-Shell-Setup"
      setting_name = "AutoLogon"
      content      = "<AutoLogon><Password><Value>${var.config["vm_password"]}</Value></Password><Enabled>true</Enabled><LogonCount>1</LogonCount><Username>${var.config["vm_username"]}</Username></AutoLogon>"
    }

    # Unattend config is to enable basic auth in WinRM, required for the provisioner stage.
    additional_unattend_config {
      pass         = "oobeSystem"
      component    = "Microsoft-Windows-Shell-Setup"
      setting_name = "FirstLogonCommands"

      #content      = "${file("${path.module}/files/FirstLogonCommands.xml")}"

      content = "${file("${path.module}/files/FirstLogonCommands.xml")}"
    }
  }
}

resource "null_resource" "create-dir" {
  provisioner "remote-exec" {
    connection {
      type     = "winrm"
      host     = "${azurerm_public_ip.vm-pip.ip_address}"
      user     = "${var.config["vm_username"]}"
      password = "${var.config["vm_password"]}"
      insecure = true

      #use_ntlm = true
      timeout = "30m"
    }

    inline = [
      "PowerShell -Command New-Item -Path \"C:\\scripts\" -ItemType Directory -Force",
    ]
  }

  depends_on = ["azurerm_virtual_machine.vm-1"]
}

resource "null_resource" "copy-files" {
  # Copies all files and folders in scripts to C:/scripts
  provisioner "file" {
    connection {
      type     = "winrm"
      host     = "${azurerm_public_ip.vm-pip.ip_address}"
      user     = "${var.config["vm_username"]}"
      password = "${var.config["vm_password"]}"

      timeout = "30m"
    }

    source      = "./scripts/"
    destination = "c:/scripts"
  }

  depends_on = ["null_resource.create-dir"]
}

resource "null_resource" "local-exec-vm-1" {
  provisioner "remote-exec" {
    connection {
      type     = "winrm"
      host     = "${azurerm_public_ip.vm-pip.fqdn}"
      user     = "${var.config["vm_username"]}"
      password = "${var.config["vm_password"]}"
      timeout  = "5m"
    }

    inline = [
      "powershell.exe -ExecutionPolicy Bypass -File C:\\scripts\\InstallJira.ps1",
    ]
  }

  depends_on = ["null_resource.copy-files"]
}
