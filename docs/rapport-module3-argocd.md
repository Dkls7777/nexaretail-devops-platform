# Module 3 — ArgoCD GitOps

**Statut :** ✅ Terminé  
**Date :** 26 mai 2026  

## Ce qui a été réalisé

- ArgoCD installé via Helm dans le namespace `argocd` (7 pods Running)
- Helm chart `nexaretail-api` créé (Chart.yaml, values.yaml, deployment, service)
- Application ArgoCD configurée avec auto-sync + self-heal activés
- Synchronisation Git → Cluster validée : `Synced`
- 2 pods déployés dans `nexaretail-prod` (ImagePullBackOff attendu — image M4/M5)

## Validation

| Composant | Statut |
|-----------|--------|
| ArgoCD pods | 7/7 Running ✅ |
| Application SYNC STATUS | Synced ✅ |
| Pods nexaretail-prod | Créés ✅ (image M4) |

## Mot de passe ArgoCD admin

Stocké localement — à remplacer par Vault en M8.
