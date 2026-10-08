--!strict
local TestKit = require("@tools/lib/TestKit")
local RateGate = require("@shared/Net/RateGate")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

describe("Net/RateGate", function()
	it("applique un cooldown entre deux appels acceptés", function()
		local gate = RateGate.new(nil, 3)
		expect(RateGate.tryPass(gate, 10)).toBe(true)
		expect(RateGate.tryPass(gate, 12.9)).toBe(false)
		expect(RateGate.tryPass(gate, 13)).toBe(true)
	end)

	it("limite le nombre d'appels par seconde", function()
		local gate = RateGate.new(2, nil)
		expect(RateGate.tryPass(gate, 0)).toBe(true)
		expect(RateGate.tryPass(gate, 0.1)).toBe(true)
		expect(RateGate.tryPass(gate, 0.2)).toBe(false)
		expect(RateGate.tryPass(gate, 1.05)).toBe(true)
	end)

	it("laisse tout passer sans limite", function()
		local gate = RateGate.new(nil, nil)
		for i = 1, 50 do
			expect(RateGate.tryPass(gate, i * 0.001)).toBe(true)
		end
	end)
end)

return nil
