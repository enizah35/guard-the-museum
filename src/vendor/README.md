# src/vendor — modules tiers copiés

Synchronisé par Rojo dans `ServerStorage.Vendor` (serveur uniquement).

## À copier (tâche P1.8)

- **ProfileStore** (loleris) — sauvegarde avec verrouillage de session.
  Copier le fichier `ProfileStore.luau` de la dernière version publiée ici,
  **sans le modifier**, et noter ci-dessous la version et la source.

| Module | Version | Source | Date de copie |
|---|---|---|---|
| ProfileStore | à compléter | à compléter | à compléter |

## Règles

- Un module vendored n'est jamais modifié sur place : on le remplace par une
  version publiée et on met à jour ce tableau.
- Les fichiers vendored peuvent ne pas être en `--!strict` : ils sont exclus de
  la vérification `--!strict`, de selene et de StyLua (voir CI).
