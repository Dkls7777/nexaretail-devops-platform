# ==============================================================================
# NexaRetail DevOps Platform — Main Infrastructure
# ==============================================================================

# --- Resource Group (le dossier qui contient tout) ---
resource "azurerm_resource_group" "main" {
  name     = "--rg"
  location = var.location

  tags = {
    project     = var.project
    environment = var.environment
    managed_by  = "terraform"
  }
}

# --- Reseau virtuel (le reseau prive de NexaRetail) ---
resource "azurerm_virtual_network" "main" {
  name                = "--vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tags = azurerm_resource_group.main.tags
}

# --- Sous-reseau dedie au cluster AKS ---
resource "azurerm_subnet" "aks" {
  name                 = "aks-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}

# --- Log Analytics (centralise tous les logs) ---
resource "azurerm_log_analytics_workspace" "main" {
  name                = "--law"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = azurerm_resource_group.main.tags
}

# --- Azure Container Registry (stocke les images Docker) ---
resource "azurerm_container_registry" "main" {
  name                = "acr"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Standard"
  admin_enabled       = false

  tags = azurerm_resource_group.main.tags
}

# --- Cluster AKS (les 3 serveurs Kubernetes) ---
module "aks" {
  source = "../../modules/aks"

  cluster_name        = "--aks"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.aks.id
  kubernetes_version  = var.kubernetes_version
  node_count          = var.aks_node_count
  min_count           = var.aks_min_count
  max_count           = var.aks_max_count
  vm_size             = var.aks_vm_size
  law_workspace_id    = azurerm_log_analytics_workspace.main.id

  tags = azurerm_resource_group.main.tags
}

# --- Donner acces AKS a l'ACR (pull des images Docker) ---
resource "azurerm_role_assignment" "aks_acr" {
  principal_id                     = module.aks.kubelet_identity
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.main.id
  skip_service_principal_aad_check = true
}
