#!/usr/bin/env bash
set -euo pipefail

# Usage: pull_updates.sh [repo_path]
REPO_PATH=${1:-$PWD}

if [ ! -d "$REPO_PATH/.git" ]; then
  echo "Erreur: $REPO_PATH n'est pas un dépôt git." >&2
  exit 1
fi

cd "$REPO_PATH"
echo "Pulling latest changes in $REPO_PATH"
git fetch origin
git pull origin main
echo "Pull terminé. Branch: $(git rev-parse --abbrev-ref HEAD)"
