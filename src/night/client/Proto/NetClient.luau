--!strict
-- Accès client aux remotes créées par le serveur (Common.NetServer) depuis le contrat.
-- Version minimale en attendant le wrapper typé P1.4.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Contract = require(ReplicatedStorage.Shared.Net.Contract)

local NetClient = {}

local REMOTE_TIMEOUT = 30

local function remote(name: string): RemoteEvent
	assert(Contract[name] ~= nil, `NetClient: remote inconnue du contrat : {name}`)
	local folder = ReplicatedStorage:WaitForChild("Remotes", REMOTE_TIMEOUT)
	assert(folder ~= nil, "NetClient: dossier Remotes introuvable")
	local instance = folder:WaitForChild(name, REMOTE_TIMEOUT)
	assert(instance ~= nil and instance:IsA("RemoteEvent"), `NetClient: remote {name} introuvable`)
	return instance :: RemoteEvent
end

-- Envoie une intention au serveur (C→S). Le contenu est vérifié localement par le
-- validateur du contrat pour détecter tôt les erreurs de programmation.
function NetClient.send(name: string, payload: unknown)
	local spec = Contract[name]
	assert(spec ~= nil and spec.direction == "ClientToServer", `NetClient.send: {name} n'est pas C→S`)
	local valid, reason = spec.validate(payload)
	assert(valid, `NetClient.send: contenu invalide pour {name} : {reason}`)
	remote(name):FireServer(payload)
end

-- Écoute une remote S→C.
function NetClient.on(name: string, handler: (payload: unknown) -> ())
	local spec = Contract[name]
	assert(spec ~= nil and spec.direction == "ServerToClient", `NetClient.on: {name} n'est pas S→C`)
	remote(name).OnClientEvent:Connect(handler)
end

return NetClient
