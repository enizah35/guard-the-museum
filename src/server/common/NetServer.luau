--!strict
-- Côté serveur du contrat réseau (version minimale, en attendant le wrapper typé P1.4).
-- * Crée un RemoteEvent par entrée de `Shared.Net.Contract` dans ReplicatedStorage.Remotes.
--   C'est le SEUL endroit qui crée des RemoteEvents.
-- * `on(name, handler)` : branche un gestionnaire C→S après validation du contenu
--   et contrôle de fréquence (`rateLimitPerSecond` / `cooldownSeconds`) par joueur.
-- * `fireAll` / `fireClient` : envoi S→C.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Contract = require(ReplicatedStorage.Shared.Net.Contract)
local Log = require(ReplicatedStorage.Shared.Log)
local RateGate = require(ReplicatedStorage.Shared.Net.RateGate)

local log = Log.new("NetServer")

local NetServer = {}

local folder: Folder? = nil
local remotes: { [string]: RemoteEvent } = {}
local gates: { [Player]: { [string]: RateGate.Gate } } = {}

local function ensureFolder(): Folder
	local existing = folder
	if existing then
		return existing
	end
	local created = Instance.new("Folder")
	created.Name = "Remotes"
	for name in Contract do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = created
		remotes[name] = remote
	end
	created.Parent = ReplicatedStorage
	folder = created
	Players.PlayerRemoving:Connect(function(player: Player)
		gates[player] = nil
	end)
	return created
end

local function getRemote(name: string): RemoteEvent
	ensureFolder()
	local remote: RemoteEvent? = remotes[name]
	if remote == nil then
		error(`NetServer: remote inconnue du contrat : {name}`)
	end
	return remote
end

local function gateFor(player: Player, name: string): RateGate.Gate
	local perPlayer = gates[player]
	if perPlayer == nil then
		perPlayer = {}
		gates[player] = perPlayer
	end
	local gate = perPlayer[name]
	if gate == nil then
		local spec = Contract[name]
		gate = RateGate.new(spec.rateLimitPerSecond, spec.cooldownSeconds)
		perPlayer[name] = gate
	end
	return gate
end

-- Crée toutes les remotes du contrat (idempotent). À appeler au démarrage du serveur.
function NetServer.init()
	ensureFolder()
end

-- Branche un gestionnaire sur une remote C→S. Le contenu reçu a passé le validateur du contrat.
function NetServer.on(name: string, handler: (player: Player, payload: unknown) -> ())
	local spec = Contract[name]
	assert(spec ~= nil and spec.direction == "ClientToServer", `NetServer.on: {name} n'est pas une remote C→S`)
	getRemote(name).OnServerEvent:Connect(function(player: Player, payload: unknown)
		local valid, reason = spec.validate(payload)
		if not valid then
			log.warn(`{name} rejeté pour {player.Name} : {reason or "contenu invalide"}`)
			return
		end
		if not RateGate.tryPass(gateFor(player, name), os.clock()) then
			return
		end
		handler(player, payload)
	end)
end

function NetServer.fireAll(name: string, payload: unknown)
	local spec = Contract[name]
	assert(spec ~= nil and spec.direction == "ServerToClient", `NetServer.fireAll: {name} n'est pas une remote S→C`)
	getRemote(name):FireAllClients(payload)
end

function NetServer.fireClient(name: string, player: Player, payload: unknown)
	local spec = Contract[name]
	assert(
		spec ~= nil and spec.direction == "ServerToClient",
		`NetServer.fireClient: {name} n'est pas une remote S→C`
	)
	getRemote(name):FireClient(player, payload)
end

return NetServer
