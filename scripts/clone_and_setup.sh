#!/usr/bin/env bash
set -euo pipefail

REPO_URL=${1:-https://github.com/fstl6841/Share_point.git}
TARGET_DIR=${2:-$HOME/Share_point}

if [ -d "$TARGET_DIR" ]; then
  echo "Le dossier $TARGET_DIR existe déjà. Abandon." >&2
  exit 1
fi

echo "Clonage de $REPO_URL dans $TARGET_DIR"
git clone "$REPO_URL" "$TARGET_DIR"

if [ -f "$TARGET_DIR/upload_and_push.sh" ]; then
  chmod +x "$TARGET_DIR/upload_and_push.sh"
fi

echo "Installation terminée. Pour garder le dépôt à jour, utilisez scripts/pull_updates.sh ou installez la tâche cron avec scripts/setup_cron_pull.sh"
