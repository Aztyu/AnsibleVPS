# Backend state : S3-compatible (Hetzner Object Storage).
#
# Aucun secret ici : les identifiants S3 sont lus depuis l'environnement
# (AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY), standard du backend S3.
# Voir tofu/README.md.
terraform {
  backend "s3" {
    bucket = "ansiblevps-tofu-state"
    key    = "arr/terraform.tfstate"
    region = "fsn1"

    endpoints = {
      s3 = "https://fsn1.your-objectstorage.com"
    }

    # Verrou natif S3 (OpenTofu >= 1.10)
    use_lockfile = true

    # Réglages requis pour un endpoint S3 non-AWS
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
  }
}
