# Guide de Reproduction — Phase 1 (Terraform / Azure AKS)

> Ce guide permet à n'importe qui de reproduire exactement la Phase 1
> du projet NexaRetail DevOps Platform, étape par étape.

---

##  Prérequis

- Windows 10/11 avec PowerShell
- Git installé
- Un compte Azure (gratuit ou payant)
- Un compte GitHub

---

##  Étape 1 — Installer Terraform

**1.1 Télécharger Terraform**

Aller sur : https://developer.hashicorp.com/terraform/install#windows  
Télécharger la version **AMD64** (fichier `.zip`)

**1.2 Installer dans PowerShell**

```powershell
# Créer le dossier
New-Item -ItemType Directory -Force -Path "C:\terraform"

# Décompresser le zip
Expand-Archive -Path "$env:USERPROFILE\Downloads\terraform_*.zip" -DestinationPath "C:\terraform" -Force

# Ajouter au PATH (niveau utilisateur, sans droits admin)
[System.Environment]::SetEnvironmentVariable("Path", $env:Path + ";C:\terraform", "User")
```

**1.3 Fermer et rouvrir PowerShell, puis vérifier**

```powershell
terraform --version
# Résultat attendu : Terraform v1.15.4 on windows_amd64
```

---

##  Étape 2 — Installer Azure CLI

**2.1 Télécharger l'installeur**

Aller sur : https://aka.ms/installazurecliwindows  
Double-cliquer sur le `.msi` et suivre l'installation.

**2.2 Vérifier**

```powershell
az --version
# Résultat attendu : azure-cli 2.86.0
```

---

##  Étape 3 — Configurer Azure

**3.1 Se connecter à Azure**

```powershell
az login
# Une fenêtre navigateur s'ouvre → se connecter avec son compte Microsoft
# Sélectionner l'abonnement → appuyer sur Entrée
```

**3.2 Vérifier le bon compte actif**

```powershell
az account show
# Vérifier que "name" correspond à votre abonnement
```

**3.3 Enregistrer le provider Storage (nouveau compte)**

```powershell
az provider register --namespace Microsoft.Storage

# Attendre que ce soit enregistré (1-2 minutes)
az provider show --namespace Microsoft.Storage --query "registrationState"
# Résultat attendu : "Registered"
```

**3.4 Créer le Resource Group pour l'état Terraform**

```powershell
az group create --name nexaretail-tfstate-rg --location francecentral
# Résultat : "provisioningState": "Succeeded"
```

**3.5 Créer le Storage Account**

```powershell
az storage account create `
  --name nexaretailtfstate `
  --resource-group nexaretail-tfstate-rg `
  --location francecentral `
  --sku Standard_LRS
# Résultat : "provisioningState": "Succeeded"
```

**3.6 Créer le container tfstate**

```powershell
az storage container create `
  --name tfstate `
  --account-name nexaretailtfstate
# Résultat : { "created": true }
```

---

##  Étape 4 — Créer la structure des dossiers

Naviguer dans le repo GitHub cloné localement :

```powershell
cd C:\Users\<ton-user>\nexaretail-devops-platform

# Créer les dossiers Terraform
New-Item -ItemType Directory -Force -Path "infrastructure\terraform\environments\prod"
New-Item -ItemType Directory -Force -Path "infrastructure\terraform\modules\aks"
```

---

##  Étape 5 — Créer les fichiers Terraform

>  **Important :** Toujours utiliser `@'...'@` (guillemets simples)
> et non `@"..."@` pour éviter que PowerShell interprète les variables `${var.x}`.

**5.1 providers.tf**

```powershell
@'
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.110.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.53.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.31.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "nexaretail-tfstate-rg"
    storage_account_name = "nexaretailtfstate"
    container_name       = "tfstate"
    key                  = "prod/terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
}

provider "azuread" {}
'@ | Set-Content -Path "infrastructure\terraform\environments\prod\providers.tf" -Encoding UTF8
```

**5.2 variables.tf**

```powershell
@'
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
  default     = "1.33"
}
'@ | Set-Content -Path "infrastructure\terraform\environments\prod\variables.tf" -Encoding UTF8
```

**5.3 main.tf**

```powershell
@'
resource "azurerm_resource_group" "main" {
  name     = "${var.project}-${var.environment}-rg"
  location = var.location
  tags = {
    project     = var.project
    environment = var.environment
    managed_by  = "terraform"
  }
}

resource "azurerm_virtual_network" "main" {
  name                = "${var.project}-${var.environment}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = azurerm_resource_group.main.tags
}

resource "azurerm_subnet" "aks" {
  name                 = "aks-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_log_analytics_workspace" "main" {
  name                = "${var.project}-${var.environment}-law"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = azurerm_resource_group.main.tags
}

resource "azurerm_container_registry" "main" {
  name                = "${var.project}${var.environment}acr"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Standard"
  admin_enabled       = false
  tags                = azurerm_resource_group.main.tags
}

module "aks" {
  source              = "../../modules/aks"
  cluster_name        = "${var.project}-${var.environment}-aks"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.aks.id
  kubernetes_version  = var.kubernetes_version
  node_count          = var.aks_node_count
  min_count           = var.aks_min_count
  max_count           = var.aks_max_count
  vm_size             = var.aks_vm_size
  law_workspace_id    = azurerm_log_analytics_workspace.main.id
  tags                = azurerm_resource_group.main.tags
}

resource "azurerm_role_assignment" "aks_acr" {
  principal_id                     = module.aks.kubelet_identity
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.main.id
  skip_service_principal_aad_check = true
}
'@ | Set-Content -Path "infrastructure\terraform\environments\prod\main.tf" -Encoding UTF8
```

**5.4 outputs.tf**

```powershell
@'
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
'@ | Set-Content -Path "infrastructure\terraform\environments\prod\outputs.tf" -Encoding UTF8
```

**5.5 terraform.tfvars**

```powershell
[System.IO.File]::WriteAllText(
  "C:\Users\<ton-user>\nexaretail-devops-platform\infrastructure\terraform\environments\prod\terraform.tfvars",
  @'
location           = "francecentral"
environment        = "prod"
project            = "nexaretail"
aks_node_count     = 3
aks_min_count      = 2
aks_max_count      = 5
aks_vm_size        = "Standard_D2s_v3"
kubernetes_version = "1.33"
'@,
  [System.Text.UTF8Encoding]::new($false)
)
```

**5.6 modules/aks/variables.tf**

```powershell
@'
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
  default     = "1.33"
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
'@ | Set-Content -Path "infrastructure\terraform\modules\aks\variables.tf" -Encoding UTF8
```

**5.7 modules/aks/main.tf**

```powershell
@'
resource "azurerm_kubernetes_cluster" "main" {
  name                = var.cluster_name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.cluster_name
  kubernetes_version  = var.kubernetes_version

  default_node_pool {
    name                = "systempool"
    node_count          = var.node_count
    vm_size             = var.vm_size
    vnet_subnet_id      = var.subnet_id
    enable_auto_scaling = true
    min_count           = var.min_count
    max_count           = var.max_count

    upgrade_settings {
      max_surge = "10%"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = "azure"
    network_policy    = "azure"
    load_balancer_sku = "standard"
  }

  oms_agent {
    log_analytics_workspace_id = var.law_workspace_id
  }

  role_based_access_control_enabled = true

  tags = var.tags
}
'@ | Set-Content -Path "infrastructure\terraform\modules\aks\main.tf" -Encoding UTF8
```

**5.8 modules/aks/outputs.tf**

```powershell
@'
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
  description = "Identite du kubelet (pour acceder a l ACR)"
  value       = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
}
'@ | Set-Content -Path "infrastructure\terraform\modules\aks\outputs.tf" -Encoding UTF8
```

---

##  Étape 6 — Lancer Terraform

```powershell
cd infrastructure\terraform\environments\prod

# Initialiser (télécharge les providers, configure le backend)
terraform init

# Vérifier la version Kubernetes disponible dans votre région
az aks get-versions --location francecentral --query "values[].version" -o table

# Prévisualiser ce qui va être créé (sans rien modifier)
terraform plan

# Créer les ressources sur Azure (taper "yes" pour confirmer)
terraform apply
```

>  **Note version Kubernetes :** Utiliser `az aks get-versions` pour choisir
> une version non-LTS disponible dans votre région. Eviter 1.29, 1.30, 1.31
> (LTS payant). Version 1.33 recommandée.

---

##  Étape 7 — .gitignore (IMPORTANT)

Ne jamais committer le dossier `.terraform` (contient des binaires de 200MB+).
Vérifier que le `.gitignore` contient bien ces lignes :

```
.terraform/
.terraform.lock.hcl
```

---

##  Étape 8 — Commit et push sur GitHub

```bash
git add infrastructure/terraform/
git add .gitignore
git commit -m "feat(terraform): M1 - IaC AKS cluster prod-ready

- providers.tf : Azure provider + backend Blob Storage
- variables.tf : parametres configurables (nodes, VM size, region)
- main.tf : Resource Group, VNet, Subnet, ACR, Log Analytics, AKS
- outputs.tf : cluster name, ACR URL, workspace ID
- modules/aks : module reutilisable avec autoscaling 2->5 nodes"

git push origin main
```

---

##  Nettoyage (pour éviter les frais Azure)

Quand le projet est terminé ou en pause, supprimer les ressources :

```powershell
cd infrastructure\terraform\environments\prod
terraform destroy
# Taper "yes" pour confirmer
```

> Cela supprime toutes les ressources dans `nexaretail-prod-rg` mais conserve
> le backend tfstate. Le code reste intact sur GitHub.

---

##  Résultat attendu

Après avoir suivi ce guide, vous devez avoir sur Azure :

```
nexaretail-prod-rg
├── nexaretail-prod-vnet     Réseau virtuel
├── aks-subnet               Sous-réseau
├── nexaretailprodacr        Container Registry
├── nexaretail-prod-law      Log Analytics
└── nexaretail-prod-aks      Cluster AKS (si quota VM disponible)
```

Et sur GitHub :
```
infrastructure/terraform/      8 fichiers Terraform
.gitignore                     .terraform/ exclu
```

---

##  Erreurs fréquentes

### Variables vides (`--rg`, `acr`)
**Cause :** Utilisation de `@"..."@` au lieu de `@'...'@` dans PowerShell.  
**Fix :** Toujours utiliser des guillemets simples pour les heredoc Terraform.

### `K8sVersionNotSupported`
**Cause :** Version Kubernetes obsolète ou en LTS payant.  
**Fix :** `az aks get-versions --location francecentral -o table` → choisir 1.33+.

### `SubscriptionNotFound`
**Cause :** Azure CLI utilise un mauvais compte.  
**Fix :** `az account set --subscription "<ID>"` puis `az account show`.

### `.terraform` rejeté par GitHub (fichier > 100MB)
**Cause :** `git add` trop large, inclut les binaires providers.  
**Fix :**
```bash
git rm -r --cached infrastructure/terraform/environments/prod/.terraform
echo ".terraform/" >> .gitignore
git reset --hard <hash-dernier-commit-propre>
git push origin main
```
