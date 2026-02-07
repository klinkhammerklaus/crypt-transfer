#!/usr/bin/env bash
set -euo pipefail

# Expliziter PATH für cron-Umgebung
export PATH="/usr/local/bin:/usr/bin:/bin:$PATH"

# Absoluter Pfad (funktioniert auch wenn $HOME in cron nicht gesetzt ist)
BASEDIR="${HOME:-/home/mm}/projekte/crypt-transfer"
cd "$BASEDIR"

# Kill alte Instanzen dieses Scripts (außer uns selbst)
SCRIPT_PATH="$(realpath "$0")"
for pid in $(pgrep -f "$SCRIPT_PATH"); do
  [[ "$pid" != "$$" ]] && kill "$pid" 2>/dev/null || true
done
sleep 0.5

# Funktion um aktuellen Git-Commit zu holen
get_commit() {
  git rev-parse HEAD 2>/dev/null || echo "none"
}

# Einmalig beim Start: pull & decrypt
git pull --ff-only || true
./decrypt

# Dann: watch loop
last_commit=$(get_commit)
while true; do
  # Fetch remote changes (ohne zu mergen)
  git fetch origin master 2>/dev/null || true
  
  current_commit=$(get_commit)
  remote_commit=$(git rev-parse origin/master 2>/dev/null || echo "none")
  
  # Wenn remote ahead ist: pull & decrypt
  if [[ "$current_commit" != "$remote_commit" ]]; then
    git pull --ff-only || true
    ./decrypt
    last_commit=$(get_commit)
  fi
  
  sleep 5  # alle 5 Sekunden checken (anpassbar)
done
