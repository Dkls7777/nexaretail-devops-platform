# Phase 6 — CD Automation GitOps

> **Projet :** NexaRetail DevOps Platform
> **Auteur :** Sam DOSSOU -Etudiant L3 Cybersecurite EFREI Paris
> **Date :** 27 mai 2026
> **Statut :** Termine

---

## Contenu de ce dossier

| Fichier | Description |
|---------|-------------|
| `README.md` | Ce fichier — rapport + bilan de la phase |
| `guide-reproduction.md` | Toutes les commandes exactes pour reproduire |

---

## Objectif de la Phase 6

Apres avoir mis en place le pipeline CI (M5) qui pousse automatiquement
l'image Docker sur l'ACR Azure, il restait un probleme : ArgoCD surveille
le repo Git, pas l'ACR. Si `values.yaml` ne change pas, ArgoCD ne redeploit rien.

Cette phase ferme la boucle CI/CD en ajoutant un job CD qui met a jour
automatiquement le tag de l'image dans le Helm chart apres chaque build reussi.

> "Avant : apres le build, il fallait modifier values.yaml a la main et pusher
> pour que ArgoCD detecte le changement. Maintenant : le pipeline fait tout
> automatiquement - build, scan, push ACR, mise a jour du chart, redeploiement
> en moins de 2 minutes."

---

## Ce qui a ete realise

### Secret GitHub GH_PAT

Creation d'un Personal Access Token GitHub avec les scopes `repo` et `workflow`,
stocke comme secret `GH_PAT` dans le repo. Ce token permet au pipeline
de committer et pusher dans le repo depuis GitHub Actions sans exposer
de credentials humains.

Secrets GitHub configures au total :

| Secret | Role |
|--------|------|
| `AZURE_CREDENTIALS` | Connexion Azure via Service Principal |
| `ACR_LOGIN_SERVER` | URL du registre Docker Azure |
| `GH_PAT` | Token pour le commit automatique du tag |

### Job 3 — update-helm

Ajout d'un troisieme job dans `.github/workflows/ci.yml` qui s'execute
apres le build et le push ACR reussis.

Ce job realise 4 operations :

1. Checkout du repo avec le token `GH_PAT`
2. `sed` pour remplacer le tag image dans `helm/nexaretail-api/values.yaml`
3. Commit signe par `github-actions[bot]` avec `[skip ci]` pour eviter une boucle infinie
4. Push vers `main` — ArgoCD detecte le changement et redeploit automatiquement

### Validation du pipeline complet

Le run #5 a valide la chaine complete en 1m 23s :

```
Job 1 - Code Quality & npm Audit     : 10s  - 0 vulnerabilite
Job 2 - Build - Trivy Scan - Push    : 56s  - image 1.0.5 pushee sur ACR
Job 3 - Update Helm values - GitOps  : 6s   - values.yaml mis a jour, commit pousse
```

Verification dans `helm/nexaretail-api/values.yaml` apres le run :

```yaml
image:
  repository: nexaretail-api
  tag: "1.0.5"    <- mis a jour automatiquement par github-actions[bot]
```

---

## Architecture CD

```
Developpeur
    |
    v
git push origin main
    |
    v
GitHub Actions — ci.yml
    |
    |-- Job 1 : npm audit (10s)
    |       |
    |-- Job 2 : docker build + trivy scan + push ACR (56s)
    |       |
    |-- Job 3 : sed values.yaml + git commit + git push (6s)
                    |
                    v
              ArgoCD detecte le changement dans values.yaml (< 3 min)
                    |
                    v
              kubectl rollout — zero downtime
                    |
                    v
              nexaretail-api:1.0.5 en production
```

---

## Structure des fichiers modifies

```
.github/
└── workflows/
    └── ci.yml        <- Job 3 update-helm ajoute (41 lignes supplementaires)

helm/
└── nexaretail-api/
    └── values.yaml   <- Tag mis a jour automatiquement a chaque run
```

---

## Validation Phase 6

```
Secret GH_PAT configure dans GitHub          OK
Job 3 update-helm ajoute dans ci.yml         OK
Run #5 pipeline complet                      OK  — 1m 23s
Job 1 Code Quality & npm Audit               OK  — 10s
Job 2 Build - Trivy Scan - Push ACR          OK  — 56s
Job 3 Update Helm values - GitOps            OK  — 6s
values.yaml tag = "1.0.5" apres le run       OK
Commit github-actions[bot] visible sur Git   OK
```

---

## Problemes rencontres et solutions

| Probleme | Cause | Solution |
|----------|-------|----------|
| Pipeline ne se declenchait pas apres le push M6 | Incident GitHub Actions (statut yellow) | Attendre la resolution de l'incident + re-pusher |
| Compte GitHub suspendu (erreur 403) | Faux positif lie a l'incident GitHub | Ticket #4418582 soumis, resolu par l'equipe GitHub Support |
| `rejected — fetch first` au push | Edition web GitHub pendant la pause creait une divergence | `git pull origin main --rebase` puis `git push` |

---

## Chiffres cles

| Indicateur | Valeur |
|------------|--------|
| Lignes ajoutees dans ci.yml | 41 |
| Secrets GitHub configures | 3 (AZURE_CREDENTIALS, ACR_LOGIN_SERVER, GH_PAT) |
| Jobs dans le pipeline | 3 |
| Duree totale pipeline | 1m 23s |
| Runs avant succes | 2 (incident GitHub) |
| Ticket Jira ferme | SCRUM-15 |

---

## Liens utiles

- **GitHub :** github.com/Dkls7777/nexaretail-devops-platform
- **GitHub Actions :** github.com/Dkls7777/nexaretail-devops-platform/actions
- **Jira :** samdossou26.atlassian.net (SCRUM-15)
- **Guide reproduction :** voir `guide-reproduction.md`
