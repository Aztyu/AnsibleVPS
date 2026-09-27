# Plan — Gestion de la configuration Radarr/Sonarr avec OpenTofu

## Objectif

Gérer la configuration de Radarr et Sonarr (indexers, download clients, quality
profiles, root folders, naming, notifications…) de manière déclarative avec
OpenTofu, en utilisant les providers communautaires `devopsarr/radarr` et
`devopsarr/sonarr`, exécuté **localement** depuis la machine de dev.

## Contexte / constat sur le repo

- Radarr et Sonarr tournent en **services systemd** sur le VPS (installés par le
  rôle `jellyfin`), ports 7878 / 8989 (`movies.` / `series.corentinbeal.fr`).
- Aucun état Terraform n'existe : toute la config actuelle a été faite via l'UI.
- Secrets : pattern `group_vars/all/vault` + mapping dans `vars` + miroir
  `global_vars.yml` (à garder en sync pour ansible-lint).
- Radarr/Sonarr ne sont pas protégés par basic auth sur Caddy (pas d'entrée
  `user/password` dans `caddy/vars/main.yml`) : les clés API servent d'authentification.

## Décision d'architecture

**Retenue : Option A — OpenTofu exécuté localement depuis la machine de dev.**

Motivation : voir et valider le `tofu plan` avant chaque `tofu apply`.

| | Option A : tofu depuis la machine locale | Option B : rôle Ansible exécuté sur le VPS |
|---|---|---|
| Cible API | `https://movies./series.corentinbeal.fr` (via Caddy) | `http://localhost:7878` / `:8989` |
| Fichiers `.tf` | dans le repo, appliqués à la main | dans le repo, déployés par Ansible |
| State | local, à gitignore | sur le VPS (path à inclure dans les backups) |
| Secrets | tfvars local gitignoré / env vars | rendus depuis Ansible Vault → tfvars sur le VPS |
| Déclenchement | manuel (`tofu plan` → `tofu apply`) | `ansible-playbook --tags=tofu` |

Contraintes assumées de l'option A :
- Accès API via les endpoints publics Caddy (Caddy/DNS doivent être up).
- Clés API présentes localement dans `terraform.tfvars` **gitignoré** (récupérables
  via `ansible-vault view group_vars/all/vault`).
- Deux points d'entrée de config (Ansible pour l'infra, tofu pour la config arr) —
  accepté.
- Pas de rôle Ansible `tofu` : le playbook ne déploie ni n'exécute les `.tf`.

### Backend state — retenue : S3 sur Hetzner Object Storage

Le state ne vit pas en local mais dans un bucket **S3-compatible Hetzner Object
Storage** (~0,50 €/mois), accessible depuis plusieurs machines :

- Backend `s3` d'OpenTofu avec endpoint Hetzner, `use_lockfile = true`
  (verrou natif S3, OpenTofu ≥ 1.10).
- Identifiants du bucket dans un `backend.tfvars` **gitignoré** (même pattern que
  les clés API), passé via `tofu init -backend-config=backend.tfvars`.
- Alternatives écartées :
  - `sftp` backend sur le VPS : simple mais **pas de verrou**, et le state meurt
    avec le VPS ;
  - Cloudflare R2 / Backblaze B2 : valables, mais compte tiers inutile si on est
    déjà chez Hetzner ;
  - Terraform Cloud : support OpenTofu non officiel.
- Contenu du state (clés API en clair) : le bucket doit rester privé.

## Détail des tâches

### Phase 1 — Préparation manuelle (pas de code, machine locale + console Hetzner)

#### 1a. Installer OpenTofu localement

- [ ] Installer OpenTofu sur la machine de dev — Windows :
      `winget install OpenTofu.OpenTofu` (ou `scoop install opentofu` /
      `choco install opentofu`), ou via WSL (`apt` avec le repo officiel).
- [ ] Vérifier : `tofu version` — **≥ 1.10 obligatoire** (verrou S3 natif
      `use_lockfile`).

#### 1b. Créer le bucket Object Storage Hetzner (backend state)

- [ ] Console Hetzner Cloud (console.hetzner.cloud) → projet → **Object Storage**
      → *Create Bucket*.
- [ ] Nom : ex. `ansiblevps-tofu-state` ; région : celle du VPS (ex. Falkenstein
      `fsn1`) ; **Private** (pas de public access).
- [ ] Activer le **versioning** du bucket (récupération d'un état antérieur du state).
- [ ] Noter l'endpoint : `https://<bucket-name>.<region>.your-objectstorage.com`
      (ex. `fsn1.your-objectstorage.com`).
- [ ] Créer des **identifiants S3** (*Security* → *S3 credentials* ou via les
      options du bucket) : Access Key + Secret, restreintes au bucket et en
      lecture/écriture si possible. Les garder pour `backend.tfvars` (Phase 2).

#### 1c. Extraire les clés API Radarr / Sonarr et les verser au vault

- [ ] Récupérer les clés : UI Radarr/Sonarr → *Settings → General → API Key*, ou
      directement sur le VPS :
      `grep ApiKey /var/lib/radarr/config.xml` et `/var/lib/sonarr/config.xml`.
- [ ] Les ajouter au vault du repo :
      `ansible-vault edit group_vars/all/vault --vault-password-file=password.sh`
      (entrées `vault_radarr_api_key` / `vault_sonarr_api_key`), puis mapping dans
      `group_vars/all/vars` et miroir `global_vars.yml` (AGENTS.md impose la sync).

#### 1d. Vérifier la connectivité API depuis la machine locale

- [ ] `curl -s -H "X-Api-Key: <clé>" https://movies.corentinbeal.fr/api/v3/system/status`
      (et idem sur `series.`) → doit renvoyer du JSON (confirme endpoint Caddy + clé
      + en-tête d'auth utilisés par les providers).

#### 1e. Inventaire de la config existante (radarr + sonarr)

- [ ] Pour chaque app, relever la liste des objets existants (UI *Settings*, ou
      export JSON via l'API — depuis le VPS en localhost, plus simple) :

  | Élément | Endpoint API v3 | UI |
  |---|---|---|
  | Root folders | `/rootfolder` | Media Management → Root Folders |
  | Media management | `/config/mediamanagement` | Media Management |
  | Naming | `/naming/config` et `/naming` (custom formats) | Settings → Media Management → Naming / Custom Formats |
  | Quality profiles | `/qualityprofile` | Profiles |
  | Quality definitions | `/qualitydefinition` | Quality |
  | Download clients | `/downloadclient` | Download Clients |
  | Indexers | `/indexer` et `/indexerproxy` | Indexers (+ Proxies) |
  | Notifications | `/notification` | Connect |
  | Remote path mappings | `/remotepathmapping` | Download Clients → Remote Path Mappings |
  | Tags | `/tag` | Tags |

  Exemple : `curl -s -H "X-Api-Key: <clé>" http://localhost:7878/api/v3/rootfolder`
  (sur le VPS) ; noter les **IDs** — ils servent pour `tofu import` en Phase 3.
- [x] Script d'inventaire fourni : `tofu/inventory.sh` (clés via variables
      d'env `RADARR_API_KEY`/`SONARR_API_KEY`, URLs overridables, exports dans
      `tofu/inventory/` **gitignoré** — contient des secrets, IDs résumés dans
      `_ids.txt` pour les `tofu import`).

#### 1f. Vérifier la couverture des providers — FAIT (2026-09-27)

Résultat : **tout l'inventaire est couvert** par les providers.
Versions à épingler (dernières, binaires Windows dispo) : `devopsarr/radarr 2.5.0`,
`devopsarr/sonarr 3.5.0`.

| Élément inventorié (radarr / sonarr) | Resource `radarr_*` (v2.5.0) | Resource `sonarr_*` (v3.5.0) |
|---|---|---|
| Root folder (1 / 1) | `root_folder` | `root_folder` |
| Media management | `media_management` | `media_management` |
| Naming (export à refaire : endpoint corrigé `/api/v3/config/naming`) | `naming` | `naming` |
| Quality profiles (7 / 6) | `quality_profile` | `quality_profile` |
| Quality definitions (30 / 22, défauts système) | `quality_definition` | `quality_definition` |
| Custom formats (0 / 0) | `custom_format` | `custom_format` |
| Delay profile (1 / 1) | `delay_profile` | `delay_profile` |
| Download client Transmission (1 / 1) | `download_client_transmission` | `download_client_transmission` |
| Indexers Torznab (3 / 3) | `indexer_torznab` | `indexer_torznab` |
| Import lists (0 / 0) | `import_list` (+19 types dédiés) | `import_list` (+11 types dédiés) |
| Import list exclusions (0 / 0) | `import_list_exclusion` | `import_list_exclusion` |
| Notifications (0 / 0) | `notification` (+29 types dédiés : gotify, ntfy, discord…) | `notification` (+29 types dédiés) |
| Remote path mapping (1 / 1) | `remote_path_mapping` | `remote_path_mapping` |
| Tags (0 / 0) | `tag`, `auto_tag` | `tag`, `auto_tag` |
| Host config (Settings → General) | `host` | `host` |
| Options download clients | `download_client_config` | `download_client_config` |
| Options indexers | `indexer_config` | `indexer_config` |
| Metadata | `metadata` (+ emby/kodi) | `metadata` (+ kodi) |
| Release profiles (Sonarr uniquement, export à refaire) | — | `release_profile` |

Non couvert (sans impact) :
- **Indexer proxies** : n'existent pas sur Radarr/Sonarr (fonctionnalité Prowlarr)
  — endpoint retiré du script.
- **UI config** (`/api/v3/config/ui`), clés API, tâches planifiées, backups :
  opérationnel, pas de resource — reste hors tofu.

Décisions proposées (à valider) :
1. **Quality definitions** (30/22, défauts système non personnalisés) : ne PAS les
   gérer dans tofu (bruit pour zéro customisation) — elles resteront telles quelles.
2. **Quality profiles** : importer uniquement les profils personnalisés
   (`HD - 720p/1080p`, `Custom 1080p` sur radarr ; `HD - 720p/1080p` sur sonarr) et
   laisser les profils système (`Any`, `SD`, `HD-720p`…) hors tofu.
3. Collections vides (custom formats, notifications, tags, import lists) : rien à
   importer ; les futurs ajouts se feront directement dans les `.tf`.

#### Critère de sortie de la Phase 1

- [ ] `tofu version` ≥ 1.10 ; bucket créé + identifiants S3 notés ; clés API
      récupérées et versées au vault (1c toujours en attente : absent du vault) ;
      `curl system/status` OK sur les deux apps ; inventaire + IDs sauvegardés ;
      couverture providers vérifiée (1f FAIT).
- [ ] **Re-exécuter `tofu/inventory.sh`** (corrigé) pour compléter l'inventaire :
      naming, host config, options download clients/indexers, metadata,
      exclusions radarr, release profiles sonarr + IDs dans `_ids.txt`
      (fallback python ajouté).

### Phase 2 — Configuration locale du projet tofu — FAIT

- [x] Dossier `tofu/` versionné (code `.tf` uniquement).
- [x] `tofu/versions.tf` : `required_version >= 1.10` + provider
      `devopsarr/sonarr 3.5.0` épinglé.
- [x] `tofu/providers.tf` + `tofu/variables.tf` : provider Sonarr configuré par
      variables (`sonarr_url`) ; les clés API viennent de Bitwarden (voir plus bas).
- [x] `tofu/backend.tf` : `backend "s3"` complet avec les valeurs **non secrètes**
      versionnées (bucket `ansiblevps-tofu-state`, endpoint
      `fsn1.your-objectstorage.com`, `key = arr/terraform.tfstate`,
      `use_lockfile = true`, `skip_*`) — aucun secret dans le fichier.
- [x] Identifiants S3 via l'environnement (`AWS_ACCESS_KEY_ID` /
      `AWS_SECRET_ACCESS_KEY`), standard du backend S3 — pas de fichier à
      gitignorer. `backend.tfvars` abandonné (un bloc backend ne peut pas
      référencer de variables : config partielle inutile ici).
- [x] `tofu/secrets.tf` + provider officiel `bitwarden/bitwarden-secrets` **1.0.1**
      (signé Bitwarden, binaire windows/amd64 dispo) : les clés API sont lues
      dans **Bitwarden Secrets Manager** par nom (`sonarr_api_key`,
      `prowlarr_api_key`) via `list_secrets` → `secret`. Auth par
      `BW_ACCESS_TOKEN` (machine account) + `bitwarden_organization_id`
      (tfvars) ; `api_url`/`identity_url` par défaut sur Bitwarden cloud.
      ⚠️ La doc du provider annonce ces trois champs "optionnels" : ils ne le
      sont que via variables d'environnement — le provider n'a **aucun défaut**,
      donc le plan échoue ("Missing URI for ... API endpoint") si on ne les
      fournit pas explicitement.
- [x] `tofu/terraform.tfvars.example` (commité, optionnel : seulement `sonarr_url`).
- [x] `tofu/README.md` : prérequis, workflow `plan` → review → `apply`, imports,
      contenu géré / non géré.
- [x] `.gitignore` : tfvars, backend.tfvars, `.terraform/`, state, lock.hcl —
      vérifié (`git check-ignore`).
- [x] Validé : `tofu fmt -check` OK, `tofu init -backend=false` + `tofu validate` OK
      (OpenTofu v1.11.5 dans WSL).
- [x] Le provider **radarr** sera ajouté à `versions.tf`/`providers.tf` lors de la
      Phase 3 côté Radarr.

Reste à faire (dépend d'actions manuelles) :
- [ ] Créer les secrets `sonarr_api_key` / `prowlarr_api_key` dans Bitwarden
      Secrets Manager + un machine account (jeton → `BW_ACCESS_TOKEN`).
- [ ] Exporter `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` (1b : identifiants
      S3 Hetzner) puis `tofu -chdir=tofu init` (backend réel).
- [ ] 1c (Ansible) : ce n'est plus nécessaire pour tofu — les clés API ne
      transitent plus par le vault. Le vault reste la source pour Ansible.

### Phase 3 — Écrire les configs `.tf` + importer l'existant

**Côté Sonarr — démarré**

- [x] `tofu/sonarr.tf` écrit à partir de l'inventaire : `root_folder`,
      `media_management`, `delay_profile`, `remote_path_mapping`,
      `download_client_transmission`, 3× `indexer_torznab` (clé Prowlarr via
      Bitwarden), `quality_profile` personnalisé (via data sources `sonarr_quality`).
- [x] Commandes `tofu import` en commentaire au-dessus de chaque ressource.
- [x] Décisions 1f appliquées : qualité système non gérée, seuls les profils
      personnalisés, quality definitions hors tofu.
- [ ] Compléter après nouvel inventaire : `naming`, `host`, `release_profile`,
      `metadata`, options indexers/download clients.
- [ ] Exécuter les imports puis `tofu plan` → objectif : aucun drift.

**Côté Radarr — à faire**

- [ ] Ajouter le provider radarr + `tofu/radarr.tf` sur le même modèle.
- [ ] Ordre prudent : d'abord root folders, download clients, quality profiles ;
      puis indexers (Prowlarr + Transmission), custom formats/naming, notifications.

- [ ] `tofu plan` vide (aucun drift) comme critère de fin de phase.

### Phase 4 — Hygiène

- [ ] Optionnel : activer la **versioning de versioning S3** du bucket (récupérer
      un état antérieur du state si besoin).
- [ ] Vérifier ansible-lint depuis WSL : `Passed: 0 failure(s), 0 warning(s)`.
- [ ] Vérifier que `git status` reste propre (aucun tfvars/state commité).

## Risques / questions ouvertes

1. **Maturité des providers** : `devopsarr` est maintenu par une personne, la
   couverture de ressources est bonne mais pas exhaustive ; vérifier les derniers
   releases avant d'épingler.
2. **Dérive bidirectionnelle** : toute modification manuelle dans l'UI sera
   "corrigée" (ou détectée) par le prochain `tofu apply` — décider si c'est le
   comportement voulu (c'est le but, mais à assumer).
3. **Suppressions** : un `apply` avec une ressource retirée du `.tf` **supprime**
   l'objet dans Radarr/Sonarr (ex : retirer un indexer du code le supprime du
   service). Attention lors des revues.
4. **State + secrets** : le state contient les clés API (les *data sources*
   Bitwarden y sont matérialisées, comme les secrets lus) ; il vit dans le
   bucket S3 privé (ne jamais le rendre public), avec identifiants locaux via
   `AWS_*` dans l'environnement.
5. **Dérive Ansible** : le rôle `jellyfin` réinstalle/redémarre Radarr/Sonarr à
   chaque exécution ; pas de conflit avec la config gérée par tofu (les données
   persistent dans `/var/lib/{radarr,sonarr}`), mais à garder à l'esprit.
6. **Compteur Hetzner** : le bucket Object Storage est un nouveau compte de
   facturation (petit, mais à assumer).
7. **HCL ≠ YAML** : ne pas préfixer les `.tf`/`.tfvars` par `---` (convention du
   repo YAML, invalide en HCL) — `tofu fmt`/`validate` le rejettent.
8. **Bootstrap Bitwarden** : `BW_ACCESS_TOKEN` (machine account) reste un secret
   d'environnement — le provider ne peut pas s'auto-authentifier. Bitwarden
   **Secrets Manager** requis : Vaultwarden ne l'implémente pas (dans ce cas,
   `maxlaverse/bitwarden` serait la seule option).

Décisions prises :
- Périmètre : **tout** ce que les providers couvrent.
- Approche : **importer l'existant** (nettoyage éventuel ensuite, via tofu).
- State : **backend S3 Hetzner Object Storage** avec verrou natif ; valeurs non
  secrètes dans `backend.tf`, identifiants S3 via `AWS_*` (env).
- Secrets applicatifs : **Bitwarden Secrets Manager** via le provider officiel
  `bitwarden/bitwarden-secrets` (les clés API ne passent plus par tfvars).
