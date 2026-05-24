# ==============================================================================
# NexaRetail DevOps Platform — Variables
# ==============================================================================

variable "location" {
  description = "Region Azure ou deployer les ressources"
  type        = string
  default     = "francecentral"
}

variable "environment" {
  description = "Environnement (prod, staging, dev)"
  type        = string
  default     = "prod"
}

variable "project" {
  description = "Nom du projet"
  type        = string
  default     = "nexaretail"
}

variable "aks_node_count" {
  description = "Nombre de nodes AKS au demarrage"
  type        = number
  default     = 3
}

variable "aks_min_count" {
  description = "Nombre minimum de nodes (autoscaling)"
  type        = number
  default     = 2
}

variable "aks_max_count" {
  description = "Nombre maximum de nodes (autoscaling)"
  type        = number
  default     = 5
}

variable "aks_vm_size" {
  description = "Taille des VMs pour les nodes AKS"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "kubernetes_version" {
  description = "Version de Kubernetes"
  type        = string
  default     = "1.29"
}
