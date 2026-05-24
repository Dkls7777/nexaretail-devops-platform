# ==============================================================================
# NexaRetail DevOps Platform — Valeurs de production
# ==============================================================================

location           = "francecentral"
environment        = "prod"
project            = "nexaretail"

# Cluster AKS
aks_node_count     = 3
aks_min_count      = 2
aks_max_count      = 5
aks_vm_size        = "Standard_D2s_v3"
kubernetes_version = "1.29"
