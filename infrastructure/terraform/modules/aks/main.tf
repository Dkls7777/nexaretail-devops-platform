# ==============================================================================
# NexaRetail DevOps Platform — Module AKS Main
# ==============================================================================

resource "azurerm_kubernetes_cluster" "main" {
  name                = var.cluster_name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.cluster_name
  kubernetes_version  = var.kubernetes_version

  # Node pool principal (les 3 serveurs)
  default_node_pool {
    name                = "systempool"
    node_count          = var.node_count
    vm_size             = var.vm_size
    vnet_subnet_id      = var.subnet_id

    # Autoscaling : entre 2 et 5 nodes selon la charge
    auto_scaling_enabled = true
    min_count           = var.min_count
    max_count           = var.max_count

    upgrade_settings {
      max_surge = "10%"
    }
  }

  # Identite managee (pas besoin de gerer des credentials)
  identity {
    type = "SystemAssigned"
  }

  # Reseau Azure CNI (intégration native avec le VNet)
  network_profile {
    network_plugin    = "azure"
    network_policy    = "azure"
    load_balancer_sku = "standard"
  }

  # Monitoring connecte au Log Analytics
  oms_agent {
    log_analytics_workspace_id = var.law_workspace_id
  }

  # Securite
  role_based_access_control_enabled = true

  tags = var.tags
}
