--!strict
local TestKit = require("@tools/lib/TestKit")
local ProtoConfig = require("@shared/Content/ProtoConfig")
local Threat = require("@shared/Domain/Proto/Threat")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local cfg = table.clone(ProtoConfig)
cfg.threatMax = 100
cfg.threatPerActiveAnomalyPerSecond = 0.5

describe("Domain/Proto/Threat", function()
	it("ne bouge pas sans anomalie active", function()
		expect(Threat.tick(12, 10, 0, cfg)).toBe(12)
	end)

	it("monte proportionnellement au temps et au nombre d'anomalies actives", function()
		expect(Threat.tick(0, 10, 1, cfg)).toBeCloseTo(5)
		expect(Threat.tick(0, 10, 3, cfg)).toBeCloseTo(15)
	end)

	it("reste bornée entre 0 et threatMax", function()
		expect(Threat.tick(99, 100, 4, cfg)).toBe(100)
		expect(Threat.applyDelta(3, -5, cfg)).toBe(0)
		expect(Threat.applyDelta(95, 10, cfg)).toBe(100)
	end)

	it("signale la menace maximale", function()
		expect(Threat.isMaxed(100, cfg)).toBe(true)
		expect(Threat.isMaxed(99.9, cfg)).toBe(false)
	end)

	it("refuse un pas de temps négatif", function()
		expect(function()
			Threat.tick(0, -1, 1, cfg)
		end).toThrow("dt négatif")
	end)
end)

return nil
