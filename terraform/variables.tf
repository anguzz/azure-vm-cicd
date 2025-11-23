variable "resource_group_name" {
  description = "Name of the Azure resource group"
  type        = string
  default     = "rg-devops-demo"
}

variable "location" {
  description = "Azure region to deploy resources"
  type        = string
  default     = "eastus"
}

variable "vm_name" {
  description = "Virtual machine name"
  type        = string
  default     = "devops-demo-vm"
}

variable "vm_size" {
  description = "VM size"
  type        = string
  default     = "Standard_B1s"
}

variable "admin_username" {
  description = "Admin username for SSH"
  type        = string
  default     = "azureuser"
}


