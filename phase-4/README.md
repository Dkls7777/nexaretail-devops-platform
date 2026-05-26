# Phase 4 — Application Node.js Conteneurisée

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

## 🎯 Objectif de la Phase 4

Après avoir mis en place le moteur de déploiement GitOps (M3), les pods
`nexaretail-api` étaient en `ImagePullBackOff` — ArgoCD déployait correctement
les manifests, mais l'image Docker n'existait pas encore.

Cette phase crée l'**application Node.js** qui simule l'API de commandes B2B
de NexaRetail, la conteneurise avec un Dockerfile optimisé, et la charge dans
le cluster kind pour que les pods passent enfin en `Running`.

> *"Avant : on déployait une archive zip sur un serveur OVH via FTP en priant
> pour que les dépendances soient les bonnes. Maintenant : l'application tourne
> dans un container Docker immuable, identique entre dev, staging et prod."*

---

## 📦 Ce qui a été réalisé

### 🟢 Application Node.js — API de commandes B2B

Création d'une API Express.js simulant le système de commandes de NexaRetail :

| Endpoint | Méthode | Description |
|----------|---------|-------------|
| `/health` | GET | Health check pour K8s liveness/readiness probe |
| `/version` | GET | Informations sur la version et l'environnement |
| `/api/orders` | GET | Liste des 5 commandes B2B simulées |
| `/api/orders/:id` | GET | Détail d'une commande par ID |
| `/api/orders/stats/summary` | GET | CA total, répartition par statut, marchands |
| `/metrics` | GET | Métriques Prometheus (HTTP duration histogram) |

> **Pourquoi `/metrics` dès maintenant ?** Prometheus (M7) scrappe cet endpoint
> pour mesurer les performances. En l'intégrant dès M4, le monitoring sera
> opérationnel sans modifier l'application plus tard.

### 🐳 Dockerfile multi-stage

Le Dockerfile utilise une stratégie **multi-stage** en deux étapes :

- **Stage `builder`** : installe toutes les dépendances npm
- **Stage `runtime`** : copie uniquement le nécessaire dans une image légère

Optimisations de sécurité appliquées :
- Image de base `node:20-alpine` (~5MB vs ~300MB pour node:20)
- Utilisateur non-root `nexaretail` (bonne pratique CIS Kubernetes Benchmark)
- `HEALTHCHECK` Docker intégré (30s interval, 3s timeout)
- `.dockerignore` pour exclure `node_modules`, `.env`, `.git`

### ✅ Validation complète de la chaîne GitOps

Après `kind load docker-image` et `git push`, ArgoCD a automatiquement
redéployé les pods avec la nouvelle image. Les 2 pods sont passés de
`ImagePullBackOff` à **`Running`** sans aucune intervention manuelle.

```
ArgoCD : Synced + Healthy   ✅
2 pods Running              ✅
/health depuis le cluster   ✅  (hostname = nom du pod K8s)
/api/orders/stats/summary   ✅  (CA : 8 201,25€ — 4 marchands)
```

---

## 🏗️ Architecture de l'application

```
app/
├── src/
│   ├── index.js                 ← Serveur Express (port 3000) + métriques Prometheus
│   ├── routes/
│   │   └── orders.js            ← CRUD commandes B2B (5 commandes simulées)
│   └── middleware/
│       └── health.js            ← Health check (uptime, hostname, version)
├── package.json                 ← Express 4.18.2 + prom-client 15.1.0
├── Dockerfile                   ← Multi-stage : builder + runtime node:20-alpine
└── .dockerignore                ← Exclut node_modules, .env, .git

         ↓ docker build + kind load

Cluster Kubernetes (kind-nexaretail-aks)
│
└── namespace: nexaretail-prod
    ├── nexaretail-api-xxx-pod1    Running ✅  (image nexaretail-api:1.0.0)
    └── nexaretail-api-xxx-pod2    Running ✅  (image nexaretail-api:1.0.0)

         ↑ déployé automatiquement par ArgoCD (Git → Cluster)
```

---

## 📁 Structure des fichiers créés

```
app/
├── .dockerignore                ← node_modules, .env, .git exclus
├── Dockerfile                   ← Multi-stage node:20-alpine, user non-root
├── package.json                 ← Dépendances : express, prom-client
└── src/
    ├── index.js                 ← Serveur Express + histogram Prometheus
    ├── middleware/
    │   └── health.js            ← /health endpoint
    └── routes/
        └── orders.js            ← /api/orders (GET /, /:id, /stats/summary)

helm/nexaretail-api/
└── values.yaml                  ← Mis à jour : image nexaretail-api:1.0.0 (kind local)
```

---

## ✅ Validation Phase 4

```
docker build -t nexaretail-api:1.0.0 .
→ Successfully built b80bcdd25daf                                    ✅
→ 0 vulnerabilities (npm audit)                                      ✅

docker run + curl /health
→ {"status":"healthy","uptime":25,"version":"1.0.0"}                 ✅

kind load docker-image nexaretail-api:1.0.0 --name nexaretail-aks
→ Image chargée dans le cluster kind                                 ✅

kubectl get pods -n nexaretail-prod
→ nexaretail-api-xxx   1/1   Running   (x2)                          ✅

kubectl get applications -n argocd
→ nexaretail-api   Synced   Healthy                                  ✅

curl /health depuis le cluster (port-forward)
→ hostname = nexaretail-api-6c7c7b64fb-ttfpz (nom du pod K8s)        ✅
```

---

## 🐛 Problèmes rencontrés et solutions

| Problème | Cause | Solution |
|----------|-------|----------|
| `curl: Failed to connect` sur port-forward en arrière-plan | `&` démarre le process mais curl s'exécute avant que le tunnel soit établi | Ajouter `sleep 3` entre le port-forward et le curl |
| `ImagePullBackOff` persistant après le push | `values.yaml` pointait encore vers `nexaretailprodacr.azurecr.io` | Mettre à jour `image.repository: nexaretail-api` + `pullPolicy: IfNotPresent` |

---

## 📊 Chiffres clés

| Indicateur | Valeur |
|------------|--------|
| Fichiers créés | 7 |
| Lignes de code Node.js | ~120 |
| Dépendances npm | 2 (express, prom-client) |
| Vulnérabilités npm | 0 |
| Taille image Docker | ~120 MB (vs ~400 MB sans multi-stage) |
| Endpoints API | 6 |
| Pods Running | 2 |
| Tickets Jira fermés | 1 (SCRUM-9) |

---

## 🔗 Liens utiles

- **GitHub :** github.com/Dkls7777/nexaretail-devops-platform
- **Jira :** samdossou26.atlassian.net (SCRUM-9)
- **Tester l'API :** `kubectl port-forward -n nexaretail-prod deployment/nexaretail-api 3000:3000`
  puis `curl http://localhost:3000/health`
- **Guide reproduction :** voir `guide-reproduction.md`
