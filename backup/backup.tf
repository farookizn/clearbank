# Create a Recovery Services Vault
resource "azurerm_recovery_services_vault" "vault" {
  for_each = var.environments

  name                = "${each.key}-vault"
  location            = azurerm_resource_group.rg[each.key].location
  resource_group_name = azurerm_resource_group.rg[each.key].name

  sku {
    name = "Standard"
  }
}

# Create a backup policy
resource "azurerm_backup_policy_vm" "policy" {
  for_each = var.environments

  name                = "${each.key}-backup-policy"
  resource_group_name = azurerm_resource_group.rg[each.key].name
  recovery_vault_name = azurerm_recovery_services_vault.vault[each.key].name

  backup {
    frequency = "Daily"
    time      = "23:00"
  }

  retention_daily {
    count = 7
  }
}

# Apply backup policy to the VM
resource "azurerm_backup_protected_vm" "protected_vm" {
  for_each            = var.environments
  resource_group_name = azurerm_resource_group.rg[each.key].name
  recovery_vault_name = azurerm_recovery_services_vault.vault[each.key].name
  source_vm_id        = azurerm_linux_virtual_machine.vm[each.key].id
  backup_policy_id    = azurerm_backup_policy_vm.policy[each.key].id
}
