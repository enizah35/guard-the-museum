--!strict
-- Point d'entrée serveur de la place Night. Phase 0 : journalise le démarrage.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Log = require(ReplicatedStorage.Shared.Log)
local StudioMode = require(ServerScriptService.Common.StudioMode)

local log = Log.new("Night/Server")
log.info(`démarrage (Studio : {StudioMode.isStudio()})`)
