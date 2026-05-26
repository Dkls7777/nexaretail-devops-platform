# Guide de Reproduction — Phase 5 (CI GitHub Actions + Trivy + ACR Azure)

> Ce guide permet à n'importe qui de reproduire exactement la Phase 5
> du projet NexaRetail DevOps Platform, étape par étape.

---

## ⚙️ Prérequis

- Avoir complété la Phase 4 (application Node.js conteneurisée, repo GitHub existant)
- WSL Ubuntu avec Azure CLI installé
- Compte Azure avec l'ACR `nexaretailprodacr` actif
- Compte GitHub avec accès au repo `nexaretail-devops-platform`

---

## ☁️ Étape 1 — Vérifier que l'ACR Azure est actif

Dans WSL :

```bash
az acr show --name nexaretailprodacr --query "provisioningState" -o tsv
# Résultat attendu : Succeeded
```

> Si l'ACR a été supprimé (terraform destroy), le recréer :
> ```bash
> cd /mnt/c/Users/<ton-user>/nexaretail-devops-platform/infrastructure/terraform/environments/prod
> terraform apply -target=azurerm_container_registry.main
> ```

---

## 🔐 Étape 2 — Créer le Service Principal Azure

Le Service Principal est un "compte robot" Azure que GitHub Actions utilise
pour se connecter et pusher des images sur l'ACR, sans utiliser de credentials humains.

**2.1 — Récupérer l'ID de subscription**

```bash
az account show --query id -o tsv
# Exemple : 631eaf73-95bd-4df4-93d6-495d57cf6cee
```

**2.2 — Créer le Service Principal avec rôle AcrPush**

Dans WSL (utiliser `\` pour les retours à la ligne, pas `` ` ``) :

```bash
az ad sp create-for-rbac \
  --name "nexaretail-github-actions" \
  --sdk-auth
```

> ⚠️ **Important :** La commande `--sdk-auth` ne fonctionne pas toujours
> avec `--role` et `--scopes` en une seule commande dans WSL.
> On assigne le rôle séparément à l'étape suivante.

Tu obtiens un JSON avec `appId`, `password`, `tenant`. Note-les.

**2.3 — Assigner le rôle AcrPush au Service Principal**

```bash
az role assignment create \
  --assignee <appId-du-SP> \
  --role AcrPush \
  --scope /subscriptions/<SUBSCRIPTION_ID>/resourceGroups/nexaretail-prod-rg/providers/Microsoft.ContainerRegistry/registries/nexaretailprodacr
```

Résultat attendu : JSON avec `"principalType": "ServicePrincipal"`

**2.4 — Construire le JSON AZURE_CREDENTIALS**

GitHub Actions attend un JSON dans ce format exact :

```json
{
  "clientId": "<appId>",
  "clientSecret": "<password>",
  "subscriptionId": "<SUBSCRIPTION_ID>",
  "tenantId": "<tenant>",
  "activeDirectoryEndpointUrl": "https://login.microsoftonline.com",
  "resourceManagerEndpointUrl": "https://management.azure.com/",
  "activeDirectoryGraphResourceId": "https://graph.windows.net/",
  "sqlManagementEndpointUrl": "https://management.core.windows.net:8443/",
  "galleryEndpointUrl": "https://gallery.azure.com/",
  "managementEndpointUrl": "https://management.core.windows.net/"
}
```

> ⚠️ Ne jamais committer ce JSON sur GitHub. Ne jamais le partager publiquement.

---

## 🔒 Étape 3 — Configurer les secrets GitHub

Dans Chrome, ouvrir :
**`github.com/<ton-user>/nexaretail-devops-platform/settings/secrets/actions`**

Cliquer **"New repository secret"** et créer ces 2 secrets :

**Secret 1 — `AZURE_CREDENTIALS`**

Nom : `AZURE_CREDENTIALS`
Valeur : le JSON complet construit à l'étape 2.4

**Secret 2 — `ACR_LOGIN_SERVER`**

Nom : `ACR_LOGIN_SERVER`
Valeur : `nexaretailprodacr.azurecr.io`

Vérification — la page doit afficher :
```
Repository secrets
├── ACR_LOGIN_SERVER     ✅
└── AZURE_CREDENTIALS    ✅
```

---

## 📁 Étape 4 — Créer le dossier workflows

Dans WSL :

```bash
cd /mnt/c/Users/<ton-user>/nexaretail-devops-platform

mkdir -p .github/workflows
```

---

## 📝 Étape 5 — Créer le fichier ci.yml

```bash
cat > .github/workflows/ci.yml << 'EOF'
name: CI — Build, Scan & Push

on:
  push:
    branches: [main]
    paths:
      - 'app/**'
      - 'helm/**'
      - '.github/workflows/ci.yml'
  pull_request:
    branches: [main]

env:
  IMAGE_NAME: nexaretail-api
  ACR_LOGIN_SERVER: ${{ secrets.ACR_LOGIN_SERVER }}

jobs:
  # ─────────────────────────────────────────────
  # JOB 1 : Qualité & sécurité du code
  # ─────────────────────────────────────────────
  code-quality:
    name: 🔍 Code Quality & npm Audit
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
          cache-dependency-path: app/package.json

      - name: Install dependencies
        working-directory: app
        run: npm install

      - name: npm audit (sécurité dépendances)
        working-directory: app
        run: npm audit --audit-level=high

  # ─────────────────────────────────────────────
  # JOB 2 : Build + Scan Trivy + Push ACR
  # ─────────────────────────────────────────────
  build-scan-push:
    name: 🐳 Build → Trivy Scan → Push ACR
    runs-on: ubuntu-latest
    needs: code-quality

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Login Azure
        uses: azure/login@v2
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}

      - name: Login ACR Azure
        run: az acr login --name nexaretailprodacr

      - name: Build image Docker
        run: |
          docker build \
            --build-arg BUILD_DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ) \
            --build-arg APP_VERSION=1.0.${{ github.run_number }} \
            -t $ACR_LOGIN_SERVER/$IMAGE_NAME:1.0.${{ github.run_number }} \
            -t $ACR_LOGIN_SERVER/$IMAGE_NAME:latest \
            app/

      - name: Scan Trivy — CRITICAL et HIGH bloquants
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ env.ACR_LOGIN_SERVER }}/${{ env.IMAGE_NAME }}:latest
          format: table
          exit-code: '1'
          severity: 'CRITICAL,HIGH'
          ignore-unfixed: true
          skip-dirs: '/usr/local/lib/node_modules/npm,/usr/local/lib/node_modules/corepack,/opt/yarn-v1.22.22'

      - name: Rapport Trivy complet (informatif)
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ env.ACR_LOGIN_SERVER }}/${{ env.IMAGE_NAME }}:latest
          format: sarif
          output: trivy-results.sarif
          severity: 'MEDIUM,LOW'
          skip-dirs: '/usr/local/lib/node_modules/npm,/usr/local/lib/node_modules/corepack,/opt/yarn-v1.22.22'
        continue-on-error: true

      - name: Upload rapport Trivy
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: trivy-security-report
          path: trivy-results.sarif

      - name: Push vers ACR Azure
        if: github.ref == 'refs/heads/main' && github.event_name == 'push'
        run: |
          docker push $ACR_LOGIN_SERVER/$IMAGE_NAME:1.0.${{ github.run_number }}
          docker push $ACR_LOGIN_SERVER/$IMAGE_NAME:latest
          echo "✅ Image pushée : $ACR_LOGIN_SERVER/$IMAGE_NAME:1.0.${{ github.run_number }}"
EOF
```

Vérifier le fichier :

```bash
cat .github/workflows/ci.yml
```

---

## 📤 Étape 6 — Commit et push

> ⚠️ **Important :** Le push de fichiers dans `.github/workflows/` nécessite
> un token GitHub avec le scope `workflow` coché.
> Si ton token actuel est refusé, crée-en un nouveau sur :
> `github.com/settings/tokens/new` → cocher ✅ `repo` ET ✅ `workflow`

```bash
git add .github/
git commit -m "feat(ci): M5 - GitHub Actions CI pipeline

- Job 1 : npm audit securite dependances (bloque si HIGH)
- Job 2 : docker build + trivy scan (bloque si CRITICAL/HIGH)
- Push ACR Azure nexaretailprodacr sur branch main uniquement
- Rapport Trivy SARIF uploade comme artifact"

git push origin main
```

Quand Git demande le mot de passe → coller le token `ghp_...`

---

## 🔍 Étape 7 — Surveiller le pipeline

Ouvrir Chrome : **`github.com/<ton-user>/nexaretail-devops-platform/actions`**

Le pipeline démarre automatiquement. Cliquer sur le run en cours pour voir
les 2 jobs s'exécuter en temps réel.

---

## ✅ Résultat attendu

```
Job 1 — 🔍 Code Quality & npm Audit    →  ✅  ~10s
Job 2 — 🐳 Build → Trivy Scan → Push   →  ✅  ~54s
─────────────────────────────────────────────────────
Status : Success   •   ~1m 11s   •   1 Artifact
```

Vérifier que l'image est bien dans l'ACR Azure :

```bash
az acr repository list --name nexaretailprodacr -o table
# nexaretail-api

az acr repository show-tags --name nexaretailprodacr --repository nexaretail-api -o table
# latest
# 1.0.3  (numéro = run_number GitHub Actions)
```

---

## 🐛 Erreurs fréquentes

### `refusing to allow a PAT to create or update workflow`
**Cause :** Le token GitHub n'a pas le scope `workflow`.
**Fix :** Créer un nouveau PAT sur `github.com/settings/tokens/new`
avec les scopes `repo` ET `workflow` cochés.

### `--name: command not found` (Service Principal)
**Cause :** Utilisation des backticks `` ` `` (syntaxe PowerShell) dans WSL bash.
**Fix :** Remplacer tous les `` ` `` par `\` pour les retours à la ligne dans WSL.

### Trivy bloque sur des vulnérabilités dans `/usr/local/lib/node_modules/npm`
**Cause :** Trivy scanne les modules npm intégrés à Node.js 20 (outils système,
pas le code applicatif). Ces CVEs ne sont pas exploitables à runtime.
**Fix :** Ajouter `skip-dirs` dans la config Trivy :
```yaml
skip-dirs: '/usr/local/lib/node_modules/npm,/usr/local/lib/node_modules/corepack,/opt/yarn-v1.22.22'
```

### `ERROR: cannot find ignorefile '.trivyignore'`
**Cause :** Le paramètre `trivyignores: .trivyignore` référence un fichier
qui n'existe pas dans le repo.
**Fix :** Supprimer la ligne `trivyignores` du `ci.yml` :
```bash
sed -i '/trivyignores: .trivyignore/d' .github/workflows/ci.yml
git add .github/workflows/ci.yml
git commit -m "fix(ci): supprimer reference trivyignore manquant"
git push origin main
```

### `Login Azure` échoue — `ClientSecretCredential authentication failed`
**Cause :** Le JSON dans `AZURE_CREDENTIALS` est mal formaté ou incomplet.
**Fix :** Vérifier que le secret contient bien les 10 champs du JSON
(clientId, clientSecret, subscriptionId, tenantId + 6 URLs Azure).
