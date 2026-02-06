#!/usr/bin/env bash
set -e

KEYDIR="$HOME/projekte/keys"

GH_USER=$(cat "$KEYDIR/gh-username.txt")
GH_PAT=$(cat "$KEYDIR/gh-pat.txt")

REPO="crypt-transfer"

git add .
git commit -m "auto update" || true

git push https://$GH_USER:$GH_PAT@github.com/$GH_USER/$REPO.git

