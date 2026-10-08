--!strict
-- PROTOTYPE P0.5 — tablette caméras : bascule la Camera du joueur sur les caméras de
-- sécurité (parts taguées `SecurityCam`). C : ouvrir / quitter, Q / E : précédente / suivante.
-- Boutons à l'écran pour le tactile. Le serveur est prévenu (Night.ViewCamera) pour
-- autoriser les signalements faits depuis la caméra.

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Hud = require(script.Parent.Hud)
local NetClient = require(script.Parent.NetClient)

local CameraTablet = {}

type CameraEntry = {
	cameraId: string,
	roomId: string,
	part: BasePart,
}

export type CameraTablet = {
	isActive: () -> boolean,
	currentRoomId: () -> string?,
	exit: () -> (),
}

local RENDER_STEP = "ProtoCameraTablet"

local function stringAttribute(instance: Instance, name: string): string?
	local value = instance:GetAttribute(name)
	return if type(value) == "string" and #value > 0 then value else nil
end

local function listCameras(): { CameraEntry }
	local list: { CameraEntry } = {}
	for _, instance in CollectionService:GetTagged("SecurityCam") do
		local roomId = stringAttribute(instance, "RoomId")
		if instance:IsA("BasePart") and roomId ~= nil then
			table.insert(list, {
				cameraId = stringAttribute(instance, "CameraId") or instance.Name,
				roomId = roomId,
				part = instance :: BasePart,
			})
		end
	end
	table.sort(list, function(a: CameraEntry, b: CameraEntry): boolean
		return a.cameraId < b.cameraId
	end)
	return list
end

-- Active / désactive les déplacements du personnage (PlayerModule standard de Roblox).
local controls: any = nil
local function setControlsEnabled(enabled: boolean)
	if controls == nil then
		local ok, result = pcall(function(): any
			local playerScripts = Players.LocalPlayer:WaitForChild("PlayerScripts")
			local playerModule = (require :: any)(playerScripts:WaitForChild("PlayerModule"))
			return playerModule:GetControls()
		end)
		if not ok then
			return
		end
		controls = result
	end
	pcall(function()
		if enabled then
			controls:Enable()
		else
			controls:Disable()
		end
	end)
end

function CameraTablet.new(hud: Hud.Hud): CameraTablet
	local cameras: { CameraEntry } = {}
	local index: number? = nil

	-- Précharge le module de contrôles (évite une attente à la première ouverture).
	task.spawn(setControlsEnabled, true)

	-- Interface : bouton d'ouverture + barre de navigation en mode caméra.
	local openButton = Hud.button("Caméras [C]", {
		Name = "OpenCameras",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.45, 0), -- à gauche, hors des zones tactiles de Roblox
		Size = UDim2.fromOffset(160, 44),
	}, hud.gui)

	local bar = Hud.make("Frame", {
		Name = "CameraBar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.fromOffset(520, 50),
		BackgroundTransparency = 1,
		Visible = false,
	}, hud.gui) :: Frame
	local prevButton = Hud.button("◀ [Q]", { Size = UDim2.new(0, 90, 1, 0) }, bar)
	local title = Hud.label({
		Position = UDim2.fromOffset(100, 0),
		Size = UDim2.new(0, 220, 1, 0),
		Text = "",
		TextStrokeTransparency = 0.3,
	}, bar)
	local nextButton =
		Hud.button("[E] ▶", { Position = UDim2.fromOffset(330, 0), Size = UDim2.new(0, 90, 1, 0) }, bar)
	local exitButton =
		Hud.button("Quitter [C]", { Position = UDim2.fromOffset(430, 0), Size = UDim2.new(0, 90, 1, 0) }, bar)

	-- Filtre « vidéosurveillance » : léger voile et pastille REC.
	local overlay = Hud.make("Frame", {
		Name = "CameraOverlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(20, 40, 30),
		BackgroundTransparency = 0.85,
		Visible = false,
		ZIndex = 0,
	}, hud.gui) :: Frame
	Hud.label({
		Position = UDim2.fromOffset(16, 16),
		Size = UDim2.fromOffset(120, 28),
		Text = "● REC",
		TextColor3 = Color3.fromRGB(230, 50, 50),
		TextXAlignment = Enum.TextXAlignment.Left,
	}, overlay)

	local function current(): CameraEntry?
		return if index ~= nil then cameras[index] else nil
	end

	local function show(newIndex: number)
		index = newIndex
		local entry = cameras[newIndex]
		title.Text = `{entry.cameraId} · {entry.roomId}`
		NetClient.send("Night.ViewCamera", entry.cameraId)
	end

	local function enter()
		cameras = listCameras()
		if #cameras == 0 then
			hud.toast("Aucune caméra de sécurité dans ce musée", Hud.colors.info)
			return
		end
		local camera = Workspace.CurrentCamera
		camera.CameraType = Enum.CameraType.Scriptable
		setControlsEnabled(false)
		openButton.Visible = false
		bar.Visible = true
		overlay.Visible = true
		show(1)
		RunService:BindToRenderStep(RENDER_STEP, Enum.RenderPriority.Camera.Value + 1, function()
			local entry = current()
			if entry ~= nil then
				Workspace.CurrentCamera.CFrame = entry.part.CFrame
			end
		end)
	end

	local function exit()
		if index == nil then
			return
		end
		index = nil
		RunService:UnbindFromRenderStep(RENDER_STEP)
		local camera = Workspace.CurrentCamera
		camera.CameraType = Enum.CameraType.Custom
		local character = Players.LocalPlayer.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if humanoid then
			camera.CameraSubject = humanoid
		end
		setControlsEnabled(true)
		openButton.Visible = true
		bar.Visible = false
		overlay.Visible = false
		NetClient.send("Night.ViewCamera", nil)
	end

	local function toggle()
		if index == nil then
			enter()
		else
			exit()
		end
	end

	local function cycle(step: number)
		local i = index
		if i == nil or #cameras == 0 then
			return
		end
		show((i - 1 + step) % #cameras + 1)
	end

	openButton.Activated:Connect(toggle)
	exitButton.Activated:Connect(exit)
	prevButton.Activated:Connect(function()
		cycle(-1)
	end)
	nextButton.Activated:Connect(function()
		cycle(1)
	end)

	ContextActionService:BindAction("ProtoCameraToggle", function(_, inputState: Enum.UserInputState)
		if inputState == Enum.UserInputState.Begin then
			toggle()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.C)
	ContextActionService:BindAction("ProtoCameraCycle", function(_, inputState: Enum.UserInputState, input: InputObject)
		if inputState ~= Enum.UserInputState.Begin or index == nil then
			return Enum.ContextActionResult.Pass
		end
		local isPrev = input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.Left
		cycle(if isPrev then -1 else 1)
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.Q, Enum.KeyCode.E, Enum.KeyCode.Left, Enum.KeyCode.Right)

	-- Respawn pendant la vue caméra : on revient à la vue normale.
	Players.LocalPlayer.CharacterAdded:Connect(function()
		exit()
	end)

	return {
		isActive = function(): boolean
			return index ~= nil
		end,
		currentRoomId = function(): string?
			local entry = current()
			return if entry then entry.roomId else nil
		end,
		exit = exit,
	}
end

return CameraTablet
