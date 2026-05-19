# Share_point

Ce dépôt sert à partager des fichiers entre ordinateurs via GitHub.

Usage rapide
- Cloner le dépôt sur une autre machine :

```bash
git clone https://github.com/fstl6841/Share_point.git
```

- Ajouter un fichier, committer et pousser :

```bash
cp /chemin/vers/fichier ./
git add .
git commit -m "Ajout de fichier"
git push origin main
```

Conseils pratiques
- Si vous préférez l'authentification SSH (plus pratique), ajoutez votre clé publique à GitHub.
- Pour les fichiers >100MB, utilisez Git LFS : `git lfs install` puis `git lfs track "*.psd"` (exemple).
- Rendez le dépôt privé si les fichiers sont sensibles (Settings → Repository settings → Change visibility).

Script d'aide
- Un script simple `upload_and_push.sh` est fourni pour copier un ou plusieurs fichiers dans le dépôt, commit et push automatiquement.

Support
Si vous voulez que je :
- ajoute un `.gitignore` personnalisé, ou
- active `git lfs` et configure des patterns, ou
- ajoute un workflow GitHub Actions pour sauvegarde automatisée,
dites-le et je m'en occupe.

---
Fichier généré automatiquement par un assistant pour faciliter le partage de fichiers.