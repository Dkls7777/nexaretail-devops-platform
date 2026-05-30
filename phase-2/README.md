# Phase 2 — Configuration Kubernetes avec Ansible

> **Projet :** NexaRetail DevOps Platform
> **Auteur :** Sam DOSSOU — Étudiant L3 Cybersécurité EFREI Paris
> **Statut :**  Terminé

---

##  Contenu de ce dossier

| Fichier | Description |
|---------|-------------|
| `README.md` | Ce fichier — rapport + bilan de la phase |
| `guide-reproduction.md` | Toutes les commandes exactes pour reproduire |

---

##  Objectif de la Phase 2

Après avoir provisionné l'infrastructure en Phase 1, il faut maintenant
**configurer** le cluster Kubernetes pour accueillir les workloads NexaRetail.

Ansible permet de faire cette configuration de manière **reproductible et
idempotente** : qu'on lance le playbook une ou dix fois, le résultat est
toujours identique. C'est exactement ce dont NexaRetail a besoin pour éviter
les erreurs humaines qui causaient les incidents.

> *"Avant : on configurait le cluster à la main en espérant ne rien oublier.
> Maintenant : une commande ansible-playbook recrée toute la configuration en
> 30 secondes, identique à chaque fois."*

---

##  Ce qui a été réalisé

###  Installation de l'environnement Linux (WSL)

Ansible ne fonctionne pas nativement sur Windows comme control node.
La solution standard en entreprise est d'utiliser WSL (Windows Subsystem
for Linux) — un vrai Ubuntu qui tourne à l'intérieur de Windows, sans
dual boot ni machine virtuelle séparée.

- WSL 2.7.3 installé via PowerShell (`wsl --install -d Ubuntu`)
- Ubuntu 24 (resolute) configuré avec compte utilisateur Linux
- C'est la première fois que Sam dispose d'un vrai environnement Linux sur son PC

###  Installation de la chaîne d'outils DevOps

Dans WSL, installation de tous les outils nécessaires au projet :

| Outil | Version | Rôle |
|-------|---------|------|
| Ansible | 2.20.1 | Automatisation de configuration |
| kubectl | v1.36.1 | Client Kubernetes |
| Azure CLI | 2.86.0 | Client Azure |
| Docker | 29.1.3 | Conteneurisation |
| kind | 0.27.0 | Kubernetes local |
| Helm | v3.21.0 | Gestionnaire de paquets Kubernetes |

###  Problème quota Azure — Changement de stratégie

On a tenté de créer un cluster AKS sur Azure, mais la subscription gratuite
n'autorise que des VMs très premium (série M, NC, NV — à partir de 500€/mois).
Les VMs standard nécessaires à AKS (Standard_B2s, Standard_D2s) sont bloquées.

**Solution adoptée : `kind` (Kubernetes IN Docker)**
kind crée un vrai cluster Kubernetes local dans Docker. Comportement identique
à AKS pour tous nos besoins DevSecOps. C'est d'ailleurs ce que font la plupart
des équipes DevOps pour les environnements de développement.

###  Cluster Kubernetes local

Le cluster `nexaretail-aks` a été créé avec kind en **13 secondes**.
1 node control-plane en Kubernetes v1.32.2, prêt à recevoir nos workloads.

###  Configuration Ansible du cluster

Création de 8 fichiers Ansible organisés en 3 rôles :

- **namespaces** : 6 espaces de travail NexaRetail isolés par équipe
- **rbac** : contrôle d'accès Kubernetes (qui peut faire quoi)
- **helm-repos** : 4 dépôts de packages pour les outils DevSecOps

Le playbook `site.yml` orchestre ces 3 rôles avec des pre_tasks de vérification
et des post_tasks de résumé.

---

##  Architecture configurée

```
Cluster Kubernetes (kind-nexaretail-aks)
│
├── nexaretail-prod        ← Applications de production
├── nexaretail-staging     ← Environnement de test
├── monitoring             ← Prometheus + Grafana (Phase 7)
├── argocd                 ← GitOps controller (Phase 3)
├── vault                  ← Gestion des secrets (Phase 8)
└── security               ← Falco + Kubescape (Phases 9-10)

RBAC
├── ClusterRole nexaretail-devops    ← Lecture + écriture pods/services
├── ClusterRole nexaretail-readonly  ← Lecture seule
└── ServiceAccount argocd-deployer   ← Compte de déploiement ArgoCD

Helm Repositories
├── prometheus-community  ← Monitoring stack
├── argo                  ← ArgoCD + Argo Rollouts
├── hashicorp             ← Vault
└── falcosecurity         ← Falco runtime security
```

---

##  Structure des fichiers Ansible créés

```
ansible/
├── ansible.cfg                          ← Configuration Ansible
├── requirements.yml                     ← Collections Galaxy
├── inventory/
│   └── hosts.yml                        ← Inventaire cluster
├── group_vars/
│   └── all.yml                          ← Variables globales (namespaces, repos)
├── roles/
│   ├── namespaces/tasks/main.yml        ← Création des 6 namespaces
│   ├── rbac/tasks/main.yml              ← ClusterRoles + ServiceAccount
│   └── helm-repos/tasks/main.yml        ← Ajout des 4 repos Helm
└── playbooks/
    └── site.yml                         ← Playbook principal
```

---

##  Validation Ansible

```
PLAY RECAP
nexaretail-cluster : ok=16  changed=2  unreachable=0  failed=0  

kubectl get namespaces
NAME                 STATUS   AGE
argocd               Active   ✅
monitoring           Active   ✅
nexaretail-prod      Active   ✅
nexaretail-staging   Active   ✅
security             Active   ✅
vault                Active   ✅

helm repo list
prometheus-community  https://prometheus-community.github.io/helm-charts  ✅
argo                  https://argoproj.github.io/argo-helm                ✅
hashicorp             https://helm.releases.hashicorp.com                 ✅
falcosecurity         https://falcosecurity.github.io/charts              ✅
```

---

##  Problèmes rencontrés et solutions

| Problème | Cause | Solution |
|----------|-------|----------|
| `ansible` non reconnu sur Windows | Ansible ne supporte pas Windows comme control node | Installer via WSL |
| AKS bloqué sur Azure | Quota VM subscription gratuite (VMs premium uniquement) | Utiliser kind (Kubernetes local) |
| `chmod` échoue sur /mnt/c | NTFS Windows ne supporte pas les permissions Linux | Exécuter depuis le home Linux `~/` |
| `ansible.cfg` ignoré | Dossier Windows world-writable ignoré par Ansible | Passer `ANSIBLE_ROLES_PATH` en variable d'env |
| Variables `namespaces` undefined | group_vars non chargées automatiquement | Utiliser `--extra-vars "@group_vars/all.yml"` |
| Helm installation échoue via playbook | sudo non interactif dans Ansible | Installer Helm manuellement au préalable |
| Token GitHub demandé | GitHub n'accepte plus les mots de passe depuis 2021 | Créer un Personal Access Token (PAT) |

---

##  Chiffres clés

| Indicateur | Valeur |
|------------|--------|
| Fichiers Ansible créés | 8 |
| Namespaces Kubernetes créés | 6 |
| ClusterRoles configurés | 2 |
| ServiceAccounts créés | 1 |
| Repos Helm ajoutés | 4 |
| Tasks Ansible exécutées | 16 (0 erreur) |
| Tickets Jira fermés | 1 (SCRUM-7) |

---

##  Liens utiles

- **GitHub :** github.com/Dkls7777/nexaretail-devops-platform
- **Jira :** samdossou26.atlassian.net (SCRUM-7)
- **Guide reproduction :** voir `guide-reproduction.md`

---

##  Code source de cette phase

| Fichier | Description |
|---------|-------------|
| [`ansible/site.yml`](https://github.com/Dkls7777/nexaretail-devops-platform/blob/main/ansible/site.yml) | Playbook principal |
| [`ansible/group_vars/all.yml`](https://github.com/Dkls7777/nexaretail-devops-platform/blob/main/ansible/group_vars/all.yml) | Variables globales |
| [`ansible/roles/namespaces/tasks/main.yml`](https://github.com/Dkls7777/nexaretail-devops-platform/blob/main/ansible/roles/namespaces/tasks/main.yml) | Création des namespaces |
| [`ansible/roles/rbac/tasks/main.yml`](https://github.com/Dkls7777/nexaretail-devops-platform/blob/main/ansible/roles/rbac/tasks/main.yml) | Configuration RBAC |

> Dossier complet : [`ansible/`](https://github.com/Dkls7777/nexaretail-devops-platform/tree/main/ansible)
