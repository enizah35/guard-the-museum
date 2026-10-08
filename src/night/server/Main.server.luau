--!strict
-- Point d'entrée serveur de la place Night.
-- Phase 0 : lance le PROTOTYPE P0.5 de la boucle (carte de secours si besoin + NightService).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Log = require(ReplicatedStorage.Shared.Log)
local ProtoConfig = require(ReplicatedStorage.Shared.Content.ProtoConfig)
local NetServer = require(ServerScriptService.Common.NetServer)
local StudioMode = require(ServerScriptService.Common.StudioMode)
local FallbackMap = require(script.Parent.FallbackMap)
local NightService = require(script.Parent.Proto.NightService)

local log = Log.new("Night/Server")
log.info(`démarrage (Studio : {StudioMode.isStudio()})`)

NetServer.init()

if ProtoConfig.fallbackMapEnabled and FallbackMap.ensure() then
	log.info("aucun objet Anomalable trouvé : carte de secours générée (FallbackMap)")
end

NightService.start()
