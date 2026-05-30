# Phase 9 — Securite Runtime avec Falco

> **Projet :** NexaRetail DevOps Platform
> **Auteur :** Sam DOSSOU — Etudiant L3 Cybersecurite EFREI Paris
> 
> **Statut :** Termine

---

## Contenu de ce dossier

| Fichier | Description |
|---------|-------------|
| `README.md` | Ce fichier — rapport + bilan de la phase |
| `guide-reproduction.md` | Toutes les commandes exactes pour reproduire |
| `nexaretail-rules.yaml` | Regles Falco custom NexaRetail |
| `values.yaml` | Configuration Helm Falco |

---

## Objectif de la Phase 9

Apres avoir securise les secrets (M8), il restait un angle mort majeur :
que se passe-t-il a l'interieur des conteneurs en cours d'execution ?

Un attaquant qui compromet un pod peut ouvrir un shell, lire les fichiers
systeme, exfiltrer des donnees vers l'exterieur — sans que Kubernetes,
ArgoCD ou Prometheus ne detectent quoi que ce soit. Ces outils surveillent
l'etat des pods, pas leur comportement interne.

Falco repond a cette question. Il surveille les appels systeme Linux en
temps reel via eBPF et genere des alertes des qu'un comportement anormal
est detecte dans un conteneur.

> "Avant : si un attaquant ouvrait un shell dans un pod de prod, on ne le
> savait jamais. Maintenant : Falco detecte l'acces en moins de 5 secondes
> et loggue qui, quand, dans quel pod, avec quelle commande."

---

## Ce qui a ete realise

### Installation de Falco

Falco installe via Helm dans le namespace `security` du cluster kind.
Driver `modern_ebpf` utilise — le seul compatible avec kind sous WSL
(pas d'acces direct au module kernel de l'hote).

| Composant | Role |
|-----------|------|
| falco (DaemonSet) | Agent de surveillance des appels systeme |
| falco-driver-loader (init container) | Charge le driver eBPF au demarrage |

### Regles custom NexaRetail

3 regles creees dans `nexaretail-rules.yaml`, couvrant les scenarios
de menace les plus critiques pour NexaRetail :

| Regle | Priorite | Declencheur | MITRE ATT&CK |
|-------|----------|-------------|--------------|
| NexaRetail Shell in Production Container | CRITICAL | Shell ouvert dans nexaretail-prod | T1059 Execution |
| NexaRetail Sensitive File Access | ERROR | Lecture /etc/passwd, /etc/shadow | T1003 Credential Access |
| NexaRetail Unexpected Outbound Connection | WARNING | Connexion sortante hors ports autorises | T1041 Exfiltration |

Les regles sont chargees via le parametre `customRules` du chart Helm,
qui cree automatiquement un ConfigMap et le monte dans `/etc/falco/rules.d/`.
Falco scanne ce repertoire au demarrage en complement des regles par defaut.

### Test de detection valide

Un shell a ete ouvert volontairement dans le pod `nexaretail-api` en
production via `kubectl exec`. Falco a genere une alerte en moins de 5
secondes avec les informations suivantes :

- Nom du pod impacte
- Namespace (nexaretail-prod)
- Commande exacte executee
- Image du conteneur
- Timestamp de l'evenement

---

## Architecture deployee

```
Cluster Kubernetes (kind-nexaretail-aks)
|
+-- namespace: security
|   +-- falco (DaemonSet)                  Running 2/2
|       +-- driver: modern_ebpf
|       +-- regles par defaut : /etc/falco/falco_rules.yaml
|       +-- regles custom     : /etc/falco/rules.d/nexaretail_rules.yaml
|
+-- namespace: nexaretail-prod  <-- surveille par Falco
|   +-- nexaretail-api (pods)
|
+-- namespace: nexaretail-staging  <-- surveille par Falco
```

---

## Regles custom et couverture MITRE ATT&CK

```
Regle 1 : NexaRetail Shell in Production Container
  Condition : shell (bash/sh/zsh/ash/dash) spawn dans nexaretail-prod
  Priorite  : CRITICAL
  MITRE     : T1059 - Command and Scripting Interpreter

Regle 2 : NexaRetail Sensitive File Access
  Condition : lecture de /etc/passwd, /etc/shadow, /etc/sudoers, id_rsa
  Priorite  : ERROR
  MITRE     : T1003 - OS Credential Dumping

Regle 3 : NexaRetail Unexpected Outbound Connection
  Condition : connexion sortante hors ports 3000/443/80/5432
  Priorite  : WARNING
  MITRE     : T1041 - Exfiltration Over C2 Channel
```

---

## Structure des fichiers crees

```
falco/
+-- nexaretail-rules.yaml    <- 3 regles custom de detection
+-- values.yaml              <- Configuration Helm complete
```

---

## Validation Phase 9

```
helm install falco (driver modern_ebpf)
-> STATUS: deployed                                         OK

kubectl get pods -n security
-> falco-xxxxx : 2/2 Running                               OK

kubectl logs falco | grep rules
-> /etc/falco/falco_rules.yaml         schema validation: ok  OK
-> /etc/falco/rules.d/nexaretail_rules.yaml  schema: ok       OK

kubectl exec dans nexaretail-prod
-> Alerte Falco generee en < 5 secondes                    OK
-> Pod, namespace, commande et image loggues               OK

git push origin main
-> 2 fichiers commites (nexaretail-rules.yaml, values.yaml) OK
```

---

## Problemes rencontres et solutions

| Probleme | Cause | Solution |
|----------|-------|----------|
| Pod en Init:0/1 au demarrage | Chargement du driver eBPF, comportement normal | Attendre 30-60 secondes |
| Regles custom non chargees apres helm upgrade | Le pod DaemonSet ne redemarre pas automatiquement | kubectl rollout restart daemonset/falco -n security |
| extraVolumeMounts ne charge pas les regles | Falco ne scanne pas le chemin configure avec extraVolumes | Utiliser le parametre customRules du chart Helm |

---

## Chiffres cles

| Indicateur | Valeur |
|------------|--------|
| Pods deployes | 1 DaemonSet (2 containers : falco + driver-loader) |
| Driver utilise | modern_ebpf |
| Regles par defaut | falco_rules.yaml (regles built-in Falco) |
| Regles custom creees | 3 |
| Scenarios MITRE couverts | 3 (T1059, T1003, T1041) |
| Temps de detection teste | < 5 secondes |
| Fichiers crees | 2 |
| Ticket Jira ferme | SCRUM-20 |

---

## Liens utiles

- **GitHub :** github.com/Dkls7777/nexaretail-devops-platform
- **Jira :** samdossou26.atlassian.net (SCRUM-20)
- **Guide reproduction :** voir `guide-reproduction.md`

---

##  Code source de cette phase

| Fichier | Description |
|---------|-------------|
| [`falco/nexaretail-rules.yaml`](https://github.com/Dkls7777/nexaretail-devops-platform/blob/main/falco/nexaretail-rules.yaml) | 3 règles custom MITRE ATT&CK (accès /etc/passwd, shell, connexion sortante) |

> Dossier complet : [`falco/`](https://github.com/Dkls7777/nexaretail-devops-platform/tree/main/falco)
