# Phase 11 — Pipeline Demo Bout en Bout

> **Projet :** NexaRetail DevOps Platform
> **Auteur :** Sam DOSSOU — Etudiant L3 Cybersecurite EFREI Paris
> **Date :** 28 mai 2026
> **Statut :** Termine

---

## Contenu de ce dossier

| Fichier | Description |
|---------|-------------|
| `README.md` | Ce fichier — rapport + bilan de la phase |
| `guide-reproduction.md` | Toutes les commandes exactes pour reproduire |
| `docs/rapport-module11-demo.md` | Rapport de validation complete |

---

## Objectif de la Phase 11

Apres avoir construit chaque composant de la plateforme DevSecOps en M0-M10,
cette phase valide que l'ensemble fonctionne comme un systeme coherent.

Un seul `git push` doit suffire a declencher toute la chaine :
build, scan securite, push registre, mise a jour du chart, deploiement
automatique, metriques, surveillance runtime, secrets injectes.

> "Avant : deployer en production prenait 35 a 50 minutes, impliquait
> des manipulations manuelles et des croisements de doigts. Maintenant :
> un push sur main et la plateforme fait tout en 1 minute 46 secondes,
> avec scan securite, zero downtime, et surveillance temps reel."

---

## Ce qui a ete realise

### Remise en etat du cluster

Apres un redemarrage de WSL, le cluster kind et Vault necessitent
une procedure de relance :

- Demarrage du container kind : `docker start nexaretail-aks-control-plane`
- Unseal de Vault avec 3 des 5 cles (seuil Shamir)
- Verification de tous les namespaces et pods

### Changement de code

Ajout d'un champ `demo` dans l'endpoint `/version` de l'API Node.js
pour rendre le deploiement visuellement verifiable en production.

```javascript
// app/src/index.js
res.json({
  name: 'nexaretail-api',
  version: process.env.APP_VERSION || '1.0.0',
  environment: process.env.NODE_ENV || 'development',
  buildDate: process.env.BUILD_DATE || 'local',
  demo: 'M11 - Pipeline bout en bout - NexaRetail DevSecOps'
});
```

### Pipeline GitHub Actions — Run #6

| Job | Duree | Resultat |
|-----|-------|----------|
| Code Quality & npm Audit | 15s | 0 vulnerabilite |
| Build — Trivy Scan — Push ACR | 1m17s | 0 CRITICAL/HIGH — image 1.0.6 pushee |
| Update Helm values — GitOps | 4s | values.yaml tag 1.0.5 → 1.0.6 |
| Total | 1m 46s | Success |

### Redeploiement ArgoCD

ArgoCD a detecte le commit automatique de `github-actions[bot]` sur
`values.yaml` et a lance un rolling update sans aucune intervention.

```
nexaretail-api   Synced   Healthy
2 pods Running   nexaretail-api:1.0.6
```

### Validation de la chaine complete

Verification de chaque composant apres le deploiement :

**Application**
```json
GET /version → { "demo": "M11 - Pipeline bout en bout - NexaRetail DevSecOps" }
```

**Metriques Prometheus**
```
process_cpu_user_seconds_total   actif
process_cpu_system_seconds_total actif
```

**Falco — Alertes custom actives sur pods 1.0.6**
```
ERROR   — Acces fichier sensible /etc/passwd detecte
WARNING — Connexion sortante inattendue detectee
```

**Vault**
```
vault-0   1/1 Running   Unsealed: true
```

---

## Architecture de la chaine DevSecOps complete

```
Developpeur
    |
    v
git push origin main
    |
    v
GitHub Actions ci.yml
    |
    |-- Job 1 : npm audit (15s)
    |       |-- 0 vulnerabilite
    |
    |-- Job 2 : docker build + trivy scan + push ACR (1m17s)
    |       |-- 0 CRITICAL/HIGH
    |       |-- nexaretail-api:1.0.6 pushee sur ACR
    |
    |-- Job 3 : sed values.yaml + git commit [skip ci] + push (4s)
                    |
                    v
              ArgoCD detecte values.yaml modifie (< 3 min)
                    |
                    v
              Rolling update zero downtime
                    |
                    v
              Pods Running — nexaretail-api:1.0.6
                    |
                    v
              Vault injecte les secrets au demarrage
                    |
                    v
              Prometheus scrappe /metrics
                    |
                    v
              Falco surveille le runtime
                    |
                    v
              Kubescape score > 70% maintenu
```

---

## Checklist de validation

```
Cluster kind relance                        OK
Vault unseale (3/5 cles)                    OK
ArgoCD Synced / Healthy                     OK
Pipeline Run #6 — 3 jobs en vert            OK  — 1m 46s
Image 1.0.6 pushee sur ACR                  OK
values.yaml tag = "1.0.6"                   OK
Commit github-actions[bot] sur main         OK
2 pods nexaretail-api:1.0.6 Running         OK
GET /version retourne demo M11              OK
GET /metrics retourne metriques Prometheus  OK
Falco alertes actives sur pods 1.0.6        OK
Vault 1/1 Running                           OK
Prometheus 2/2 Running                      OK
Grafana 3/3 Running                         OK
Rapport docs/rapport-module11-demo.md       OK
Ticket Jira SCRUM-22                        Termine
```

---

## Resultats Avant / Apres NexaRetail

| Indicateur | Avant (OVH) | Apres (DevSecOps) |
|------------|-------------|-------------------|
| Frequence deploiement | 1x/semaine | Plusieurs fois/jour |
| Duree deploiement | 35-50 min | 1m 46s |
| Downtime planifie | Chaque semaine | Zero (rolling updates) |
| MTTR incident | 3h47 (janv. 2026) | < 15 minutes |
| Detection vulnerabilites | Manuelle | Automatique (Trivy) |
| Secrets en clair | Oui | Non (Vault) |
| Detection intrusion | Non | Temps reel (Falco) |
| Score conformite | 0% | >70% (Kubescape NSA/CISA) |

---

## Problemes rencontres et solutions

| Probleme | Cause | Solution |
|----------|-------|----------|
| kubectl refused connection apres WSL restart | Cluster kind arrete | `docker start nexaretail-aks-control-plane` |
| Vault 0/1 Ready | Re-initialisation necessaire apres perte donnees kind | `vault operator init` + unseal 3/5 cles |
| ErrImagePull sur nouveau pod | kind ne peut pas puller depuis ACR Azure | Build local + `kind load docker-image` |
| Port-forward echoue | Service expose 3000/TCP pas 80/TCP | `kubectl port-forward svc/... 3000:3000` |

---

## Chiffres cles

| Indicateur | Valeur |
|------------|--------|
| Duree totale pipeline | 1m 46s |
| Jobs GitHub Actions | 3 |
| Vulnerabilites detectees | 0 |
| Pods deployes | 2 |
| Composants valides | 8 (ArgoCD, Prometheus, Grafana, Vault, Falco, Trivy, Kubescape, NetworkPolicy) |
| Ticket Jira ferme | SCRUM-22 |

---

## Liens utiles

- **GitHub Actions :** github.com/Dkls7777/nexaretail-devops-platform/actions
- **Rapport validation :** docs/rapport-module11-demo.md
- **Jira :** samdossou26.atlassian.net (SCRUM-22)
- **Guide reproduction :** voir `guide-reproduction.md`
