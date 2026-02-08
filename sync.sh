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
STATEFILE=".sync-state"

mkdir -p "$INPUT" "$ENC"

# Funktion: Erstelle Liste aller input-Dateien (relativ)
get_input_files() {
  find "$INPUT" -type f -print0 2>/dev/null | while IFS= read -r -d '' f; do
    echo "${f#${INPUT}/}"
  done | sort
}

# Funktion: Erstelle Liste aller encrypted-Dateien (ohne .enc Endung)
get_encrypted_files() {
  find "$ENC" -type f -name "*.enc" -print0 2>/dev/null | while IFS= read -r -d '' f; do
    rel="${f#${ENC}/}"
    echo "${rel%.enc}"
  done | sort
}

# Funktion: Prüfe ob Verschlüsselung nötig ist
need_encrypt() {
  while IFS= read -r -d '' f; do
    rel="${f#${INPUT}/}"
    [[ -f "${ENC}/${rel}.enc" ]] || return 0
  done < <(find "$INPUT" -type f -print0 2>/dev/null)
  return 1
}

# Funktion: Lösche verwaiste .enc Dateien
cleanup_deleted() {
  local deleted=0
  
  # Aktuelle input-Dateien
  get_input_files > "${STATEFILE}.current"
  
  # Alle encrypted-Dateien
  get_encrypted_files > "${STATEFILE}.encrypted"
  
  # Finde Dateien die in encrypted/ sind, aber nicht in input/
  while IFS= read -r enc_file; do
    if ! grep -Fxq "$enc_file" "${STATEFILE}.current"; then
      rm -f "${ENC}/${enc_file}.enc"
      echo "🗑️  Deleted: ${enc_file}.enc (source file removed)"
      deleted=1
    fi
  done < "${STATEFILE}.encrypted"
  
  rm -f "${STATEFILE}.current" "${STATEFILE}.encrypted"
  
  return $deleted
}

# Einmalig beim Start: sync falls nötig
if need_encrypt; then
  ./encrypt
  git add -A
  git diff --cached --quiet || {
    git commit -m "auto sync"
    git push
  }
fi

# Cleanup bei Start
if cleanup_deleted; then
  git add -A
  git diff --cached --quiet || {
    git commit -m "auto cleanup: removed deleted files"
    git push
  }
fi

# Watch loop
last_count=$(get_input_files | wc -l)
while true; do
  current_count=$(get_input_files | wc -l)
  
  # Änderung erkannt (neue oder gelöschte Dateien)
  if [[ "$current_count" != "$last_count" ]]; then
    sleep 1  # debounce
    
    # Verschlüssele neue/geänderte Dateien
    if need_encrypt; then
      ./encrypt
    fi
    
    # Cleanup gelöschter Dateien
    cleanup_deleted
    
    # Commit & Push
    git add -A
    git diff --cached --quiet || {
      git commit -m "auto sync"
      git push
    }
    
    last_count=$current_count
  fi
  
  sleep 1
done
