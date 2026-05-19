#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <file1> [file2 ...]"
  exit 1
fi

# Ensure we're in a git repo
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Erreur: ce script doit être exécuté depuis la racine d'un dépôt git." >&2
  exit 2
fi

FILES=()
for p in "$@"; do
  if [ ! -e "$p" ]; then
    echo "Avertissement: '$p' n'existe pas, skipping." >&2
    continue
  fi
  cp -r "$p" ./
  FILES+=("$(basename "$p")")
done

if [ ${#FILES[@]} -eq 0 ]; then
  echo "Aucun fichier valide à ajouter." >&2
  exit 3
fi

git add -- "${FILES[@]}"
git commit -m "Ajout: ${FILES[*]}" || echo "Rien à committer"
git push origin main

echo "Push terminé."
