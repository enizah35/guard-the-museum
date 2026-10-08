--!strict
-- Réglages du PROTOTYPE P0.5 (boucle jetable). DONNÉES uniquement.
-- Toutes les constantes de rythme sont ici : c'est le seul fichier à modifier pour régler le fun.
-- Les durées sont en secondes de jeu réel, la menace va de 0 à `threatMax`.
-- Avant de tester en jeu, `lune run tools/proto-sim` montre l'effet d'un réglage sur 50 nuits.

export type ProtoRuleId = "Moved" | "Missing"

export type ProtoConfig = {
	-- Nuit
	nightDurationSeconds: number, -- durée réelle d'une nuit (horloge accélérée 00:00 → 06:00)
	clockStartHour: number, -- heure affichée au début de la nuit
	clockEndHour: number, -- heure affichée à la fin de la nuit (victoire)
	briefingSeconds: number, -- compte à rebours avant le début de la nuit
	restartDelaySeconds: number, -- durée de l'écran de fin avant de relancer une nuit

	-- Anomalies
	firstAnomalyDelaySeconds: number, -- délai avant la première anomalie
	anomalyIntervalMinSeconds: number, -- intervalle min entre deux anomalies
	anomalyIntervalMaxSeconds: number, -- intervalle max entre deux anomalies
	maxActiveAnomalies: number, -- au-delà, le tirage est sauté (la menace monte déjà)
	rules: { ProtoRuleId }, -- règles actives du prototype

	-- Règle Moved : déplacement visible mais subtil
	moveOffsetMinStuds: number,
	moveOffsetMaxStuds: number,
	moveYawMinDegrees: number,
	moveYawMaxDegrees: number,

	-- Menace
	threatMax: number, -- défaite quand la menace atteint cette valeur
	threatPerActiveAnomalyPerSecond: number, -- hausse par anomalie active non signalée
	threatCorrectReport: number, -- variation sur un signalement juste (négatif = baisse)
	threatWrongReport: number, -- variation sur un faux signalement

	-- Score
	scoreCorrectReport: number,
	scoreWrongReport: number, -- le score ne descend jamais sous 0

	-- Signalement
	reportRangeStuds: number, -- distance max joueur ↔ objet (hors vue caméra)

	-- Divers
	seed: number, -- 0 = graine aléatoire à chaque serveur ; sinon nuits reproductibles
	fallbackMapEnabled: boolean, -- génère la carte de secours si aucun objet `Anomalable`
}

local ProtoConfig: ProtoConfig = {
	nightDurationSeconds = 360,
	clockStartHour = 0,
	clockEndHour = 6,
	briefingSeconds = 10,
	restartDelaySeconds = 15,

	firstAnomalyDelaySeconds = 15,
	anomalyIntervalMinSeconds = 25,
	anomalyIntervalMaxSeconds = 35,
	maxActiveAnomalies = 4,
	rules = { "Moved", "Missing" },

	moveOffsetMinStuds = 1.5,
	moveOffsetMaxStuds = 3,
	moveYawMinDegrees = 12,
	moveYawMaxDegrees = 30,

	threatMax = 100,
	threatPerActiveAnomalyPerSecond = 0.25,
	threatCorrectReport = -8,
	threatWrongReport = 10,

	scoreCorrectReport = 100,
	scoreWrongReport = -25,

	reportRangeStuds = 30,

	seed = 0,
	fallbackMapEnabled = true,
}

table.freeze(ProtoConfig.rules)
return table.freeze(ProtoConfig)
