--!strict
-- PROTOTYPE P0.5 — planification des anomalies. Module PUR (temps et aléa injectés).
-- * Une anomalie toutes les `anomalyIntervalMin..MaxSeconds` secondes.
-- * Jamais deux anomalies sur le même objet en même temps.
-- * Au-delà de `maxActiveAnomalies`, le tirage est sauté (on attend le suivant).
-- Le serveur applique ensuite l'effet visuel (déplacement, disparition).

local ProtoConfig = require("../../Content/ProtoConfig")
local Rng = require("../Rng")
local Types = require("../../Types")

type ProtoConfig = ProtoConfig.ProtoConfig
type Rng = Rng.Rng

-- Objet anomalable connu du serveur (lu depuis les tags de la carte).
export type ObjectRef = {
	objectId: Types.ObjectId,
	roomId: Types.RoomId,
	category: string,
}

-- Paramètres de la règle Moved (en studs et en degrés, autour de la position de référence).
export type MoveParams = {
	offsetX: number,
	offsetZ: number,
	yawDegrees: number,
}

export type Anomaly = {
	key: Types.AnomalyKey,
	ruleId: ProtoConfig.ProtoRuleId,
	objectId: Types.ObjectId,
	roomId: Types.RoomId,
	startedAt: number,
	move: MoveParams?,
}

export type Scheduler = {
	nextAt: number,
	active: { [Types.ObjectId]: Anomaly },
	activeCount: number,
}

local AnomalyScheduler = {}

function AnomalyScheduler.makeKey(ruleId: string, objectId: string, roomId: string): Types.AnomalyKey
	return `{ruleId}:{objectId}:{roomId}`
end

local function between(rng: Rng, min: number, max: number): number
	return min + Rng.nextFloat(rng) * (max - min)
end

function AnomalyScheduler.nextInterval(rng: Rng, cfg: ProtoConfig): number
	return between(rng, cfg.anomalyIntervalMinSeconds, cfg.anomalyIntervalMaxSeconds)
end

-- Tire un déplacement subtil : distance et angle dans les bornes, sens aléatoires.
function AnomalyScheduler.rollMove(rng: Rng, cfg: ProtoConfig): MoveParams
	local angle = Rng.nextFloat(rng) * 2 * math.pi
	local distance = between(rng, cfg.moveOffsetMinStuds, cfg.moveOffsetMaxStuds)
	local yaw = between(rng, cfg.moveYawMinDegrees, cfg.moveYawMaxDegrees)
	if Rng.nextFloat(rng) < 0.5 then
		yaw = -yaw
	end
	return {
		offsetX = math.cos(angle) * distance,
		offsetZ = math.sin(angle) * distance,
		yawDegrees = yaw,
	}
end

-- `now` : secondes écoulées depuis le début de la nuit.
function AnomalyScheduler.new(now: number, cfg: ProtoConfig): Scheduler
	return {
		nextAt = now + cfg.firstAnomalyDelaySeconds,
		active = {},
		activeCount = 0,
	}
end

-- À appeler à chaque pas de temps. Renvoie l'anomalie créée, ou nil.
function AnomalyScheduler.update(
	scheduler: Scheduler,
	now: number,
	objects: { ObjectRef },
	rng: Rng,
	cfg: ProtoConfig
): Anomaly?
	if now < scheduler.nextAt then
		return nil
	end
	scheduler.nextAt = now + AnomalyScheduler.nextInterval(rng, cfg)
	if scheduler.activeCount >= cfg.maxActiveAnomalies or #cfg.rules == 0 then
		return nil
	end

	local candidates: { ObjectRef } = {}
	for _, object in objects do
		if scheduler.active[object.objectId] == nil then
			table.insert(candidates, object)
		end
	end
	if #candidates == 0 then
		return nil
	end

	local object = Rng.pick(rng, candidates)
	local ruleId = Rng.pick(rng, cfg.rules)
	local anomaly: Anomaly = {
		key = AnomalyScheduler.makeKey(ruleId, object.objectId, object.roomId),
		ruleId = ruleId,
		objectId = object.objectId,
		roomId = object.roomId,
		startedAt = now,
		move = if ruleId == "Moved" then AnomalyScheduler.rollMove(rng, cfg) else nil,
	}
	scheduler.active[object.objectId] = anomaly
	scheduler.activeCount += 1
	return anomaly
end

-- Retire l'anomalie active sur cet objet (signalement juste). Renvoie l'anomalie retirée.
function AnomalyScheduler.resolve(scheduler: Scheduler, objectId: Types.ObjectId): Anomaly?
	local anomaly = scheduler.active[objectId]
	if anomaly == nil then
		return nil
	end
	scheduler.active[objectId] = nil
	scheduler.activeCount -= 1
	return anomaly
end

-- Anomalies actives triées par date d'apparition (pour l'affichage et les tests).
function AnomalyScheduler.activeList(scheduler: Scheduler): { Anomaly }
	local list: { Anomaly } = {}
	for _, anomaly in scheduler.active do
		table.insert(list, anomaly)
	end
	table.sort(list, function(a: Anomaly, b: Anomaly): boolean
		if a.startedAt == b.startedAt then
			return a.key < b.key
		end
		return a.startedAt < b.startedAt
	end)
	return list
end

return AnomalyScheduler
