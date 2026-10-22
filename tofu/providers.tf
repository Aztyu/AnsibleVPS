# Providers

# Bitwarden Secrets Manager (bitwarden/bitwarden-secrets)
# Le jeton du machine account est lu depuis l'environnement : BW_ACCESS_TOKEN.
provider "bitwarden-secrets" {
  api_url         = var.bitwarden_api_url
  identity_url    = var.bitwarden_identity_url
  organization_id = var.bitwarden_organization_id
}

# Sonarr (devopsarr/sonarr) — la clé API provient de Bitwarden (voir secrets.tf)
provider "sonarr" {
  url     = var.sonarr_url
  api_key = data.bitwarden-secrets_secret.sonarr_api_key.value
}
