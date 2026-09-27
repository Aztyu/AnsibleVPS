# Secrets — Bitwarden Secrets Manager.
#
# Prérequis : un machine account Bitwarden Secrets Manager avec accès en lecture
# au(x) projet(s), et son jeton dans BW_ACCESS_TOKEN.
#
# Les secrets sont résolus par leur **nom** (`key` dans Secrets Manager) : créer
# dans Bitwarden des secrets portant exactement ces noms (sinon le plan échoue
# avec une erreur d'index sur `local.secrets[...]`).

data "bitwarden-secrets_list_secrets" "all" {}

locals {
  # nom du secret (key) -> identifiant
  secrets = { for s in data.bitwarden-secrets_list_secrets.all.secrets : s.key => s.id }
}

# Sonarr -> Settings -> General -> API Key
data "bitwarden-secrets_secret" "sonarr_api_key" {
  id = local.secrets["sonarr_api_key"]
}

# Prowlarr -> Settings -> General -> API Key (utilisée par les indexers Torznab)
data "bitwarden-secrets_secret" "prowlarr_api_key" {
  id = local.secrets["prowlarr_api_key"]
}
