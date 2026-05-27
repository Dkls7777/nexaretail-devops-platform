# Guide de Reproduction — Phase 6 (CD Automation GitOps)

> Ce guide permet a n'importe qui de reproduire exactement la Phase 6
> du projet NexaRetail DevOps Platform, etape par etape.

---

## Prerequis

- Avoir complete la Phase 5 (pipeline CI fonctionnel, image pushee sur ACR Azure)
- Repo GitHub existant : github.com/Dkls7777/nexaretail-devops-platform
- Secrets GitHub `AZURE_CREDENTIALS` et `ACR_LOGIN_SERVER` deja configures

---

## Etape 1 — Creer le token GitHub GH_PAT

Le job CD doit committer et pusher dans le repo depuis GitHub Actions.
Il faut un token dedie avec les bons droits.

Ouvrir Chrome et aller sur :

```
https://github.com/settings/tokens/new
```

Configurer le token :

- **Note :** `nexaretail-cd-gitops`
- **Expiration :** 90 days
- **Scopes :** cocher `repo` ET `workflow`

Cliquer "Generate token" et copier le token `ghp_...`.

---

## Etape 2 — Ajouter le secret GH_PAT dans GitHub

Aller sur :

```
https://github.com/Dkls7777/nexaretail-devops-platform/settings/secrets/actions
```

Cliquer "New repository secret" :

- **Nom :** `GH_PAT`
- **Valeur :** le token `ghp_...` copie a l'etape 1

Verification — la page doit afficher 3 secrets :

```
ACR_LOGIN_SERVER      OK
AZURE_CREDENTIALS     OK
GH_PAT                OK
```

---

## Etape 3 — Ajouter le job update-helm dans ci.yml

Ouvrir le terminal WSL Ubuntu :

```bash
cd /mnt/c/Users/dossa/nexaretail-devops-platform
```

Ajouter le job CD a la fin du fichier `ci.yml` existant :

```bash
cat >> .github/workflows/ci.yml << 'EOF'

  # ─────────────────────────────────────────────
  # JOB 3 : Mise a jour automatique du Helm Chart
  # ─────────────────────────────────────────────
  update-helm:
    name: Update Helm values - GitOps
    runs-on: ubuntu-latest
    needs: build-scan-push
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'

    steps:
      - name: Checkout avec token CD
        uses: actions/checkout@v4
        with:
          token: ${{ secrets.GH_PAT }}
          fetch-depth: 0

      - name: Mettre a jour le tag image dans values.yaml
        run: |
          NEW_TAG="1.0.${{ github.run_number }}"
          echo "Nouveau tag : $NEW_TAG"
          sed -i "s|tag: \".*\"|tag: \"${NEW_TAG}\"|g" helm/nexaretail-api/values.yaml
          echo "values.yaml mis a jour :"
          grep "tag:" helm/nexaretail-api/values.yaml

      - name: Configurer Git
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"

      - name: Commit et push du nouveau tag
        run: |
          git add helm/nexaretail-api/values.yaml
          git diff --staged --quiet || git commit -m "chore(cd): bump nexaretail-api image tag to 1.0.${{ github.run_number }}

          - Image: nexaretailprodacr.azurecr.io/nexaretail-api:1.0.${{ github.run_number }}
          - Pipeline run: ${{ github.run_number }}
          - Commit source: ${{ github.sha }}
          [skip ci]"
          git push origin main
          echo "values.yaml pousse — ArgoCD va detecter le changement"
EOF
```

Verifier que le job est bien ajoute :

```bash
tail -50 .github/workflows/ci.yml
```

---

## Etape 4 — Commit et push

```bash
git add .github/workflows/ci.yml
git commit -m "feat(cd): M6 - ajout job update-helm pour CD automatique GitOps

- Job 3 update-helm declenche apres build-scan-push reussi
- sed met a jour le tag image dans helm/nexaretail-api/values.yaml
- commit automatique par github-actions[bot]
- ArgoCD detecte le changement et redeploit en moins de 3 minutes
- [skip ci] pour eviter une boucle infinie de pipelines"

git push origin main
```

GitHub demande un token `ghp_...` comme mot de passe.

---

## Etape 5 — Surveiller le pipeline

Ouvrir Chrome :

```
https://github.com/Dkls7777/nexaretail-devops-platform/actions
```

Les 3 jobs doivent s'enchainer et passer en vert :

```
Job 1 - Code Quality & npm Audit     : ~10s
Job 2 - Build - Trivy Scan - Push    : ~56s
Job 3 - Update Helm values - GitOps  : ~6s
```

---

## Etape 6 — Verifier le resultat

Verifier que `values.yaml` a ete mis a jour automatiquement sur GitHub :

```
https://github.com/Dkls7777/nexaretail-devops-platform/blob/main/helm/nexaretail-api/values.yaml
```

La ligne `tag:` doit afficher le numero du run :

```yaml
image:
  repository: nexaretail-api
  tag: "1.0.5"
```

Verifier le commit automatique dans l'historique Git :

```
https://github.com/Dkls7777/nexaretail-devops-platform/commits/main
```

Un commit signe `github-actions[bot]` doit apparaitre avec le message
`chore(cd): bump nexaretail-api image tag to 1.0.X`.

---

## Resultat attendu

```
Secret GH_PAT configure                     OK
Job 3 ajoute dans ci.yml                    OK
Pipeline 3 jobs en vert                     OK
values.yaml tag mis a jour automatiquement  OK
Commit github-actions[bot] dans Git         OK
```

---

## Erreurs frequentes

### Pipeline ne se declenche pas apres le push

**Cause :** Le filtre `paths` dans ci.yml ne couvre que `app/**`, `helm/**`
et `.github/workflows/ci.yml`. Si aucun de ces fichiers n'a change, le pipeline
ne se declenche pas.

**Fix :** Faire un petit commit sur `app/` pour forcer le declenchement :

```bash
echo "# trigger" >> app/README.md
git add app/README.md
git commit -m "chore: trigger pipeline"
git push origin main
```

### Erreur 403 au push depuis GitHub Actions

**Cause :** Le token `GH_PAT` n'a pas le scope `workflow` ou a expire.

**Fix :** Creer un nouveau token sur `github.com/settings/tokens/new`
avec les scopes `repo` ET `workflow` coches, et mettre a jour le secret `GH_PAT`.

### Boucle infinie de pipelines

**Cause :** Le commit du job 3 declenche un nouveau pipeline qui declenche
un nouveau commit, etc.

**Fix :** Le `[skip ci]` dans le message de commit empeche GitHub Actions
de declencher un nouveau pipeline sur ce commit. Verifier qu'il est bien present.

### `rejected — fetch first` au push local

**Cause :** Le job 3 a committe dans le repo depuis GitHub Actions, creant
une divergence avec le clone local.

**Fix :**

```bash
git pull origin main --rebase
git push origin main
```
