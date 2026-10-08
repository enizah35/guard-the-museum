# Guard the Museum

Jeu Roblox d'horreur légère en coop (1 à 4 joueurs) : surveiller un musée hanté la nuit
et signaler les anomalies avant que la menace n'atteigne 100.

Conventions et règles : voir [CLAUDE.md](CLAUDE.md).

## Démarrer

1. Installer [Rokit](https://github.com/rojo-rbx/rokit), puis à la racine du dépôt :

   ```bash
   rokit install
   ```

2. Synchroniser le code vers Studio (plugin Rojo installé dans Studio), une place à la fois :

   ```bash
   rojo serve lobby.project.json   # place Lobby
   rojo serve night.project.json   # place Nuit
   ```

3. Lancer les tests (hors Studio) :

   ```bash
   lune run tools/test
   ```

Vérifications faites par la CI : `stylua --check src tests tools`, `lune run tools/check-strict`,
`selene src tests tools`, `rojo build` des 2 places, `luau-lsp analyze` et `lune run tools/test`.

Optionnel (UI, phase 2) : `wally install` pour récupérer React-lua dans `Packages/`.
