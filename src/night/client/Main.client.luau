--!strict
-- Point d'entrée client de la place Night.
-- Phase 0 : interface du PROTOTYPE P0.5 (HUD, tablette caméras, signalement).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Shared.Log)
local CameraTablet = require(script.Parent.Proto.CameraTablet)
local Hud = require(script.Parent.Proto.Hud)
local ReportController = require(script.Parent.Proto.ReportController)

local log = Log.new("Night/Client")
local player = Players.LocalPlayer
log.info(`démarrage pour {player.Name}`)

local nightState = ReplicatedStorage:WaitForChild("NightState", 30)
if nightState == nil then
	log.warn("NightState introuvable : le serveur du prototype n'a pas démarré")
	return
end

local hud = Hud.new(player:WaitForChild("PlayerGui"), nightState)
local tablet = CameraTablet.new(hud)
ReportController.new(hud, tablet)
