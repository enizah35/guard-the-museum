--!strict
-- DataStoreService en mémoire (sous-ensemble utile : GetDataStore, GetAsync,
-- SetAsync, UpdateAsync, RemoveAsync, IncrementAsync).
--   * Les valeurs sont copiées en profondeur à l'écriture et à la lecture,
--     comme une vraie sérialisation : muter un résultat ne modifie pas le store.
--   * Les valeurs non sérialisables (fonctions, userdata, clés mixtes) sont refusées.
--   * `failNext(n, message?)` fait échouer les n prochains appels (tester les pcall).

export type MockDataStore = {
	GetAsync: (self: MockDataStore, key: string) -> any,
	SetAsync: (self: MockDataStore, key: string, value: any) -> (),
	UpdateAsync: (self: MockDataStore, key: string, transform: (old: any) -> any) -> any,
	RemoveAsync: (self: MockDataStore, key: string) -> any,
	IncrementAsync: (self: MockDataStore, key: string, delta: number?) -> number,
	-- Outils de test
	failNext: (self: MockDataStore, count: number, message: string?) -> (),
	callCount: (self: MockDataStore) -> number,
	rawGet: (self: MockDataStore, key: string) -> any,
}

export type MockDataStoreService = {
	GetDataStore: (self: MockDataStoreService, name: string, scope: string?) -> MockDataStore,
}

local MockDataStore = {}

local function copyValue(value: any, depth: number): any
	assert(depth < 64, "MockDataStore : valeur trop profonde ou cyclique")
	local kind = type(value)
	if kind == "nil" or kind == "boolean" or kind == "number" or kind == "string" then
		return value
	elseif kind == "table" then
		local out = {}
		for k, v in value do
			assert(
				type(k) == "string" or type(k) == "number",
				`MockDataStore : clé non sérialisable ({type(k)})`
			)
			out[k] = copyValue(v, depth + 1)
		end
		return out
	end
	error(`MockDataStore : valeur non sérialisable ({kind})`, 0)
end

function MockDataStore.newStore(): MockDataStore
	local data: { [string]: any } = {}
	local failuresLeft = 0
	local failureMessage = "MockDataStore : échec simulé"
	local calls = 0

	local function enter(key: string)
		calls += 1
		assert(type(key) == "string" and #key > 0 and #key <= 50, "MockDataStore : clé invalide")
		if failuresLeft > 0 then
			failuresLeft -= 1
			error(failureMessage, 0)
		end
	end

	local store: MockDataStore = {
		GetAsync = function(_self: MockDataStore, key: string): any
			enter(key)
			return copyValue(data[key], 0)
		end,
		SetAsync = function(_self: MockDataStore, key: string, value: any)
			enter(key)
			data[key] = copyValue(value, 0)
		end,
		UpdateAsync = function(_self: MockDataStore, key: string, transform: (old: any) -> any): any
			enter(key)
			local newValue = transform(copyValue(data[key], 0))
			if newValue == nil then
				-- Roblox : renvoyer nil annule l'écriture.
				return copyValue(data[key], 0)
			end
			data[key] = copyValue(newValue, 0)
			return copyValue(newValue, 0)
		end,
		RemoveAsync = function(_self: MockDataStore, key: string): any
			enter(key)
			local old = data[key]
			data[key] = nil
			return old
		end,
		IncrementAsync = function(_self: MockDataStore, key: string, delta: number?): number
			enter(key)
			local old = data[key]
			assert(old == nil or type(old) == "number", "MockDataStore : IncrementAsync sur une valeur non numérique")
			local value = (old or 0) + (delta or 1)
			data[key] = value
			return value
		end,
		failNext = function(_self: MockDataStore, count: number, message: string?)
			failuresLeft = count
			failureMessage = message or failureMessage
		end,
		callCount = function(_self: MockDataStore): number
			return calls
		end,
		rawGet = function(_self: MockDataStore, key: string): any
			return copyValue(data[key], 0)
		end,
	}
	return store
end

-- Service : un même (nom, scope) renvoie toujours le même store.
function MockDataStore.newService(): MockDataStoreService
	local stores: { [string]: MockDataStore } = {}
	local service: MockDataStoreService = {
		GetDataStore = function(_self: MockDataStoreService, name: string, scope: string?): MockDataStore
			local id = `{scope or "global"}/{name}`
			local store = stores[id]
			if store == nil then
				store = MockDataStore.newStore()
				stores[id] = store
			end
			return store
		end,
	}
	return service
end

return MockDataStore
