--!strict
local TestKit = require("@tools/lib/TestKit")
local NightClock = require("@shared/Domain/Proto/NightClock")
local ProtoConfig = require("@shared/Content/ProtoConfig")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

local cfg = table.clone(ProtoConfig)
cfg.nightDurationSeconds = 360
cfg.clockStartHour = 0
cfg.clockEndHour = 6

describe("Domain/Proto/NightClock", function()
	it("affiche 00:00 au début et 06:00 à la fin", function()
		expect(NightClock.format(0, cfg)).toBe("00:00")
		expect(NightClock.format(360, cfg)).toBe("06:00")
		expect(NightClock.format(9999, cfg)).toBe("06:00")
	end)

	it("accélère le temps : 1 s réelle = 1 min de jeu pour une nuit de 6 min", function()
		expect(NightClock.format(61, cfg)).toBe("01:01")
		expect(NightClock.format(180, cfg)).toBe("03:00")
		expect(NightClock.format(359.9, cfg)).toBe("05:59")
	end)

	it("respecte une autre durée et une autre plage horaire", function()
		local other = table.clone(cfg)
		other.nightDurationSeconds = 600
		other.clockStartHour = 22
		other.clockEndHour = 30 -- 22:00 → 06:00
		expect(NightClock.format(0, other)).toBe("22:00")
		expect(NightClock.format(300, other)).toBe("02:00")
		expect(NightClock.format(600, other)).toBe("06:00")
	end)

	it("indique la fin de la nuit et l'avancement", function()
		expect(NightClock.isOver(359, cfg)).toBe(false)
		expect(NightClock.isOver(360, cfg)).toBe(true)
		expect(NightClock.progress(90, cfg)).toBeCloseTo(0.25)
	end)
end)

return nil
