--!strict
local TestKit = require("@tools/lib/TestKit")
local Rng = require("@shared/Domain/Rng")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local function sequence(seed: number, count: number): { number }
	local rng = Rng.new(seed)
	local out = {}
	for i = 1, count do
		out[i] = Rng.nextU32(rng)
	end
	return out
end

describe("Domain/Rng", function()
	it("produit la même suite pour la même graine", function()
		expect(sequence(1234, 100)).toEqual(sequence(1234, 100))
	end)

	it("produit des suites différentes pour des graines différentes", function()
		expect(sequence(1, 20)).never.toEqual(sequence(2, 20))
		expect(sequence(0, 20)).never.toEqual(sequence(-1, 20))
	end)

	it("donne des valeurs de référence stables (même résultat sous Lune et Roblox)", function()
		-- Si ce test casse, l'algorithme a changé : toutes les nuits rejouées
		-- par graine changent aussi. Ne mettre à jour qu'en connaissance de cause.
		local rng = Rng.new(42)
		expect({ Rng.nextU32(rng), Rng.nextU32(rng), Rng.nextU32(rng) }).toEqual({ 3631470833, 3470295463, 57529585 })
		local negative = Rng.new(-7)
		expect(Rng.nextU32(negative)).toBe(2750047171)
		expect(Rng.nextInt(negative, 1, 100)).toBe(12)
	end)

	it("respecte les bornes de nextInt et nextFloat", function()
		local rng = Rng.new(7)
		local seen: { [number]: boolean } = {}
		for _ = 1, 2000 do
			local n = Rng.nextInt(rng, 1, 6)
			expect(n >= 1 and n <= 6 and n % 1 == 0).toBeTruthy()
			seen[n] = true
			local f = Rng.nextFloat(rng)
			expect(f >= 0 and f < 1).toBeTruthy()
		end
		for face = 1, 6 do
			expect(seen[face]).toBe(true)
		end
	end)

	it("ne tire jamais un index de poids nul", function()
		local rng = Rng.new(99)
		for _ = 1, 500 do
			expect(Rng.weightedIndex(rng, { 0, 3, 0, 1 }) % 2).toBe(0)
		end
		expect(function()
			Rng.weightedIndex(rng, { 0, 0 })
		end).toThrow("somme des poids nulle")
	end)

	it("mélange sans perdre d'élément ni modifier l'entrée", function()
		local input = { "a", "b", "c", "d", "e" }
		local out = Rng.shuffled(Rng.new(5), input)
		expect(input).toEqual({ "a", "b", "c", "d", "e" })
		table.sort(out)
		expect(out).toEqual(input)
	end)

	it("clone un générateur avec le même état", function()
		local rng = Rng.new(2026)
		Rng.nextU32(rng)
		local copy = Rng.clone(rng)
		expect(Rng.nextU32(copy)).toBe(Rng.nextU32(rng))
	end)
end)

return nil
