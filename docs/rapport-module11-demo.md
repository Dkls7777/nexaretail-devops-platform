# Module 11 — Pipeline Demo Bout en Bout

> **Projet :** NexaRetail DevOps Platform
> **Auteur :** Sam DOSSOU — Etudiant L3 Cybersecurite EFREI Paris
> **Date :** 28 mai 2026
> **Statut :** Termine

---

## Objectif

Valider la chaine DevSecOps complete en conditions reelles :
un seul `git push` declenche l'ensemble de la plateforme.

---

## Deroulement de la demo

### Changement de code

Ajout du champ `demo` dans l'endpoint `/version` de l'API Node.js.

```
git commit -m "feat(api): add M11 demo field to /version endpoint"
git push origin main
```

### Pipeline GitHub Actions — Run #6

| Job | Duree | Resultat |
|-----|-------|----------|
| Code Quality & npm Audit | 15s | 0 vulnerabilite |
| Build — Trivy Scan — Push ACR | 1m17s | 0 CRITICAL/HIGH — image 1.0.6 pushee |
| Update Helm values — GitOps | 4s | values.yaml tag mis a jour vers 1.0.6 |
| Total | 1m 46s | Success |

### ArgoCD — Redeploiement automatique

ArgoCD a detecte le changement dans `values.yaml` et a redeploy
l'application sans intervention manuelle.

```
nexaretail-api   Synced   Healthy
```

### Validation applicative

```json
GET /version
{
  "name": "nexaretail-api",
  "version": "1.0.0",
  "environment": "production",
  "buildDate": "local",
  "demo": "M11 - Pipeline bout en bout - NexaRetail DevSecOps"
}
```

### Validation metriques Prometheus

```
process_cpu_user_seconds_total   actif
process_cpu_system_seconds_total actif
```

### Validation Falco

Alertes custom actives sur les pods `nexaretail-api:1.0.6` :
- ERROR — Acces fichier sensible /etc/passwd detecte
- WARNING — Connexion sortante inattendue detectee

### Validation Vault

```
vault-0   1/1 Running   Unsealed: true
```

---

## Checklist finale

| Composant | Commande | Resultat |
|-----------|----------|---------|
| Node kind | kubectl get nodes | Ready |
| ArgoCD | kubectl get applications -n argocd | Synced / Healthy |
| Pods production | kubectl get pods -n nexaretail-prod | 2/2 Running |
| /version demo field | curl /version | M11 present |
| /metrics | wget localhost:3000/metrics | actif |
| Prometheus | kubectl get pods -n monitoring | 6/6 Running |
| Grafana | kubectl get pods -n monitoring | 3/3 Running |
| Vault | kubectl get pod vault-0 -n vault | 1/1 Running |
| Falco | kubectl logs -n security | Alertes actives |
| Pipeline CI | GitHub Actions Run #6 | Success 1m46s |

---

## Resultats Avant / Apres

| Indicateur | Avant (OVH) | Apres (DevSecOps) |
|------------|-------------|-------------------|
| Frequence deploiement | 1x/semaine | Plusieurs fois/jour |
| Duree deploiement | 35-50 min | 1m 46s |
| Detection vulnerabilites | Manuelle | Automatique (Trivy) |
| Secrets en clair | Oui | Non (Vault) |
| Detection intrusion | Non | Temps reel (Falco) |
| Score conformite | 0% | >70% (Kubescape NSA/CISA) |

---

## Ticket Jira

SCRUM-22 — Termine
