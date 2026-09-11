#!/bin/sh
set -eu

: "${NTFY_URL:?NTFY_URL manquant}"
: "${LAT:?LAT manquant}"
: "${LON:?LON manquant}"
RADIUS_KM=${RADIUS_KM:-10}
FUELS=$(echo "${FUELS:-e10,sp95}" | tr -d ' ')
THRESHOLD=${THRESHOLD:-2.00}
MAX_AGE_DAYS=${MAX_AGE_DAYS:-3}
STATE=${STATE:-/data/state.json}

API="https://data.economie.gouv.fr/api/explore/v2.1/catalog/datasets/prix-des-carburants-en-france-flux-instantane-v2/records"

log() { printf '%s [%-5s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" "$2"; }

mkdir -p "$(dirname "$STATE")"
[ -f "$STATE" ] || echo '{}' > "$STATE"

SELECT="id, adresse, ville, geom"
for f in $(echo "$FUELS" | tr ',' ' '); do
  SELECT="$SELECT, ${f}_prix, ${f}_maj"
done

TMP=$(mktemp); ERR=$(mktemp)
trap 'rm -f "$TMP" "$ERR"' EXIT

log INFO "requête — ${FUELS} dans ${RADIUS_KM} km autour de ${LAT},${LON}"

if ! curl -fsSG --max-time 30 --retry 2 --retry-delay 5 "$API" \
      --data-urlencode "where=within_distance(geom, geom'POINT($LON $LAT)', ${RADIUS_KM}km)" \
      --data-urlencode "select=$SELECT" \
      --data-urlencode "limit=100" \
      -o "$TMP" 2>"$ERR"; then
  log ERROR "appel API échoué : $(tr '\n' ' ' < "$ERR")"
  exit 1
fi

if ! TOTAL=$(jq -er '.total_count' "$TMP" 2>/dev/null); then
  log ERROR "réponse API illisible : $(head -c 200 "$TMP")"
  exit 1
fi
log INFO "$TOTAL station(s) dans le rayon"

ALL=$(jq -c \
  --arg fuels "$FUELS" \
  --argjson now "$(date +%s)" \
  --argjson maxage "$((MAX_AGE_DAYS * 86400))" '
  ($fuels | split(",")) as $fl
  | [ .results[] as $r
      | $fl[] as $f
      | ($r["\($f)_prix"]) as $p
      | select($p != null)
      | ($r["\($f)_maj"] // "") as $m
      | { key:   "\($r.id)|\($f)",
          fuel:  ($f | ascii_upcase),
          prix:  $p,
          label: "\($r.adresse // "?"), \($r.ville // "?")",
          maj:   $m[0:16],
          stale: (if $m == "" then false
                  else ($m[0:10] | strptime("%Y-%m-%d") | mktime) < ($now - $maxage)
                  end),
          lat:   ($r.geom.lat // 0),
          lon:   ($r.geom.lon // 0) }
    ] | sort_by(.prix)' "$TMP")

log INFO "moins cher : $(echo "$ALL" | jq -r 'if length == 0 then "aucun relevé"
  else (.[0] | "\(.prix) € \(.fuel) — \(.label)") end')"

STALE_N=$(echo "$ALL" | jq 'map(select(.stale)) | length')
[ "$STALE_N" -gt 0 ] && log INFO "$STALE_N relevé(s) ignoré(s) (plus de ${MAX_AGE_DAYS} j)"

UNDER=$(echo "$ALL" | jq -c --argjson thr "$THRESHOLD" \
  'map(select((.stale | not) and .prix < $thr))')
UNDER_N=$(echo "$UNDER" | jq length)
log INFO "$UNDER_N offre(s) sous ${THRESHOLD} €"
echo "$UNDER" | jq -r '.[] |
  "  \(.prix) € \(.fuel) — \(.label) — \(if .maj == "" then "date inconnue" else .maj end)"' |
  while IFS= read -r line; do log INFO "$line"; done

TO_NOTIFY=$(echo "$UNDER" | jq -c --argjson prev "$(cat "$STATE")" \
  'map(select(($prev[.key] // 99) > .prix))')
N=$(echo "$TO_NOTIFY" | jq length)

if [ "$N" -eq 0 ]; then
  log INFO "rien de neuf à signaler"
else
  log INFO "$N notification(s) à envoyer"
  echo "$TO_NOTIFY" | jq -c '.[]' | while IFS= read -r st; do
    prix=$(echo  "$st" | jq -r .prix)
    fuel=$(echo  "$st" | jq -r .fuel)
    label=$(echo "$st" | jq -r .label)
    maj=$(echo   "$st" | jq -r .maj)
    lat=$(echo   "$st" | jq -r .lat)
    lon=$(echo   "$st" | jq -r .lon)
    if curl -fsS --max-time 15 \
        -H "Priority: high" \
        -H "Title: ${fuel} à ${prix} €" \
        -H "Tags: fuelpump" \
        -H "Click: https://www.google.com/maps/search/?api=1&query=${lat},${lon}" \
        -d "${label}
relevé du ${maj}" \
        "$NTFY_URL" > /dev/null 2>"$ERR"; then
      log INFO "→ notifié : $fuel $prix € — $label"
    else
      log ERROR "→ envoi ntfy échoué ($label) : $(tr '\n' ' ' < "$ERR")"
    fi
  done
fi

echo "$UNDER" | jq 'map({key: .key, value: .prix}) | from_entries' > "${STATE}.tmp"
mv "${STATE}.tmp" "$STATE"
log INFO "cycle terminé"