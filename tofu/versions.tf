# Contraintes de version
# OpenTofu >= 1.10 est requis pour le verrou natif S3 (`use_lockfile`).
terraform {
  required_version = ">= 1.10.0"

  required_providers {
    # Versions épinglées (cf. Phase 1f du plan docs/plans/opentofu-arr-config.md)
    sonarr = {
      source  = "devopsarr/sonarr"
      version = "3.5.0"
    }

    # Secrets : Bitwarden Secrets Manager (provider officiel)
    bitwarden-secrets = {
      source  = "bitwarden/bitwarden-secrets"
      version = "1.0.1"
    }
  }
}
