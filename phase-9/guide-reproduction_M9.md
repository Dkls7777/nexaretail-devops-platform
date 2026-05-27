# Guide de Reproduction — Phase 9 (Falco Runtime Security)

> Ce guide permet a n'importe qui de reproduire exactement la Phase 9
> du projet NexaRetail DevOps Platform, etape par etape.

---

## Prerequis

- Avoir complete la Phase 8 (HashiCorp Vault fonctionnel)
- WSL Ubuntu avec Helm v3.21.0 et kubectl v1.36.1 installes
- Cluster kind `nexaretail-aks` fonctionnel avec le namespace `security`
- Repo GitHub existant : github.com/Dkls7777/nexaretail-devops-platform

---

## Etape 1 — Verifier le cluster

Ouvrir le terminal WSL Ubuntu :

```bash
sudo service docker start
sudo chmod 666 /var/run/docker.sock
kubectl get nodes --context kind-nexaretail-aks
```

Verifier que le namespace `security` existe :

```bash
kubectl get namespace security
# NAME       STATUS   AGE
# security   Active   ...
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

## Etape 2 — Mettre a jour les repos Helm

```bash
helm repo update
```

Verifier que le repo falcosecurity est present :

```bash
helm repo list | grep falco
# falcosecurity   https://falcosecurity.github.io/charts
```

---

## Etape 3 — Installer Falco via Helm

Le driver `modern_ebpf` est le seul compatible avec kind sous WSL.
Il ne necessite pas de module kernel et fonctionne en mode userspace.

```bash
helm install falco falcosecurity/falco \
  --namespace security \
  --set driver.kind=modern_ebpf \
  --set tty=true \
  --wait --timeout 5m
```

Le pod passe par un etat `Init:0/1` pendant le chargement du driver (normal).
Attendre 30-60 secondes puis verifier :

```bash
kubectl get pods -n security
# NAME          READY   STATUS    RESTARTS   AGE
# falco-xxxxx   2/2     Running   0          1m
```

---

## Etape 4 — Creer les regles custom NexaRetail

```bash
cd /mnt/c/Users/dossa/nexaretail-devops-platform
mkdir -p falco

cat > falco/nexaretail-rules.yaml << 'EOF'
- rule: NexaRetail Shell in Production Container
  desc: Detection d'un shell interactif ouvert dans un pod de production NexaRetail
  condition: >
    spawned_process and
    container and
    k8s.ns.name = "nexaretail-prod" and
    proc.name in (bash, sh, zsh, ash, dash)
  output: >
    CRITICAL - Shell ouvert dans pod production NexaRetail
    (pod=%k8s.pod.name ns=%k8s.ns.name user=%user.name cmd=%proc.cmdline image=%container.image.repository)
  priority: CRITICAL
  tags: [nexaretail, production, shell, mitre_execution]

- rule: NexaRetail Sensitive File Access
  desc: Detection d'un acces aux fichiers sensibles dans les conteneurs NexaRetail
  condition: >
    open_read and
    container and
    k8s.ns.name startswith "nexaretail" and
    fd.name in (/etc/passwd, /etc/shadow, /etc/sudoers, /root/.ssh/id_rsa)
  output: >
    ERROR - Acces fichier sensible dans NexaRetail
    (pod=%k8s.pod.name ns=%k8s.ns.name file=%fd.name user=%user.name image=%container.image.repository)
  priority: ERROR
  tags: [nexaretail, sensitive-file, mitre_credential_access]

- rule: NexaRetail Unexpected Outbound Connection
  desc: Detection d'une connexion reseau sortante inattendue depuis un pod NexaRetail
  condition: >
    outbound and
    container and
    k8s.ns.name = "nexaretail-prod" and
    not fd.sport in (3000, 443, 80, 5432)
  output: >
    WARNING - Connexion sortante inattendue depuis NexaRetail prod
    (pod=%k8s.pod.name ns=%k8s.ns.name dest=%fd.rip:%fd.rport proto=%fd.l4proto)
  priority: WARNING
  tags: [nexaretail, network, mitre_exfiltration]
EOF
```

---

## Etape 5 — Charger les regles custom dans Falco

Le parametre `customRules` du chart Helm cree automatiquement un ConfigMap
et le monte dans `/etc/falco/rules.d/` — repertoire scanne par Falco
en complement des regles par defaut.

```bash
helm upgrade falco falcosecurity/falco \
  --namespace security \
  --set driver.kind=modern_ebpf \
  --set tty=true \
  --set-file 'customRules.nexaretail_rules\.yaml=falco/nexaretail-rules.yaml' \
  --wait --timeout 5m
```

Redemarrer le DaemonSet pour appliquer la nouvelle configuration :

```bash
kubectl rollout restart daemonset/falco -n security
kubectl rollout status daemonset/falco -n security
# daemon set "falco" successfully rolled out
```

---

## Etape 6 — Verifier que les regles sont chargees

```bash
kubectl logs -n security -l app.kubernetes.io/name=falco -c falco --tail=30 \
  | grep -E "rules|Loading|nexaretail"
```

Resultat attendu :

```
Loading rules from:
   /etc/falco/falco_rules.yaml | schema validation: ok
   /etc/falco/rules.d/nexaretail_rules.yaml | schema validation: ok
```

---

## Etape 7 — Tester la detection en live

Dans un premier terminal, ouvrir un watch sur les logs Falco :

```bash
kubectl logs -n security -l app.kubernetes.io/name=falco -c falco -f \
  | grep -i "nexaretail\|CRITICAL\|ERROR\|WARNING"
```

Dans un second terminal, declencher une alerte en ouvrant un shell dans un pod de prod :

```bash
kubectl exec -it -n nexaretail-prod \
  $(kubectl get pods -n nexaretail-prod -o jsonpath='{.items[0].metadata.name}') \
  -- sh -c "echo test_falco_detection"
```

Dans le premier terminal, une alerte doit apparaitre en moins de 5 secondes
avec le nom du pod, le namespace, la commande executee et l'image du conteneur.

---

## Etape 8 — Creer le values.yaml

```bash
cat > falco/values.yaml << 'EOF'
# Configuration Falco - NexaRetail DevOps Platform
# Deploiement via Helm chart falcosecurity/falco

driver:
  kind: modern_ebpf

tty: true

customRules:
  nexaretail_rules.yaml: |-
    - rule: NexaRetail Shell in Production Container
      desc: Detection d'un shell interactif ouvert dans un pod de production NexaRetail
      condition: >
        spawned_process and
        container and
        k8s.ns.name = "nexaretail-prod" and
        proc.name in (bash, sh, zsh, ash, dash)
      output: >
        CRITICAL - Shell ouvert dans pod production NexaRetail
        (pod=%k8s.pod.name ns=%k8s.ns.name user=%user.name cmd=%proc.cmdline image=%container.image.repository)
      priority: CRITICAL
      tags: [nexaretail, production, shell, mitre_execution]

    - rule: NexaRetail Sensitive File Access
      desc: Detection d'un acces aux fichiers sensibles dans les conteneurs NexaRetail
      condition: >
        open_read and
        container and
        k8s.ns.name startswith "nexaretail" and
        fd.name in (/etc/passwd, /etc/shadow, /etc/sudoers, /root/.ssh/id_rsa)
      output: >
        ERROR - Acces fichier sensible dans NexaRetail
        (pod=%k8s.pod.name ns=%k8s.ns.name file=%fd.name user=%user.name image=%container.image.repository)
      priority: ERROR
      tags: [nexaretail, sensitive-file, mitre_credential_access]

    - rule: NexaRetail Unexpected Outbound Connection
      desc: Detection d'une connexion reseau sortante inattendue depuis un pod NexaRetail
      condition: >
        outbound and
        container and
        k8s.ns.name = "nexaretail-prod" and
        not fd.sport in (3000, 443, 80, 5432)
      output: >
        WARNING - Connexion sortante inattendue depuis NexaRetail prod
        (pod=%k8s.pod.name ns=%k8s.ns.name dest=%fd.rip:%fd.rport proto=%fd.l4proto)
      priority: WARNING
      tags: [nexaretail, network, mitre_exfiltration]
EOF
```

---

## Etape 9 — Commit et push sur GitHub

```bash
git add falco/
git commit -m "feat(M9): Falco runtime security - detection menaces conteneurs

- Falco installe via Helm dans le namespace security (driver modern_ebpf)
- 3 regles custom NexaRetail :
  * NexaRetail Shell in Production Container (CRITICAL)
  * NexaRetail Sensitive File Access (ERROR)
  * NexaRetail Unexpected Outbound Connection (WARNING)
- Test valide : kubectl exec dans nexaretail-prod declenche alerte en < 5s
- Couverture MITRE ATT&CK : T1059 (Execution), T1003 (Credential Access), T1041 (Exfiltration)"

git push origin main
```

---

## Resultat attendu

```
helm install falco
-> STATUS: deployed                                         OK

kubectl get pods -n security
-> falco-xxxxx : 2/2 Running                               OK

kubectl logs falco | grep rules
-> /etc/falco/falco_rules.yaml         schema validation: ok  OK
-> /etc/falco/rules.d/nexaretail_rules.yaml  schema: ok       OK

kubectl exec dans nexaretail-prod
-> Alerte Falco generee en < 5 secondes                    OK

git push origin main
-> 2 fichiers commites                                     OK
```

---

## Erreurs frequentes

### Pod bloque en Init:0/1 au demarrage
**Cause :** Le driver modern_ebpf se charge dans le init container, comportement normal.
**Fix :** Attendre 30-60 secondes. Si ca depasse 2 minutes, verifier les logs du init container :
```bash
kubectl logs -n security <pod-name> -c falco-driver-loader
```

### Regles custom non visibles dans les logs apres helm upgrade
**Cause :** Le DaemonSet ne redemarre pas automatiquement les pods existants apres un upgrade.
**Fix :**
```bash
kubectl rollout restart daemonset/falco -n security
```

### extraVolumeMounts ne charge pas les regles
**Cause :** Falco ne scanne que les chemins definis dans sa configuration interne.
**Fix :** Utiliser le parametre `customRules` du chart Helm — il gere le montage correctement.

### Alerte non visible avec le grep
**Cause :** Le grep filtre sur "nexaretail" mais la regle built-in Falco utilise un format different.
**Fix :** Retirer le filtre pour voir toutes les alertes :
```bash
kubectl logs -n security -l app.kubernetes.io/name=falco -c falco -f
```
