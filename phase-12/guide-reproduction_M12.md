# Guide de Reproduction — Phase 12 (Validation & Bilan)

> Ce guide permet de reproduire exactement la Phase 12
> du projet NexaRetail DevOps Platform.

---

## Prerequis

- Avoir complete la Phase 11 (pipeline demo bout en bout)
- WSL Ubuntu avec kubectl, docker, kind installes
- Repo GitHub : github.com/Dkls7777/nexaretail-devops-platform

---

## Etape 1 — Demarrer l'environnement

```bash
sudo service docker start
sudo chmod 666 /var/run/docker.sock
docker start nexaretail-aks-control-plane
kubectl get nodes --context kind-nexaretail-aks
```

Resultat attendu :
```
NAME                           STATUS   ROLES           AGE
nexaretail-aks-control-plane   Ready    control-plane   Xd
```

---

## Etape 2 — Unseal Vault

```bash
kubectl exec -n vault vault-0 -- vault operator unseal <cle-1>
kubectl exec -n vault vault-0 -- vault operator unseal <cle-2>
kubectl exec -n vault vault-0 -- vault operator unseal <cle-3>
```

Resultat attendu sur la 3e commande : `Sealed: false`

---

## Etape 3 — Validation globale de la stack

```bash
echo "=== NODES ===" && \
kubectl get nodes && \
echo "=== NAMESPACES ===" && \
kubectl get ns && \
echo "=== ARGOCD ===" && \
kubectl get applications -n argocd && \
echo "=== PODS PRODUCTION ===" && \
kubectl get pods -n nexaretail-prod && \
echo "=== PROMETHEUS + GRAFANA ===" && \
kubectl get pods -n monitoring && \
echo "=== VAULT ===" && \
kubectl get pod vault-0 -n vault && \
echo "=== FALCO ===" && \
kubectl get pods -n security && \
echo "=== FIN VALIDATION ==="
```

---

## Etape 4 — Tester les endpoints

```bash
kubectl port-forward svc/nexaretail-api -n nexaretail-prod 3000:3000 &
sleep 3
curl -s http://localhost:3000/health
curl -s http://localhost:3000/version
curl -s http://localhost:3000/api/orders/stats/summary
kill %1
```

---

## Etape 5 — Corriger un ImagePullBackOff (si necessaire)

Si un pod est en ImagePullBackOff apres un redemarrage :

```bash
# Identifier le tag manquant
kubectl describe pod -n nexaretail-prod -l app=nexaretail-api | grep "Image:"

# Construire et charger l'image dans kind
cd /mnt/c/Users/dossa/nexaretail-devops-platform
git pull origin main
docker build -t nexaretail-api:TAG_MANQUANT ./app/
kind load docker-image nexaretail-api:TAG_MANQUANT --name nexaretail-aks

# Verifier le rolling update
kubectl get pods -n nexaretail-prod -w
```

---

## Etape 6 — Pousser les fichiers M12

```bash
cd /mnt/c/Users/dossa/nexaretail-devops-platform

mkdir -p phase-12 docs

# Copier les fichiers telecharges depuis Claude
cp ~/Downloads/README.md phase-12/README.md
cp ~/Downloads/guide-reproduction_M12.md phase-12/guide-reproduction.md
cp ~/Downloads/rapport-final-nexaretail.md docs/rapport-final-nexaretail.md

git add phase-12/ docs/rapport-final-nexaretail.md
git commit -m "docs: add M12 final validation report and project summary"
git push origin main
```

---

## Etape 7 — Passer le ticket Jira en Termine

Sur samdossou26.atlassian.net → ticket SCRUM-M12 → Terminer

---

## Checklist finale

```
Cluster kind                          Ready
Vault unseale                         Sealed: false
ArgoCD                                Synced / Healthy
Pods nexaretail-prod                  2/2 Running
Prometheus + Grafana                  Tous Running
Falco                                 2/2 Running
GET /health                           {"status":"healthy"}
GET /version                          demo present
GET /api/orders/stats/summary         {"totalOrders":5,"merchants":4}
Rolling update zero downtime          Valide
Rapport final pousse sur GitHub       OK
Ticket Jira M12                       Termine
```
