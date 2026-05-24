# ==============================================================================
# NexaRetail DevOps Platform — Outputs
# ==============================================================================

output "resource_group_name" {
  description = "Nom du Resource Group"
  value       = azurerm_resource_group.main.name
}

output "aks_cluster_name" {
  description = "Nom du cluster AKS"
  value       = module.aks.cluster_name
}

output "aks_cluster_id" {
  description = "ID du cluster AKS"
  value       = module.aks.cluster_id
}

output "acr_login_server" {
  description = "URL de connexion au registre Docker"
  value       = azurerm_container_registry.main.login_server
}

output "acr_name" {
  description = "Nom du registre Docker"
  value       = azurerm_container_registry.main.name
}

output "law_workspace_id" {
  description = "ID du workspace de logs"
  value       = azurerm_log_analytics_workspace.main.id
}
