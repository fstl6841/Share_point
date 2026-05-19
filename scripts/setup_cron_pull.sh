#!/usr/bin/env bash
set -euo pipefail

# Usage: setup_cron_pull.sh /chemin/vers/repo interval_minutes
# Example: setup_cron_pull.sh $HOME/Share_point 15

if [ "$#" -lt 2 ]; then
  echo "Usage: $0 /chemin/vers/repo interval_minutes" >&2
  exit 1
fi

REPO_PATH=$1
INTERVAL=$2

if [ ! -d "$REPO_PATH/.git" ]; then
  echo "Erreur: $REPO_PATH n'est pas un dépôt git." >&2
  exit 1
fi

SCRIPT="$REPO_PATH/scripts/pull_updates.sh"
if [ ! -f "$SCRIPT" ]; then
  echo "Script $SCRIPT introuvable." >&2
  exit 1
fi

# Build cron schedule: every INTERVAL minutes
if [ "$INTERVAL" -le 0 ] 2>/dev/null; then
  echo "Interval doit être > 0" >&2
  exit 1
fi

CRON_ENTRY="*/$INTERVAL * * * * $SCRIPT $REPO_PATH >/dev/null 2>&1"

(crontab -l 2>/dev/null | grep -v -F "$SCRIPT" || true; echo "$CRON_ENTRY") | crontab -

echo "Tâche cron installée: $CRON_ENTRY"
