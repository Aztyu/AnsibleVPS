# Variables — les secrets ne sont plus ici : ils viennent de Bitwarden (secrets.tf).

variable "sonarr_url" {
  description = "URL de l'API Sonarr (endpoint Caddy ou localhost depuis le VPS)"
  type        = string
  default     = "https://series.corentinbeal.fr"
}

# --- Bitwarden Secrets Manager -------------------------------------------------
# Le provider n'a aucune valeur par défaut (contrairement à ce que suggère sa doc) :
# api_url, identity_url et organization_id doivent toujours être fournis, ici ou
# via BW_API_URL / BW_IDENTITY_API_URL / BW_ORGANIZATION_ID.

variable "bitwarden_api_url" {
  description = "Endpoint API de Bitwarden Secrets Manager"
  type        = string
  default     = "https://api.bitwarden.eu"
}

variable "bitwarden_identity_url" {
  description = "Endpoint IDENTITY de Bitwarden Secrets Manager"
  type        = string
  default     = "https://identity.bitwarden.eu"
}

variable "bitwarden_organization_id" {
  description = "ID de l'organisation Bitwarden (Organization -> Settings), à mettre dans terraform.tfvars"
  type        = string
}
