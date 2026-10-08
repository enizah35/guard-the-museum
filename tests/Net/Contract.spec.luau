--!strict
local TestKit = require("@tools/lib/TestKit")
local Contract = require("@shared/Net/Contract")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

describe("Net/Contract", function()
	it("déclare chaque remote avec un nom cohérent, un sens et un validateur", function()
		local count = 0
		for key, spec in Contract do
			count += 1
			expect(spec.name).toBe(key)
			expect(spec.direction == "ClientToServer" or spec.direction == "ServerToClient").toBeTruthy()
			expect(type(spec.validate)).toBe("function")
			expect(string.match(key, "^%u%a+%.%u%a+$") ~= nil).toBeTruthy()
		end
		expect(count).toBeGreaterThan(0)
	end)

	it("impose une limite de fréquence ou un cooldown à chaque remote C→S", function()
		for _, spec in Contract do
			if spec.direction == "ClientToServer" then
				expect(spec.rateLimitPerSecond ~= nil or spec.cooldownSeconds ~= nil).toBeTruthy()
			end
		end
	end)

	it("rejette les contenus invalides de Night.Report", function()
		local validate = Contract["Night.Report"].validate
		expect((validate({ roomId = "Hall", objectId = "Vase_03", ruleId = "Moved" }))).toBe(true)
		expect((validate(nil))).toBe(false)
		expect((validate("Hall"))).toBe(false)
		expect((validate({ roomId = "Hall", objectId = "Vase_03" }))).toBe(false)
		expect((validate({ roomId = 1, objectId = "Vase_03", ruleId = "Moved" }))).toBe(false)
		expect((validate({ roomId = "Hall", objectId = "Vase_03", ruleId = "Moved", extra = true }))).toBe(false)
		expect((validate({ roomId = string.rep("x", 65), objectId = "V", ruleId = "Moved" }))).toBe(false)
	end)

	it("rejette un contenu sur les remotes sans contenu, et un ping non Vector3", function()
		expect((Contract["Lobby.LeavePod"].validate(nil))).toBe(true)
		expect((Contract["Lobby.LeavePod"].validate({}))).toBe(false)
		expect((Contract["Night.Ping"].validate({ x = 1, y = 2, z = 3 }))).toBe(false)
	end)

	it("valide Night.ViewCamera (identifiant ou nil pour quitter)", function()
		local validate = Contract["Night.ViewCamera"].validate
		expect((validate("CAM-1"))).toBe(true)
		expect((validate(nil))).toBe(true)
		expect((validate(3))).toBe(false)
		expect((validate(""))).toBe(false)
	end)

	it("valide Night.ReportResult avec ses champs optionnels d'équipe", function()
		local validate = Contract["Night.ReportResult"].validate
		expect((validate({ ok = false, threatDelta = 10 }))).toBe(true)
		expect((validate({
			ok = true,
			anomalyKey = "Moved:Vase:Hall",
			threatDelta = -5,
			scoreDelta = 100,
			objectId = "Vase",
			roomId = "Hall",
			ruleId = "Moved",
			reporterName = "Hugo",
		}))).toBe(true)
		expect((validate({ ok = true, threatDelta = -5, scoreDelta = "100" }))).toBe(false)
		expect((validate({ ok = true, threatDelta = -5, reporterName = 12 }))).toBe(false)
	end)

	it("est figé (aucune remote ajoutée à l'exécution)", function()
		expect(function()
			(Contract :: any)["Hack.Remote"] = {}
		end).toThrow()
	end)
end)

return nil
