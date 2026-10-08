--!strict
local TestKit = require("@tools/lib/TestKit")
local AnomalyScheduler = require("@shared/Domain/Proto/AnomalyScheduler")
local ProtoConfig = require("@shared/Content/ProtoConfig")
local ReportJudge = require("@shared/Domain/Proto/ReportJudge")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

type Anomaly = AnomalyScheduler.Anomaly

local cfg = ProtoConfig

local function active(): { [string]: Anomaly }
	return {
		Vase = {
			key = "Moved:Vase:Hall",
			ruleId = "Moved",
			objectId = "Vase",
			roomId = "Hall",
			startedAt = 12,
			move = { offsetX = 1, offsetZ = 1, yawDegrees = 15 },
		},
		Globe = {
			key = "Missing:Globe:Archives",
			ruleId = "Missing",
			objectId = "Globe",
			roomId = "Archives",
			startedAt = 40,
		},
	}
end

describe("Domain/Proto/ReportJudge", function()
	it("valide un signalement juste (bon objet, bonne règle, bonne salle)", function()
		local verdict = ReportJudge.judge(active(), { roomId = "Hall", objectId = "Vase", ruleId = "Moved" }, cfg)
		expect(verdict.ok).toBe(true)
		expect(verdict.anomalyKey).toBe("Moved:Vase:Hall")
		expect(verdict.threatDelta).toBe(cfg.threatCorrectReport)
		expect(verdict.scoreDelta).toBe(cfg.scoreCorrectReport)
	end)

	it("refuse un objet sans anomalie", function()
		local verdict = ReportJudge.judge(active(), { roomId = "Hall", objectId = "Statue", ruleId = "Moved" }, cfg)
		expect(verdict.ok).toBe(false)
		expect(verdict.anomalyKey).toBeNil()
		expect(verdict.threatDelta).toBe(cfg.threatWrongReport)
		expect(verdict.scoreDelta).toBe(cfg.scoreWrongReport)
	end)

	it("refuse la mauvaise règle sur un objet anomal", function()
		local verdict = ReportJudge.judge(active(), { roomId = "Archives", objectId = "Globe", ruleId = "Moved" }, cfg)
		expect(verdict.ok).toBe(false)
	end)

	it("refuse la mauvaise salle", function()
		local verdict = ReportJudge.judge(active(), { roomId = "Galerie", objectId = "Vase", ruleId = "Moved" }, cfg)
		expect(verdict.ok).toBe(false)
	end)

	it("connaît les règles du prototype", function()
		expect(ReportJudge.isKnownRule("Moved", cfg)).toBe(true)
		expect(ReportJudge.isKnownRule("Missing", cfg)).toBe(true)
		expect(ReportJudge.isKnownRule("Rotated", cfg)).toBe(false)
	end)
end)

return nil
