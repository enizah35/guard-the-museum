--!strict
-- RNG déterministe à graine. Module PUR : aucune API Roblox (ni Random, ni os.time).
-- Même graine ⇒ même suite, sous Lune comme dans Roblox.
--
-- Algorithme : xorshift32 (Marsaglia) avec une graine mélangée par un hachage
-- entier (murmur3 fmix32). Toute l'arithmétique reste sur 32 bits via bit32 :
-- aucun produit ne dépasse 2^53, donc pas de perte de précision des doubles.
--
-- Usage :
--   local rng = Rng.new(1234)
--   local n = Rng.nextInt(rng, 1, 6)
--   local x = Rng.pick(rng, { "a", "b" })

local Rng = {}

export type Rng = {
	state: number, -- entier 32 bits non nul
}

-- Multiplication 32 bits modulo 2^32 (équivalent de Math.imul), sans perte de précision.
local function mul32(a: number, b: number): number
	local aHi = bit32.rshift(a, 16)
	local aLo = bit32.band(a, 0xFFFF)
	local bHi = bit32.rshift(b, 16)
	local bLo = bit32.band(b, 0xFFFF)
	local lo = aLo * bLo
	local mid = bit32.band(aHi * bLo + aLo * bHi, 0xFFFF)
	return bit32.band(lo + bit32.lshift(mid, 16), 0xFFFFFFFF)
end

local function fmix32(h: number): number
	h = bit32.bxor(h, bit32.rshift(h, 16))
	h = mul32(h, 0x85EBCA6B)
	h = bit32.bxor(h, bit32.rshift(h, 13))
	h = mul32(h, 0xC2B2AE35)
	h = bit32.bxor(h, bit32.rshift(h, 16))
	return h
end

-- Crée un générateur. `seed` : entier quelconque (les décimales sont ignorées).
function Rng.new(seed: number): Rng
	assert(type(seed) == "number" and seed == seed, "Rng.new: graine numérique attendue")
	local s = bit32.band(math.floor(math.abs(seed)) % 4294967296, 0xFFFFFFFF)
	if seed < 0 then
		s = bit32.bnot(s)
	end
	local state = fmix32(bit32.bxor(s, 0x9E3779B9))
	if state == 0 then
		state = 0x6D2B79F5
	end
	return { state = state }
end

-- Prochain entier 32 bits non signé, dans [1, 2^32 - 1].
function Rng.nextU32(rng: Rng): number
	local x = rng.state
	x = bit32.bxor(x, bit32.lshift(x, 13))
	x = bit32.bxor(x, bit32.rshift(x, 17))
	x = bit32.bxor(x, bit32.lshift(x, 5))
	rng.state = x
	return x
end

-- Flottant dans [0, 1[.
function Rng.nextFloat(rng: Rng): number
	return (Rng.nextU32(rng) - 1) / 4294967295
end

-- Entier dans [min, max] (bornes incluses).
function Rng.nextInt(rng: Rng, min: number, max: number): number
	assert(min <= max, "Rng.nextInt: min > max")
	local span = max - min + 1
	return min + math.floor(Rng.nextFloat(rng) * span)
end

-- Élément uniforme d'une liste non vide.
function Rng.pick<T>(rng: Rng, list: { T }): T
	assert(#list > 0, "Rng.pick: liste vide")
	return list[Rng.nextInt(rng, 1, #list)]
end

-- Index tiré selon des poids positifs (au moins un poids > 0).
function Rng.weightedIndex(rng: Rng, weights: { number }): number
	local total = 0
	for _, w in weights do
		assert(w >= 0, "Rng.weightedIndex: poids négatif")
		total += w
	end
	assert(total > 0, "Rng.weightedIndex: somme des poids nulle")
	local r = Rng.nextFloat(rng) * total
	for i, w in weights do
		r -= w
		if r < 0 then
			return i
		end
	end
	return #weights
end

-- Copie mélangée (Fisher-Yates) ; la liste d'entrée n'est pas modifiée.
function Rng.shuffled<T>(rng: Rng, list: { T }): { T }
	local out = table.clone(list)
	for i = #out, 2, -1 do
		local j = Rng.nextInt(rng, 1, i)
		out[i], out[j] = out[j], out[i]
	end
	return out
end

-- Copie indépendante (même état, suites identiques ensuite).
function Rng.clone(rng: Rng): Rng
	return { state = rng.state }
end

return Rng
