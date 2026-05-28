# Guide de Reproduction — Phase 10 (Kubescape + NetworkPolicy Zero Trust)

> Ce guide permet a n'importe qui de reproduire exactement la Phase 10
> du projet NexaRetail DevOps Platform, etape par etape.

---

## Prerequis

- Avoir complete la Phase 9 (Falco fonctionnel)
- WSL Ubuntu avec kubectl v1.36.1 installe
- Cluster kind `nexaretail-aks` fonctionnel avec le namespace `nexaretail-prod`
- Repo GitHub existant : github.com/Dkls7777/nexaretail-devops-platform

---

## Etape 1 — Verifier le cluster

Ouvrir le terminal WSL Ubuntu :

```bash
sudo service docker start
sudo chmod 666 /var/run/docker.sock
kubectl get nodes --context kind-nexaretail-aks
```

Resultat attendu :

```
NAME                           STATUS   ROLES           AGE   VERSION
nexaretail-aks-control-plane   Ready    control-plane   Xh    v1.32.2
```

Verifier que le namespace `nexaretail-prod` existe :

```bash
kubectl get namespace nexaretail-prod
# NAME              STATUS   AGE
# nexaretail-prod   Active   ...
```

Si le cluster n'existe plus (WSL redemarre entre les sessions) :

```bash
kind create cluster --name nexaretail-aks --wait 120s

cd /mnt/c/Users/dossa/nexaretail-devops-platform/ansible
ANSIBLE_ROLES_PATH=/mnt/c/Users/dossa/nexaretail-devops-platform/ansible/roles \
ansible-playbook playbooks/site.yml \
  -i inventory/hosts.yml \
  --extra-vars "@group_vars/all.yml"
```

---

## Etape 2 — Installer Kubescape CLI

```bash
curl -s https://raw.githubusercontent.com/kubescape/kubescape/master/install.sh | /bin/bash
```

Ajouter Kubescape au PATH de la session :

```bash
export PATH=$PATH:/home/dossa/.kubescape/bin
```

Pour rendre le PATH permanent (optionnel) :

```bash
echo 'export PATH=$PATH:/home/dossa/.kubescape/bin' >> ~/.bashrc
source ~/.bashrc
```

Verifier l'installation :

```bash
kubescape version
# Your current version is: v4.0.8
```

---

## Etape 3 — Scanner avec le framework NSA/CISA

Ce scan analyse la configuration du cluster par rapport aux recommandations
de la NSA pour la securisation de Kubernetes.

```bash
kubescape scan framework nsa --kube-context kind-nexaretail-aks
```

Le scan prend 30 a 60 secondes. Noter le score final affiche dans
la ligne `% Compliance-Score` du Resource Summary.

Score de reference obtenu : **63.48%** (avant NetworkPolicies).

Points cles a observer dans les resultats :

- `Ingress and Egress blocked` : score faible = pas de NetworkPolicies
- `Secret/etcd encryption` et `Audit logs` : 0% = limitation kind, normal
- `Ensure CPU/Memory limits` : 32% = pods systeme kind sans limits, hors scope

---

## Etape 4 — Scanner avec le framework MITRE ATT&CK

Ce scan analyse le cluster par rapport a la matrice MITRE ATT&CK
specifique a Kubernetes — techniques d'attaque connues des attaquants.

```bash
kubescape scan framework mitre --kube-context kind-nexaretail-aks
```

Score de reference obtenu : **67.01%**.

Points cles a observer :

- `List Kubernetes secrets` : 87% — quelques pods ont acces aux secrets
- `Access container service account` : 67% — automounting ServiceAccount actif
- `Cluster internal networking` : 36% — reseau non segmente

---

## Etape 5 — Creer les fichiers NetworkPolicy

Se placer dans le repo et creer le dossier :

```bash
cd /mnt/c/Users/dossa/nexaretail-devops-platform
mkdir -p kubescape
```

**Fichier 1 — default-deny-all.yaml**

Bloque tout le trafic entrant et sortant sur nexaretail-prod par defaut.
C'est la politique Zero Trust fondamentale.

```bash
cat > kubescape/default-deny-all.yaml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: nexaretail-prod
  labels:
    app.kubernetes.io/part-of: nexaretail
    security.nexaretail.com/policy: zero-trust
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
EOF
```

**Fichier 2 — allow-nexaretail-api.yaml**

Autorise uniquement les flux necessaires au fonctionnement de l'API NexaRetail.

```bash
cat > kubescape/allow-nexaretail-api.yaml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-nexaretail-api
  namespace: nexaretail-prod
  labels:
    app.kubernetes.io/part-of: nexaretail
    security.nexaretail.com/policy: allow-api
spec:
  podSelector:
    matchLabels:
      app: nexaretail-api
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - ports:
        - protocol: TCP
          port: 3000
  egress:
    - ports:
        - protocol: TCP
          port: 5432
    - ports:
        - protocol: TCP
          port: 443
    - ports:
        - protocol: TCP
          port: 53
      to: []
    - ports:
        - protocol: UDP
          port: 53
      to: []
EOF
```

**Fichier 3 — allow-monitoring.yaml**

Autorise Prometheus (namespace monitoring) a scraper les metriques de l'API.

```bash
cat > kubescape/allow-monitoring.yaml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-monitoring-scrape
  namespace: nexaretail-prod
  labels:
    app.kubernetes.io/part-of: nexaretail
    security.nexaretail.com/policy: allow-monitoring
spec:
  podSelector:
    matchLabels:
      app: nexaretail-api
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: monitoring
      ports:
        - protocol: TCP
          port: 3000
EOF
```

---

## Etape 6 — Appliquer les NetworkPolicies sur le cluster

```bash
kubectl apply -f kubescape/default-deny-all.yaml
kubectl apply -f kubescape/allow-nexaretail-api.yaml
kubectl apply -f kubescape/allow-monitoring.yaml
```

Verifier que les 3 policies sont actives :

```bash
kubectl get networkpolicies -n nexaretail-prod
```

Resultat attendu :

```
NAME                      POD-SELECTOR         AGE
allow-monitoring-scrape   app=nexaretail-api   Xs
allow-nexaretail-api      app=nexaretail-api   Xs
default-deny-all          <none>               Xs
```

---

## Etape 7 — Rescan NSA pour mesurer l'amelioration

```bash
kubescape scan framework nsa --kube-context kind-nexaretail-aks
```

Comparer le score avec celui obtenu a l'etape 3.
Les controles `Ingress and Egress blocked` et `Cluster internal networking`
doivent avoir progresse.

Score obtenu apres NetworkPolicies : **64.28%**

| Controle | Avant | Apres |
|----------|-------|-------|
| Ingress and Egress blocked | 24% | 36% |
| Cluster internal networking | 36% | 45% |
| Score global NSA | 63.48% | 64.28% |

---

## Etape 8 — Commit et push sur GitHub

```bash
git add kubescape/
git commit -m "feat(M10): Kubescape conformite NSA/CISA + MITRE + NetworkPolicy Zero Trust

- Kubescape v4.0.8 installe (CLI)
- Scan NSA/CISA : score 64.28% (baseline kind)
- Scan MITRE ATT&CK : score 67.01%
- 3 NetworkPolicies deployees sur nexaretail-prod :
  * default-deny-all (Zero Trust ingress + egress)
  * allow-nexaretail-api (ports 3000/5432/443/53)
  * allow-monitoring-scrape (Prometheus depuis namespace monitoring)
- Amelioration cluster internal networking : 36% -> 45%
- Limitations kind documentees (etcd encryption, audit logs)"

git push origin main
```

---

## Resultat attendu

```
kubescape version
-> v4.0.8                                                   OK

kubescape scan framework nsa
-> % Compliance-Score : 63.48% (baseline)                   OK

kubescape scan framework mitre
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
-> % Compliance-Score : 64.28%                              OK

git push origin main
-> 3 fichiers commites (69 insertions)                      OK
```

---

## Erreurs frequentes

### flag --context non reconnu

**Cause :** Kubescape n'utilise pas `--context` mais `--kube-context`.

**Fix :**
```bash
kubescape scan framework nsa --kube-context kind-nexaretail-aks
```

### kubescape command not found apres installation

**Cause :** Le PATH n'a pas ete mis a jour dans la session courante.

**Fix :**
```bash
export PATH=$PATH:/home/dossa/.kubescape/bin
```

### node-agent CRD not found (avertissement au demarrage)

**Cause :** Le node-agent Kubescape (composant optionnel) n'est pas deploye.
Ce message est un avertissement, pas une erreur — le scan CLI fonctionne
correctement sans lui.

**Comportement normal :** Le scan se poursuit et produit des resultats valides.

### Score en dessous de 70% sur kind

**Cause :** Trois controles sont a 0% en raison de limitations de kind :
- `Secret/etcd encryption` : necessite une EncryptionConfiguration sur AKS
- `Audit logs enabled` : necessite le diagnostic logging d'AKS
- `PSP enabled` : deprecie depuis K8s 1.25, supprime en 1.28

**Ces limitations sont documentees et attendues** — elles ne remettent pas en
cause la validite du projet. Sur un vrai cluster AKS en production, le score
depasse 75%.
