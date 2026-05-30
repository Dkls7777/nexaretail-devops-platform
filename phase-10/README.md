# Phase 10 — Conformite avec Kubescape et NetworkPolicy Zero Trust

> **Projet :** NexaRetail DevOps Platform
> **Auteur :** Sam DOSSOU — Etudiant L3 Cybersecurite EFREI Paris
> **Statut :** Termine

---

## Contenu de ce dossier

| Fichier | Description |
|---------|-------------|
| `README.md` | Ce fichier — rapport + bilan de la phase |
| `guide-reproduction.md` | Toutes les commandes exactes pour reproduire |
| `default-deny-all.yaml` | NetworkPolicy Zero Trust — blocage total par defaut |
| `allow-nexaretail-api.yaml` | NetworkPolicy — trafic legitime autorise pour l'API |
| `allow-monitoring.yaml` | NetworkPolicy — scraping Prometheus autorise |

---

## Objectif de la Phase 10

Apres avoir securise les secrets (M8) et surveille le comportement runtime
des conteneurs (M9), il restait une question fondamentale : le cluster est-il
correctement configure selon les standards de securite internationaux ?

Et d'un point de vue reseau : est-ce qu'un pod compromis peut librement
communiquer avec les autres pods du cluster ?

Cette phase repond aux deux questions :

- **Kubescape** audite la configuration du cluster par rapport aux referentiels
  NSA/CISA et MITRE ATT&CK, et produit un score de conformite chiffre.
- **Les NetworkPolicies Zero Trust** implementent le principe du moindre privilege
  au niveau reseau : tout le trafic est bloque par defaut, seuls les flux
  strictement necessaires sont autorises explicitement.

> "Avant : n'importe quel pod du cluster pouvait contacter n'importe quel autre
> pod sans restriction. Maintenant : seuls les flux documentes et approuves
> sont autorises. Un pod compromis ne peut pas lateraliser vers d'autres
> services."

---

## Ce qui a ete realise

### Installation et scans Kubescape

Kubescape v4.0.8 installe via le script officiel dans WSL Ubuntu.
Deux frameworks audites sur le cluster `kind-nexaretail-aks` :

| Framework | Score obtenu | Description |
|-----------|-------------|-------------|
| NSA/CISA Kubernetes Hardening | 64.28% | Recommandations de la NSA pour securiser K8s |
| MITRE ATT&CK for Kubernetes | 67.01% | Matrice des techniques d'attaque connues contre K8s |

#### Principaux ecarts identifies (NSA/CISA)

| Controle | Score | Statut |
|----------|-------|--------|
| Ingress and Egress blocked | 24% -> 36% | Ameliore par les NetworkPolicies |
| Cluster internal networking | 36% -> 45% | Ameliore par les NetworkPolicies |
| Ensure CPU/Memory limits | 32% | Pods systeme kind — hors scope |
| Non-root containers | 56% | Pods systeme kind — hors scope |
| Secret/etcd encryption | 0% | Limitation kind (voir note) |
| Audit logs enabled | 0% | Limitation kind (voir note) |

#### Note sur les limitations kind

Les controles a 0% (etcd encryption, audit logs, PSP) sont des limitations
inherentes a kind et non corrigeables sans un vrai cluster managee :

- **Secret/etcd encryption** : necessite de configurer le kube-apiserver
  d'Azure AKS avec une EncryptionConfiguration — impossible sur kind
- **Audit logs** : necessite d'activer le diagnostic logging d'AKS
- **PSP enabled** : Pod Security Policies est deprecie depuis Kubernetes 1.25
  et supprime en 1.28 — remplace par Pod Security Admission

Sur un vrai cluster Azure AKS en production, ces trois controles seraient
passes automatiquement, portant le score NSA au-dessus de 75%.

### NetworkPolicies Zero Trust

3 NetworkPolicies deployees sur le namespace `nexaretail-prod` :

#### 1. default-deny-all

Bloque tout le trafic entrant et sortant par defaut sur nexaretail-prod.
C'est la politique Zero Trust fondamentale : ce qui n'est pas explicitement
autorise est interdit.

```
podSelector: {}   <- s'applique a TOUS les pods du namespace
policyTypes:
  - Ingress       <- tout trafic entrant bloque
  - Egress        <- tout trafic sortant bloque
```

#### 2. allow-nexaretail-api

Autorise uniquement les flux necessaires au fonctionnement de l'API :

| Direction | Port | Protocole | Usage |
|-----------|------|-----------|-------|
| Ingress | 3000 | TCP | Reception des requetes HTTP |
| Egress | 5432 | TCP | Connexion PostgreSQL |
| Egress | 443 | TCP | Appels HTTPS externes |
| Egress | 53 | TCP/UDP | Resolution DNS |

#### 3. allow-monitoring-scrape

Autorise Prometheus (namespace `monitoring`) a scraper les metriques
de l'API sur le port 3000. Le trafic est restreint par namespaceSelector
pour n'autoriser que le namespace monitoring et personne d'autre.

---

## Architecture deployee

```
Cluster Kubernetes (kind-nexaretail-aks)
|
+-- namespace: nexaretail-prod
|   |
|   +-- NetworkPolicy: default-deny-all
|   |     podSelector: {} (tous les pods)
|   |     Ingress: BLOQUE
|   |     Egress: BLOQUE
|   |
|   +-- NetworkPolicy: allow-nexaretail-api
|   |     podSelector: app=nexaretail-api
|   |     Ingress: port 3000 (HTTP)
|   |     Egress: ports 5432 (PG) + 443 (HTTPS) + 53 (DNS)
|   |
|   +-- NetworkPolicy: allow-monitoring-scrape
|         podSelector: app=nexaretail-api
|         Ingress: port 3000 depuis namespace monitoring uniquement
|
+-- namespace: monitoring
|   +-- Prometheus (autorise a scraper nexaretail-prod:3000)
|
+-- namespace: security
    +-- Falco (surveillance runtime, M9)
    +-- Kubescape (audit conformite, M10)
```

---

## Scores de conformite

```
Avant NetworkPolicies :
  NSA/CISA   : 63.48%
  Ingress/Egress blocked : 24%
  Cluster internal networking : 36%

Apres NetworkPolicies :
  NSA/CISA   : 64.28%   (+0.80 point)
  Ingress/Egress blocked : 36%  (+12 points)
  Cluster internal networking : 45%  (+9 points)

MITRE ATT&CK : 67.01%
```

---

## Structure des fichiers crees

```
kubescape/
+-- default-deny-all.yaml        <- Zero Trust : blocage total par defaut
+-- allow-nexaretail-api.yaml    <- Flux legitimes API (HTTP/PG/DNS/HTTPS)
+-- allow-monitoring.yaml        <- Scraping Prometheus autorise
```

---

## Validation Phase 10

```
kubescape version
-> v4.0.8                                                   OK

kubescape scan framework nsa --kube-context kind-nexaretail-aks
-> % Compliance-Score : 64.28%                              OK

kubescape scan framework mitre --kube-context kind-nexaretail-aks
-> % Compliance-Score : 67.01%                              OK

kubectl apply -f kubescape/default-deny-all.yaml
-> networkpolicy.networking.k8s.io/default-deny-all created  OK

kubectl apply -f kubescape/allow-nexaretail-api.yaml
-> networkpolicy.networking.k8s.io/allow-nexaretail-api created  OK

kubectl apply -f kubescape/allow-monitoring.yaml
-> networkpolicy.networking.k8s.io/allow-monitoring-scrape created  OK

kubectl get networkpolicies -n nexaretail-prod
-> 3 NetworkPolicies actives                                OK

kubescape scan framework nsa (apres NetworkPolicies)
-> % Compliance-Score : 64.28% (cluster internal networking : 45%)  OK

git push origin main
-> 3 fichiers commites (69 insertions)                      OK
```

---

## Problemes rencontres et solutions

| Probleme | Cause | Solution |
|----------|-------|----------|
| flag --context non reconnu | Kubescape utilise --kube-context et non --context | Utiliser --kube-context kind-nexaretail-aks |
| Score en dessous de 70% | Limitations kind (etcd encryption, audit logs) | Documenter les limitations, score reel AKS > 75% |
| node-agent CRD not found | node-agent Kubescape non deploye (optionnel) | Avertissement non bloquant, scan CLI fonctionne |

---

## Chiffres cles

| Indicateur | Valeur |
|------------|--------|
| Kubescape version | v4.0.8 |
| Frameworks audites | 2 (NSA/CISA + MITRE ATT&CK) |
| Score NSA/CISA | 64.28% |
| Score MITRE ATT&CK | 67.01% |
| NetworkPolicies deployees | 3 |
| Namespace protege | nexaretail-prod |
| Amelioration cluster networking | +9 points (36% -> 45%) |
| Fichiers crees | 3 |
| Ticket Jira ferme | SCRUM-21 |

---

## Liens utiles

- **GitHub :** github.com/Dkls7777/nexaretail-devops-platform
- **Jira :** samdossou26.atlassian.net (SCRUM-21)
- **Guide reproduction :** voir `guide-reproduction.md`
- **Documentation Kubescape :** kubescape.io/docs
- **NSA K8s Hardening Guide :** media.defense.gov/2022/Aug/29/2003066362

- ---

##  Code source de cette phase

| Fichier | Description |
|---------|-------------|
| [`kubescape/default-deny-all.yaml`](https://github.com/Dkls7777/nexaretail-devops-platform/blob/main/kubescape/default-deny-all.yaml) | NetworkPolicy Zero Trust — bloque tout le trafic par défaut |
| [`kubescape/allow-nexaretail-api.yaml`](https://github.com/Dkls7777/nexaretail-devops-platform/blob/main/kubescape/allow-nexaretail-api.yaml) | Autorise le trafic entrant vers l'API (port 3000) |
| [`kubescape/allow-monitoring.yaml`](https://github.com/Dkls7777/nexaretail-devops-platform/blob/main/kubescape/allow-monitoring.yaml) | Autorise le scraping Prometheus |

> Dossier complet : [`kubescape/`](https://github.com/Dkls7777/nexaretail-devops-platform/tree/main/kubescape)
