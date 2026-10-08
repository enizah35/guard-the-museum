--!strict
-- Types partagés entre serveur, client et Domain.
-- Ce module ne contient QUE des types (aucune valeur, aucune API Roblox) :
-- il est donc chargeable sous Lune comme dans Roblox.

-- Rôles (§5 P1.6). En solo et en duo, plusieurs rôles sont fusionnés côté serveur.
export type RoleId = "Cameras" | "Patrol" | "Technician" | "Curator"

-- Identifiants de contenu : chaînes stables définies dans shared/Content (données uniquement).
export type RuleId = string -- ex. "Moved", "Missing", "Rotated"…
export type ObjectId = string -- attribut `ObjectId` des objets tagués `Anomalable`
export type RoomId = string -- attribut `RoomId` des salles et des caméras
export type CameraId = string
export type WingId = string
export type PodId = string

-- Clé d'anomalie = règle × objet × salle, ex. "Moved:Vase_03:Hall".
export type AnomalyKey = string

export type Difficulty = "Normal" | "Hard"

-- Phases d'une Nuit (état continu répliqué par attributs sur l'objet `NightState`).
export type NightPhase = "Briefing" | "Running" | "Hunt" | "Ended"

-- Configuration d'une Nuit transmise via TeleportData depuis le Lobby.
-- En Studio (pas de TeleportData), une configuration simulée est chargée : solo, aile 1.
export type NightConfig = {
	wingId: WingId,
	difficulty: Difficulty,
	partyUserIds: { number },
	seed: number,
	simulated: boolean,
}

-- Contenu de `Night.Report` (C→S).
export type ReportPayload = {
	roomId: RoomId,
	objectId: ObjectId,
	ruleId: RuleId,
}

-- Contenu de `Night.ReportResult` (S→C).
export type ReportResult = {
	ok: boolean,
	anomalyKey: AnomalyKey?,
	threatDelta: number,
}

return {}
