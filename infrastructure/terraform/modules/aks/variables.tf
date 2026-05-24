# ==============================================================================
# NexaRetail DevOps Platform — Module AKS Variables
# ==============================================================================

variable "cluster_name" {
  description = "Nom du cluster AKS"
  type        = string
}

variable "location" {
  description = "Region Azure"
  type        = string
}

variable "resource_group_name" {
  description = "Nom du Resource Group"
  type        = string
}

variable "subnet_id" {
  description = "ID du sous-reseau pour les nodes AKS"
  type        = string
}

variable "kubernetes_version" {
  description = "Version de Kubernetes"
  type        = string
  default     = "1.29"
}

variable "node_count" {
  description = "Nombre initial de nodes"
  type        = number
  default     = 3
}

variable "min_count" {
  description = "Nombre minimum de nodes (autoscaling)"
  type        = number
  default     = 2
}

variable "max_count" {
  description = "Nombre maximum de nodes (autoscaling)"
  type        = number
  default     = 5
}

variable "vm_size" {
  description = "Taille des VMs"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "law_workspace_id" {
  description = "ID du Log Analytics Workspace"
  type        = string
}

variable "tags" {
  description = "Tags Azure"
  type        = map(string)
  default     = {}
}
