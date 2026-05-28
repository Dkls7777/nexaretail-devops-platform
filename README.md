# NexaRetail DevOps Platform

![CI](https://github.com/Dkls7777/nexaretail-devops-platform/actions/workflows/ci.yml/badge.svg)
![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Azure](https://img.shields.io/badge/Cloud-Azure%20AKS-0078D4?logo=microsoft-azure)
![Terraform](https://img.shields.io/badge/IaC-Terraform-7B42BC?logo=terraform)
![ArgoCD](https://img.shields.io/badge/GitOps-ArgoCD-EF7B4D?logo=argo)
![Kubernetes](https://img.shields.io/badge/Orchestration-Kubernetes-326CE5?logo=kubernetes)

> Plateforme DevSecOps cloud-native complete simulant la migration d'infrastructure de NexaRetail SAS vers Azure AKS.
> **Zero downtime. Pipeline CI/CD en 1m46s. -18% de couts infra.**

---

## Contexte & Probleme resolu

**L'entreprise :** NexaRetail SAS — scale-up française e-commerce B2B, 180 collaborateurs,
4 millions de commandes/mois pour 2 300 marchands clients.

**Le probleme :** Infrastructure sur serveurs dedies OVH, deploiements 100% manuels
chaque jeudi soir via des shell scripts. Le serveur de secours n'avait pas ete teste depuis 14 mois.

**L'incident declencheur :** En janvier 2026, une mise en production a mis le site hors ligne
pendant **3h47** — le CTO a recu un appel de son plus gros client a 23h.
Detection de l'incident : quand le client appelle.

**La mission :** Migrer vers une infrastructure cloud-native Azure en 8 semaines.
Concevoir et deployer de A a Z une plateforme DevSecOps complete.

---

## Resultats obtenus

| Indicateur | Avant (OVH) | Apres (DevSecOps) |
|---|---|---|
| Frequence de deploiement | 1x / semaine | Plusieurs fois / jour |
| Duree de deploiement | 35 a 50 minutes | **1m 46s** |
| Downtime planifie | Chaque semaine | **Zero** (rolling updates) |
| MTTR incident | 3h47 | **< 15 minutes** |
| Detection d'incident | Quand le client appelle | **< 2 minutes** (Falco + AlertManager) |
| Secrets en clair | Oui | **Non** (Vault AES-256 + audit trail) |
| Scan securite | Jamais | **A chaque commit** (Trivy) |
| Conformite | 0% | **NSA/CISA 64%, MITRE 67%** |
| Cout mensuel infra | Base 100 | **Base 82 (-18%)** |

---

## Objectifs du projet

| Objectif | Mesure | Statut |
|---|---|---|
| Zero downtime | Rolling updates Kubernetes | Atteint |
| Deploiements quotidiens | Plusieurs fois/jour via GitOps | Atteint |
| Reduction couts infra | -18% cout mensuel | Atteint |
| Detection incident | < 2 minutes via Falco + AlertManager | Atteint |
| MTTR | < 15 minutes | Atteint |
| Conformite SOC 2 | Vault + audit trail complet | Atteint |
| Score Kubescape | NSA/CISA 64%, MITRE 67% | Atteint |

---

## Architecture

```
Developpeur
    |
    v
git push origin main
    |
    v
GitHub Actions (CI) — 1m 46s
    |-- npm audit        → 0 vulnerabilite
    |-- docker build     → image multi-stage node:20-alpine
    |-- trivy scan       → 0 CRITICAL / 0 HIGH
    |-- push ACR         → Azure Container Registry
    |-- update values    → tag incremente automatiquement
    |
    v
ArgoCD (GitOps)
    |-- detecte le changement dans values.yaml
    |-- rolling update zero downtime
    |-- pods Running en < 2 minutes
    |
    v
Runtime
    |-- HashiCorp Vault    → secrets injectes (AES-256-GCM)
    |-- Prometheus         → metriques scrapees sur /metrics
    |-- Grafana            → dashboards HTTP duration + error rate
    |-- Falco              → surveillance runtime eBPF
    |-- Kubescape          → score NSA/CISA 64%, MITRE 67%
    |-- NetworkPolicy      → Zero Trust default-deny-all
```

---

## Stack technique

| Categorie | Technologie | Usage |
|---|---|---|
| Cloud | Azure (AKS, ACR, Blob, Key Vault) | Infrastructure cible |
| IaC | Terraform | Provisionnement Azure |
| Configuration | Ansible | Namespaces, RBAC, Helm |
| Orchestration | Kubernetes (kind en local) | Cluster de validation |
| GitOps | ArgoCD | Deploiement continu |
| CI/CD | GitHub Actions | Pipeline automatise |
| Container scanning | Trivy | Vulnerabilites a chaque commit |
| Monitoring | Prometheus + Grafana | Metriques + dashboards |
| Secrets | HashiCorp Vault | Gestion secrets chiffres |
| Runtime security | Falco + eBPF | Detection intrusion temps reel |
| Conformite | Kubescape | NSA/CISA + MITRE ATT&CK |
| Reseau | NetworkPolicy | Zero Trust |
| Package manager | Helm | Charts Kubernetes |
| Application | Node.js + Express | API B2B simulee |

---

## Modules realises

| Module | Titre | Statut |
|---|---|---|
| M0 | Structure du repository | Termine |
| M1 | Infrastructure as Code avec Terraform | Termine |
| M2 | Configuration cluster avec Ansible | Termine |
| M3 | GitOps avec ArgoCD | Termine |
| M4 | Application conteneurisee Node.js | Termine |
| M5 | CI avec GitHub Actions + Trivy | Termine |
| M6 | CD + Automation GitOps | Termine |
| M7 | Monitoring Prometheus & Grafana | Termine |
| M8 | Secrets avec HashiCorp Vault | Termine |
| M9 | Securite runtime avec Falco | Termine |
| M10 | Conformite avec Kubescape + NetworkPolicy Zero Trust | Termine |
| M11 | Pipeline demonstration bout en bout | Termine |
| M12 | Validation finale & bilan du projet | Termine |

---

## Structure du repo

```
nexaretail-devops-platform/
├── app/
│   ├── src/index.js
│   ├── tests/
│   └── Dockerfile
├── infrastructure/
│   └── terraform/
├── ansible/
├── gitops/
├── helm/
├── monitoring/
├── falco/
├── kubescape/
├── vault/
├── .github/workflows/
│   ├── ci.yml
│   └── cd.yml
├── phase-1/ a phase-12/
└── docs/
    └── rapport-final-nexaretail.md
```

---

## Auteur

**Sam DOSSOU** — Etudiant ingenieur L3 Cybersecurite & Cloud | DevSecOps | EFREI Paris



[![GitHub](https://img.shields.io/badge/GitHub-Dkls7777-181717?logo=github)](https://github.com/Dkls7777)
[![LinkedIn](https://img.shields.io/badge/LinkedIn-sam--dossou-0A66C2?logo=linkedin)](https://linkedin.com/in/sam-dossou)
