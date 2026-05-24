#  NexaRetail DevOps Platform

![CI](https://github.com/Dkls7777/nexaretail-devops-platform/actions/workflows/ci.yml/badge.svg)
![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Azure](https://img.shields.io/badge/Cloud-Azure%20AKS-0078D4?logo=microsoft-azure)
![Terraform](https://img.shields.io/badge/IaC-Terraform-7B42BC?logo=terraform)
![ArgoCD](https://img.shields.io/badge/GitOps-ArgoCD-EF7B4D?logo=argo)
![Kubernetes](https://img.shields.io/badge/Orchestration-Kubernetes-326CE5?logo=kubernetes)

> Plateforme DevSecOps cloud-native complète simulant la migration d'infrastructure de NexaRetail SAS vers Azure AKS. Zéro downtime, déploiements quotidiens, -18% de coûts infra.


##  Contexte & Problème résolu
 
*L'entreprise :* NexaRetail SAS — scale-up française e-commerce B2B, 180 collaborateurs, 
4 millions de commandes/mois pour 2 300 marchands clients.

**Le problème :** Infrastructure sur serveurs dédiés OVH, déploiements 100% manuels 
chaque jeudi soir via des shell scripts dans des cron jobs. Le serveur de secours 
n'avait pas été testé depuis 14 mois.

**L'incident déclencheur :** En janvier, une mise en production a mis le site hors ligne 
pendant **3h47** — le CTO a reçu un appel de son plus gros client à 23h. 
MTTR (temps de restauration) : 3h47. Détection de l'incident : quand le client appelle.

**Ma mission :** Migrer vers une infrastructure cloud-native Azure en 8 semaines.
Concevoir et déployer de A à Z une plateforme DevSecOps complète incluant :
- Provisionnement IaC avec Terraform (AKS, ACR, Key Vault)
- Pipeline CI/CD avec GitHub Actions et quality gate Trivy
- GitOps avec ArgoCD — chaque push sur main déclenche un déploiement automatique
- Monitoring avec SLO Prometheus (99,5% des requêtes < 500ms)
- Gestion des secrets avec HashiCorp Vault (conformité SOC 2)
- Sécurité runtime avec Falco et audit Kubescape (score NSA/CISA > 70%)

##  Objectifs

| Objectif | Mesure | Statut |
|---|---|---|
| Zéro downtime | Rolling updates Kubernetes | 🔄 En cours |
| Déploiements quotidiens | Plusieurs fois/jour via GitOps | 🔄 En cours |
| Réduction coûts infra | -18% coût mensuel | 🔄 En cours |
| Détection incident | < 2 minutes via alertes Prometheus | 🔄 En cours |
| MTTR | < 15 minutes | 🔄 En cours |
| Conformité SOC 2 | Score Kubescape NSA/CISA > 70% | 🔄 En cours |


##  Architecture
GitHub → GitHub Actions (CI) → Azure Container Registry
↓
ArgoCD (GitOps) → AKS Cluster
↓
Prometheus + Grafana | Vault | Falco | Kubescape


##  Stack technique

| Catégorie | Technologie |
|---|---|
| Cloud | Microsoft Azure (AKS, ACR, Key Vault) |
| IaC | Terraform |
| Configuration | Ansible |
| GitOps | ArgoCD + Helm |
| CI/CD | GitHub Actions |
| Monitoring | Prometheus + Grafana |
| Secrets | HashiCorp Vault |
| Sécurité runtime | Falco |
| Conformité | Kubescape (NSA/CISA, MITRE) |
| Container Scanning | Trivy |


## 📁 Structure du repo
nexaretail-devops-platform/
├── app/
│   ├── src/index.js
│   ├── tests/
│   └── Dockerfile
├── infrastructure/
│   └── terraform/
├── platform/
│   ├── argocd/
│   ├── helm/nexaretail-api/
│   ├── monitoring/
│   └── security/
├── .github/workflows/
│   ├── ci.yml
│   └── cd.yml
└── docs/


##  Résultats Avant / Après

| Indicateur | Avant (OVH) | Après (Cloud Native) |
|---|---|---|
| Fréquence de déploiement | 1x/semaine | Plusieurs fois/jour |
| Durée de déploiement | 35-50 min | 4-6 min |
| MTTR | 3h47 | < 15 minutes |
| Détection d'incident | Quand le client appelle | < 2 minutes |
| Coût mensuel infra | Base 100 | Base 82 (-18%) |


##  Modules

- **Module 0** — Structure du repository
- **Module 1** — Infrastructure as Code avec Terraform
- **Module 2** — Configuration cluster avec Ansible
- **Module 3** — GitOps avec ArgoCD
- **Module 4** — Application conteneurisée Node.js
- **Module 5** — CI avec GitHub Actions + Trivy
- **Module 6** — CD + Automation GitOps
- **Module 7** — Monitoring Prometheus & Grafana
- **Module 8** — Secrets avec HashiCorp Vault
- **Module 9** — Sécurité runtime avec Falco
- **Module 10** — Conformité avec Kubescape

---

##  Auteur

**Sam DOSSOU** — Ingénieur Cybersécurité & Cloud | DevSecOps | EFREI Paris
[![GitHub](https://img.shields.io/badge/GitHub-Dkls7777-181717?logo=github)](https://github.com/Dkls7777)
[![LinkedIn](https://img.shields.io/badge/LinkedIn-sam--dossou-0A66C2?logo=linkedin)](https://linkedin.com/in/sam-dossou)
