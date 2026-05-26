# Phase 3 — GitOps avec ArgoCD

> **Projet :** NexaRetail DevOps Platform  
> **Auteur :** Sam DOSSOU — Étudiant L3 Cybersécurité EFREI Paris  
> **Date :** 26 mai 2026  
> **Statut :** ✅ Terminé  

---

## 📋 Contenu de ce dossier

| Fichier | Description |
|---------|-------------|
| `README.md` | Ce fichier — rapport + bilan de la phase |
| `guide-reproduction.md` | Toutes les commandes exactes pour reproduire |

---

## 🎯 Objectif de la Phase 3

Après avoir provisionné l'infrastructure (M1) et configuré le cluster (M2),
il faut maintenant mettre en place le **moteur de déploiement automatique**.

ArgoCD est le cerveau GitOps du projet : il surveille le repo GitHub en permanence
et synchronise automatiquement ce qui est dans `main` vers le cluster Kubernetes.
Plus de `kubectl apply` à la main — **Git devient la seule source de vérité**.

> *"Avant : on déployait en SSH sur les serveurs OVH en espérant ne rien casser.
> Maintenant : un `git push` déclenche automatiquement le déploiement via ArgoCD,
> avec rollback instantané si quelque chose tourne mal."*

---

## 📦 Ce qui a été réalisé

### ☸️ Installation d'ArgoCD

ArgoCD a été installé via Helm dans le namespace `argocd` du cluster kind local.
7 pods déployés et Running en moins de 3 minutes.

> **Correction rencontrée :** le nom du chart Helm est `argo/argo-cd`
> et non `argo/argocd`. Erreur classique documentée dans le guide.

### 📁 Helm Chart nexaretail-api

Création d'un chart Helm complet simulant l'API de commandes NexaRetail :

| Fichier | Rôle |
|---------|------|
| `Chart.yaml` | Métadonnées du chart (nom, version) |
| `values.yaml` | 2 replicas, ressources CPU/RAM, image ACR |
| `templates/deployment.yaml` | Déploiement Kubernetes avec variables Helm |
| `templates/service.yaml` | Service ClusterIP exposant le port 3000 |

### 🔄 Application ArgoCD (GitOps)

Création du manifest `gitops/applications/nexaretail-api.yaml` — la pièce centrale :

- `repoURL` : pointe vers github.com/Dkls7777/nexaretail-devops-platform
- `path` : surveille le dossier `helm/nexaretail-api`
- `automated.selfHeal: true` : corrige toute modification manuelle du cluster
- `automated.prune: true` : supprime les ressources retirées de Git
- `targetRevision: main` : suit la branche principale

### ✅ Synchronisation Git → Cluster validée

Après le `git push`, ArgoCD a automatiquement détecté les nouveaux fichiers
et déployé les manifests dans `nexaretail-prod` sans aucune intervention manuelle.
Les 2 pods `nexaretail-api` ont bien été créés par ArgoCD.

> **Note :** les pods sont en `ImagePullBackOff` car l'image Docker
> `nexaretailprodacr.azurecr.io/nexaretail-api:latest` n'existe pas encore.
> Elle sera construite en **M4 (app Node.js)** et publiée en **M5 (CI/CD)**.
> Cela confirme que le pipeline GitOps fonctionne — seule l'image manque.

---

## 🏗️ Architecture GitOps déployée

```
GitHub (source de vérité)
│
└── main branch
    ├── helm/nexaretail-api/        ← Chart Helm surveillé par ArgoCD
    │   ├── Chart.yaml
    │   ├── values.yaml
    │   └── templates/
    │       ├── deployment.yaml
    │       └── service.yaml
    └── gitops/applications/
        └── nexaretail-api.yaml     ← Manifest Application ArgoCD

         ↓ auto-sync (toutes les 3 min)

Cluster Kubernetes (kind-nexaretail-aks)
│
└── namespace: argocd
│   ├── argocd-application-controller-0     Running ✅
│   ├── argocd-applicationset-controller    Running ✅
│   ├── argocd-dex-server                   Running ✅
│   ├── argocd-notifications-controller     Running ✅
│   ├── argocd-redis                        Running ✅
│   ├── argocd-repo-server                  Running ✅
│   └── argocd-server                       Running ✅
│
└── namespace: nexaretail-prod
    ├── nexaretail-api-xxx-pod1    (ImagePullBackOff — image M4/M5)
    └── nexaretail-api-xxx-pod2    (ImagePullBackOff — image M4/M5)
```

---

## 📁 Structure des fichiers créés

```
helm/
└── nexaretail-api/
    ├── Chart.yaml                   ← Chart Helm v2
    ├── values.yaml                  ← 2 replicas, CPU/RAM, image ACR
    └── templates/
        ├── deployment.yaml          ← Deployment K8s avec Helm templating
        └── service.yaml             ← Service ClusterIP port 3000

gitops/
└── applications/
    └── nexaretail-api.yaml          ← Application ArgoCD (auto-sync + self-heal)

docs/
└── rapport-module3-argocd.md        ← Ce rapport
```

---

## ✅ Validation ArgoCD

```
kubectl get pods -n argocd
→ 7/7 Running                                                       ✅

kubectl get applications -n argocd
→ nexaretail-api   Synced   Progressing                             ✅

kubectl get pods -n nexaretail-prod
→ 2 pods créés par ArgoCD (ImagePullBackOff attendu — image M4/M5)  ✅
```

---

## 🐛 Problèmes rencontrés et solutions

| Problème | Cause | Solution |
|----------|-------|----------|
| `chart "argocd" not found in argo index` | Mauvais nom de chart | Utiliser `argo/argo-cd` (avec tiret) |
| `app path does not exist` | Fichiers non encore pushés sur GitHub | Pusher d'abord, ArgoCD lit le repo distant |
| `rejected — fetch first` | Divergence entre local et remote | `git stash && git pull --rebase && git stash pop && git push` |

---

## 📊 Chiffres clés

| Indicateur | Valeur |
|------------|--------|
| Pods ArgoCD déployés | 7 |
| Fichiers Helm créés | 4 |
| Fichiers GitOps créés | 1 |
| Commits Git | 2 |
| Tickets Jira fermés | 1 (SCRUM-8) |
| Délai sync Git → Cluster | < 3 minutes (automatique) |

---

## 🔗 Liens utiles

- **GitHub :** github.com/Dkls7777/nexaretail-devops-platform
- **Jira :** samdossou26.atlassian.net (SCRUM-8)
- **ArgoCD UI :** `kubectl port-forward service/argocd-server -n argocd 8080:443`
  puis ouvrir https://localhost:8080 (admin / `Ir3XwzA-zS0zS98l`)
- **Guide reproduction :** voir `guide-reproduction.md`
