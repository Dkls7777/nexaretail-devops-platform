# Guide de Reproduction — Phase 4 (App Node.js / Docker)

> Ce guide permet à n'importe qui de reproduire exactement la Phase 4
> du projet NexaRetail DevOps Platform, étape par étape.

---

## ⚙️ Prérequis

- Avoir complété la Phase 3 (ArgoCD installé, cluster kind `nexaretail-aks` fonctionnel)
- WSL Ubuntu avec Docker, kubectl et kind installés
- Repo GitHub existant : github.com/Dkls7777/nexaretail-devops-platform
- Node.js non requis en local (l'app tourne dans Docker)

---

## ☸️ Étape 1 — Vérifier le cluster

Ouvrir le terminal **WSL Ubuntu** :

```bash
sudo service docker start
sudo chmod 666 /var/run/docker.sock
kubectl get nodes --context kind-nexaretail-aks
```

Résultat attendu :
```
NAME                           STATUS   ROLES           AGE   VERSION
nexaretail-aks-control-plane   Ready    control-plane   ...   v1.32.2
```

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

Et réinstaller ArgoCD :

```bash
helm repo update
helm install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  --set server.service.type=NodePort \
  --wait

kubectl apply -f gitops/applications/nexaretail-api.yaml
```

---

## 📁 Étape 2 — Créer la structure de l'application

```bash
cd /mnt/c/Users/<ton-user>/nexaretail-devops-platform

mkdir -p app/src/routes
mkdir -p app/src/middleware
```

---

## 📝 Étape 3 — Créer les fichiers Node.js

> ⚠️ **Important :** Utiliser `<< 'EOF'` (guillemets simples) pour éviter
> que bash interprète les variables `${variable}` dans le code source.

**3.1 — package.json**

```bash
cat > app/package.json << 'EOF'
{
  "name": "nexaretail-api",
  "version": "1.0.0",
  "description": "API NexaRetail - Gestion des commandes B2B",
  "main": "src/index.js",
  "scripts": {
    "start": "node src/index.js",
    "dev": "nodemon src/index.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "prom-client": "^15.1.0"
  }
}
EOF
```

**3.2 — src/middleware/health.js**

```bash
cat > app/src/middleware/health.js << 'EOF'
const os = require('os');

const healthCheck = (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: Math.floor(process.uptime()),
    hostname: os.hostname(),
    version: process.env.APP_VERSION || '1.0.0'
  });
};

module.exports = { healthCheck };
EOF
```

> **Pourquoi un health check ?** Kubernetes envoie des requêtes sur `/health`
> (liveness + readiness probes) pour savoir si le pod est vivant.
> Si le pod répond 200 → ok. Sinon → K8s le redémarre automatiquement.

**3.3 — src/routes/orders.js**

```bash
cat > app/src/routes/orders.js << 'EOF'
const express = require('express');
const router = express.Router();

const orders = [
  { id: 'CMD-001', merchant: 'Boutique Paris', amount: 1250.00, status: 'delivered', items: 3 },
  { id: 'CMD-002', merchant: 'Shop Lyon', amount: 890.50, status: 'processing', items: 1 },
  { id: 'CMD-003', merchant: 'Store Bordeaux', amount: 3400.00, status: 'pending', items: 7 },
  { id: 'CMD-004', merchant: 'Boutique Paris', amount: 560.00, status: 'delivered', items: 2 },
  { id: 'CMD-005', merchant: 'E-shop Nantes', amount: 2100.75, status: 'processing', items: 4 }
];

router.get('/', (req, res) => {
  res.json({ total: orders.length, orders });
});

router.get('/stats/summary', (req, res) => {
  const totalRevenue = orders.reduce((sum, o) => sum + o.amount, 0);
  const byStatus = orders.reduce((acc, o) => {
    acc[o.status] = (acc[o.status] || 0) + 1;
    return acc;
  }, {});
  res.json({
    totalOrders: orders.length,
    totalRevenue: totalRevenue.toFixed(2),
    byStatus,
    merchants: [...new Set(orders.map(o => o.merchant))].length
  });
});

router.get('/:id', (req, res) => {
  const order = orders.find(o => o.id === req.params.id);
  if (!order) return res.status(404).json({ error: 'Commande non trouvée' });
  res.json(order);
});

module.exports = router;
EOF
```

**3.4 — src/index.js**

```bash
cat > app/src/index.js << 'EOF'
const express = require('express');
const client = require('prom-client');
const { healthCheck } = require('./middleware/health');
const ordersRouter = require('./routes/orders');

const app = express();
const PORT = process.env.PORT || 3000;

const register = new client.Registry();
client.collectDefaultMetrics({ register });

const httpRequestDuration = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Durée des requêtes HTTP en secondes',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [0.1, 0.3, 0.5, 1, 2, 5]
});
register.registerMetric(httpRequestDuration);

app.use((req, res, next) => {
  const end = httpRequestDuration.startTimer();
  res.on('finish', () => {
    end({ method: req.method, route: req.path, status_code: res.statusCode });
  });
  next();
});

app.use(express.json());

app.get('/health', healthCheck);
app.get('/version', (req, res) => {
  res.json({
    name: 'nexaretail-api',
    version: process.env.APP_VERSION || '1.0.0',
    environment: process.env.NODE_ENV || 'development',
    buildDate: process.env.BUILD_DATE || 'local'
  });
});
app.use('/api/orders', ordersRouter);

app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

app.listen(PORT, () => {
  console.log(`NexaRetail API démarrée sur le port ${PORT}`);
  console.log(`Health : http://localhost:${PORT}/health`);
  console.log(`Métriques : http://localhost:${PORT}/metrics`);
});
EOF
```

---

## 🐳 Étape 4 — Créer le Dockerfile multi-stage

```bash
cat > app/Dockerfile << 'EOF'
# ─── Stage 1 : Build ───────────────────────────────────────────
FROM node:20-alpine AS builder

WORKDIR /app

COPY package.json ./
RUN npm install --omit=dev

# ─── Stage 2 : Runtime ─────────────────────────────────────────
FROM node:20-alpine AS runtime

# Sécurité : ne pas tourner en root
RUN addgroup -S nexaretail && adduser -S nexaretail -G nexaretail

WORKDIR /app

COPY --from=builder /app/node_modules ./node_modules
COPY src/ ./src/
COPY package.json ./

RUN chown -R nexaretail:nexaretail /app

USER nexaretail

ENV NODE_ENV=production
ENV PORT=3000

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s \
  CMD wget -qO- http://localhost:3000/health || exit 1

CMD ["node", "src/index.js"]
EOF
```

> **Pourquoi multi-stage ?** Le stage `builder` installe les dépendances,
> le stage `runtime` ne garde que le strict nécessaire.
> Résultat : image ~120MB au lieu de ~400MB, moins de surface d'attaque pour Trivy (M5).
> Tourner en utilisateur non-root est une exigence du CIS Kubernetes Benchmark.

---

## 📄 Étape 5 — Créer le .dockerignore

```bash
cat > app/.dockerignore << 'EOF'
node_modules
.npm
*.log
.env
.git
README.md
EOF
```

---

## 🔨 Étape 6 — Builder l'image Docker

```bash
cd app
docker build -t nexaretail-api:1.0.0 .
```

Résultat attendu :
```
Successfully built b80bcdd25daf
Successfully tagged nexaretail-api:1.0.0
```

> ⏳ Premier build : 1-2 minutes (télécharge node:20-alpine).
> Les builds suivants seront quasi-instantanés grâce au cache Docker.

Vérifier que l'image est bien créée :

```bash
docker images | grep nexaretail-api
# nexaretail-api   1.0.0   b80bcdd25daf   ...   ~120MB
```

---

## 🧪 Étape 7 — Tester l'image en local

```bash
docker run -d --name nexaretail-test -p 3000:3000 nexaretail-api:1.0.0

# Attendre 2 secondes que le container démarre
sleep 2

curl http://localhost:3000/health
# {"status":"healthy","timestamp":"...","uptime":2,"hostname":"...","version":"1.0.0"}

curl http://localhost:3000/version
# {"name":"nexaretail-api","version":"1.0.0","environment":"production","buildDate":"local"}

curl http://localhost:3000/api/orders
# {"total":5,"orders":[...]}

curl http://localhost:3000/api/orders/stats/summary
# {"totalOrders":5,"totalRevenue":"8201.25","byStatus":{"delivered":2,"processing":2,"pending":1},"merchants":4}
```

Arrêter et supprimer le container de test :

```bash
docker stop nexaretail-test && docker rm nexaretail-test
```

---

## ☸️ Étape 8 — Charger l'image dans kind

```bash
cd /mnt/c/Users/<ton-user>/nexaretail-devops-platform

kind load docker-image nexaretail-api:1.0.0 --name nexaretail-aks
```

Résultat attendu :
```
Image: "nexaretail-api:1.0.0" with ID "sha256:b80b..." not yet present on node
"nexaretail-aks-control-plane", loading...
```

> **Pourquoi cette étape ?** kind crée un cluster Kubernetes dans Docker.
> Les images buildées localement ne sont pas automatiquement disponibles
> dans ce cluster. `kind load` les injecte directement dans le nœud.

---

## 🔧 Étape 9 — Mettre à jour le Helm Chart

Modifier `values.yaml` pour pointer vers l'image locale (et non l'ACR Azure) :

```bash
cat > helm/nexaretail-api/values.yaml << 'EOF'
replicaCount: 2

image:
  repository: nexaretail-api
  pullPolicy: IfNotPresent
  tag: "1.0.0"

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

> `pullPolicy: IfNotPresent` → Kubernetes utilise l'image déjà présente
> dans le nœud kind sans tenter de la télécharger depuis un registry externe.

---

## 📤 Étape 10 — Commit et push sur GitHub

ArgoCD surveille le repo en permanence. Dès qu'on push, il détecte le
changement dans `values.yaml` et redéploie automatiquement les pods.

```bash
git add app/ helm/nexaretail-api/values.yaml
git commit -m "feat(M4): App Node.js conteneurisée + Dockerfile multi-stage

- package.json : Express + prom-client
- src/index.js : serveur Express port 3000 + métriques Prometheus
- src/routes/orders.js : CRUD commandes B2B (5 commandes simulées)
- src/middleware/health.js : health check pour K8s liveness probe
- Dockerfile multi-stage (builder + runtime node:20-alpine)
- Utilisateur non-root nexaretail (sécurité container)
- values.yaml : image nexaretail-api:1.0.0 (kind local)"

git push origin main
```

> GitHub demande un token PAT (`ghp_...`) comme mot de passe.

---

## ✅ Étape 11 — Vérifier le déploiement

Attendre ~1 minute puis vérifier :

```bash
# Les pods doivent être Running (plus d'ImagePullBackOff)
kubectl get pods -n nexaretail-prod
# NAME                              READY   STATUS    RESTARTS   AGE
# nexaretail-api-xxx-xxx            1/1     Running   0          ...
# nexaretail-api-xxx-xxx            1/1     Running   0          ...

# ArgoCD doit être Synced + Healthy
kubectl get applications -n argocd
# NAME             SYNC STATUS   HEALTH STATUS
# nexaretail-api   Synced        Healthy
```

Tester l'API depuis l'intérieur du cluster :

```bash
kubectl port-forward -n nexaretail-prod deployment/nexaretail-api 3000:3000 &
sleep 3
curl http://localhost:3000/health
curl http://localhost:3000/api/orders/stats/summary
kill %1
```

> **Astuce :** Le champ `hostname` dans la réponse `/health` affiche le nom
> du pod Kubernetes qui a répondu — preuve que la requête traverse bien le cluster.

---

## ✅ Résultat attendu

```
docker build → Successfully built                    ✅
npm audit    → found 0 vulnerabilities               ✅
docker run   → /health répond {"status":"healthy"}   ✅
kind load    → Image chargée dans le cluster         ✅
kubectl get pods -n nexaretail-prod → 2/2 Running    ✅
kubectl get applications -n argocd  → Synced Healthy ✅
```

---

## 🐛 Erreurs fréquentes

### `curl: Failed to connect` avec port-forward en arrière-plan
**Cause :** Le `&` démarre le port-forward en arrière-plan mais curl s'exécute
immédiatement avant que le tunnel soit établi.
**Fix :** Ajouter `sleep 3` entre le port-forward et le curl :
```bash
kubectl port-forward -n nexaretail-prod deployment/nexaretail-api 3000:3000 &
sleep 3
curl http://localhost:3000/health
kill %1
```

### Pods toujours en `ImagePullBackOff` après le push
**Cause :** Le `values.yaml` pointe encore vers `nexaretailprodacr.azurecr.io`.
**Fix :** Vérifier que `image.repository: nexaretail-api` (sans le préfixe ACR)
et `pullPolicy: IfNotPresent` sont bien dans `helm/nexaretail-api/values.yaml`.

### `image not found` au démarrage du container
**Cause :** L'image a été buildée mais pas chargée dans kind.
**Fix :** Relancer `kind load docker-image nexaretail-api:1.0.0 --name nexaretail-aks`.

### `DEPRECATED: The legacy builder`
**Cause :** Docker utilise l'ancien builder au lieu de BuildKit.
**Fix :** Message d'avertissement uniquement, sans impact sur le build.
Pour le supprimer : `export DOCKER_BUILDKIT=1` avant `docker build`.
