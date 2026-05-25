# Rapport Module 1 — Infrastructure as Code (Terraform / Azure AKS)

**Projet :** NexaRetail DevOps Platform  
**Auteur :** Sam DOSSOU  
**Date :** 25 mai 2026  
**Statut :** Terminé ✅

---

## Contexte

NexaRetail SAS (e-commerce B2B, 4M commandes/mois) subissait des incidents liés à des déploiements manuels sur OVH. En janvier, une mise en production a mis le site hors ligne pendant **3h47**. L'objectif de ce module est de poser les fondations d'une infrastructure cloud-native reproductible et automatisée sur Azure AKS.

---

## Ce qui a été réalisé

### Outils installés
- **Terraform v1.15.4** — Infrastructure as Code
- **Azure CLI v2.86.0** — Interface Azure depuis le terminal

### Backend Terraform sur Azure
- Resource Group `nexaretail-tfstate-rg` créé
- Storage Account `nexaretailtfstate` créé (francecentral)
- Container `tfstate` configuré pour stocker l'état Terraform

### Fichiers Terraform créés (353 lignes)

| Fichier | Rôle |
|---------|------|
| `environments/prod/providers.tf` | Connexion Azure + backend Blob Storage |
| `environments/prod/variables.tf` | 8 variables configurables |
| `environments/prod/main.tf` | Ressources Azure : RG, VNet, Subnet, ACR, Log Analytics, AKS |
| `environments/prod/outputs.tf` | 6 outputs réutilisables par les modules suivants |
| `environments/prod/terraform.tfvars` | Valeurs de production |
| `modules/aks/main.tf` | Module AKS réutilisable avec autoscaling |
| `modules/aks/variables.tf` | 12 variables d'entrée |
| `modules/aks/outputs.tf` | cluster_name, cluster_id, kube_config, kubelet_identity |

### Ressources Azure créées

| Ressource | Nom | Statut |
|-----------|-----|--------|
| Resource Group | `nexaretail-prod-rg` | ✅ Créé |
| Virtual Network | `nexaretail-prod-vnet` | ✅ Créé |
| Subnet | `aks-subnet` (10.0.1.0/24) | ✅ Créé |
| Container Registry | `nexaretailprodacr` | ✅ Créé |
| Log Analytics | `nexaretail-prod-law` | ✅ Créé |
| AKS Cluster | `nexaretail-prod-aks` | ⚠️ Bloqué quota VM free tier
### Validation Terraform
terraform init  → Providers installés, backend configuré ✅
terraform plan  → Plan: 7 to add, 0 to change, 0 to destroy ✅
terraform apply → 5/7 ressources créées sur Azure
# Problèmes rencontrés et solutions

| Problème | Cause | Solution |
|----------|-------|----------|
| Variables vides `--rg` | PowerShell interprète `${var.x}` | Utiliser `@'...'@` (single-quote) |
| K8s version non supportée | 1.29 obsolète en francecentral | Mise à jour vers 1.33 |
| VM size non disponible | Quota free tier Azure | Limitation connue, non bloquante pour le portfolio |
| .terraform committé | `git add` trop large | Reset + `.gitignore` corrigé |

## Architecture déployée
Azure Cloud (francecentral)
└── nexaretail-prod-rg
├── nexaretail-prod-vnet (10.0.0.0/16)
│   └── aks-subnet (10.0.1.0/24)
├── nexaretailprodacr (Container Registry)
├── nexaretail-prod-law (Log Analytics)
└── nexaretail-prod-aks (AKS — 3 nodes, autoscale 2→5)

---

## Commits Git

- `c9a7788` — feat(terraform): M1 - IaC AKS cluster prod-ready
- `a0255a8` — fix(terraform): correction interpolation variables, version K8s 1.33, gitignore

## Ticket Jira

- **SCRUM-6** — Provisionner le cluster AKS avec Terraform → Terminé ✅
