--!strict
-- Signal minimal compatible avec l'usage courant de RBXScriptSignal :
-- signal:Connect(fn) -> connexion (:Disconnect()), signal:Fire(...).
-- Les callbacks sont appelés de façon synchrone (contrairement à Roblox) :
-- les tests restent déterministes.

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

export type Signal = {
	Connect: (self: Signal, fn: (...any) -> ()) -> Connection,
	Once: (self: Signal, fn: (...any) -> ()) -> Connection,
	Fire: (self: Signal, ...any) -> (),
	connectionCount: (self: Signal) -> number,
}

local Signal = {}

function Signal.new(): Signal
	local listeners: { { fn: (...any) -> (), connection: Connection } } = {}

	local function connect(fn: (...any) -> (), once: boolean): Connection
		local entry: { fn: (...any) -> (), connection: Connection }
		local connection: Connection = {
			Connected = true,
			Disconnect = function(self: Connection)
				if not self.Connected then
					return
				end
				self.Connected = false
				local index = table.find(listeners, entry)
				if index then
					table.remove(listeners, index)
				end
			end,
		}
		local callback = fn
		if once then
			callback = function(...: any)
				connection:Disconnect()
				fn(...)
			end
		end
		entry = { fn = callback, connection = connection }
		table.insert(listeners, entry)
		return connection
	end

	local signal: Signal = {
		Connect = function(_self: Signal, fn: (...any) -> ())
			return connect(fn, false)
		end,
		Once = function(_self: Signal, fn: (...any) -> ())
			return connect(fn, true)
		end,
		Fire = function(_self: Signal, ...: any)
			for _, entry in table.clone(listeners) do
				if entry.connection.Connected then
					entry.fn(...)
				end
			end
		end,
		connectionCount = function(_self: Signal)
			return #listeners
		end,
	}
	return signal
end

return Signal
