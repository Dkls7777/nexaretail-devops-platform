# Phase 12 — Validation & Bilan du Projet

> **Projet :** NexaRetail DevOps Platform
> **Auteur :** Sam DOSSOU — Etudiant L3 Cybersecurite EFREI Paris
> **Statut :** Termine

---

## Contenu de ce dossier

| Fichier | Description |
|---------|-------------|
| `README.md` | Ce fichier — rapport + bilan de la phase |
| `guide-reproduction.md` | Toutes les commandes exactes pour reproduire |
| `docs/rapport-final-nexaretail.md` | Rapport de bilan complet du projet |

---

## Objectif de la Phase 12

Apres 11 modules de construction, cette phase finale valide que la plateforme
DevSecOps NexaRetail est complete, coherente et documentee.

Elle produit le rapport de bilan definitif du projet, met a jour le README
principal, et clos tous les tickets Jira.

---

## Validation technique realisee

### Etat final de la stack — 28 mai 2026

| Composant | Commande | Resultat |
|-----------|----------|---------|
| Node | kubectl get nodes | Ready — v1.32.2 |
| Namespaces | kubectl get ns | 9 Active |
| ArgoCD | kubectl get applications -n argocd | Synced / Healthy |
| Pods prod | kubectl get pods -n nexaretail-prod | 2/2 Running (1.0.7) |
| Prometheus | kubectl get pods -n monitoring | 6/6 Running |
| Vault | kubectl get pod vault-0 -n vault | 1/1 Running — Unsealed |
| Falco | kubectl get pods -n security | 2/2 Running |
| /health | curl localhost:3000/health | {"status":"healthy"} |
| /version | curl localhost:3000/version | demo M11 present |
| /api/orders | curl localhost:3000/api/orders/stats/summary | 5 orders, 4 marchands |

### Rolling update zero downtime valide

Lors de cette phase, un pod en `ImagePullBackOff` (tag 1.0.7) a ete resolu
par build local + `kind load docker-image`. ArgoCD a orchestre le rolling
update automatiquement : les anciens pods 1.0.6 ont ete remplaces par
les nouveaux 1.0.7 sans interruption de service.

```
nexaretail-api-68f7cf75dd-bch7r   0/1  ImagePullBackOff  →  1/1 Running
nexaretail-api-9f77f9c6f-gdg9f    1/1  Running           →  Terminating
nexaretail-api-68f7cf75dd-t8gf2   0/1  Pending           →  1/1 Running
```

Duree du rolling update : < 2 secondes.

---

## Bilan Avant / Apres NexaRetail

| Indicateur | Avant (OVH) | Apres (DevSecOps) |
|------------|-------------|-------------------|
| Frequence deploiement | 1x/semaine | Plusieurs fois/jour |
| Duree deploiement | 35-50 min | 1m 46s |
| Downtime | Chaque semaine | Zero |
| MTTR incident | 3h47 (janv. 2026) | < 15 minutes |
| Detection incident | Quand client appelle | < 2 min (Falco + AlertManager) |
| Secrets en clair | Oui | Non (Vault AES-256) |
| Scan securite | Jamais | A chaque commit (Trivy) |
| Conformite | 0% | NSA/CISA 64%, MITRE 67% |
| Couts infra | Base 100 | Base 82 (-18%) |

---

## Modules realises — Recapitulatif

| Module | Titre | Outils |
|--------|-------|--------|
| M0 | Structure repo | Git, GitHub |
| M1 | Infrastructure IaC | Terraform, Azure |
| M2 | Configuration | Ansible, Helm, kubectl |
| M3 | GitOps | ArgoCD |
| M4 | Application | Node.js, Docker |
| M5 | CI | GitHub Actions, Trivy |
| M6 | CD | GitOps automation |
| M7 | Monitoring | Prometheus, Grafana |
| M8 | Secrets | HashiCorp Vault |
| M9 | Runtime security | Falco, eBPF |
| M10 | Conformite | Kubescape, NetworkPolicy |
| M11 | Demo pipeline | Bout en bout |
| M12 | Validation & bilan | Ce module |

---

## Chiffres cles du projet

| Indicateur | Valeur |
|------------|--------|
| Duree totale | ~15 heures |
| Modules completes | 13 |
| Fichiers crees | > 80 |
| Lignes de code / config | > 2 500 |
| Tickets Jira fermes | 13 |
| Composants DevSecOps | 11 |

---

## Liens utiles

- **GitHub :** github.com/Dkls7777/nexaretail-devops-platform
- **Jira :** samdossou26.atlassian.net
- **Rapport final :** docs/rapport-final-nexaretail.md

- ---

##  Code source de cette phase

| Fichier | Description |
|---------|-------------|
| [`docs/rapport-final-nexaretail.md`](https://github.com/Dkls7777/nexaretail-devops-platform/blob/main/docs/rapport-final-nexaretail.md) | Rapport final — bilan avant/après, stack, chiffres clés |

> Tous les dossiers : [`infrastructure/`](https://github.com/Dkls7777/nexaretail-devops-platform/tree/main/infrastructure) · [`ansible/`](https://github.com/Dkls7777/nexaretail-devops-platform/tree/main/ansible) · [`app/`](https://github.com/Dkls7777/nexaretail-devops-platform/tree/main/app) · [`helm/`](https://github.com/Dkls7777/nexaretail-devops-platform/tree/main/helm) · [`monitoring/`](https://github.com/Dkls7777/nexaretail-devops-platform/tree/main/monitoring) · [`vault/`](https://github.com/Dkls7777/nexaretail-devops-platform/tree/main/vault) · [`falco/`](https://github.com/Dkls7777/nexaretail-devops-platform/tree/main/falco) · [`kubescape/`](https://github.com/Dkls7777/nexaretail-devops-platform/tree/main/kubescape)
