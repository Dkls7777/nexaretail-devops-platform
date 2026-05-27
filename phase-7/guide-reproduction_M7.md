# Guide de Reproduction — Phase 7 (Prometheus + Grafana)

> Ce guide permet a n'importe qui de reproduire exactement la Phase 7
> du projet NexaRetail DevOps Platform, etape par etape.

---

## Prerequis

- Avoir complete la Phase 6 (pipeline CI/CD fonctionnel)
- WSL Ubuntu avec Helm v3.21.0, kubectl v1.36.1 et kind installes
- Cluster kind `nexaretail-aks` fonctionnel avec les 6 namespaces (dont `monitoring`)
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
nexaretail-aks-control-plane   Ready    control-plane   ...   v1.32.2
```

Verifier que le namespace `monitoring` existe :

```bash
kubectl get namespaces | grep monitoring
# monitoring   Active   ...
```

Si le cluster n'existe plus (WSL redémarre entre les sessions) :

```bash
kind create cluster --name nexaretail-aks --wait 120s
```

Puis relancer le playbook Ansible pour recreer les namespaces :

```bash
cd /mnt/c/Users/dossa/nexaretail-devops-platform/ansible

ANSIBLE_ROLES_PATH=/mnt/c/Users/dossa/nexaretail-devops-platform/ansible/roles \
ansible-playbook playbooks/site.yml \
  -i inventory/hosts.yml \
  --extra-vars "@group_vars/all.yml"
```

---

## Etape 2 — Installer kube-prometheus-stack

Mettre a jour les repos Helm puis installer la stack :

```bash
helm repo update

helm install kube-prometheus-stack \
  prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set grafana.service.type=NodePort \
  --set grafana.adminPassword='NexaRetail2026!' \
  --set prometheus.prometheusSpec.retention=15d \
  --wait
```

> L'option `--wait` fait que la commande ne rend la main qu'une fois tous
> les pods demarres. Compter 2 a 3 minutes.

Resultat attendu en fin de commande :
```
NAME: kube-prometheus-stack
LAST DEPLOYED: ...
NAMESPACE: monitoring
STATUS: deployed
REVISION: 1
```

Verifier que les 6 pods sont Running :

```bash
kubectl get pods -n monitoring
```

Resultat attendu :
```
NAME                                                       READY   STATUS
alertmanager-kube-prometheus-stack-alertmanager-0          2/2     Running
kube-prometheus-stack-grafana-xxx                          3/3     Running
kube-prometheus-stack-kube-state-metrics-xxx               1/1     Running
kube-prometheus-stack-operator-xxx                         1/1     Running
kube-prometheus-stack-prometheus-node-exporter-xxx         1/1     Running
prometheus-kube-prometheus-stack-prometheus-0              2/2     Running
```

---

## Etape 3 — Creer le ServiceMonitor

Le ServiceMonitor indique a Prometheus de scraper automatiquement
l'endpoint `/metrics` de l'API NexaRetail.

> Le label `release: kube-prometheus-stack` est obligatoire : c'est ce que
> le prometheus-operator utilise pour selectionner les ServiceMonitors a prendre
> en compte. Sans ce label, Prometheus ignore le fichier.

Se placer dans le repo :

```bash
cd /mnt/c/Users/dossa/nexaretail-devops-platform
mkdir -p monitoring
```

Creer le fichier :

```bash
cat > monitoring/servicemonitor-nexaretail.yaml << 'EOF'
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: nexaretail-api
  namespace: monitoring
  labels:
    release: kube-prometheus-stack
spec:
  namespaceSelector:
    matchNames:
      - nexaretail-prod
  selector:
    matchLabels:
      app: nexaretail-api
  endpoints:
    - port: http
      path: /metrics
      interval: 30s
EOF
```

Appliquer :

```bash
kubectl apply -f monitoring/servicemonitor-nexaretail.yaml
# servicemonitor.monitoring.coreos.com/nexaretail-api created
```

---

## Etape 4 — Creer les alertes SLO

Ce fichier definit deux alertes couvrant les cas critiques NexaRetail :
- latence P95 au-dessus du SLO de 500ms pendant 2 minutes
- API completement inaccessible pendant 1 minute

```bash
cat > monitoring/prometheusrule-nexaretail.yaml << 'EOF'
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: nexaretail-alerts
  namespace: monitoring
  labels:
    release: kube-prometheus-stack
spec:
  groups:
    - name: nexaretail.slo
      interval: 30s
      rules:
        - alert: NexaRetailAPIHighLatency
          expr: |
            histogram_quantile(0.95,
              sum(rate(http_request_duration_seconds_bucket{job="nexaretail-api"}[5m]))
              by (le, route)
            ) > 0.5
          for: 2m
          labels:
            severity: warning
            team: backend
          annotations:
            summary: "API NexaRetail latence elevee"
            description: "Le P95 de latence depasse 500ms depuis 2 minutes sur la route {{ $labels.route }}"

        - alert: NexaRetailAPIDown
          expr: |
            absent(http_request_duration_seconds_count{job="nexaretail-api"})
          for: 1m
          labels:
            severity: critical
            team: backend
          annotations:
            summary: "API NexaRetail inaccessible"
            description: "Aucune metrique recue depuis l'API NexaRetail depuis 1 minute"
EOF
```

Appliquer :

```bash
kubectl apply -f monitoring/prometheusrule-nexaretail.yaml
# prometheusrule.monitoring.coreos.com/nexaretail-alerts created
```

---

## Etape 5 — Verifier Grafana

Lancer le port-forward (le terminal reste bloque, c'est normal) :

```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
```

Ouvrir Chrome sur : http://localhost:3000

Identifiants :
- Login : `admin`
- Mot de passe : `NexaRetail2026!`

L'interface Grafana doit s'afficher. La datasource Prometheus est
connectee automatiquement par kube-prometheus-stack.

Faire `Ctrl+C` dans le terminal pour stopper le port-forward.

---

## Etape 6 — Commit et push sur GitHub

```bash
cd /mnt/c/Users/dossa/nexaretail-devops-platform

git add monitoring/
git commit -m "feat(M7): Prometheus + Grafana monitoring stack

- kube-prometheus-stack installe via Helm (namespace monitoring)
- 6 pods Running : Prometheus, Grafana, AlertManager, exporters
- ServiceMonitor nexaretail-api : scrape /metrics toutes les 30s
- PrometheusRule : alerte latence P95 > 500ms + alerte API down
- Grafana accessible sur port 3000 (admin / NexaRetail2026!)"

git push origin main
```

> Si le push est rejete (`fetch first`), c'est le job CD qui a committe
> automatiquement. Faire :
> ```bash
> git pull origin main --rebase
> git push origin main
> ```

---

## Resultat attendu

```
kubectl get pods -n monitoring     -> 6/6 Running            OK
kubectl apply servicemonitor       -> created                 OK
kubectl apply prometheusrule       -> created                 OK
Grafana http://localhost:3000      -> interface accessible    OK
git push origin main               -> push reussi             OK
Jira SCRUM-16                      -> Termine                 OK
```

---

## Erreurs frequentes

### Mot de passe sudo oublie
**Cause :** WSL demande le mot de passe Linux cree lors de l'installation
d'Ubuntu, pas le mot de passe Windows.
**Fix :** Dans PowerShell Windows :
```powershell
wsl -u root
```
Puis dans le terminal root :
```bash
passwd dossa
```
Choisir un nouveau mot de passe, fermer et rouvrir WSL normalement.

### `rejected — fetch first` au push
**Cause :** Le job CD (github-actions[bot]) a committe automatiquement
dans le repo, creant une divergence avec le clone local.
**Fix :**
```bash
git pull origin main --rebase
git push origin main
```

### ServiceMonitor ignore par Prometheus
**Cause :** Le label `release: kube-prometheus-stack` est absent du ServiceMonitor.
**Fix :** Verifier que le metadata du fichier contient bien :
```yaml
labels:
  release: kube-prometheus-stack
```

### Grafana ne demarre pas (pod en Pending)
**Cause :** Ressources insuffisantes sur le noeud kind (RAM).
**Fix :** Fermer les applications lourdes sur Windows pour liberer de la RAM,
puis attendre que le pod demarre (`kubectl get pods -n monitoring -w`).
