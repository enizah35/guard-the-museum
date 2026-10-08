--!strict
-- Journalisation minimale et pure (print/warn uniquement, disponibles sous Lune et Roblox).
-- Format : [GTM][Contexte] message

local Log = {}

export type Logger = {
	info: (message: string) -> (),
	warn: (message: string) -> (),
}

function Log.new(context: string): Logger
	local prefix = `[GTM][{context}]`
	return {
		info = function(message: string)
			print(`{prefix} {message}`)
		end,
		warn = function(message: string)
			warn(`{prefix} {message}`)
		end,
	}
end

return Log
