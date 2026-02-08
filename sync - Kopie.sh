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

INPUT="input"
ENC="encrypted"

count_files() {
  find "$INPUT" -type f 2>/dev/null | wc -l
}

# Einmalig beim Start: sync falls nötig
need_encrypt=0
while IFS= read -r -d '' f; do
  rel="${f#${INPUT}/}"
  [[ -f "${ENC}/${rel}.enc" ]] || { need_encrypt=1; break; }
done < <(find "$INPUT" -type f -print0 2>/dev/null)

if [[ "$need_encrypt" -eq 1 ]]; then
  ./encrypt
  git add -A
  git diff --cached --quiet || {
    git commit -m "auto sync"
    git push
  }
fi

# Dann: watch loop
last_count=$(count_files)
while true; do
  current_count=$(count_files)
  
  if [[ "$current_count" != "$last_count" ]]; then
    sleep 1  # debounce
    ./encrypt
    git add -A
    git diff --cached --quiet || {
      git commit -m "auto sync"
      git push
    }
    last_count=$current_count
  fi
  
  sleep 1
done
