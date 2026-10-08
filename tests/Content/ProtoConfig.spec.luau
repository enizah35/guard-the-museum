--!strict
local TestKit = require("@tools/lib/TestKit")
local ProtoConfig = require("@shared/Content/ProtoConfig")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

describe("Content/ProtoConfig", function()
	it("a des bornes cohérentes", function()
		local c = ProtoConfig
		expect(c.nightDurationSeconds).toBeGreaterThan(0)
		expect(c.clockEndHour).toBeGreaterThan(c.clockStartHour)
		expect(c.anomalyIntervalMinSeconds).toBeGreaterThan(0)
		expect(c.anomalyIntervalMaxSeconds >= c.anomalyIntervalMinSeconds).toBeTruthy()
		expect(c.moveOffsetMaxStuds >= c.moveOffsetMinStuds).toBeTruthy()
		expect(c.moveYawMaxDegrees >= c.moveYawMinDegrees).toBeTruthy()
		expect(c.maxActiveAnomalies).toBeGreaterThan(0)
		expect(c.threatMax).toBeGreaterThan(0)
		expect(c.threatCorrectReport <= 0).toBeTruthy()
		expect(c.threatWrongReport >= 0).toBeTruthy()
		expect(c.reportRangeStuds).toBeGreaterThan(0)
	end)

	it("respecte le rythme demandé pour le prototype (25-35 s, nuit de 6 min, 00:00 → 06:00)", function()
		expect(ProtoConfig.anomalyIntervalMinSeconds).toBe(25)
		expect(ProtoConfig.anomalyIntervalMaxSeconds).toBe(35)
		expect(ProtoConfig.nightDurationSeconds).toBe(360)
		expect(ProtoConfig.clockStartHour).toBe(0)
		expect(ProtoConfig.clockEndHour).toBe(6)
	end)

	it("n'active que des règles connues, sans doublon", function()
		local seen: { [string]: boolean } = {}
		for _, rule in ProtoConfig.rules do
			expect(rule == "Moved" or rule == "Missing").toBeTruthy()
			expect(seen[rule]).toBeNil()
			seen[rule] = true
		end
		expect(#ProtoConfig.rules).toBeGreaterThan(0)
	end)

	it("est figée", function()
		expect(function()
			(ProtoConfig :: any).threatMax = 1
		end).toThrow()
	end)
end)

return nil
