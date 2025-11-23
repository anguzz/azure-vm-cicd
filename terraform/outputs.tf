output "public_ip" {
  description = "Public IP of the VM"
  value       = azurerm_public_ip.public_ip.ip_address
}

output "vm_id" {
  description = "VM resource ID"
  value       = azurerm_linux_virtual_machine.vm.id
}
