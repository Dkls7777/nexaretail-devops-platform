# Guide de Reproduction — Phase 8 (HashiCorp Vault)

> Ce guide permet a n'importe qui de reproduire exactement la Phase 8
> du projet NexaRetail DevOps Platform, etape par etape.

---

## Prerequis

- Avoir complete la Phase 7 (Prometheus + Grafana fonctionnel)
- WSL Ubuntu avec Helm v3.21.0 et kubectl v1.36.1 installes
- Cluster kind `nexaretail-aks` fonctionnel avec le namespace `vault`
- Repo GitHub existant : github.com/Dkls7777/nexaretail-devops-platform

---

## Etape 1 — Verifier le cluster

Ouvrir le terminal WSL Ubuntu :

```bash
sudo service docker start
sudo chmod 666 /var/run/docker.sock
kubectl get nodes --context kind-nexaretail-aks
```

Verifier que le namespace `vault` existe :

```bash
kubectl get namespaces | grep vault
# vault   Active   ...
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

## Etape 2 — Installer Vault via Helm

```bash
helm repo update

helm install vault hashicorp/vault \
  --namespace vault \
  --set server.ha.enabled=false \
  --set server.dataStorage.size=1Gi \
  --set ui.enabled=true \
  --set ui.serviceType=NodePort \
  --wait
```

Verifier l'etat des pods (vault-0 sera en 0/1 — c'est normal) :

```bash
kubectl get pods -n vault
# vault-0                                0/1   Running   0   32s   <- sealed, normal
# vault-agent-injector-xxx               1/1   Running   0   32s
```

---

## Etape 3 — Initialiser Vault

Cette operation ne se fait qu'une seule fois. Les cles generees doivent
etre conservees en lieu sur — sans elles, Vault est inaccessible definitivement.

```bash
kubectl exec -n vault vault-0 -- vault operator init \
  -key-shares=5 \
  -key-threshold=3
```

La commande affiche 5 `Unseal Key` et 1 `Initial Root Token`.
Les noter immediatement dans un endroit securise.

En production : stocker les cles dans Azure Key Vault ou les distribuer
a 5 personnes differentes (ceremonie de cles SOC 2).

---

## Etape 4 — Deverrouiller Vault (Unseal)

Fournir 3 cles sur 5 (remplacer par les cles obtenues a l'etape 3) :

```bash
kubectl exec -n vault vault-0 -- vault operator unseal <UNSEAL_KEY_1>
kubectl exec -n vault vault-0 -- vault operator unseal <UNSEAL_KEY_2>
kubectl exec -n vault vault-0 -- vault operator unseal <UNSEAL_KEY_3>
```

Apres la 3eme cle, le resultat doit afficher `Sealed: false`.

Verifier que vault-0 est passe a 1/1 :

```bash
kubectl get pods -n vault
# vault-0   1/1   Running   0   ...
```

---

## Etape 5 — Configurer Vault

Se connecter avec le root token, activer KV v2 et stocker les secrets :

```bash
# Connexion
kubectl exec -n vault vault-0 -- vault login <ROOT_TOKEN>

# Activer le moteur KV v2
kubectl exec -n vault vault-0 -- vault secrets enable -path=nexaretail kv-v2

# Stocker les secrets applicatifs
kubectl exec -n vault vault-0 -- vault kv put nexaretail/api \
  db_host="postgres.nexaretail-prod.svc.cluster.local" \
  db_name="nexaretail_prod" \
  db_user="nexaretail_app" \
  db_password="S3cur3P@ssw0rd!" \
  jwt_secret="nexaretail-jwt-secret-2026" \
  api_key="nxa-prod-api-key-xyz789"
```

---

## Etape 6 — Configurer l'authentification Kubernetes

```bash
# Activer l'auth Kubernetes
kubectl exec -n vault vault-0 -- vault auth enable kubernetes

# Configurer la confiance envers le cluster
kubectl exec -n vault vault-0 -- sh -c '
vault write auth/kubernetes/config \
  kubernetes_host="https://kubernetes.default.svc.cluster.local:443"
'

# Creer la policy lecture seule
# Important : utiliser sh -c avec pipe, le heredoc <<EOF ne fonctionne pas dans kubectl exec
kubectl exec -n vault vault-0 -- sh -c \
  'echo "path \"nexaretail/data/api\" { capabilities = [\"read\"] }" | vault policy write nexaretail-api -'

# Creer le role Kubernetes
kubectl exec -n vault vault-0 -- vault write auth/kubernetes/role/nexaretail-api \
  bound_service_account_names="argocd-deployer" \
  bound_service_account_namespaces="nexaretail-prod" \
  policies="nexaretail-api" \
  ttl="1h"
```

---

## Etape 7 — Verifier la configuration

```bash
# Verifier la policy
kubectl exec -n vault vault-0 -- vault policy read nexaretail-api

# Verifier le role
kubectl exec -n vault vault-0 -- vault read auth/kubernetes/role/nexaretail-api

# Verifier les secrets
kubectl exec -n vault vault-0 -- vault kv get nexaretail/api
```

---

## Etape 8 — Creer les fichiers de configuration

```bash
cd /mnt/c/Users/dossa/nexaretail-devops-platform
mkdir -p vault

cat > vault/vault-auth-config.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: vault-config-doc
  namespace: vault
  labels:
    project: nexaretail
    component: vault
data:
  kubernetes_host: "https://kubernetes.default.svc.cluster.local:443"
  kv_path: "nexaretail/"
  kv_version: "v2"
  role: "nexaretail-api"
  bound_service_account: "argocd-deployer"
  bound_namespace: "nexaretail-prod"
  token_ttl: "1h"
EOF

cat > vault/vault-policy-nexaretail.hcl << 'EOF'
path "nexaretail/data/api" {
  capabilities = ["read"]
}
EOF
```

---

## Etape 9 — Commit et push sur GitHub

```bash
git add vault/
git commit -m "feat(M8): HashiCorp Vault - secrets management

- Vault 1.21.2 installe via Helm (namespace vault)
- Initialise avec 5 unseal keys, threshold 3
- Moteur KV v2 active sur nexaretail/
- 6 secrets stockes : db_host, db_name, db_user, db_password, jwt_secret, api_key
- Auth Kubernetes activee : ServiceAccount argocd-deployer / nexaretail-prod
- Policy nexaretail-api : read-only sur nexaretail/data/api
- Role Kubernetes : TTL 1h, principe du moindre privilege"

git push origin main
```

---

## Resultat attendu

```
kubectl get pods -n vault
-> vault-0 : 1/1 Running                    OK
-> vault-agent-injector : 1/1 Running        OK

vault kv get nexaretail/api
-> 6 secrets affiches                        OK

vault policy read nexaretail-api
-> path nexaretail/data/api read             OK

vault read auth/kubernetes/role/nexaretail-api
-> TTL 1h, SA argocd-deployer               OK

git push origin main
-> 2 fichiers commites                       OK
```

---

## Erreurs frequentes

### vault-0 reste en 0/1 apres installation
**Cause :** Vault demarre toujours en mode sealed. Comportement attendu.
**Fix :** Lancer l'initialisation puis l'unseal avec 3 cles.

### Vault repasse en sealed apres un restart du pod
**Cause :** Vault se re-scelle automatiquement a chaque redemerrage.
**Fix :** Relancer les 3 commandes vault operator unseal avec les memes cles.
En production, configurer l'Auto-Unseal via Azure Key Vault.

### Heredoc <<EOF echoue dans kubectl exec
**Cause :** kubectl exec ne transmet pas les heredocs multi-lignes correctement.
**Fix :** Utiliser sh -c avec echo et pipe :
```bash
kubectl exec -n vault vault-0 -- sh -c \
  'echo "path \"nexaretail/data/api\" { capabilities = [\"read\"] }" | vault policy write nexaretail-api -'
```

### WARNING audience not configured sur le role
**Cause :** Message informatif de Vault recommandant de configurer une audience JWT.
**Fix :** Sans impact pour notre cas d'usage. Ignorer le warning.
