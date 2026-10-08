--!strict
-- Point d'entrée client de la place Night. Phase 0 : journalise le démarrage.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Shared.Log)

local log = Log.new("Night/Client")
log.info(`démarrage pour {Players.LocalPlayer.Name}`)
