# Guide de Reproduction — Phase 2 (Ansible / Kubernetes)

> Ce guide permet à n'importe qui de reproduire exactement la Phase 2
> du projet NexaRetail DevOps Platform, étape par étape.

---

##  Prérequis

- Windows 10/11 avec droits administrateur
- Git installé
- Compte GitHub
- Avoir complété la Phase 1 (repo GitHub existant)

---

##  Étape 1 — Installer WSL (Windows Subsystem for Linux)

Dans PowerShell :

```powershell
wsl --install -d Ubuntu
```

> Ubuntu se télécharge (~500MB). À l'ouverture, créer un username et mot de passe Linux.
> Le mot de passe ne s'affiche pas en tapant, c'est normal.

Vérification :
```powershell
wsl --version
# WSL version: 2.7.3.0
```

> **Pourquoi WSL ?** Ansible ne fonctionne pas nativement sur Windows.
> WSL crée un vrai Linux à l'intérieur de Windows sans dual boot.

---

##  Étape 2 — Installer Ansible dans WSL

Ouvrir le terminal WSL (taper `wsl` dans PowerShell ou chercher "Ubuntu" dans le menu démarrer) :

```bash
sudo apt update && sudo apt upgrade -y && \
sudo apt install -y python3 python3-pip software-properties-common && \
sudo add-apt-repository --yes --update ppa:ansible/ansible && \
sudo apt install -y ansible
```

> Note : le PPA Ansible peut retourner une erreur 404 sur Ubuntu récent.
> Ansible s'installe quand même depuis les dépôts Ubuntu officiels. C'est normal.

Vérification :
```bash
ansible --version
# ansible [core 2.20.1]
```

---

##  Étape 3 — Installer kubectl + Azure CLI

```bash
# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl

# Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
```

Vérification :
```bash
kubectl version --client && az --version | head -3
# Client Version: v1.36.1
# azure-cli 2.86.0
```

---

##  Étape 4 — Installer Docker + kind

> **Pourquoi kind et pas AKS ?**
> La subscription Azure gratuite bloque les VMs standard nécessaires à AKS.
> kind (Kubernetes IN Docker) crée un vrai cluster Kubernetes localement.
> Comportement identique à AKS pour tous les besoins DevSecOps.

```bash
# Docker
sudo apt install -y docker.io util-linux-extra
sudo usermod -aG docker $USER
sudo service docker start
sudo chmod 666 /var/run/docker.sock

# kind
cd ~
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.27.0/kind-linux-amd64
chmod 700 kind
sudo install -o root -g root -m 0755 kind /usr/local/bin/kind
rm kind
```

Vérification :
```bash
docker --version   # Docker version 29.1.3
kind --version     # kind version 0.27.0
```

---

##  Étape 5 — Créer le cluster Kubernetes

```bash
sudo service docker start
sudo chmod 666 /var/run/docker.sock

kind create cluster \
  --name nexaretail-aks \
  --wait 120s
```

Vérification :
```bash
kubectl get nodes
# NAME                           STATUS   ROLES           AGE   VERSION
# nexaretail-aks-control-plane   Ready    control-plane   67s   v1.32.2
```

---

##  Étape 6 — Installer Helm

> Important : installer Helm depuis le home Linux (`~/`) et non depuis /mnt/c.
> Le système de fichiers Windows (NTFS) ne supporte pas les permissions Linux (chmod).

```bash
cd ~
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
sudo ./get_helm.sh
rm get_helm.sh
```

Vérification :
```bash
helm version
# version.BuildInfo{Version:"v3.21.0", ...}
```

---

##  Étape 7 — Créer la structure Ansible

Se placer dans le repo :
```bash
cd /mnt/c/Users/<ton-user>/nexaretail-devops-platform
```

Créer les dossiers :
```bash
mkdir -p ansible/{inventory,group_vars,roles/{namespaces,rbac,helm-repos}/tasks,playbooks}
```

---

##  Étape 8 — Créer les fichiers Ansible

### 8.1 — Configuration (`ansible/ansible.cfg`)

```bash
cat > ansible/ansible.cfg << 'EOF'
[defaults]
roles_path = ./roles
inventory = ./inventory/hosts.yml
host_key_checking = False
EOF
```

### 8.2 — Inventaire (`ansible/inventory/hosts.yml`)

```bash
cat > ansible/inventory/hosts.yml << 'EOF'
---
all:
  children:
    kubernetes:
      hosts:
        nexaretail-cluster:
          ansible_connection: local
          ansible_python_interpreter: /usr/bin/python3
          kubeconfig: "{{ lookup('env', 'HOME') }}/.kube/config"
          kube_context: "kind-nexaretail-aks"
EOF
```

### 8.3 — Variables globales (`ansible/group_vars/all.yml`)

```bash
cat > ansible/group_vars/all.yml << 'EOF'
---
kube_context: "kind-nexaretail-aks"
kubeconfig: "{{ lookup('env', 'HOME') }}/.kube/config"

namespaces:
  - name: nexaretail-prod
    labels:
      env: production
      team: backend
  - name: nexaretail-staging
    labels:
      env: staging
      team: backend
  - name: monitoring
    labels:
      env: production
      team: ops
  - name: argocd
    labels:
      env: production
      team: platform
  - name: vault
    labels:
      env: production
      team: security
  - name: security
    labels:
      env: production
      team: security

helm_repos:
  - name: prometheus-community
    url: https://prometheus-community.github.io/helm-charts
  - name: argo
    url: https://argoproj.github.io/argo-helm
  - name: hashicorp
    url: https://helm.releases.hashicorp.com
  - name: falcosecurity
    url: https://falcosecurity.github.io/charts
EOF
```

### 8.4 — Role namespaces (`ansible/roles/namespaces/tasks/main.yml`)

```bash
cat > ansible/roles/namespaces/tasks/main.yml << 'EOF'
---
- name: Créer les namespaces NexaRetail
  kubernetes.core.k8s:
    kubeconfig: "{{ kubeconfig }}"
    context: "{{ kube_context }}"
    state: present
    definition:
      apiVersion: v1
      kind: Namespace
      metadata:
        name: "{{ item.name }}"
        labels: "{{ item.labels }}"
  loop: "{{ namespaces }}"

- name: Vérifier les namespaces créés
  kubernetes.core.k8s_info:
    kubeconfig: "{{ kubeconfig }}"
    context: "{{ kube_context }}"
    kind: Namespace
  register: ns_list

- name: Afficher les namespaces
  debug:
    msg: "Namespace {{ item.metadata.name }} — {{ item.status.phase }}"
  loop: "{{ ns_list.resources }}"
  when: item.metadata.name in namespaces | map(attribute='name') | list
EOF
```

### 8.5 — Role RBAC (`ansible/roles/rbac/tasks/main.yml`)

```bash
cat > ansible/roles/rbac/tasks/main.yml << 'EOF'
---
- name: Créer le ClusterRole DevOps NexaRetail
  kubernetes.core.k8s:
    kubeconfig: "{{ kubeconfig }}"
    context: "{{ kube_context }}"
    state: present
    definition:
      apiVersion: rbac.authorization.k8s.io/v1
      kind: ClusterRole
      metadata:
        name: nexaretail-devops
      rules:
        - apiGroups: ["", "apps", "batch"]
          resources: ["pods", "deployments", "services", "configmaps", "jobs"]
          verbs: ["get", "list", "watch", "create", "update", "patch"]
        - apiGroups: ["monitoring.coreos.com"]
          resources: ["prometheusrules", "servicemonitors"]
          verbs: ["get", "list", "watch", "create", "update", "patch"]

- name: Créer le ClusterRole lecture seule
  kubernetes.core.k8s:
    kubeconfig: "{{ kubeconfig }}"
    context: "{{ kube_context }}"
    state: present
    definition:
      apiVersion: rbac.authorization.k8s.io/v1
      kind: ClusterRole
      metadata:
        name: nexaretail-readonly
      rules:
        - apiGroups: ["", "apps"]
          resources: ["pods", "deployments", "services", "configmaps"]
          verbs: ["get", "list", "watch"]

- name: Créer le ServiceAccount ArgoCD
  kubernetes.core.k8s:
    kubeconfig: "{{ kubeconfig }}"
    context: "{{ kube_context }}"
    state: present
    definition:
      apiVersion: v1
      kind: ServiceAccount
      metadata:
        name: argocd-deployer
        namespace: nexaretail-prod
EOF
```

### 8.6 — Role helm-repos (`ansible/roles/helm-repos/tasks/main.yml`)

```bash
cat > ansible/roles/helm-repos/tasks/main.yml << 'EOF'
---
- name: Installer Helm si absent
  shell: |
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
  args:
    creates: /usr/local/bin/helm

- name: Ajouter les repositories Helm NexaRetail
  kubernetes.core.helm_repository:
    name: "{{ item.name }}"
    repo_url: "{{ item.url }}"
    state: present
  loop: "{{ helm_repos }}"

- name: Mettre à jour les repositories Helm
  command: helm repo update
  changed_when: true

- name: Lister les repositories Helm
  command: helm repo list
  register: helm_repo_list
  changed_when: false

- name: Afficher les repositories
  debug:
    msg: "{{ helm_repo_list.stdout_lines }}"
EOF
```

### 8.7 — Playbook principal (`ansible/playbooks/site.yml`)

```bash
cat > ansible/playbooks/site.yml << 'EOF'
---
- name: NexaRetail — Configuration du cluster Kubernetes
  hosts: nexaretail-cluster
  gather_facts: false

  pre_tasks:
    - name: Vérifier la connexion au cluster
      command: kubectl cluster-info --context kind-nexaretail-aks
      changed_when: false

    - name: Afficher le contexte actif
      command: kubectl config current-context
      register: current_context
      changed_when: false

    - name: Confirmer le cluster cible
      debug:
        msg: " Configuration du cluster : {{ current_context.stdout }}"

  roles:
    - namespaces
    - rbac
    - helm-repos

  post_tasks:
    - name: Résumé — Namespaces créés
      command: kubectl get namespaces --context kind-nexaretail-aks
      register: ns_summary
      changed_when: false

    - name: Afficher le résumé
      debug:
        msg: "{{ ns_summary.stdout_lines }}"
EOF
```

### 8.8 — Requirements Galaxy (`ansible/requirements.yml`)

```bash
cat > ansible/requirements.yml << 'EOF'
---
collections:
  - name: kubernetes.core
    version: ">=2.4.0"
  - name: community.general
    version: ">=7.0.0"
EOF
```

---

##  Étape 9 — Installer les dépendances et lancer le playbook

```bash
# Librairie Python pour Kubernetes
pip install kubernetes --break-system-packages

# Collections Ansible Galaxy
ansible-galaxy collection install -r ansible/requirements.yml

# Lancer le playbook depuis le dossier ansible/
cd ansible

ANSIBLE_ROLES_PATH=/mnt/c/Users/<ton-user>/nexaretail-devops-platform/ansible/roles \
ansible-playbook playbooks/site.yml \
  -i inventory/hosts.yml \
  --extra-vars "@group_vars/all.yml"
```

> **Pourquoi ces options ?**
> - `ANSIBLE_ROLES_PATH` : le dossier Windows est ignoré comme source de config
>   par Ansible (world-writable). On force le chemin des rôles.
> - `--extra-vars "@group_vars/all.yml"` : les variables group_vars ne sont pas
>   chargées automatiquement pour la même raison.

---

##  Résultat attendu

```
PLAY RECAP
nexaretail-cluster : ok=16  changed=2  unreachable=0  failed=0
```

Vérification finale :
```bash
kubectl get namespaces
# NAME                 STATUS   AGE
# argocd               Active
# monitoring           Active
# nexaretail-prod      Active
# nexaretail-staging   Active
# security             Active
# vault                Active

helm repo list
# NAME                  URL
# prometheus-community  https://prometheus-community.github.io/helm-charts
# argo                  https://argoproj.github.io/argo-helm
# hashicorp             https://helm.releases.hashicorp.com
# falcosecurity         https://falcosecurity.github.io/charts
```

---

##  Étape 10 — Commit et push sur GitHub

```bash
cd /mnt/c/Users/<ton-user>/nexaretail-devops-platform

# Configurer Git dans WSL (à faire une seule fois)
git config --global --add safe.directory /mnt/c/Users/<ton-user>/nexaretail-devops-platform
git config --global user.email "ton-email@gmail.com"
git config --global user.name "Ton Nom"

git add ansible/
git commit -m "feat(M2): Ansible configuration - namespaces, RBAC, helm repos

- 6 namespaces créés (prod, staging, monitoring, argocd, vault, security)
- ClusterRoles DevOps et ReadOnly configurés
- ServiceAccount ArgoCD déployé
- 4 repos Helm ajoutés (prometheus, argo, hashicorp, falco)
- Playbook site.yml validé : ok=16 failed=0"

git push origin main
```

> **Pour le push, GitHub demande un token (pas le mot de passe) :**
> 1. Aller sur https://github.com/settings/tokens/new
> 2. Note : `nexaretail-wsl` — Expiration : 90 days — Scope : ✅ `repo`
> 3. Cliquer "Generate token" et copier le token `ghp_...`
> 4. Coller le token dans le terminal quand "Password" est demandé
> ⚠️ Ne jamais partager ce token publiquement

---

##  Erreurs fréquentes

### `ansible` non reconnu
**Cause :** Ansible non installé ou exécuté depuis PowerShell.
**Fix :** Toujours lancer Ansible depuis WSL Ubuntu, pas PowerShell.

### `ResourceGroupNotFound` ou `BadRequest` AKS
**Cause :** Quota VM bloqué sur subscription Azure gratuite.
**Fix :** Utiliser kind à la place d'AKS.

### `chmod: Operation not permitted`
**Cause :** Tentative de chmod sur un fichier dans /mnt/c (Windows NTFS).
**Fix :** Toujours exécuter les scripts depuis le home Linux `~/`.

### `ansible.cfg` ignoré (world writable directory)
**Cause :** Ansible refuse les fichiers de config dans des dossiers world-writable (NTFS).
**Fix :** Utiliser `ANSIBLE_ROLES_PATH` en variable d'environnement.

### `'namespaces' is undefined`
**Cause :** group_vars/all.yml non chargé automatiquement.
**Fix :** Ajouter `--extra-vars "@group_vars/all.yml"` à la commande ansible-playbook.

### `sudo: A terminal is required to authenticate` (Helm)
**Cause :** Le script Helm utilise sudo mais Ansible ne peut pas ouvrir de terminal interactif.
**Fix :** Installer Helm manuellement avant de lancer le playbook (voir Étape 6).

### Token GitHub demandé au lieu du mot de passe
**Cause :** GitHub a supprimé l'authentification par mot de passe en 2021.
**Fix :** Créer un Personal Access Token sur https://github.com/settings/tokens/new (scope : repo).
