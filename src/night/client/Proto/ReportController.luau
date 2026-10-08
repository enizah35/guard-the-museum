--!strict
-- PROTOTYPE P0.5 — signalement : clic / tap sur un objet `Anomalable` (à portée, ou vu
-- depuis une caméra de sa salle), puis choix de la règle dans un petit menu.
-- Le client n'envoie qu'une intention (Night.Report) ; le serveur juge et répond à
-- toute l'équipe (Night.ReportResult).

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local ProtoConfig = require(ReplicatedStorage.Shared.Content.ProtoConfig)
local Contract = require(ReplicatedStorage.Shared.Net.Contract)
local Types = require(ReplicatedStorage.Shared.Types)
local CameraTablet = require(script.Parent.CameraTablet)
local Hud = require(script.Parent.Hud)
local NetClient = require(script.Parent.NetClient)

local ReportController = {}

local RAY_LENGTH = 500
local RULE_LABELS: { [string]: string } = {
	Moved = "Déplacé",
	Missing = "Disparu",
}
local REPORT_COOLDOWN = Contract["Night.Report"].cooldownSeconds or 3
local PING_SOUND = "rbxasset://sounds/electronicpingshort.wav"

type Target = {
	instance: PVInstance,
	objectId: string,
	roomId: string,
}

local function stringAttribute(instance: Instance, name: string): string?
	local value = instance:GetAttribute(name)
	return if type(value) == "string" and #value > 0 then value else nil
end

-- Remonte depuis la part touchée jusqu'à l'instance taguée `Anomalable`.
local function findTarget(hit: Instance): Target?
	local current: Instance? = hit
	while current ~= nil and current ~= Workspace do
		if CollectionService:HasTag(current, "Anomalable") and current:IsA("PVInstance") then
			local objectId = stringAttribute(current, "ObjectId")
			local roomId = stringAttribute(current, "RoomId")
			if objectId ~= nil and roomId ~= nil then
				return { instance = current :: PVInstance, objectId = objectId, roomId = roomId }
			end
			return nil
		end
		current = current.Parent
	end
	return nil
end

local function playPing(speed: number)
	local sound = Instance.new("Sound")
	sound.SoundId = PING_SOUND
	sound.PlaybackSpeed = speed
	sound.Volume = 0.6
	sound.Parent = SoundService
	sound:Play()
	task.delay(2, function()
		sound:Destroy()
	end)
end

function ReportController.new(hud: Hud.Hud, tablet: CameraTablet.CameraTablet)
	local player = Players.LocalPlayer
	local selected: Target? = nil
	local lastReportAt = -math.huge

	local selectionBox = Instance.new("SelectionBox")
	selectionBox.Name = "ProtoReportSelection"
	selectionBox.Color3 = Color3.fromRGB(255, 220, 60)
	selectionBox.LineThickness = 0.06
	selectionBox.Parent = hud.gui

	-- Menu de choix de la règle.
	local menu = Hud.make("Frame", {
		Name = "ReportMenu",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -72),
		Size = UDim2.fromOffset(420, 96),
		BackgroundColor3 = Color3.fromRGB(15, 15, 25),
		BackgroundTransparency = 0.25,
		Visible = false,
	}, hud.gui) :: Frame
	Hud.make("UICorner", { CornerRadius = UDim.new(0, 10) }, menu)
	local menuTitle = Hud.label({
		Position = UDim2.fromOffset(8, 4),
		Size = UDim2.new(1, -16, 0, 30),
		Text = "",
	}, menu)
	local buttonRow = Hud.make("Frame", {
		Position = UDim2.fromOffset(8, 40),
		Size = UDim2.new(1, -16, 0, 48),
		BackgroundTransparency = 1,
	}, menu)
	Hud.make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, buttonRow)

	local function closeMenu()
		selected = nil
		selectionBox.Adornee = nil
		menu.Visible = false
	end

	local function sendReport(ruleId: string)
		local target = selected
		if target == nil then
			return
		end
		local now = os.clock()
		local wait = REPORT_COOLDOWN - (now - lastReportAt)
		if wait > 0 then
			hud.toast(`Patientez {math.ceil(wait)} s avant un nouveau signalement`, Hud.colors.info)
			return
		end
		lastReportAt = now
		local payload: Types.ReportPayload = {
			roomId = target.roomId,
			objectId = target.objectId,
			ruleId = ruleId,
		}
		NetClient.send("Night.Report", payload)
		closeMenu()
	end

	for order, ruleId in ProtoConfig.rules do
		local button = Hud.button(`{order}. {RULE_LABELS[ruleId] or ruleId}`, {
			LayoutOrder = order,
			Size = UDim2.new(0, 128, 1, 0),
		}, buttonRow)
		button.Activated:Connect(function()
			sendReport(ruleId)
		end)
	end
	local cancel = Hud.button("Annuler", {
		LayoutOrder = 99,
		Size = UDim2.new(0, 120, 1, 0),
		BackgroundColor3 = Color3.fromRGB(70, 40, 40),
	}, buttonRow)
	cancel.Activated:Connect(closeMenu)

	-- Raccourcis clavier 1, 2… pour les règles quand le menu est ouvert.
	local ruleKeys = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four }
	ContextActionService:BindAction("ProtoReportRule", function(_, inputState: Enum.UserInputState, input: InputObject)
		if inputState ~= Enum.UserInputState.Begin or selected == nil then
			return Enum.ContextActionResult.Pass
		end
		local slot = table.find(ruleKeys, input.KeyCode)
		local ruleId = if slot then ProtoConfig.rules[slot] else nil
		if ruleId == nil then
			return Enum.ContextActionResult.Pass
		end
		sendReport(ruleId)
		return Enum.ContextActionResult.Sink
	end, false, table.unpack(ruleKeys))

	local function canReach(target: Target): (boolean, string?)
		if tablet.isActive() then
			if tablet.currentRoomId() == target.roomId then
				return true
			end
			return false, "Cette caméra ne couvre pas cette salle"
		end
		local character = player.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if root == nil or not root:IsA("BasePart") then
			return false, nil
		end
		local distance = ((root :: BasePart).Position - target.instance:GetPivot().Position).Magnitude
		if distance > ProtoConfig.reportRangeStuds then
			return false, "Trop loin : approchez-vous ou utilisez une caméra"
		end
		return true
	end

	local function pickAt(screenPosition: Vector2)
		local nightState = ReplicatedStorage:FindFirstChild("NightState")
		if nightState == nil or nightState:GetAttribute("Phase") ~= "Running" then
			return
		end
		local camera = Workspace.CurrentCamera
		local ray = camera:ScreenPointToRay(screenPosition.X, screenPosition.Y)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		local character = player.Character
		params.FilterDescendantsInstances = if character then { character } else {}
		local result = Workspace:Raycast(ray.Origin, ray.Direction * RAY_LENGTH, params)
		if result == nil then
			return
		end
		local target = findTarget(result.Instance)
		if target == nil then
			return
		end
		local ok, reason = canReach(target)
		if not ok then
			if reason then
				hud.toast(reason, Hud.colors.info)
			end
			return
		end
		selected = target
		selectionBox.Adornee = target.instance
		menuTitle.Text = `Signaler : {target.objectId} ({target.roomId})`
		menu.Visible = true
	end

	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed or input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end
		pickAt(Vector2.new(input.Position.X, input.Position.Y))
	end)
	UserInputService.TouchTapInWorld:Connect(function(position: Vector2, processedByUI: boolean)
		if not processedByUI then
			pickAt(position)
		end
	end)

	-- Résultat diffusé à toute l'équipe.
	NetClient.on("Night.ReportResult", function(payload: unknown)
		local valid = Contract["Night.ReportResult"].validate(payload)
		if not valid then
			return
		end
		local result = payload :: Types.ReportResult
		local who = result.reporterName or "?"
		local rule = if result.ruleId then RULE_LABELS[result.ruleId] or result.ruleId else "?"
		local object = result.objectId or "?"
		local threat = if result.threatDelta >= 0 then `+{result.threatDelta}` else tostring(result.threatDelta)
		local current = selected
		if result.ok and current ~= nil and current.objectId == result.objectId then
			closeMenu() -- un coéquipier vient de signaler cet objet
		end
		if result.ok then
			hud.toast(`✔ {who} : « {rule} » sur {object} (menace {threat})`, Hud.colors.ok)
			playPing(1.2)
		else
			hud.toast(`✘ {who} : faux signalement « {rule} » sur {object} (menace {threat})`, Hud.colors.bad)
			playPing(0.5)
		end
	end)

	-- Fin de nuit : on ferme le menu et la vue caméra.
	local nightState = ReplicatedStorage:WaitForChild("NightState")
	nightState:GetAttributeChangedSignal("Phase"):Connect(function()
		if nightState:GetAttribute("Phase") ~= "Running" then
			closeMenu()
			tablet.exit()
		end
	end)
end

return ReportController
