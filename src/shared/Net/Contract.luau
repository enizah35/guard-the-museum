--!strict
-- Contrat réseau : SOURCE UNIQUE de toutes les remotes (plan technique §3).
-- Règles :
--   * Toute remote utilisée par le jeu est déclarée ici, avec un validateur.
--   * Le serveur rejette toute entrée C→S dont le validateur renvoie false.
--   * Ce module est PUR (pas d'API Roblox hors `typeof`) : il est testé sous Lune.
-- Squelette de phase 0 : quelques remotes d'exemple. La liste complète et le
-- wrapper typé `Net.luau` arrivent en P1.4.

local Types = require("../Types")

export type Direction = "ClientToServer" | "ServerToClient"

-- Renvoie (true) si le contenu est acceptable, sinon (false, raison).
export type Validator = (payload: unknown) -> (boolean, string?)

export type RemoteSpec = {
	name: string,
	direction: Direction,
	-- Nombre maximal d'appels par seconde et par joueur (C→S uniquement).
	rateLimitPerSecond: number?,
	-- Délai minimal entre deux appels acceptés, en secondes (C→S uniquement).
	cooldownSeconds: number?,
	validate: Validator,
}

local MAX_ID_LENGTH = 64

local function isId(value: unknown): boolean
	return type(value) == "string" and #value > 0 and #value <= MAX_ID_LENGTH
end

local function noPayload(payload: unknown): (boolean, string?)
	if payload ~= nil then
		return false, "aucun contenu attendu"
	end
	return true
end

local function validateReport(payload: unknown): (boolean, string?)
	if type(payload) ~= "table" then
		return false, "table attendue"
	end
	local t = payload :: { [unknown]: unknown }
	for key in t do
		if key ~= "roomId" and key ~= "objectId" and key ~= "ruleId" then
			return false, "champ inattendu"
		end
	end
	if not (isId(t.roomId) and isId(t.objectId) and isId(t.ruleId)) then
		return false, "roomId, objectId et ruleId doivent être des identifiants"
	end
	return true
end

local function validateReportResult(payload: unknown): (boolean, string?)
	if type(payload) ~= "table" then
		return false, "table attendue"
	end
	local t = payload :: { [unknown]: unknown }
	if type(t.ok) ~= "boolean" or type(t.threatDelta) ~= "number" then
		return false, "ok (boolean) et threatDelta (number) attendus"
	end
	if t.anomalyKey ~= nil and not isId(t.anomalyKey) then
		return false, "anomalyKey invalide"
	end
	return true
end

local function validatePing(payload: unknown): (boolean, string?)
	if typeof(payload) ~= "Vector3" then
		return false, "Vector3 attendu"
	end
	return true
end

local function validatePodId(payload: unknown): (boolean, string?)
	if not isId(payload) then
		return false, "podId invalide"
	end
	return true
end

-- Formes des contenus, réexportées pour les appelants (les validateurs s'y conforment).
export type ReportPayload = Types.ReportPayload
export type ReportResult = Types.ReportResult

local Contract: { [string]: RemoteSpec } = {
	["Lobby.JoinPod"] = {
		name = "Lobby.JoinPod",
		direction = "ClientToServer",
		rateLimitPerSecond = 2,
		validate = validatePodId,
	},
	["Lobby.LeavePod"] = {
		name = "Lobby.LeavePod",
		direction = "ClientToServer",
		rateLimitPerSecond = 2,
		validate = noPayload,
	},
	["Night.Report"] = {
		name = "Night.Report",
		direction = "ClientToServer",
		cooldownSeconds = 3,
		validate = validateReport,
	},
	["Night.ReportResult"] = {
		name = "Night.ReportResult",
		direction = "ServerToClient",
		validate = validateReportResult,
	},
	["Night.Ping"] = {
		name = "Night.Ping",
		direction = "ClientToServer",
		rateLimitPerSecond = 1,
		validate = validatePing,
	},
}

return table.freeze(Contract)
