# Guard the Museum — conventions du dépôt

À lire avant toute modification. Références : plan technique, périmètre et note de
conformité (documents de projet de Hugo, `roblox/*-guard-the-museum.md`).

## Le jeu en 3 lignes

Horreur légère en coop (1 à 4 joueurs) : des gardes de nuit surveillent un musée hanté
par caméras, patrouille, réparations et catalogue, et signalent les anomalies
(objet déplacé, disparu, tourné…). Chaque erreur fait monter la menace ; à 100, l'entité chasse.

## Stack

- **Luau natif `--!strict`** (pas de roblox-ts).
- **Rokit** (`rokit.toml`) fixe les versions de : Rojo 7.7, Wally, selene, StyLua, Lune, luau-lsp.
- **Rojo** synchronise le code vers Studio. Rojo ne gère **que le code** : le décor reste
  dans la place publiée (Hugo fait le level design dans Studio).
- **Lune** exécute les tests et les scripts hors Roblox (`tools/`).
- **Wally** : React-lua (`jsdotlua/react`, `jsdotlua/react-roblox` 17.2.1) déclaré pour
  l'UI de phase 2. Pas encore installé en CI : aucun code n'en dépend.
- **ProfileStore** (sauvegarde) sera copié dans `src/vendor/` (P1.8).
- **Réseau** : module `Net` maison construit sur `src/shared/Net/Contract.luau`. Pas de Knit.

## Arborescence

```
lobby.project.json / night.project.json   # 1 projet Rojo par place
src/shared/        → ReplicatedStorage.Shared       (les 2 places)
  Types.luau         types partagés (aucune valeur)
  Log.luau           journalisation pure
  Net/Contract.luau  SOURCE UNIQUE des remotes + validateurs
  Domain/            LOGIQUE PURE, sans API Roblox, testée sous Lune (Rng.luau…)
  Content/           DONNÉES uniquement (règles, objets, ailes, codex…) — à venir P1.1
  UI/                composants React-lua — à venir P2.3
src/server/common/ → ServerScriptService.Common     (services serveur communs)
src/lobby/server/  → ServerScriptService.Lobby      (place Lobby)
src/lobby/client/  → StarterPlayer.StarterPlayerScripts.Lobby
src/night/server/  → ServerScriptService.Night      (place Nuit)
src/night/client/  → StarterPlayer.StarterPlayerScripts.Night
src/vendor/        → ServerStorage.Vendor           (modules tiers copiés, non modifiés)
Packages/          → ReplicatedStorage.Packages     (Wally, optionnel, ignoré par git)
tests/**/*.spec.luau   specs Lune
tools/test.luau        lanceur de tests ; tools/lib/TestKit.luau (describe/it/expect)
tools/mocks/           MockDataStore, MockPlayers, MockClock, Signal
tools/check-strict.luau vérifie `--!strict` en tête de chaque fichier
maps/                  exports .rbxm des ailes (git LFS) — à venir P0.4
```

Nommage Rojo : `X.server.luau` = Script, `X.client.luau` = LocalScript, `X.luau` = ModuleScript,
`init.luau` = le dossier devient le ModuleScript.

## Commandes

```bash
rokit install                         # installe les outils aux versions fixées
rojo serve lobby.project.json         # sync vers Studio (place Lobby)
rojo serve night.project.json         # sync vers Studio (place Nuit)
lune run tools/test                   # tous les tests
lune run tools/test Rng               # seulement les specs dont le chemin contient "Rng"
lune run tools/check-strict           # --!strict partout
stylua src tests tools                # formate (CI : stylua --check)
selene src tests tools                # lint
rojo sourcemap lobby.project.json -o sourcemap.json   # pour luau-lsp dans l'éditeur
```

Sans Rokit (conteneur cloud qui n'atteint pas les releases GitHub) : `cargo install --locked stylua --version 2.5.2 --features luau`. Sans la feature `luau`, StyLua calcule la largeur des lignes autrement et la CI rejette le formatage.

La CI (`.github/workflows/ci.yml`) lance, sur chaque PR et chaque push sur `main` :
StyLua `--check`, `check-strict`, selene, `rojo build` des 2 places, `luau-lsp analyze`
(strict, définitions Roblox, sur `src/`) et les tests Lune. Elle n'utilise aucun secret.
**Une PR ne se fusionne que CI verte.**

## Règles de code

1. **`--!strict` en première ligne de chaque fichier `.luau`** (sauf `src/vendor/`). Vérifié en CI.
2. **`Domain/` est pur** : aucune API Roblox (`game`, `workspace`, `Instance`, `task`, `Random`,
   `os.time`, `tick`…). Le temps et l'aléa sont injectés (horloge en paramètre, `Domain/Rng`).
   Tout module de `Domain/` a des specs Lune.
3. **Requires dans `src/shared/`** : uniquement des chemins relatifs en chaîne
   (`require("./Rng")`, `require("../Types")`, `require("@self/Enfant")` depuis un `init.luau`),
   pour que le même fichier marche sous Lune et dans Roblox. Ailleurs (serveur, client) :
   requires par instance (`require(ReplicatedStorage.Shared.Domain.Rng)`).
   Les specs utilisent les alias `.luaurc` `@shared/…` et `@tools/…` (Lune uniquement).
4. **Le serveur décide de tout.** Le client affiche et envoie des intentions. Il ne décide
   jamais : anomalie active, menace, récompenses, possession d'un objet, succès d'une réparation.
5. **Toute remote est déclarée dans `Net/Contract.luau`** avec un sens, une limite de fréquence
   ou un cooldown (C→S) et un **validateur**. Le serveur rejette toute entrée invalide
   (type, valeurs énumérées, rôle, distance, cooldown, phase). Pas de RemoteEvent créé ailleurs.
   L'état continu (horloge, menace, phase) passe par des attributs sur l'objet `NightState`.
6. **`Content/` = données uniquement** (tables littérales typées), aucune logique. Ajouter une
   anomalie = ajouter une ligne de données (+ un tag dans la carte), pas du code.
7. Tags carte : objets à anomalie = tag `Anomalable` + attributs `ObjectId`, `Category`, `RoomId` ;
   caméras = tag `SecurityCam` + attribut `RoomId`.
8. Achats : `ProcessReceipt` idempotent (via `purchaseLog`), un seul script le gère ; game passes
   vérifiés par `UserOwnsGamePassAsync`, jamais copiés dans le profil.
9. Pas de secret dans le dépôt (clés Open Cloud, cookies…). Jamais.

## Pièges Roblox connus

- **Yields** : `*Async`, `WaitForChild`, `task.wait`, `InvokeServer` suspendent le thread.
  Jamais de yield dans un callback qui ne le supporte pas (`ProcessReceipt` doit rester court,
  `BindToClose` a 30 s max). Toujours `pcall` autour des appels réseau/DataStore/Policy/Teleport.
- **`task.wait` / `task.spawn` / `task.delay`**, jamais `wait`, `spawn`, `delay` (obsolètes).
  Pas de boucles `while true do task.wait() end` pour de la logique : utiliser des événements
  ou `RunService.Heartbeat` avec un pas de temps.
- **Réplication** : ce que le serveur crée/modifie dans `Workspace`/`ReplicatedStorage` est
  répliqué ; ce que le client modifie ne l'est pas (sauf physique de son personnage).
  `ServerStorage`/`ServerScriptService` sont invisibles côté client. Ne jamais faire confiance
  à une valeur venant du client.
- **StreamingEnabled** : côté client, une instance lointaine peut ne pas exister →
  `WaitForChild` avec délai ou modèles `Persistent`/`Atomic`. Décision (streaming ou non pour
  les salles vues par caméras) à prendre en P0.4.
- **TeleportData absent en Studio** : les téléportations ne marchent pas dans Studio.
  La place Nuit lancée seule doit charger une **configuration simulée** (`NightConfig` avec
  `simulated = true` : solo, aile 1, graine fixe).
- **DataStores en Studio** : sans « Enable Studio Access to API Services », les appels échouent
  → profil en mémoire (cf. `tools/mocks/MockDataStore` pour les tests).
- **AnalyticsService** : n'envoie rien en Studio ; appels serveur uniquement.
- `Players.LocalPlayer` n'existe que côté client. `PlayerAdded` peut avoir déjà été émis pour
  les joueurs présents : traiter aussi `Players:GetPlayers()` au démarrage.
- Réglage d'avatar du projet : **R15 Only** (taux DevEx majoré), à régler dans Studio.
- Un seul `rojo serve` à la fois vers Studio.

## Conformité (à respecter dans toute fonctionnalité)

- **Chat limité** (chat désactivé par défaut pour les comptes Kids/Select) : la coop ne dépend
  **jamais** du chat. Communication par **pings, marqueurs, emotes et messages prédéfinis**.
- **Aucun lien ni pseudo de réseau social dans le jeu** (TikTok, Discord, X…). Seulement sur la
  page du jeu.
- **Aucun PNJ conversationnel piloté par une IA** (ferait passer le jeu en 18+).
- **Récap / rediffusion de fin de nuit** : lancé par le joueur, passable, **jamais en boucle
  automatique et jamais récompensé**. Bouton de partage masqué si `IsContentSharingAllowed = false`.
- **Pas de caisses aléatoires payantes** ni d'avantage acheté au MVP. Si un jour un objet aléatoire
  payant est ajouté : probabilités affichées (somme 100 %) avant tout achat, et
  `PolicyService:GetPolicyInfoForPlayerAsync` (`ArePaidRandomItemsRestricted`) côté serveur,
  dans un `pcall`, avec repli.
- **Pas de gore** : ni sang réaliste, ni blessure réaliste, même un instant → label visé **Mild**.
  Option « scares réduits » obligatoire.
- Analytics : uniquement `AnalyticsService` natif, aucune donnée joueur envoyée à un tiers.

## Workflow des agents

- **Une branche `agent/<tâche>` et un worktree git par agent** ; jamais de commit direct sur `main`.
- Les branches `agent/*` sont des étapes intermédiaires : un agent **intégrateur** les réunit
  et ouvre **une seule PR par phase**. Push sur `main` : validation de Hugo obligatoire.
- Commits clairs, en français.
- Agents dans le cloud (sans Studio) : `Domain`, `Content`, tests, UI typée. Vérifier
  localement `lune run tools/test`, `stylua --check`, `selene` avant de rendre la main.
- **Tests de jeu dans Studio via le serveur MCP officiel de Roblox Studio sur le PC Windows
  de Hugo** (`start_stop_play`, `get_console_output`, `execute_luau`…). Obligatoire avant
  de fusionner un service serveur. Ces tests se font l'un après l'autre (un seul Studio).
- Aucune action extérieure (publication, dépense de Robux, Open Cloud, message) sans
  validation explicite de Hugo.
