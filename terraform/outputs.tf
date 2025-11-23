output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "public_ip_address" {
  value = azurerm_linux_virtual_machine.my_terraform_vm.public_ip_address
}

output "private_key_pem" {
  # This value extracts the privateKey from the JSON output of the azapi action
  value     = jsondecode(azapi_resource_action.ssh_public_key_gen.output).privateKey
  # CRITICAL: This hides the key from normal Terraform log output in CI/CD
  sensitive = true 
}