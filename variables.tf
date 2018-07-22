variable "subscription_id" {}
variable "client_id" {}
variable "client_secret" {}

variable "tenant_id" {}

variable "config" {
  type = "map"

  default {
    # Resource Group settings
    "resource_group" = "TEST-RSG-JIR-WIN-001"
    "location"       = "East US"

    # Network Security Group settings
    "security_group_name" = "TEST-NSG-JIR-WIN-001"

    # Network settings
    "vnet_name"            = "TEST-VNT-JIR-WIN-001"
    "vnet_address_range"   = "10.0.0.0/24"
    "subnet_name"          = "TEST-SNT-JIR-WIN-001"
    "subnet_address_range" = "10.0.0.0/28"

    # Virtual Machine settings
    "vm_name" = "TESTJIRWINVM001"

    #"jenkins_master_secondary_vmname"     = "TESTJENMSTVM002"
    "vm_size"            = "Standard_DS2_v2"
    "vm_image_publisher" = "MicrosoftWindowsServer"
    "vm_image_offer"     = "WindowsServer"
    "vm_image_sku"       = "2016-Datacenter"
    "vm_image_version"   = "latest"

    "vm_username" = "os_admin"
    "vm_password" = "P@ssword12345"
  }
}
