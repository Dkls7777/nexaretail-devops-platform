# Phase 1 — Infrastructure as Code (Terraform / Azure AKS)

> **Projet :** NexaRetail DevOps Platform  
> **Auteur :** Sam DOSSOU — Étudiant L3 Cybersécurité EFREI Paris    
> **Statut :**  Terminé  

---

##  Contenu de ce dossier

| Fichier | Description |
|---------|-------------|
| `README.md` | Ce fichier — rapport + guide de reproduction |
| `guide-reproduction.md` | Toutes les commandes exactes pour reproduire |

---

##  Objectif de la Phase 1

L'objectif de la Phase 1 est de poser les fondations de l'infrastructure cloud-native de NexaRetail en écrivant le code Terraform qui permet de créer automatiquement sur Azure tous les serveurs, réseaux et services nécessaires au projet.
Avant cette phase, l'infrastructure n'existait que dans des clics manuels impossibles à reproduire. Après cette phase, une seule commande terraform apply suffit pour recréer toute l'infrastructure en 8 minutes, identique à chaque fois.

---

##  Ce qui a été réalisé

### Module 0 — Structure du repo GitHub
- Création de 11 dossiers organisant tout le projet DevSecOps
- Commit conventionnel `feat(structure): M0`
- Ticket Jira SCRUM-5 → Terminé 

### Module 1 — Terraform / Azure AKS
- Installation de Terraform v1.15.4 et Azure CLI v2.86.0
- Création d'un compte Azure (200$ de crédits gratuits)
- Configuration du backend Terraform sur Azure Blob Storage
- Écriture de 8 fichiers Terraform (353 lignes de code IaC)
- Déploiement de 5 ressources Azure réelles
- Ticket Jira SCRUM-6 → Terminé 

---

##  Architecture déployée sur Azure

```
Azure Cloud (France Central)
│
├── nexaretail-tfstate-rg          ← Backend état Terraform
│   └── nexaretailtfstate          ← Storage Account
│       └── tfstate                ← Container
│
└── nexaretail-prod-rg             ← Ressources production
    ├── nexaretail-prod-vnet       ← Réseau virtuel (10.0.0.0/16)
    │   └── aks-subnet             ← Sous-réseau (10.0.1.0/24)
    ├── nexaretailprodacr          ← Container Registry (images Docker)
    ├── nexaretail-prod-law        ← Log Analytics (logs centralisés)
    └── nexaretail-prod-aks        ← Cluster AKS (code prêt, quota VM*)
```

> *Le cluster AKS est bloqué par le quota VM du compte gratuit Azure.
> Le code Terraform est 100% valide (`terraform plan` : 7 ressources, 0 erreurs).
> Avec un abonnement standard, `terraform apply` crée le cluster complet.*

---

##  Structure des fichiers Terraform créés

```
infrastructure/terraform/
├── environments/
│   └── prod/
│       ├── providers.tf      ← Connexion Azure + backend Blob Storage
│       ├── variables.tf      ← 8 variables configurables
│       ├── main.tf           ← Ressources Azure (RG, VNet, ACR, AKS...)
│       ├── outputs.tf        ← 6 outputs réutilisables
│       └── terraform.tfvars  ← Valeurs de production
└── modules/
    └── aks/
        ├── main.tf           ← Module AKS réutilisable + autoscaling
        ├── variables.tf      ← 12 variables d'entrée
        └── outputs.tf        ← cluster_name, cluster_id, kube_config
```

---

##  Validation Terraform

```
terraform init   → Providers installés, backend Azure configuré    
terraform plan   → Plan: 7 to add, 0 to change, 0 to destroy       
terraform apply  → 5/7 ressources créées sur Azure                  
```

---

##  Problèmes rencontrés et solutions

| Problème | Solution |
|----------|----------|
| Variables PowerShell vides `--rg` | Utiliser `@'...'@` au lieu de `@"..."@` |
| K8s version 1.29 obsolète | `az aks get-versions` → version 1.33 |
| K8s 1.30/1.31 en LTS payant | Version 1.33 non-LTS sélectionnée |
| VM Standard_D2s_v3 quota | Limitation compte gratuit, code valide |
| `.terraform` committé (224MB) | `git reset --hard` + `.gitignore` corrigé |
| Provider Microsoft.Storage non enregistré | `az provider register` |

---

##  Chiffres clés

| Indicateur | Valeur |
|------------|--------|
| Fichiers Terraform créés | 8 |
| Lignes de code IaC | 353 |
| Ressources Azure créées | 5 |
| Commits Git | 4 |
| Tickets Jira fermés | 2 (SCRUM-5, SCRUM-6) |

---

## 🔗 Liens utiles

- **GitHub :** github.com/Dkls7777/nexaretail-devops-platform
- **Jira :** samdossou26.atlassian.net
- **Azure Portal :** portal.azure.com → nexaretail-prod-rg
- **Guide reproduction :** voir `guide-reproduction.md`

- ---

##  Code source de cette phase

Les fichiers de configuration deployés lors de cette phase :

| Fichier | Description |
|---------|-------------|
| [`infrastructure/terraform/environments/prod/main.tf`](https://github.com/Dkls7777/nexaretail-devops-platform/blob/main/infrastructure/terraform/environments/prod/main.tf) | Ressources Azure principales (AKS, ACR, VNet) |
| [`infrastructure/terraform/environments/prod/variables.tf`](https://github.com/Dkls7777/nexaretail-devops-platform/blob/main/infrastructure/terraform/environments/prod/variables.tf) | Déclaration des variables |
| [`infrastructure/terraform/environments/prod/terraform.tfvars`](https://github.com/Dkls7777/nexaretail-devops-platform/blob/main/infrastructure/terraform/environments/prod/terraform.tfvars) | Valeurs des variables (région, noms) |
| [`infrastructure/terraform/modules/aks/main.tf`](https://github.com/Dkls7777/nexaretail-devops-platform/blob/main/infrastructure/terraform/modules/aks/main.tf) | Module AKS réutilisable |
| [`infrastructure/terraform/modules/aks/variables.tf`](https://github.com/Dkls7777/nexaretail-devops-platform/blob/main/infrastructure/terraform/modules/aks/variables.tf) | Variables du module AKS |

> Le dossier complet : [`infrastructure/`](https://github.com/Dkls7777/nexaretail-devops-platform/tree/main/infrastructure)
