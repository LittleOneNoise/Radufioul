#!/bin/sh
INTERVAL=${INTERVAL:-1800}
log() { printf '%s [%-5s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" "$2"; }

log INFO "radufioul démarré — cycle toutes les ${INTERVAL}s"
trap 'log INFO "arrêt demandé"; exit 0' TERM INT

while :; do
  /usr/local/bin/check.sh || log ERROR "cycle en échec, on retente dans ${INTERVAL}s"
  sleep "$INTERVAL" &
  wait $!
done