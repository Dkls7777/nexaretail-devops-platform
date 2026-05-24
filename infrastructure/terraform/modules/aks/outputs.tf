# ==============================================================================
# NexaRetail DevOps Platform — Module AKS Outputs
# ==============================================================================

output "cluster_name" {
  description = "Nom du cluster AKS"
  value       = azurerm_kubernetes_cluster.main.name
}

output "cluster_id" {
  description = "ID du cluster AKS"
  value       = azurerm_kubernetes_cluster.main.id
}

output "kube_config" {
  description = "Configuration kubectl (sensible)"
  value       = azurerm_kubernetes_cluster.main.kube_config_raw
  sensitive   = true
}

output "kubelet_identity" {
  description = "Identite du kubelet (pour acceder a l'ACR)"
  value       = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
}
