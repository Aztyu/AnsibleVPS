# OpenTofu — configuration Sonarr (et à terme Radarr)

Gestion déclarative de la configuration Sonarr via le provider
[`devopsarr/sonarr`](https://registry.opentofu.org/providers/devopsarr/sonarr),
exécuté **localement** (voir `docs/plans/opentofu-arr-config.md`).

Les clés API ne sont pas stockées en clair : elles viennent de **Bitwarden
Secrets Manager** (provider officiel `bitwarden/bitwarden-secrets`).

## Prérequis

- OpenTofu >= 1.10 (verrou S3 natif) : `tofu version`
- Un **machine account** Bitwarden Secrets Manager, avec accès lecture sur les
  secrets utilisés, et son jeton dans la variable d'environnement
  `BW_ACCESS_TOKEN`
- L'**ID de l'organisation** Bitwarden (Organization -> Settings) à mettre dans
  `terraform.tfvars` — le provider exige aussi `api_url` / `identity_url`
  (valeurs par défaut Bitwarden cloud dans `variables.tf`)
- Les identifiants S3 du bucket état (Hetzner Object Storage), via
  `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`

> Le backend S3 est résolu au moment de `tofu init`, avant tout provider : ses
> identifiants **ne peuvent pas** venir de Bitwarden, d'où les variables `AWS_*`.

## Secrets dans Bitwarden

Les secrets sont résolus par leur **nom**. À créer dans Secrets Manager :

| Nom (`key`) | Contenu |
|---|---|
| `sonarr_api_key` | Sonarr -> Settings -> General -> API Key |
| `prowlarr_api_key` | Prowlarr -> Settings -> General -> API Key |

Voir `secrets.tf` : `list_secrets` construit la correspondance nom -> id, puis
chaque secret est lu par son id. Ajouter un secret = ajouter un bloc
`data "bitwarden-secrets_secret"` + l'utiliser.

Auto-hébergement (Bitwarden self-hosted uniquement — **Vaultwarden ne supporte
pas Secrets Manager**) : renseigner `BW_API_URL`, `BW_IDENTITY_API_URL`,
`BW_ORGANIZATION_ID`.

Région : un jeton d'un compte **EU** (`vault.bitwarden.eu`) doit interroger
`https://api.bitwarden.eu` / `https://identity.bitwarden.eu`, sinon l'API
répond `invalid_client`. Défauts = cloud US.

## Mise en place (une fois)

```bash
export BW_ACCESS_TOKEN="..."              # machine account
cp tofu/terraform.tfvars.example tofu/terraform.tfvars   # renseigner l'org ID
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."

tofu -chdir=tofu init
```

`tofu/terraform.tfvars` (gitignoré) contient `bitwarden_organization_id` et, si
besoin, les surcharges (`sonarr_url`, URLs self-hosted).

## Workflow quotidien

```bash
export BW_ACCESS_TOKEN="..." AWS_ACCESS_KEY_ID="..." AWS_SECRET_ACCESS_KEY="..."

tofu -chdir=tofu plan     # relire le plan
tofu -chdir=tofu apply    # appliquer
```

## Inventaire (Phase 1e)

`tofu/inventory.sh` exporte la configuration existante (JSON) dans
`tofu/inventory/` (gitignoré — contient des secrets) :

```bash
RADARR_API_KEY=... SONARR_API_KEY=... ./tofu/inventory.sh
```

Les IDs des ressources sont résumés dans `tofu/inventory/<app>/_ids.txt`.

## Importer l'existant (première fois)

Les commandes `tofu import` sont en commentaire au-dessus de chaque ressource
dans `sonarr.tf`. Les exécuter avant le premier `apply`, par exemple :

```bash
tofu -chdir=tofu import sonarr_root_folder.series 1
tofu -chdir=tofu import sonarr_media_management.this ""
tofu -chdir=tofu import sonarr_delay_profile.this 1
# ...
```

Objectif : `tofu plan` sans changement (aucun drift).

## Contenu géré

- Dossiers racine, gestion des médias, profils de délai, mappings de chemins
- Client de téléchargement (Transmission), indexers Torznab (Prowlarr)
- Profils de qualité personnalisés (les profils système restent hors tofu)

## Non géré (par choix ou non supporté)

- **Quality definitions** : défauts système, laissés hors tofu.
- **UI config, clés API, tâches planifiées, backups** : opérationnel, pas de resource.
- **`tv_imported_category`** d'un download client : absent du provider.

## Limites à connaître

- Les valeurs lues depuis Bitwarden via un *data source* sont écrites dans le
  **state** (bucket S3 privé) : le state contient donc les clés API.
- Une donnée lue (`data`) est rafraîchie à chaque plan : une rotation du secret
  dans Bitwarden est appliquée au plan suivant.

## À compléter (en attente d'un nouvel inventaire)

Les endpoints suivants n'ont pas encore été exportés (script corrigé depuis) :

- `sonarr_naming` (`/api/v3/config/naming`)
- `sonarr_host` (Settings -> General, `/api/v3/config/host`)
- `download_client_config`, `indexer_config`, `metadata`, `release_profile`
