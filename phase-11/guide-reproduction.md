# Guide de Reproduction — Phase 11 (Pipeline Demo Bout en Bout)

> Ce guide permet a n'importe qui de reproduire exactement la Phase 11
> du projet NexaRetail DevOps Platform, etape par etape.

---

## Prerequis

- Avoir complete les phases M0 a M10
- WSL Ubuntu avec Docker, kubectl, kind, git installes
- Cluster kind `nexaretail-aks` cree lors de M2
- Repo GitHub : github.com/Dkls7777/nexaretail-devops-platform
- Secrets GitHub configures : AZURE_CREDENTIALS, ACR_LOGIN_SERVER, GH_PAT

---

## Etape 1 — Remettre en etat le cluster

### 1.1 Demarrer Docker et le cluster kind

```bash
sudo service docker start
sudo chmod 666 /var/run/docker.sock
docker start nexaretail-aks-control-plane
kubectl get nodes --context kind-nexaretail-aks
```

Resultat attendu :
```
NAME                           STATUS   ROLES           AGE
nexaretail-aks-control-plane   Ready    control-plane   ...
```

### 1.2 Verifier tous les namespaces et pods

```bash
kubectl get namespaces
kubectl get pods -n argocd
kubectl get pods -n monitoring
kubectl get pods -n vault
kubectl get pods -n security
kubectl get pods -n nexaretail-prod
```

### 1.3 Unsealer Vault

Si vault-0 est en 0/1 Ready, re-initialiser et unsealer :

```bash
# Re-initialisation (si donnees perdues apres redemarrage kind)
kubectl exec -n vault vault-0 -- vault operator init \
  -key-shares=5 \
  -key-threshold=3

# Copier les 5 cles unseal et le root token affiches

# Unseal avec 3 cles
kubectl exec -n vault vault-0 -- vault operator unseal "CLE_1"
kubectl exec -n vault vault-0 -- vault operator unseal "CLE_2"
kubectl exec -n vault vault-0 -- vault operator unseal "CLE_3"

# Verifier
kubectl get pod vault-0 -n vault
# Attendu : 1/1 Running
```

### 1.4 Verifier ArgoCD

```bash
kubectl get applications -n argocd
# Attendu : nexaretail-api   Synced   Healthy (ou Degraded si image manquante)
```

### 1.5 Corriger ErrImagePull si necessaire

Si un pod est en ErrImagePull, builder et charger l'image dans kind :

```bash
# Verifier le tag manquant
grep "tag:" helm/nexaretail-api/values.yaml

# Cloner le repo si absent
cd ~
git clone https://github.com/Dkls7777/nexaretail-devops-platform.git
cd nexaretail-devops-platform

# Builder l'image avec le bon tag
docker build -t nexaretail-api:TAG_MANQUANT ./app/

# Charger dans kind
kind load docker-image nexaretail-api:TAG_MANQUANT --name nexaretail-aks

# Forcer le redemarrage
kubectl rollout restart deployment/nexaretail-api -n nexaretail-prod
kubectl get pods -n nexaretail-prod -w
```

---

## Etape 2 — Faire un changement de code visible

### 2.1 Modifier l'endpoint /version

```bash
cd ~/nexaretail-devops-platform
sed -i 's/buildDate: process.env.BUILD_DATE || .local./buildDate: process.env.BUILD_DATE || '\''local'\'',\n    demo: '\''M11 - Pipeline bout en bout - NexaRetail DevSecOps'\''/' app/src/index.js
```

Verifier la modification :

```bash
sed -n '28,45p' app/src/index.js
```

Le champ `demo` doit apparaitre dans le JSON retourne.

### 2.2 Commit et push

```bash
git add app/src/index.js
git commit -m "feat(api): add M11 demo field to /version endpoint"
git push origin main
```

---

## Etape 3 — Observer le pipeline

### 3.1 GitHub Actions

Ouvrir dans le navigateur :
```
https://github.com/Dkls7777/nexaretail-devops-platform/actions
```

Le run doit afficher 3 jobs en vert :
- Code Quality & npm Audit (~15s)
- Build → Trivy Scan → Push ACR (~1m17s)
- Update Helm values → GitOps (~4s)

### 3.2 Surveiller ArgoCD en parallele

```bash
watch -n 5 "kubectl get applications -n argocd && echo '---' && kubectl get pods -n nexaretail-prod"
```

Apres que le Job 3 soit termine, ArgoCD detecte le changement en moins de 3 minutes.

### 3.3 Recuperer le nouveau tag et charger dans kind

```bash
git pull origin main
grep "tag:" helm/nexaretail-api/values.yaml
# Recuperer le nouveau tag (ex: 1.0.6)

docker build -t nexaretail-api:NOUVEAU_TAG ./app/
kind load docker-image nexaretail-api:NOUVEAU_TAG --name nexaretail-aks
kubectl get pods -n nexaretail-prod -w
```

---

## Etape 4 — Validation de la stack complete

### 4.1 Validation complete en une commande

```bash
echo "=== ARGOCD ===" && \
kubectl get applications -n argocd && \
echo "=== PODS PRODUCTION ===" && \
kubectl get pods -n nexaretail-prod && \
echo "=== PROMETHEUS ===" && \
kubectl get pods -n monitoring && \
echo "=== FALCO ===" && \
kubectl get pods -n security && \
echo "=== VAULT ===" && \
kubectl get pod vault-0 -n vault
```

### 4.2 Tester l'endpoint /version

```bash
kubectl port-forward svc/nexaretail-api -n nexaretail-prod 3000:3000 &
sleep 2
curl http://localhost:3000/version
kill %1
```

Resultat attendu :
```json
{
  "name": "nexaretail-api",
  "version": "1.0.0",
  "environment": "production",
  "buildDate": "local",
  "demo": "M11 - Pipeline bout en bout - NexaRetail DevSecOps"
}
```

### 4.3 Tester les metriques Prometheus

```bash
kubectl exec -n nexaretail-prod deployment/nexaretail-api -- \
  wget -qO- http://localhost:3000/metrics | head -10
```

### 4.4 Verifier les alertes Falco

```bash
kubectl logs -n security -l app.kubernetes.io/name=falco --since=10m | \
  grep -i "notice\|warning\|error\|critical" | tail -5
```

---

## Etape 5 — Rapport et cloture

### 5.1 Pusher le rapport de validation

```bash
mkdir -p docs
# Copier le fichier rapport-module11-demo.md dans docs/
git add docs/rapport-module11-demo.md
git commit -m "docs: add M11 end-to-end demo validation report"
git push origin main
```

### 5.2 Passer le ticket Jira en Termine

Sur samdossou26.atlassian.net → SCRUM-22 → Terminer

---

## Resultat attendu final

```
Cluster kind                    Ready
Vault                           1/1 Running — Unsealed
ArgoCD                          Synced / Healthy
Pods nexaretail-prod            2/2 Running
Pipeline GitHub Actions         3 jobs en vert — Success
/version                        demo: M11 present
/metrics                        Prometheus actif
Falco                           Alertes custom actives
Prometheus + Grafana            Running
Ticket Jira SCRUM-22            Termine
```
