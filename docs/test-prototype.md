# Tester le prototype P0.5 (boucle jetable)

Objectif : répondre à **« une nuit est-elle amusante à 2 ? »** avant d'aller plus loin.
Le prototype est volontairement minimal : 2 règles (Déplacé, Disparu), signalement, menace,
horloge, tablette caméras, écran de fin. Tout le code « jetable » est repérable :

- `src/shared/Content/ProtoConfig.luau` : **tous les réglages** (seul fichier à modifier pour régler le fun) ;
- `src/shared/Domain/Proto/` : logique pure (Threat, NightClock, AnomalyScheduler, ReportJudge, NightLoop), testée sous Lune ;
- `src/night/server/FallbackMap.luau` : carte de secours (à supprimer quand la greybox existe) ;
- `src/night/server/Proto/` et `src/night/client/Proto/` : services serveur et interface client minces ;
- `tools/proto-sim.luau` : simulation d'équilibrage hors Studio.

## Lancer

1. À la racine du dépôt (branche `agent/p0-prototype`) :

   ```bash
   rokit install
   rojo serve night.project.json
   ```

2. Dans Studio : ouvrir une place vide (modèle **Baseplate**) ou la place Nuit, puis
   plugin Rojo → **Connect**. Le code arrive dans ReplicatedStorage, ServerScriptService
   et StarterPlayerScripts.
3. **Solo** : bouton **Play** (F5).
4. **À 2** : onglet **Test** → *Clients and Servers* → **2 Players** → **Start**. Studio ouvre un
   serveur et 2 fenêtres clients. Pour arrêter : **Cleanup**.

Carte : si le Workspace contient des objets tagués `Anomalable` (attributs `ObjectId`, `Category`,
`RoomId`) et des caméras `SecurityCam` (`RoomId`, `CameraId`), ils sont utilisés. Sinon le serveur
génère la carte de secours : 4 salles (Hall, Galerie, Sculptures, Archives), 12 objets, 3 caméras
(les Archives n'ont pas de caméra : il faut y aller à pied). Message dans la sortie :
`[GTM][Night/Server] aucun objet Anomalable trouvé : carte de secours générée`.

> Si la place a `Workspace.StreamingEnabled` activé et une grande carte, les vues caméras de
> salles lointaines peuvent être vides. Pour ce prototype, le plus simple est de désactiver
> StreamingEnabled (la carte de secours est déjà en `ModelStreamingMode = Persistent`).

## Commandes de jeu

| Action | Clavier / souris | Tactile |
|---|---|---|
| Signaler un objet | clic gauche sur l'objet (à moins de 30 studs, ou vu depuis une caméra de sa salle) | tap sur l'objet |
| Choisir la règle | `1` Déplacé, `2` Disparu, ou boutons du menu | boutons du menu |
| Ouvrir / quitter les caméras | `C` | bouton « Caméras » à gauche / « Quitter » |
| Caméra précédente / suivante | `Q` / `E` (ou flèches gauche / droite) | boutons ◀ ▶ |

Un objet **disparu** se signale en cliquant à l'endroit où il était (il reste « cliquable »).
Délai de 3 s entre deux signalements (contrat réseau).

Déroulé : briefing de 10 s (mémorisez les salles) → nuit de 6 min (00:00 → 06:00) → écran de fin
(victoire ou défaite, signalements justes et faux, score) → nouvelle nuit après 15 s.

Le serveur écrit chaque anomalie dans la **sortie serveur** (`[GTM][Night/NightService] anomalie
Moved:Hall_Vase:Hall à 47 s`) : pratique pour vérifier, mais ne la regardez pas pendant un vrai test.

## Vérifications hors Studio

```bash
lune run tools/test          # specs (dont Domain/Proto/*)
lune run tools/check-strict
stylua --check src tests tools
selene src tests tools
rojo build night.project.json -o night.rbxl
lune run tools/proto-sim     # effet des réglages sur 50 nuits simulées
```

`proto-sim` joue des nuits avec une équipe fictive qui signale chaque anomalie après N secondes.
Avec les réglages actuels : équipe qui réagit en moins de 45 s → victoire ; ~60 s avec quelques
faux signalements → défaite vers 4 min 45 ; équipe passive → défaite vers 2 min 40.

## 5 questions pour juger le fun (et quoi régler)

1. **Est-ce que je remarque les anomalies, et est-ce satisfaisant de les trouver ?**
   Trop facile → baisser `moveOffsetMinStuds/MaxStuds` et `moveYawMinDegrees/MaxDegrees`.
   Introuvable → les augmenter. « Disparu » trop évident par rapport à « Déplacé » → retirer
   temporairement `"Missing"` de `rules` pour comparer.
2. **Y a-t-il des temps morts, ou au contraire de la panique permanente ?**
   Régler `anomalyIntervalMinSeconds/MaxSeconds` (rythme), `firstAnomalyDelaySeconds`
   (montée en tension) et `maxActiveAnomalies` (cumul possible).
3. **La menace crée-t-elle de la tension sans sembler injuste ?**
   `threatPerActiveAnomalyPerSecond` (pression du temps), `threatCorrectReport` (récompense),
   `threatWrongReport` (punition des faux signalements : trop forte → on n'ose plus signaler,
   trop faible → on signale tout au hasard). Vérifier ensuite avec `lune run tools/proto-sim`.
4. **À 2, est-ce qu'on se répartit naturellement le travail (l'un aux caméras, l'autre en ronde) ?**
   Si l'un s'ennuie : réduire `reportRangeStuds` (la ronde devient nécessaire) ou rendre les caméras
   moins pratiques ; si personne ne va aux caméras, elles ne servent pas encore : noter pourquoi.
   Noter aussi si le retour d'équipe (« ✔ Hugo : Déplacé sur Hall_Vase ») suffit sans chat.
5. **Une nuit de 6 min donne-t-elle envie d'en relancer une ?**
   `nightDurationSeconds` (durée), `restartDelaySeconds` (pause), `scoreCorrectReport` /
   `scoreWrongReport`. Noter ce qui manque le plus (sons, peur, variété des règles, rôles…).

Pour rejouer exactement la même nuit (comparer deux réglages) : mettre `seed` à un nombre non nul.

## Limites connues du prototype

- Défaite immédiate à 100 de menace (pas encore de chasse par l'entité).
- Pas de rôles, pas de briefing interactif, pas de son à part un « ping », pas d'option
  « scares réduits » (aucun scare dans le proto).
- Une anomalie peut apparaître sous les yeux d'un joueur (le vrai jeu les fera apparaître hors de vue).
- Le clic sur l'emplacement d'un objet disparu affiche son contour de sélection : on peut
  « balayer » une salle au clic. À traiter si le test montre que les joueurs le font.
- Mauvaise règle sur le bon objet = faux signalement (choix strict, à discuter).
