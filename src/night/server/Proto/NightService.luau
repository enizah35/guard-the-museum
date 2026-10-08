--!strict
-- PROTOTYPE P0.5 — service serveur de la boucle de nuit (mince : la logique est dans
-- Shared.Domain.Proto.NightLoop). Rôle :
-- * faire avancer NightLoop à chaque Heartbeat et appliquer ses événements à la carte ;
-- * publier l'état continu en attributs sur ReplicatedStorage.NightState ;
-- * recevoir Night.Report / Night.ViewCamera, valider (phase, objet, salle, distance ou
--   caméra regardée), juger, puis diffuser Night.ReportResult à toute l'équipe.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Log = require(ReplicatedStorage.Shared.Log)
local NightLoop = require(ReplicatedStorage.Shared.Domain.Proto.NightLoop)
local ProtoConfig = require(ReplicatedStorage.Shared.Content.ProtoConfig)
local ReportJudge = require(ReplicatedStorage.Shared.Domain.Proto.ReportJudge)
local Types = require(ReplicatedStorage.Shared.Types)
local NetServer = require(ServerScriptService.Common.NetServer)
local ObjectRegistry = require(script.Parent.ObjectRegistry)

local log = Log.new("Night/NightService")

local NightService = {}

local state: NightLoop.State
local nightState: Folder
local viewingCamera: { [Player]: string } = {}

local function setAttribute(name: string, value: any)
	if nightState:GetAttribute(name) ~= value then
		nightState:SetAttribute(name, value)
	end
end

local function publish()
	setAttribute("Phase", state.phase)
	setAttribute("NightElapsed", math.floor(state.nightElapsed))
	setAttribute("PhaseSecondsLeft", math.ceil(NightLoop.secondsLeftInPhase(state)))
	setAttribute("Threat", math.floor(state.threat * 10 + 0.5) / 10)
	setAttribute("Score", state.score)
	setAttribute("CorrectReports", state.correctReports)
	setAttribute("WrongReports", state.wrongReports)
	setAttribute("ActiveAnomalies", state.scheduler.activeCount)
	setAttribute("Outcome", state.outcome or "")
end

local function applyEvents(events: { NightLoop.Event })
	for _, event in events do
		if event.kind == "AnomalySpawned" then
			local anomaly = event.anomaly
			if anomaly.ruleId == "Moved" and anomaly.move ~= nil then
				ObjectRegistry.applyMoved(anomaly.objectId, anomaly.move)
			elseif anomaly.ruleId == "Missing" then
				ObjectRegistry.applyMissing(anomaly.objectId)
			end
			-- Journal serveur uniquement (jamais envoyé aux clients : ce serait de la triche).
			log.info(`anomalie {anomaly.key} à {math.floor(anomaly.startedAt)} s`)
		elseif event.kind == "NightStarted" then
			ObjectRegistry.restoreAll()
			log.info("la nuit commence")
		elseif event.kind == "NightEnded" then
			log.info(`fin de nuit : {event.outcome} (score {state.score})`)
		elseif event.kind == "NightReset" then
			ObjectRegistry.restoreAll()
			viewingCamera = {}
		end
	end
end

local function characterPosition(player: Player): Vector3?
	local character = player.Character
	if character == nil then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root ~= nil and root:IsA("BasePart") then
		return (root :: BasePart).Position
	end
	return nil
end

-- Le joueur peut-il signaler cet objet ? (à portée, ou via une caméra de la même salle)
local function canSee(player: Player, objectId: string, roomId: string): boolean
	local cameraId = viewingCamera[player]
	if cameraId ~= nil then
		local camera = ObjectRegistry.camera(cameraId)
		if camera ~= nil and camera.roomId == roomId then
			return true
		end
	end
	local position = characterPosition(player)
	local target = ObjectRegistry.referencePosition(objectId)
	if position == nil or target == nil then
		return false
	end
	-- Marge pour les objets déplacés (le décalage max d'une anomalie Moved).
	local range = ProtoConfig.reportRangeStuds + ProtoConfig.moveOffsetMaxStuds
	return (position - target).Magnitude <= range
end

local function onReport(player: Player, payload: unknown)
	-- Le contrat a déjà validé la forme { roomId, objectId, ruleId } (identifiants).
	local report = payload :: Types.ReportPayload
	if state.phase ~= "Running" then
		return
	end
	local object = ObjectRegistry.get(report.objectId)
	if object == nil or object.roomId ~= report.roomId then
		log.warn(`signalement rejeté ({player.Name}) : objet ou salle inconnus`)
		return
	end
	if not ReportJudge.isKnownRule(report.ruleId, ProtoConfig) then
		log.warn(`signalement rejeté ({player.Name}) : règle inconnue {report.ruleId}`)
		return
	end
	if not canSee(player, report.objectId, report.roomId) then
		log.warn(`signalement rejeté ({player.Name}) : objet hors de portée`)
		return
	end

	local outcome = NightLoop.report(state, report)
	if outcome == nil then
		return
	end
	local resolved = outcome.resolved
	if resolved ~= nil then
		ObjectRegistry.restore(resolved.objectId)
	end
	local result: Types.ReportResult = {
		ok = outcome.verdict.ok,
		anomalyKey = outcome.verdict.anomalyKey,
		threatDelta = outcome.verdict.threatDelta,
		scoreDelta = outcome.verdict.scoreDelta,
		objectId = report.objectId,
		roomId = report.roomId,
		ruleId = report.ruleId,
		reporterName = string.sub(player.DisplayName, 1, 64),
	}
	NetServer.fireAll("Night.ReportResult", result)
	publish()
end

local function onViewCamera(player: Player, payload: unknown)
	if payload == nil then
		viewingCamera[player] = nil
		return
	end
	local cameraId = payload :: string
	if ObjectRegistry.camera(cameraId) ~= nil then
		viewingCamera[player] = cameraId
	end
end

function NightService.start()
	ObjectRegistry.scan()
	if #ObjectRegistry.refs() == 0 then
		log.warn("aucun objet anomalable : la nuit tournera sans anomalie")
	end

	nightState = Instance.new("Folder")
	nightState.Name = "NightState"
	nightState:SetAttribute("NightDuration", ProtoConfig.nightDurationSeconds)
	nightState:SetAttribute("ThreatMax", ProtoConfig.threatMax)
	nightState.Parent = ReplicatedStorage

	local seed = ProtoConfig.seed
	if seed == 0 then
		seed = Random.new():NextInteger(1, 2 ^ 31 - 1)
	end
	log.info(`graine de la nuit : {seed}`)
	state = NightLoop.new(ProtoConfig, seed)
	publish()

	NetServer.on("Night.Report", onReport)
	NetServer.on("Night.ViewCamera", onViewCamera)
	Players.PlayerRemoving:Connect(function(player: Player)
		viewingCamera[player] = nil
	end)

	RunService.Heartbeat:Connect(function(dt: number)
		local events = NightLoop.step(state, dt, ObjectRegistry.refs(), #Players:GetPlayers())
		applyEvents(events)
		publish()
	end)
end

return NightService
