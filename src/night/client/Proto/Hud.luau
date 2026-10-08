--!strict
-- PROTOTYPE P0.5 — HUD minimal : heure, jauge de menace, score, messages, écran de fin.
-- Lit l'état continu dans les attributs de ReplicatedStorage.NightState (le client
-- n'en décide rien). UI en instances simples (React-lua arrivera en phase 2).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local NightClock = require(ReplicatedStorage.Shared.Domain.Proto.NightClock)
local ProtoConfig = require(ReplicatedStorage.Shared.Content.ProtoConfig)

local Hud = {}

local COLOR_TEXT = Color3.fromRGB(235, 235, 240)
local COLOR_PANEL = Color3.fromRGB(15, 15, 25)
local COLOR_OK = Color3.fromRGB(90, 220, 120)
local COLOR_BAD = Color3.fromRGB(240, 80, 80)
local COLOR_INFO = Color3.fromRGB(240, 210, 110)

Hud.colors = table.freeze({ ok = COLOR_OK, bad = COLOR_BAD, info = COLOR_INFO, text = COLOR_TEXT })

-- Crée une instance et lui affecte des propriétés (utilitaire UI du prototype).
function Hud.make(className: string, props: { [string]: any }, parent: Instance?): Instance
	local instance = Instance.new(className)
	for key, value in props do
		(instance :: any)[key] = value
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

function Hud.label(props: { [string]: any }, parent: Instance): TextLabel
	local base: { [string]: any } = {
		BackgroundTransparency = 1,
		TextColor3 = COLOR_TEXT,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
	}
	for key, value in props do
		base[key] = value
	end
	return Hud.make("TextLabel", base, parent) :: TextLabel
end

function Hud.button(text: string, props: { [string]: any }, parent: Instance): TextButton
	local base: { [string]: any } = {
		Text = text,
		BackgroundColor3 = Color3.fromRGB(40, 40, 60),
		BackgroundTransparency = 0.15,
		TextColor3 = COLOR_TEXT,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		AutoButtonColor = true,
	}
	for key, value in props do
		base[key] = value
	end
	local button = Hud.make("TextButton", base, parent) :: TextButton
	Hud.make("UICorner", { CornerRadius = UDim.new(0, 8) }, button)
	Hud.make("UIPadding", {
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 6),
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 4),
	}, button)
	return button
end

export type Hud = {
	gui: ScreenGui,
	toast: (text: string, color: Color3?) -> (),
}

function Hud.new(playerGui: Instance, nightState: Instance): Hud
	local gui = Hud.make("ScreenGui", {
		Name = "ProtoNightHud",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}) :: ScreenGui

	-- Bandeau du haut : heure + jauge de menace.
	local top = Hud.make("Frame", {
		Name = "Top",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.new(0, 260, 0, 74),
		BackgroundColor3 = COLOR_PANEL,
		BackgroundTransparency = 0.35,
	}, gui)
	Hud.make("UICorner", { CornerRadius = UDim.new(0, 10) }, top)
	local clock = Hud.label({
		Name = "Clock",
		Position = UDim2.new(0, 0, 0, 4),
		Size = UDim2.new(1, 0, 0, 36),
		Text = "00:00",
	}, top)
	local barBack = Hud.make("Frame", {
		Name = "ThreatBar",
		Position = UDim2.new(0, 12, 0, 46),
		Size = UDim2.new(1, -24, 0, 18),
		BackgroundColor3 = Color3.fromRGB(40, 40, 50),
	}, top)
	Hud.make("UICorner", { CornerRadius = UDim.new(0, 6) }, barBack)
	local barFill = Hud.make("Frame", {
		Name = "Fill",
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = COLOR_OK,
	}, barBack) :: Frame
	Hud.make("UICorner", { CornerRadius = UDim.new(0, 6) }, barFill)
	local threatText = Hud.label({
		Name = "ThreatText",
		Size = UDim2.new(1, 0, 1, 0),
		Text = "Menace 0",
		ZIndex = 2,
		TextStrokeTransparency = 0.5,
	}, barBack)

	-- Score en haut à droite.
	local score = Hud.label({
		Name = "Score",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 8),
		Size = UDim2.new(0, 220, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = "Score 0",
		TextStrokeTransparency = 0.5,
	}, gui)

	-- Message central (résultats de signalement, compte à rebours).
	local banner = Hud.label({
		Name = "Banner",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 92),
		Size = UDim2.new(0.8, 0, 0, 34),
		Text = "",
		TextStrokeTransparency = 0.3,
	}, gui)

	-- Aide permanente en bas à gauche.
	Hud.label({
		Name = "Help",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 10, 1, -10),
		Size = UDim2.new(0, 420, 0, 40),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Font = Enum.Font.Gotham,
		TextTransparency = 0.2,
		Text = "Clic / tap sur un objet proche (ou vu en caméra) pour le signaler · C : caméras · Q / E : caméra précédente / suivante",
	}, gui)

	-- Écran de fin.
	local endScreen = Hud.make("Frame", {
		Name = "EndScreen",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		Visible = false,
		ZIndex = 10,
	}, gui) :: Frame
	local endTitle = Hud.label({
		Name = "Title",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.35, 0),
		Size = UDim2.new(0.8, 0, 0, 70),
		ZIndex = 11,
	}, endScreen)
	local endStats = Hud.label({
		Name = "Stats",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(0.8, 0, 0, 40),
		Font = Enum.Font.Gotham,
		ZIndex = 11,
	}, endScreen)
	local endCountdown = Hud.label({
		Name = "Countdown",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.62, 0),
		Size = UDim2.new(0.6, 0, 0, 28),
		Font = Enum.Font.Gotham,
		TextTransparency = 0.2,
		ZIndex = 11,
	}, endScreen)

	gui.Parent = playerGui

	local toastToken = 0
	local function toast(text: string, color: Color3?)
		toastToken += 1
		local token = toastToken
		banner.Text = text
		banner.TextColor3 = color or COLOR_TEXT
		banner.TextTransparency = 0
		task.delay(3.5, function()
			if token == toastToken then
				TweenService:Create(banner, TweenInfo.new(0.6), { TextTransparency = 1 }):Play()
			end
		end)
	end

	local function numberAttr(name: string): number
		local value = nightState:GetAttribute(name)
		return if type(value) == "number" then value else 0
	end

	local function stringAttr(name: string): string
		local value = nightState:GetAttribute(name)
		return if type(value) == "string" then value else ""
	end

	local lastPhase = ""
	local lastBriefingSecond = -1
	local function refresh()
		local phase = stringAttr("Phase")
		local threatMax = math.max(1, numberAttr("ThreatMax"))
		local threat = numberAttr("Threat")
		local ratio = math.clamp(threat / threatMax, 0, 1)

		clock.Text = if phase == "Briefing" then "00:00" else NightClock.format(numberAttr("NightElapsed"), ProtoConfig)
		barFill.Size = UDim2.new(ratio, 0, 1, 0)
		barFill.BackgroundColor3 = COLOR_OK:Lerp(COLOR_BAD, ratio)
		threatText.Text = `Menace {math.floor(threat)}`
		score.Text = `Score {numberAttr("Score")}  ✓{numberAttr("CorrectReports")}  ✗{numberAttr("WrongReports")}`

		local secondsLeft = numberAttr("PhaseSecondsLeft")
		if phase == "Briefing" then
			if secondsLeft ~= lastBriefingSecond then
				lastBriefingSecond = secondsLeft
				toast(`La nuit commence dans {secondsLeft} s : mémorisez les salles !`, COLOR_INFO)
			end
		else
			lastBriefingSecond = -1
		end

		if phase == "Running" and lastPhase ~= "Running" then
			toast("Minuit. Surveillez le musée jusqu'à 6 h.", COLOR_INFO)
		end

		endScreen.Visible = phase == "Ended"
		if phase == "Ended" then
			local victory = stringAttr("Outcome") == "Victory"
			endTitle.Text = if victory then "VICTOIRE : vous avez tenu jusqu'à 6 h" else "DÉFAITE : la menace a atteint 100"
			endTitle.TextColor3 = if victory then COLOR_OK else COLOR_BAD
			local correct = numberAttr("CorrectReports")
			local wrong = numberAttr("WrongReports")
			endStats.Text = `Signalements justes : {correct}   ·   faux : {wrong}   ·   score : {numberAttr("Score")}`
			endCountdown.Text = `Nouvelle nuit dans {secondsLeft} s`
		end
		lastPhase = phase
	end

	nightState.AttributeChanged:Connect(refresh)
	refresh()

	return {
		gui = gui,
		toast = toast,
	}
end

return Hud
