#!/usr/bin/env bash
set -euo pipefail

cd "$HOME/projekte/crypt-transfer"

INPUT="input"
ENC="encrypted"

# check: fehlt für irgendein input-file die encrypted/<rel>.enc ?
need_encrypt=0
while IFS= read -r -d '' f; do
  rel="${f#${INPUT}/}"
  [[ -f "${ENC}/${rel}.enc" ]] || { need_encrypt=1; break; }
done < <(find "$INPUT" -type f -print0)

# encrypt nur wenn nötig
if [[ "$need_encrypt" -eq 1 ]]; then
  ./encrypt
fi

# push nur wenn was geändert wurde
git add -A
git diff --cached --quiet && exit 0
git commit -m "auto sync"
git push
