--!strict
-- Indique si le serveur tourne dans Studio. Sert aux comportements de repli :
--   * Nuit sans TeleportData ⇒ configuration simulée (solo, aile 1) ;
--   * AnalyticsService ⇒ no-op ;
--   * DataStores sans accès API ⇒ profil en mémoire.

local RunService = game:GetService("RunService")

local StudioMode = {}

function StudioMode.isStudio(): boolean
	return RunService:IsStudio()
end

return StudioMode
