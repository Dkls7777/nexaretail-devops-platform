# Guide de Reproduction — Phase 3 (ArgoCD GitOps)

> Ce guide permet à n'importe qui de reproduire exactement la Phase 3
> du projet NexaRetail DevOps Platform, étape par étape.

---

## ⚙️ Prérequis

- Avoir complété la Phase 2 (cluster kind `nexaretail-aks` fonctionnel)
- WSL Ubuntu avec Helm v3.21.0 et kubectl v1.36.1 installés
- Repo GitHub existant : github.com/Dkls7777/nexaretail-devops-platform
- Docker démarré dans WSL

---

## ☸️ Étape 1 — Vérifier le cluster

Ouvrir le terminal **WSL Ubuntu** :

```bash
sudo service docker start
sudo chmod 666 /var/run/docker.sock
kubectl cluster-info --context kind-nexaretail-aks
```

> Résultat attendu :
> ```
> Kubernetes control plane is running at https://127.0.0.1:xxxxx
> ```

Si le cluster n'existe plus (WSL redémarré depuis la dernière session) :

```bash
kind create cluster --name nexaretail-aks --wait 120s
```

Puis relancer le playbook Ansible pour reconfigurer les namespaces :

```bash
cd /mnt/c/Users/<ton-user>/nexaretail-devops-platform/ansible

ANSIBLE_ROLES_PATH=/mnt/c/Users/<ton-user>/nexaretail-devops-platform/ansible/roles \
ansible-playbook playbooks/site.yml \
  -i inventory/hosts.yml \
  --extra-vars "@group_vars/all.yml"
```

---

## 📦 Étape 2 — Installer ArgoCD via Helm

```bash
# Mettre à jour les repos Helm
helm repo update

# Installer ArgoCD
# ⚠️ Le nom du chart est "argo-cd" (avec tiret), pas "argocd"
helm install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  --set server.service.type=NodePort \
  --wait
```

> ⏳ L'installation prend 2-3 minutes le temps que les pods démarrent.

Vérifier que les 7 pods sont Running :

```bash
kubectl get pods -n argocd
```

Résultat attendu :
```
NAME                                                READY   STATUS
argocd-application-controller-0                     1/1     Running
argocd-applicationset-controller-xxx                1/1     Running
argocd-dex-server-xxx                               1/1     Running
argocd-notifications-controller-xxx                 1/1     Running
argocd-redis-xxx                                    1/1     Running
argocd-repo-server-xxx                              1/1     Running
argocd-server-xxx                                   1/1     Running
```

---

## 🔑 Étape 3 — Récupérer le mot de passe admin

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```

> ⚠️ **Note le mot de passe** qui s'affiche — il est généré aléatoirement à chaque installation.
> À stocker dans HashiCorp Vault (M8). Ne jamais le committer sur GitHub.

Pour accéder à l'interface web ArgoCD :

```bash
kubectl port-forward service/argocd-server -n argocd 8080:443
```

Puis ouvrir https://localhost:8080 dans le navigateur.
Login : `admin` / mot de passe récupéré ci-dessus.

---

## 📁 Étape 4 — Créer la structure GitOps

```bash
cd /mnt/c/Users/<ton-user>/nexaretail-devops-platform

mkdir -p gitops/applications
mkdir -p helm/nexaretail-api/templates
```

---

## 📝 Étape 5 — Créer le Helm Chart nexaretail-api

**5.1 — Chart.yaml (métadonnées du chart)**

```bash
cat > helm/nexaretail-api/Chart.yaml << 'EOF'
apiVersion: v2
name: nexaretail-api
description: API NexaRetail - Gestion des commandes B2B
type: application
version: 0.1.0
appVersion: "1.0.0"
EOF
```

**5.2 — values.yaml (configuration)**

```bash
cat > helm/nexaretail-api/values.yaml << 'EOF'
replicaCount: 2

image:
  repository: nexaretailprodacr.azurecr.io/nexaretail-api
  pullPolicy: IfNotPresent
  tag: "latest"

service:
  type: ClusterIP
  port: 3000

resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 256Mi

autoscaling:
  enabled: false
  minReplicas: 2
  maxReplicas: 10
EOF
```

**5.3 — templates/deployment.yaml**

```bash
cat > helm/nexaretail-api/templates/deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Release.Name }}
  namespace: nexaretail-prod
  labels:
    app: {{ .Release.Name }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app: {{ .Release.Name }}
  template:
    metadata:
      labels:
        app: {{ .Release.Name }}
    spec:
      containers:
        - name: api
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - containerPort: {{ .Values.service.port }}
          resources:
            requests:
              cpu: {{ .Values.resources.requests.cpu }}
              memory: {{ .Values.resources.requests.memory }}
            limits:
              cpu: {{ .Values.resources.limits.cpu }}
              memory: {{ .Values.resources.limits.memory }}
EOF
```

**5.4 — templates/service.yaml**

```bash
cat > helm/nexaretail-api/templates/service.yaml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: {{ .Release.Name }}
  namespace: nexaretail-prod
spec:
  type: {{ .Values.service.type }}
  selector:
    app: {{ .Release.Name }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: {{ .Values.service.port }}
EOF
```

---

## 🔄 Étape 6 — Créer le manifest Application ArgoCD

```bash
cat > gitops/applications/nexaretail-api.yaml << 'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: nexaretail-api
  namespace: argocd
  labels:
    project: nexaretail
    team: backend
spec:
  project: default
  source:
    repoURL: https://github.com/Dkls7777/nexaretail-devops-platform
    targetRevision: main
    path: helm/nexaretail-api
    helm:
      valueFiles:
        - values.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: nexaretail-prod
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
EOF
```

> **Explication des paramètres clés :**
> - `automated.selfHeal: true` → si quelqu'un modifie le cluster à la main,
>   ArgoCD remet automatiquement l'état défini dans Git
> - `automated.prune: true` → supprime les ressources retirées de Git
> - `syncOptions.CreateNamespace` → crée le namespace s'il n'existe pas

---

## 📤 Étape 7 — Pusher sur GitHub AVANT d'appliquer

> ⚠️ **Important :** ArgoCD lit les fichiers depuis GitHub, pas depuis le disque local.
> Il faut impérativement pusher avant d'appliquer le manifest ArgoCD.

```bash
git add helm/ gitops/
git commit -m "feat(gitops): M3 - ArgoCD Application + Helm chart nexaretail-api

- Chart.yaml : chart Helm pour l'API NexaRetail
- values.yaml : 2 replicas, ressources CPU/RAM configurées
- templates/deployment.yaml : Deployment Kubernetes
- templates/service.yaml : Service ClusterIP port 3000
- gitops/applications/nexaretail-api.yaml : Application ArgoCD
  avec auto-sync et self-heal activés"

git push origin main
```

> GitHub demande un token PAT (`ghp_...`) comme mot de passe.

---

## 🚀 Étape 8 — Appliquer l'Application ArgoCD

```bash
kubectl apply -f gitops/applications/nexaretail-api.yaml
```

Vérifier que ArgoCD détecte l'application :

```bash
kubectl get applications -n argocd
```

Attendre la synchronisation (ArgoCD vérifie le repo toutes les 3 minutes) :

```bash
sleep 30 && kubectl get applications -n argocd
# Résultat attendu :
# NAME             SYNC STATUS   HEALTH STATUS
# nexaretail-api   Synced        Progressing
```

Vérifier les pods créés automatiquement par ArgoCD :

```bash
kubectl get pods -n nexaretail-prod
# NAME                             READY   STATUS
# nexaretail-api-xxx               0/1     ImagePullBackOff  ← Normal (image M4/M5)
# nexaretail-api-xxx               0/1     ImagePullBackOff  ← Normal (image M4/M5)
```

> L'`ImagePullBackOff` est attendu : l'image Docker sera construite en M4 et
> publiée dans l'ACR Azure en M5. ArgoCD a bien fait son travail — les pods
> existent, preuve que le Deployment Kubernetes est correct.

---

## ✅ Résultat attendu

```
kubectl get pods -n argocd        → 7/7 Running          ✅
kubectl get applications -n argocd → Synced               ✅
kubectl get pods -n nexaretail-prod → 2 pods créés        ✅
```

---

## 🐛 Erreurs fréquentes

### `chart "argocd" not found in argo index`
**Cause :** Mauvais nom de chart Helm.
**Fix :** Le chart s'appelle `argo/argo-cd` (avec tiret), pas `argo/argocd`.
```bash
helm repo update
helm install argocd argo/argo-cd ...
```

### `app path does not exist` (SYNC STATUS: Unknown)
**Cause :** Les fichiers Helm ne sont pas encore sur GitHub quand ArgoCD essaie de les lire.
**Fix :** Toujours `git push` avant de `kubectl apply` le manifest ArgoCD.

### `rejected — fetch first` lors du push
**Cause :** Le remote GitHub a des commits que le local n'a pas (ex: README édité sur GitHub).
**Fix :**
```bash
git stash
git pull origin main --rebase
git stash pop
git push origin main
```

### ArgoCD reste en `Unknown` après le push
**Cause :** ArgoCD n'a pas encore rafraîchi (cycle de 3 minutes par défaut).
**Fix :** Attendre 30-60 secondes et relancer `kubectl get applications -n argocd`.
