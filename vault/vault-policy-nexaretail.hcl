# Policy Vault NexaRetail
# Acces en lecture seule aux secrets de l'API
# Principe du moindre privilege : uniquement le chemin necessaire

path "nexaretail/data/api" {
  capabilities = ["read"]
}
