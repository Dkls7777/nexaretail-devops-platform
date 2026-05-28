#  Azure Administrator Hands-On Lab — DK WAVE TECHNOLOGY

> **Projet complet d'administration Azure** réalisé dans le cadre d'une formation pratique d'Administrateur Systèmes & Réseaux Cloud.  
> Déployé entièrement via Azure CLI, Cloud Shell et API REST Azure.

---

##  À propos

**Sam DOSSOU** — Étudiant en premiere année de cycle ingénieur/ Alternance recherchée  
Environnement : Microsoft Azure (West Europe) | Subscription : Pay-As-You-Go  
Période de réalisation : Avril 2026

---

##  Contexte du projet

**DK WAVE TECHNOLOGY** est une entreprise fictive éditrice de logiciels SaaS en pleine croissance.  
- 20 collaborateurs en télétravail  
- Application web exposée aux clients  
- Infrastructure 100 % cloud — aucun datacenter on-premise  
- Un seul administrateur IT (rôle joué dans ce lab)

L'objectif était de construire, de zéro, une infrastructure Azure **complète, sécurisée, supervisée et résiliente**, en suivant les bonnes pratiques enterprise : Zero Trust, moindre privilège, Infrastructure as Code, monitoring proactif et Disaster Recovery.

---

##  Architecture globale

```
                        ┌─────────────────────────────────────┐
                        │         Azure Subscription           │
                        │                                       │
                        │  ┌────────────────────────────────┐  │
                        │  │      rg-dkwave-shared           │  │
                        │  │  VNet · NSG · Bastion · Firewall│  │
                        │  │  Log Analytics · RSV · Policy   │  │
                        │  └────────────────────────────────┘  │
                        │                                       │
                        │  ┌────────────────────────────────┐  │
                        │  │       rg-dkwave-prod            │  │
                        │  │  vm-app01 (Ubuntu 22.04)        │  │
                        │  │  vm-web02 (Windows Server 2022) │  │
                        │  │  Key Vault · Load Balancer      │  │
                        │  └────────────────────────────────┘  │
                        │                                       │
                        │  ┌────────────────────────────────┐  │
                        │  │      rg-dkwave-nonprod          │  │
                        │  │  Environnements Dev / Test      │  │
                        │  └────────────────────────────────┘  │
                        └─────────────────────────────────────┘
```

**Réseau VNet (10.0.0.0/16) — 6 sous-réseaux :**

| Sous-réseau | Plage IP | Rôle |
|---|---|---|
| AzureFirewallSubnet | 10.0.0.0/24 | Azure Firewall |
| GatewaySubnet | 10.0.1.0/24 | VPN Gateway |
| subnet-web | 10.0.10.0/24 | Couche Web / Load Balancer |
| subnet-app | 10.0.20.0/24 | Couche Application |
| subnet-db | 10.0.30.0/24 | Base de données (usage futur) |
| AzureBastionSubnet | 10.0.40.0/26 | Accès admin sécurisé |

---

##  Phases du projet

| Phase | Titre | Statut |
|---|---|---|
| [Phase 1](./phases/phase1/README.md) |  Mise en place des fondations | Complétée |
| [Phase 2](./phases/phase2/README.md) |  Infrastructure Cœur |  Complétée |
| [Phase 3](./phases/phase3/README.md) |  Sécurité & Gouvernance |  Complétée |
| [Phase 4](./phases/phase4/README.md) |  Monitoring & Opérations |  Complétée |
| [Phase 5](./phases/phase5/README.md) |  Automatisation & Optimisation |  Complétée |
| [Phase 6](./phases/phase6/README.md) |  Résilience & Disaster Recovery |  Complétée |
| [Phase 7](./phases/phase7/README.md) |  Daily Administration & Operations |  Complétée |

---

##  Compétences démontrées

### Cloud & Azure
- Gestion d'identités avec **Entra ID** (RBAC, groupes, MFA, accès conditionnel)
- Conception et déploiement de **réseaux virtuels** segmentés (VNet, NSG, subnets)
- Sécurisation avec **Azure Firewall**, **Key Vault**, **Microsoft Defender for Cloud**, **WAF**
- Monitoring avec **Log Analytics**, **Azure Monitor**, **Data Collection Rules**, alertes CPU
- **Infrastructure as Code** avec Azure Bicep (templates paramétrés multi-environnements)
- **Backup et Disaster Recovery** avec Recovery Services Vault et Azure Site Recovery
- Administration quotidienne : cycle de vie utilisateurs, gestion d'incidents, change management

### Outils & Méthodes
- **Azure CLI** — commandes avancées et scripting
- **API REST Azure** (`az rest`) — contournement des limitations CLI
- **KQL** (Kusto Query Language) — requêtes Log Analytics
- **Azure Bicep** — Infrastructure as Code
- **Cloud Shell** — environnement de travail standardisé

### Soft Skills démontrés
- Résolution de problèmes en conditions réelles (quotas, policies bloquantes, erreurs CLI)
- Adaptation méthodologique face aux contraintes techniques imprévues
- Documentation professionnelle de chaque phase

---

##  Contrainte transversale majeure

Tout au long du projet, une **Azure Policy** enforçant 4 tags obligatoires (`Environment`, `Owner`, `Company`, `CostCenter`) bloquait automatiquement toutes les créations de ressources via les commandes CLI standard.

**Solution systématiquement appliquée :** utilisation de `az rest` avec des corps JSON complets incluant les tags requis, contournant les limitations des extensions CLI.

```bash
# Exemple de workaround az rest utilisé tout au long du projet
az rest --method PUT \
  --uri "https://management.azure.com/subscriptions/{sub}/resourceGroups/{rg}/providers/{resource}?api-version=..." \
  --body '{
    "location": "westeurope",
    "properties": { ... },
    "tags": {
      "Environment": "Production",
      "Owner": "IT",
      "Company": "DK-WAVE",
      "CostCenter": "IT-OPS"
    }
  }'
```

---

## Structure du dépôt

```
azure-admin-dkwave/
├── README.md                    ← Vous êtes ici — vue d'ensemble du projet
├── rapports/                    ← Rapports Word complets par phase
│   ├── Rapport_Phase1.docx
│   ├── Rapport_Phase2.docx
│   ├── Rapport_Phase3.docx
│   ├── Rapport_Phase4.docx
│   ├── Rapport_Phase5.docx
│   ├── Rapport_Phase6.docx
│   └── Rapport_Phase7.docx
└── phases/                      ← Détail technique de chaque phase
    ├── phase1/README.md         ← Fondations : identités, RBAC, tags
    ├── phase2/README.md         ← Réseau, VMs, Bastion, Load Balancer
    ├── phase3/README.md         ← Sécurité : Firewall, Key Vault, Defender
    ├── phase4/README.md         ← Monitoring, alertes, Log Analytics
    ├── phase5/README.md         ← Bicep IaC, Update Manager, Cost Management
    ├── phase6/README.md         ← Backup, Recovery Vault, test de restauration
    └── phase7/README.md         ← Administration quotidienne, incidents, RBAC
```

---

## Contact

**Sam DOSSOU** — En recherche d'alternance 
 [dossam2006@gmail.com]  
🔗 www.linkedin.com/in/sam-dossou
