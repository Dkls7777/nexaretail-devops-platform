# Phase 8 — Secrets avec HashiCorp Vault

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

---

## Objectif de la Phase 8

Le RSSI de NexaRetail vient d'annoncer un audit SOC 2 dans 6 semaines.
Exigences : zéro credential en dur dans le code, audit trail complet
de chaque accès aux secrets, rotation automatique possible.

Avant cette phase, les secrets (mots de passe BDD, clés JWT, API keys)
étaient soit codés en dur dans les fichiers de config, soit stockés dans
des Kubernetes Secrets encodés en base64 — ce qui n'est pas du chiffrement.

> "Avant : le mot de passe de la base de données était dans un fichier
> .env commité sur GitHub. Maintenant : Vault chiffre chaque secret en
> AES-256-GCM, loggue chaque accès avec qui/quand/depuis où, et les pods
> s'authentifient automatiquement sans jamais voir le root token."

---

## Ce qui a ete realise

### Installation de Vault

Vault 1.21.2 installé via Helm dans le namespace `vault` du cluster kind.
Deux composants déployés :

| Composant | Role |
|-----------|------|
| vault-0 | Serveur Vault (stockage et chiffrement des secrets) |
| vault-agent-injector | Injecte automatiquement les secrets dans les pods |

### Initialisation et Unseal

Vault démarre en mode sealed (verrouillé) — aucune donnée n'est accessible
tant qu'il n'est pas déverrouillé. L'initialisation a généré :

- 5 unseal keys (algorithme Shamir Secret Sharing)
- 1 root token d'administration
- Threshold : 3 clés sur 5 nécessaires pour déverrouiller

En production, chaque clé serait distribuée à une personne différente
(CISO, CTO, Lead DevOps...) ou stockée dans Azure Key Vault avec Auto-Unseal.

### Moteur KV v2 et secrets NexaRetail

Activation du moteur Key-Value version 2 sur le chemin `nexaretail/`.
KV v2 offre le versioning des secrets : chaque modification conserve
l'historique, permettant un rollback en cas d'erreur.

6 secrets stockés à `nexaretail/data/api` :

| Secret | Description |
|--------|-------------|
| `db_host` | Hôte PostgreSQL dans le cluster |
| `db_name` | Nom de la base de données |
| `db_user` | Utilisateur applicatif |
| `db_password` | Mot de passe BDD (chiffré AES-256-GCM) |
| `jwt_secret` | Clé de signature des tokens JWT |
| `api_key` | Clé d'API NexaRetail |

### Authentification Kubernetes

Configuration de l'auth method Kubernetes : les pods s'authentifient
auprès de Vault en présentant leur ServiceAccount token. Vault vérifie
ce token auprès de l'API Kubernetes et délivre un token Vault temporaire.

Plus besoin de stocker de credentials dans les pods — l'identité Kubernetes
devient le mécanisme d'authentification.

### Policy et Role — Principe du moindre privilege

Policy `nexaretail-api` : accès en lecture seule uniquement sur
`nexaretail/data/api`. Aucun autre chemin n'est accessible.

Role `nexaretail-api` lié au ServiceAccount `argocd-deployer` dans
le namespace `nexaretail-prod`, avec un token TTL de 1 heure.
Passé ce délai, le pod doit se ré-authentifier — limitation de l'impact
en cas de compromission d'un token.

---

## Architecture deployee

```
Cluster Kubernetes (kind-nexaretail-aks)
|
+-- namespace: vault
|   +-- vault-0                          Running (Unsealed)
|   |   +-- Moteur KV v2 : nexaretail/
|   |       +-- nexaretail/data/api      6 secrets chiffres AES-256-GCM
|   |
|   +-- vault-agent-injector             Running
|       +-- Injecte les secrets dans les pods via annotations
|
+-- namespace: nexaretail-prod
    +-- ServiceAccount argocd-deployer
        +-- Role nexaretail-api (TTL 1h)
        +-- Policy : read nexaretail/data/api uniquement
```

---

## Comparaison Kubernetes Secrets vs HashiCorp Vault

| Critere | Kubernetes Secrets | HashiCorp Vault |
|---------|-------------------|-----------------|
| Chiffrement | base64 (non chiffre) | AES-256-GCM |
| Audit trail | Aucun | Qui / quand / depuis ou |
| Rotation | Manuelle | Automatique et configurable |
| Versioning | Non | Oui (KV v2) |
| Multi-plateforme | K8s uniquement | K8s, VMs, CI/CD, on-prem |

---

## Structure des fichiers crees

```
vault/
+-- vault-auth-config.yaml     <- ConfigMap documentant la configuration Vault
+-- vault-policy-nexaretail.hcl <- Policy HCL : read-only nexaretail/data/api
```

---

## Validation Phase 8

```
helm install vault
-> STATUS: deployed                                         OK

kubectl get pods -n vault
-> vault-0 : 1/1 Running (apres unseal)                    OK
-> vault-agent-injector : 1/1 Running                      OK

vault operator init
-> 5 unseal keys generes                                    OK
-> root token genere                                        OK

vault operator unseal (x3)
-> Sealed: false                                            OK

vault secrets enable -path=nexaretail kv-v2
-> Enabled the kv-v2 secrets engine at: nexaretail/         OK

vault kv put nexaretail/api ...
-> version 1 stockee                                        OK

vault auth enable kubernetes
-> Enabled kubernetes auth method at: kubernetes/           OK

vault policy write nexaretail-api
-> Success! Uploaded policy: nexaretail-api                 OK

vault write auth/kubernetes/role/nexaretail-api
-> Role cree, TTL 1h                                        OK

git push origin main
-> 2 fichiers commites                                      OK
```

---

## Problemes rencontres et solutions

| Probleme | Cause | Solution |
|----------|-------|----------|
| vault-0 en 0/1 apres installation | Vault demarre en mode sealed, comportement normal | Lancer vault operator unseal avec 3 cles |
| Heredoc <<EOF echoue dans kubectl exec | kubectl exec ne supporte pas les heredocs multi-lignes | Utiliser sh -c avec echo et pipe vers vault policy write |

---

## Chiffres cles

| Indicateur | Valeur |
|------------|--------|
| Pods deployes | 2 (vault-0 + vault-agent-injector) |
| Unseal keys generes | 5 (threshold 3) |
| Secrets stockes | 6 |
| Moteurs actives | 1 (KV v2) |
| Auth methods actives | 1 (kubernetes) |
| Policies creees | 1 (nexaretail-api) |
| Roles crees | 1 (nexaretail-api) |
| Fichiers crees | 2 |
| Ticket Jira ferme | SCRUM-17 |

---

## Liens utiles

- **GitHub :** github.com/Dkls7777/nexaretail-devops-platform
- **Jira :** samdossou26.atlassian.net (SCRUM-17)
- **Guide reproduction :** voir `guide-reproduction.md`
