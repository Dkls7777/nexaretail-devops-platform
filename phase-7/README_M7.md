# Phase 7 — Monitoring avec Prometheus et Grafana

> **Projet :** NexaRetail DevOps Platform
> **Auteur :** Sam DOSSOU — Etudiant L3 Cybersecurite EFREI Paris
> **Date :** 27 mai 2026
> **Statut :** Termine

---

## Contenu de ce dossier

| Fichier | Description |
|---------|-------------|
| `README.md` | Ce fichier — rapport + bilan de la phase |
| `guide-reproduction.md` | Toutes les commandes exactes pour reproduire |

---

## Objectif de la Phase 7

Apres avoir automatise les deploiements (M6), l'infrastructure NexaRetail
tournait en aveugle : aucun moyen de savoir si l'API etait lente, si un
pod crashait, ou si le cluster manquait de ressources.

Le CTO posait la question : "Si notre API de commandes est lente, en combien
de temps tu le sais ?" La reponse honnete etait "quand un client se plaint."

Cette phase change ca. Objectif : que la reponse devienne "30 secondes".
SLO negocie : 99,5% des requetes repondent en moins de 500ms.

> "Avant : on decouvrait les incidents quand les marchands appelaient le
> support. Maintenant : Prometheus detecte la degradation en 30 secondes
> et AlertManager notifie l'equipe avant que le premier client soit impacte."

---

## Ce qui a ete realise

### Installation de kube-prometheus-stack

Installation via Helm dans le namespace `monitoring` du cluster kind.
Ce chart installe en une seule commande l'ensemble de la stack de monitoring :

| Composant | Role |
|-----------|------|
| Prometheus | Collecte et stockage des metriques |
| Grafana | Visualisation et dashboards |
| AlertManager | Gestion et routage des alertes |
| kube-state-metrics | Metriques Kubernetes (pods, deployments) |
| node-exporter | Metriques systeme (CPU, RAM, disque) |
| prometheus-operator | Gestion des CRDs (ServiceMonitor, PrometheusRule) |

Configuration appliquee :
- Retention des donnees : 15 jours
- Grafana expose en NodePort
- Mot de passe admin configure

### ServiceMonitor nexaretail-api

Creation d'un `ServiceMonitor` qui indique a Prometheus de scraper
automatiquement l'endpoint `/metrics` de l'API NexaRetail toutes les 30 secondes.

Le `prom-client` integre en M4 expose un histogramme
`http_request_duration_seconds` — c'est exactement ce que les alertes SLO
utilisent pour mesurer la latence.

### Alertes SLO — PrometheusRule

Creation de deux alertes Prometheus couvrant les cas critiques NexaRetail :

| Alerte | Condition | Severite | Delai |
|--------|-----------|----------|-------|
| NexaRetailAPIHighLatency | P95 latence > 500ms | warning | 2 minutes |
| NexaRetailAPIDown | Aucune metrique recue | critical | 1 minute |

La regle `NexaRetailAPIHighLatency` utilise `histogram_quantile` sur
le P95 — ce qui signifie que 95% des utilisateurs sont couverts par le SLO.

---

## Architecture deployee

```
Cluster Kubernetes (kind-nexaretail-aks)
|
+-- namespace: monitoring
|   +-- prometheus-kube-prometheus-stack-prometheus-0     Running
|   +-- kube-prometheus-stack-grafana-xxx                 Running
|   +-- alertmanager-kube-prometheus-stack-alertmanager-0 Running
|   +-- kube-prometheus-stack-operator-xxx                Running
|   +-- kube-prometheus-stack-kube-state-metrics-xxx      Running
|   +-- kube-prometheus-stack-prometheus-node-exporter-xx Running
|
+-- namespace: nexaretail-prod
    +-- nexaretail-api (expose /metrics sur port 3000)
             |
             | scrape toutes les 30s via ServiceMonitor
             v
        Prometheus stocke les metriques 15 jours
             |
             v
        Grafana visualise + AlertManager alerte si SLO depasse
```

---

## Structure des fichiers crees

```
monitoring/
+-- servicemonitor-nexaretail.yaml    <- Scrape /metrics de l'API toutes les 30s
+-- prometheusrule-nexaretail.yaml   <- Alertes SLO latence P95 + API down
```

---

## Validation Phase 7

```
helm install kube-prometheus-stack
-> STATUS: deployed                                          OK

kubectl get pods -n monitoring
-> 6/6 Running                                              OK

kubectl apply -f monitoring/servicemonitor-nexaretail.yaml
-> servicemonitor.monitoring.coreos.com/nexaretail-api created  OK

kubectl apply -f monitoring/prometheusrule-nexaretail.yaml
-> prometheusrule.monitoring.coreos.com/nexaretail-alerts created  OK

Grafana accessible sur http://localhost:3000
-> Interface Grafana chargee, connexion admin reussie        OK

git push origin main
-> 2 fichiers commites, push reussi                         OK
```

---

## Problemes rencontres et solutions

| Probleme | Cause | Solution |
|----------|-------|----------|
| Mot de passe sudo oublie | Premiere utilisation de sudo depuis la creation de WSL | `wsl -u root` depuis PowerShell puis `passwd dossa` |
| `rejected — fetch first` au push | Commit automatique github-actions[bot] (job CD M6) creait une divergence | `git pull origin main --rebase` puis `git push` |

---

## Chiffres cles

| Indicateur | Valeur |
|------------|--------|
| Fichiers crees | 2 |
| Pods monitoring deployes | 6 |
| Composants de la stack | 6 (Prometheus, Grafana, AlertManager, operator, kube-state-metrics, node-exporter) |
| Alertes SLO configurees | 2 |
| Retention Prometheus | 15 jours |
| Intervalle de scrape | 30 secondes |
| Ticket Jira ferme | SCRUM-16 |

---

## Liens utiles

- **GitHub :** github.com/Dkls7777/nexaretail-devops-platform
- **Jira :** samdossou26.atlassian.net (SCRUM-16)
- **Grafana :** `kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80`
  puis ouvrir http://localhost:3000 (admin / NexaRetail2026!)
- **Guide reproduction :** voir `guide-reproduction.md`
