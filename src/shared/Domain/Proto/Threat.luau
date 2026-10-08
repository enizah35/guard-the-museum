--!strict
-- PROTOTYPE P0.5 — jauge de menace. Module PUR (aucune API Roblox).
-- La menace monte avec le temps pour chaque anomalie active non signalée,
-- et bouge d'un coup sur un signalement (juste : baisse, faux : hausse).

local ProtoConfig = require("../../Content/ProtoConfig")

type ProtoConfig = ProtoConfig.ProtoConfig

local Threat = {}

function Threat.clamp(value: number, cfg: ProtoConfig): number
	return math.clamp(value, 0, cfg.threatMax)
end

-- Avance la menace de `dt` secondes avec `activeCount` anomalies actives non signalées.
function Threat.tick(value: number, dt: number, activeCount: number, cfg: ProtoConfig): number
	assert(dt >= 0, "Threat.tick: dt négatif")
	return Threat.clamp(value + dt * activeCount * cfg.threatPerActiveAnomalyPerSecond, cfg)
end

-- Applique une variation ponctuelle (signalement juste ou faux).
function Threat.applyDelta(value: number, delta: number, cfg: ProtoConfig): number
	return Threat.clamp(value + delta, cfg)
end

function Threat.isMaxed(value: number, cfg: ProtoConfig): boolean
	return value >= cfg.threatMax
end

return Threat
