#!/usr/bin/env bash
# Inventaire de la configuration Radarr / Sonarr via l'API v3 (Phase 1e du plan tofu).
# Sauvegarde un export JSON par endpoint dans tofu/inventory/<app>/.
#
# ⚠️ Les exports contiennent des secrets (clés d'indexers, credentials de download
#    clients, etc.) : tofu/inventory/ est gitignoré, ne jamais le committer.
#
# Usage (clés API disponibles via : ansible-vault view group_vars/all/vault --vault-password-file=password.sh) :
#   RADARR_API_KEY=xxx SONARR_API_KEY=yyy ./tofu/inventory.sh
#
# Options (variables d'environnement) :
#   RADARR_URL  défaut : https://movies.corentinbeal.fr
#   SONARR_URL  défaut : https://series.corentinbeal.fr
#   OUT_DIR     défaut : tofu/inventory
#   (le script fonctionne aussi sur le VPS avec RADARR_URL=http://localhost:7878
#    et SONARR_URL=http://localhost:8989)

set -euo pipefail

RADARR_URL="${RADARR_URL:-https://movies.corentinbeal.fr}"
SONARR_URL="${SONARR_URL:-https://series.corentinbeal.fr}"
OUT_DIR="${OUT_DIR:-tofu/inventory}"

: "${RADARR_API_KEY:?Variable RADARR_API_KEY requise (voir group_vars/all/vault)}"
: "${SONARR_API_KEY:?Variable SONARR_API_KEY requise (voir group_vars/all/vault)}"

# Interpréteur Python (jq est optionnel, python sert de fallback)
PY="$(command -v python3 || command -v python)"
[[ -n "$PY" ]] || PY=""

# Chaque entrée : "endpoint" ou "endpoint:endpoint_alternatif" (essayé si HTTP != 200,
# certains endpoints diffèrent entre Radarr et Sonarr — ex. exclusions).
# Chemins vérifiés depuis les clients Go des providers devopsarr (radarr-go/sonarr-go).
ENDPOINTS=(
  "system/status"
  "rootfolder"
  "config/mediamanagement"
  "config/naming"
  "qualityprofile"
  "qualitydefinition"
  "customformat"
  "delayprofile"
  "downloadclient"
  "config/downloadclient"
  "indexer"
  "config/indexer"
  "importlist"
  "importlistexclusion:exclusions"   # Radarr : /api/v3/exclusions ; Sonarr : /api/v3/importlistexclusion
  "notification"
  "remotepathmapping"
  "releaseprofile"                    # Sonarr uniquement
  "tag"
  "metadata"
  "config/host"                      # Settings -> General (gérable : resource `host`)
)
# Note : pas d'indexerproxy — les proxies d'indexers n'existent que sur Prowlarr.

# fetch <url> <clé_api> <endpoint> <endpoint_alternatif> <fichier_sortie>
# DEBUG=1 : affiche la requête curl envoyée pour chaque appel.
fetch() {
  local url="$1" key="$2" ep="$3" alt="$4" file="$5"
  local code

  mkdir -p "$(dirname "$file")"
  if [[ "${DEBUG:-0}" == "1" ]]; then
    echo "  DEBUG  curl -sS -o $file.tmp -w '%{http_code}' -H 'X-Api-Key: <clé> ($url/api/v3/$ep)'"
  fi
  code=$(curl -sS -o "$file.tmp" -w '%{http_code}' \
    -H "X-Api-Key: $key" "$url/api/v3/$ep") \
    || { echo "  ÉCHEC  $ep (curl exit $?, voir commande DEBUG ci-dessus)"; return 0; }

  if [[ "$code" != "200" && -n "$alt" ]]; then
    if [[ "${DEBUG:-0}" == "1" ]]; then
      echo "  DEBUG  curl (fallback) -H 'X-Api-Key: <clé> ($url/api/v3/$alt)'"
    fi
    code=$(curl -sS -o "$file.tmp" -w '%{http_code}' \
      -H "X-Api-Key: $key" "$url/api/v3/$alt") || true
  fi

  if [[ "$code" != "200" ]]; then
    rm -f "$file.tmp"
    echo "  ABSENT $ep (HTTP $code)"
    return 0
  fi

  pretty < "$file.tmp" > "$file" && rm -f "$file.tmp"
  if [[ -z "$PY" ]]; then
    echo "  OK     $ep (python/jq absents : JSON non reformatté, pas de comptage)"
    return 0
  fi
  if "$PY" -c "import json,sys; d=json.load(open(sys.argv[1])); sys.exit(0 if isinstance(d,list) else 1)" "$file" 2>/dev/null; then
    count=$("$PY" -c "import json,sys; print(len(json.load(open(sys.argv[1]))))" "$file" 2>/dev/null)
    echo "  OK     $ep — $count élément(s)"
  else
    echo "  OK     $ep — config"
  fi
}

# pretty : reformate le JSON (jq si présent, sinon python -m json.tool)
pretty() {
  if command -v jq >/dev/null 2>&1; then
    jq '.'
  else
    "$PY" -m json.tool
  fi
}

# Rappel des IDs : ils servent pour les `tofu import` de la Phase 3.
list_ids() { # <fichier_json>
  local file="$1"
  [[ -f "$file" ]] || return 0
  [[ -n "$PY" ]] || return 0
  "$PY" - "$file" <<'PYEOF'
import json, sys
try:
    data = json.load(open(sys.argv[1], encoding="utf-8"))
except Exception:
    sys.exit(0)
if isinstance(data, list):
    for it in data:
        name = (it.get("name") or it.get("label") or it.get("path")
                or (it.get("quality") or {}).get("name") or "")
        print(f"    {it.get('id')}  {name}")
PYEOF
}

run_app() { # <nom> <url> <clé_api>
  local app="$1" url="$2" key="$3"
  echo "==> $app ($url)"
  mkdir -p "$OUT_DIR/$app"
  local spec ep alt file ids_file="$OUT_DIR/$app/_ids.txt"
  : > "$ids_file"
  local safe
  for spec in "${ENDPOINTS[@]}"; do
    ep="${spec%%:*}"
    alt="${spec#*:}"
    [[ "$alt" == "$ep" ]] && alt=""
    # Endpoints avec un '/' (ex. system/status) : nom de fichier sécurisé
    # (sinon curl écrit dans un sous-dossier inexistant → erreur 23).
    safe="${ep//\//_}"
    file="$OUT_DIR/$app/$safe.json"
    fetch "$url" "$key" "$ep" "$alt" "$file"
    { echo "[$ep]"; list_ids "$file"; } >> "$ids_file"
  done
  echo "    (IDs des ressources listés dans $ids_file — utiles pour tofu import)"
}

run_app radarr "$RADARR_URL" "$RADARR_API_KEY"
run_app sonarr "$SONARR_URL" "$SONARR_API_KEY"

echo
echo "Terminé. Exports dans $OUT_DIR/ (gitignoré — contient des secrets)."
echo "Prochaine étape (1f) : vérifier la couverture des providers devopsarr/radarr et"
echo "devopsarr/sonarr contre ces exports."
