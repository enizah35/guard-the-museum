--!strict
-- Service Players simulé : PlayerAdded / PlayerRemoving, GetPlayers,
-- GetPlayerByUserId, et des joueurs factices avec attributs et Kick.

local Signal = require("./Signal")

export type MockPlayer = {
	UserId: number,
	Name: string,
	DisplayName: string,
	kicked: string?,
	GetAttribute: (self: MockPlayer, name: string) -> any,
	SetAttribute: (self: MockPlayer, name: string, value: any) -> (),
	Kick: (self: MockPlayer, message: string?) -> (),
}

export type MockPlayers = {
	PlayerAdded: Signal.Signal,
	PlayerRemoving: Signal.Signal,
	GetPlayers: (self: MockPlayers) -> { MockPlayer },
	GetPlayerByUserId: (self: MockPlayers, userId: number) -> MockPlayer?,
	-- Outils de test
	addPlayer: (self: MockPlayers, userId: number, name: string?) -> MockPlayer,
	removePlayer: (self: MockPlayers, player: MockPlayer) -> (),
}

local MockPlayers = {}

function MockPlayers.newPlayer(userId: number, name: string?): MockPlayer
	local attributes: { [string]: any } = {}
	local playerName = name or `Player{userId}`
	local player: MockPlayer = {
		UserId = userId,
		Name = playerName,
		DisplayName = playerName,
		kicked = nil,
		GetAttribute = function(_self: MockPlayer, attribute: string): any
			return attributes[attribute]
		end,
		SetAttribute = function(_self: MockPlayer, attribute: string, value: any)
			attributes[attribute] = value
		end,
		Kick = function(self: MockPlayer, message: string?)
			self.kicked = message or ""
		end,
	}
	return player
end

function MockPlayers.new(): MockPlayers
	local list: { MockPlayer } = {}

	local players: MockPlayers = {
		PlayerAdded = Signal.new(),
		PlayerRemoving = Signal.new(),
		GetPlayers = function(_self: MockPlayers): { MockPlayer }
			return table.clone(list)
		end,
		GetPlayerByUserId = function(_self: MockPlayers, userId: number): MockPlayer?
			for _, player in list do
				if player.UserId == userId then
					return player
				end
			end
			return nil
		end,
		addPlayer = function(self: MockPlayers, userId: number, name: string?): MockPlayer
			assert(self:GetPlayerByUserId(userId) == nil, `MockPlayers : UserId {userId} déjà présent`)
			local player = MockPlayers.newPlayer(userId, name)
			table.insert(list, player)
			self.PlayerAdded:Fire(player)
			return player
		end,
		removePlayer = function(self: MockPlayers, player: MockPlayer)
			local index = table.find(list, player)
			assert(index ~= nil, "MockPlayers : joueur absent")
			self.PlayerRemoving:Fire(player)
			table.remove(list, index)
		end,
	}
	return players
end

return MockPlayers
