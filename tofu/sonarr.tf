# Configuration Sonarr gérée par OpenTofu (provider devopsarr/sonarr 3.5.0).
#
# Les ressources ci-dessous reprennent la configuration existante (inventaire
# Phase 1e). Chaque ressource doit être importée AVANT le premier apply, avec la
# commande indiquée en commentaire au-dessus (l'ID provient de l'inventaire :
# tofu/inventory/sonarr/_ids.txt).
#
# Ordre d'import conseillé : root_folder -> media_management -> delay_profile
# -> remote_path_mapping -> download_client -> indexer -> quality_profile.

# --- Dossiers racine ---------------------------------------------------------
# tofu import sonarr_root_folder.series 1
resource "sonarr_root_folder" "series" {
  path = "/mnt/storagebox/media/series"
}

# --- Gestion des médias ------------------------------------------------------
# tofu import sonarr_media_management.this ""
resource "sonarr_media_management" "this" {
  unmonitor_previous_episodes = false
  hardlinks_copy              = true
  create_empty_folders        = false
  delete_empty_folders        = false
  enable_media_info           = true
  import_extra_files          = false
  set_permissions             = false
  skip_free_space_check       = false
  minimum_free_space          = 100
  recycle_bin_path            = ""
  recycle_bin_days            = 7
  chmod_folder                = "755"
  chown_group                 = ""
  download_propers_repacks    = "preferAndUpgrade"
  episode_title_required      = "always"
  extra_file_extensions       = "srt"
  file_date                   = "none"
  rescan_after_refresh        = "always"
}

# --- Profils de délai --------------------------------------------------------
# tofu import sonarr_delay_profile.this 1
resource "sonarr_delay_profile" "this" {
  enable_usenet                       = true
  enable_torrent                      = true
  preferred_protocol                  = "usenet"
  usenet_delay                        = 0
  torrent_delay                       = 0
  bypass_if_highest_quality           = true
  bypass_if_above_custom_format_score = false
  minimum_custom_format_score         = 0
  order                               = 2147483647
  tags                                = []
}

# --- Mapping de chemins distants ---------------------------------------------
# tofu import sonarr_remote_path_mapping.transmission 1
resource "sonarr_remote_path_mapping" "transmission" {
  host        = "localhost"
  remote_path = "/data/completed/"
  local_path  = "/mnt/storagebox/media/"
}

# --- Client de téléchargement (Transmission) ---------------------------------
# tofu import sonarr_download_client_transmission.transmission 1
resource "sonarr_download_client_transmission" "transmission" {
  enable                     = true
  priority                   = 1
  name                       = "Transmission"
  host                       = "localhost"
  port                       = 9091
  use_ssl                    = false
  url_base                   = "/transmission/"
  tv_category                = "tv-sonarr"
  recent_tv_priority         = 0
  older_tv_priority          = 0
  add_paused                 = false
  remove_completed_downloads = true
  remove_failed_downloads    = true
}

# --- Indexers (Torznab, fournis par Prowlarr) --------------------------------
# La clé API Prowlarr vient de Bitwarden Secrets Manager (voir secrets.tf).
# L'ID dans l'URL (base_url) est celui de l'indexer côté Prowlarr.

# tofu import sonarr_indexer_torznab.tpb 6
resource "sonarr_indexer_torznab" "tpb" {
  enable_rss                   = true
  enable_automatic_search      = true
  enable_interactive_search    = true
  priority                     = 25
  name                         = "The Pirate Bay (Prowlarr)"
  base_url                     = "http://localhost:9696/5/"
  api_path                     = "/api"
  api_key                      = data.bitwarden-secrets_secret.prowlarr_api_key.value
  categories                   = [5000, 5045, 5040, 5050]
  anime_standard_format_search = true
  minimum_seeders              = 1
  tags                         = []
}

# tofu import sonarr_indexer_torznab.genfree 4
resource "sonarr_indexer_torznab" "genfree" {
  enable_rss                   = true
  enable_automatic_search      = true
  enable_interactive_search    = true
  priority                     = 25
  name                         = "Generation-Free (API) (Prowlarr)"
  base_url                     = "http://localhost:9696/2/"
  api_path                     = "/api"
  api_key                      = data.bitwarden-secrets_secret.prowlarr_api_key.value
  categories                   = [5000]
  anime_standard_format_search = true
  minimum_seeders              = 1
  seed_ratio                   = 10
  tags                         = []
}

# tofu import sonarr_indexer_torznab.x1337 3
resource "sonarr_indexer_torznab" "x1337" {
  enable_rss                   = true
  enable_automatic_search      = true
  enable_interactive_search    = true
  priority                     = 25
  name                         = "1337x (Prowlarr)"
  base_url                     = "http://localhost:9696/1/"
  api_path                     = "/api"
  api_key                      = data.bitwarden-secrets_secret.prowlarr_api_key.value
  categories                   = [5000, 5040, 5030]
  anime_categories             = [5070]
  anime_standard_format_search = true
  minimum_seeders              = 1
  seed_ratio                   = 5
  tags                         = []
}

# --- Profils de qualité ------------------------------------------------------
# Seuls les profils personnalisés sont gérés ; les profils système (Any, SD,
# HD-720p, HD-1080p, Ultra-HD) restent hors tofu (décision 1f).
#
# Ordre : du meilleur au moins bon (ordre normalisé par le provider).
# Les qualités sont référencées via des data sources plutôt qu'en dur.

data "sonarr_quality" "hdtv_720p" {
  name = "HDTV-720p"
}

data "sonarr_quality" "hdtv_1080p" {
  name = "HDTV-1080p"
}

data "sonarr_quality" "webdl_720p" {
  name = "WEBDL-720p"
}

data "sonarr_quality" "webrip_720p" {
  name = "WEBRip-720p"
}

data "sonarr_quality" "bluray_720p" {
  name = "Bluray-720p"
}

data "sonarr_quality" "webdl_1080p" {
  name = "WEBDL-1080p"
}

data "sonarr_quality" "webrip_1080p" {
  name = "WEBRip-1080p"
}

data "sonarr_quality" "bluray_1080p" {
  name = "Bluray-1080p"
}

# tofu import sonarr_quality_profile.hd_720p_1080p 6
resource "sonarr_quality_profile" "hd_720p_1080p" {
  name                     = "HD - 720p/1080p"
  upgrade_allowed          = false
  cutoff                   = 4
  min_format_score         = 0
  cutoff_format_score      = 0
  min_upgrade_format_score = 1

  quality_groups = [
    {
      qualities = [data.sonarr_quality.bluray_1080p]
    },
    {
      id   = 1002
      name = "WEB 1080p"
      qualities = [
        data.sonarr_quality.webrip_1080p,
        data.sonarr_quality.webdl_1080p,
      ]
    },
    {
      qualities = [data.sonarr_quality.bluray_720p]
    },
    {
      id   = 1001
      name = "WEB 720p"
      qualities = [
        data.sonarr_quality.webrip_720p,
        data.sonarr_quality.webdl_720p,
      ]
    },
    {
      qualities = [data.sonarr_quality.hdtv_1080p]
    },
    {
      qualities = [data.sonarr_quality.hdtv_720p]
    },
  ]
}
