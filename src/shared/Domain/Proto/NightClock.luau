--!strict
-- PROTOTYPE P0.5 — horloge accélérée de la nuit. Module PUR.
-- Convertit le temps réel écoulé en heure affichée (00:00 → 06:00 par défaut).

local ProtoConfig = require("../../Content/ProtoConfig")

type ProtoConfig = ProtoConfig.ProtoConfig

local NightClock = {}

-- Avancement de la nuit dans [0, 1].
function NightClock.progress(elapsed: number, cfg: ProtoConfig): number
	if cfg.nightDurationSeconds <= 0 then
		return 1
	end
	return math.clamp(elapsed / cfg.nightDurationSeconds, 0, 1)
end

-- Minutes de jeu écoulées depuis minuit (entier, arrondi à la minute inférieure).
function NightClock.gameMinutes(elapsed: number, cfg: ProtoConfig): number
	local span = (cfg.clockEndHour - cfg.clockStartHour) * 60
	return math.floor(cfg.clockStartHour * 60 + NightClock.progress(elapsed, cfg) * span)
end

-- Texte « HH:MM ».
function NightClock.format(elapsed: number, cfg: ProtoConfig): string
	local minutes = NightClock.gameMinutes(elapsed, cfg)
	return string.format("%02d:%02d", (minutes // 60) % 24, minutes % 60)
end

function NightClock.isOver(elapsed: number, cfg: ProtoConfig): boolean
	return elapsed >= cfg.nightDurationSeconds
end

return NightClock
