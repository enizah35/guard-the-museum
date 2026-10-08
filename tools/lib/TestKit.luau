--!strict
-- Mini-framework de test (describe / it / expect), sans dépendance.
-- Les specs s'enregistrent au chargement ; tools/test.luau les exécute.
--
--   local TestKit = require("@tools/lib/TestKit")
--   local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect
--   describe("Rng", function()
--       it("est déterministe", function()
--           expect(1 + 1).toBe(2)
--       end)
--   end)

export type Case = {
	name: string,
	fn: () -> (),
}

export type Expectation = {
	toBe: (expected: any) -> (),
	toEqual: (expected: any) -> (),
	toBeNil: () -> (),
	toBeTruthy: () -> (),
	toBeCloseTo: (expected: number, epsilon: number?) -> (),
	toBeGreaterThan: (expected: number) -> (),
	toBeLessThan: (expected: number) -> (),
	toThrow: (fragment: string?) -> (),
	never: Expectation,
}

local TestKit = {}

local registry: { Case } = {}
local path: { string } = {}

function TestKit.describe(name: string, fn: () -> ())
	table.insert(path, name)
	fn()
	table.remove(path)
end

function TestKit.it(name: string, fn: () -> ())
	local full = if #path > 0 then table.concat(path, " > ") .. " > " .. name else name
	table.insert(registry, { name = full, fn = fn })
end

-- Renvoie les cas enregistrés depuis le dernier appel et vide le registre.
function TestKit.collect(): { Case }
	local cases = registry
	registry = {}
	path = {}
	return cases
end

local function show(value: any): string
	if type(value) == "string" then
		return string.format("%q", value)
	elseif type(value) == "table" then
		local parts = {}
		local count = 0
		for k, v in value do
			count += 1
			if count > 8 then
				table.insert(parts, "…")
				break
			end
			table.insert(parts, `{show(k)}={show(v)}`)
		end
		return "{" .. table.concat(parts, ", ") .. "}"
	end
	return tostring(value)
end

function TestKit.deepEqual(a: any, b: any): boolean
	if a == b then
		return true
	end
	if type(a) ~= "table" or type(b) ~= "table" then
		return false
	end
	for k, v in a do
		if not TestKit.deepEqual(v, b[k]) then
			return false
		end
	end
	for k in b do
		if a[k] == nil then
			return false
		end
	end
	return true
end

local function makeExpectation(actual: any, negated: boolean): Expectation
	local function check(passed: boolean, message: string)
		if passed == negated then
			error((if negated then "attendu le contraire : " else "") .. message, 3)
		end
	end

	local expectation = {}

	function expectation.toBe(expected: any)
		check(actual == expected, `{show(actual)} devrait être {show(expected)}`)
	end

	function expectation.toEqual(expected: any)
		check(TestKit.deepEqual(actual, expected), `{show(actual)} devrait égaler {show(expected)}`)
	end

	function expectation.toBeNil()
		check(actual == nil, `{show(actual)} devrait être nil`)
	end

	function expectation.toBeTruthy()
		check(not not actual, `{show(actual)} devrait être vrai`)
	end

	function expectation.toBeCloseTo(expected: number, epsilon: number?)
		local eps = epsilon or 1e-9
		check(
			type(actual) == "number" and math.abs(actual - expected) <= eps,
			`{show(actual)} devrait valoir {expected} ± {eps}`
		)
	end

	function expectation.toBeGreaterThan(expected: number)
		check(type(actual) == "number" and actual > expected, `{show(actual)} devrait être > {expected}`)
	end

	function expectation.toBeLessThan(expected: number)
		check(type(actual) == "number" and actual < expected, `{show(actual)} devrait être < {expected}`)
	end

	function expectation.toThrow(fragment: string?)
		assert(type(actual) == "function", "toThrow attend une fonction")
		local ok, err = pcall(actual)
		local message = tostring(err)
		local matches = not ok and (fragment == nil or string.find(message, fragment, 1, true) ~= nil)
		check(matches, if ok then "la fonction devrait lever une erreur" else `erreur inattendue : {message}`)
	end

	return expectation :: any
end

function TestKit.expect(actual: any): Expectation
	local expectation = makeExpectation(actual, false)
	expectation.never = makeExpectation(actual, true)
	return expectation
end

return TestKit
