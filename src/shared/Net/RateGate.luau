--!strict
-- Garde de fréquence pour les remotes C→S, d'après `rateLimitPerSecond` et
-- `cooldownSeconds` du contrat. Module PUR : l'horloge est passée en paramètre.
-- Une instance par (remote, joueur) côté serveur.

local RateGate = {}

export type Gate = {
	rateLimitPerSecond: number?,
	cooldownSeconds: number?,
	lastAcceptedAt: number?,
	windowStart: number,
	windowCount: number,
}

function RateGate.new(rateLimitPerSecond: number?, cooldownSeconds: number?): Gate
	return {
		rateLimitPerSecond = rateLimitPerSecond,
		cooldownSeconds = cooldownSeconds,
		lastAcceptedAt = nil,
		windowStart = -math.huge,
		windowCount = 0,
	}
end

-- Renvoie true (et enregistre l'appel) si l'appel est accepté à l'instant `now`.
function RateGate.tryPass(gate: Gate, now: number): boolean
	local cooldown = gate.cooldownSeconds
	local last = gate.lastAcceptedAt
	if cooldown ~= nil and last ~= nil and now - last < cooldown then
		return false
	end
	local limit = gate.rateLimitPerSecond
	if limit ~= nil then
		if now - gate.windowStart >= 1 then
			gate.windowStart = now
			gate.windowCount = 0
		end
		if gate.windowCount >= limit then
			return false
		end
		gate.windowCount += 1
	end
	gate.lastAcceptedAt = now
	return true
end

return RateGate
