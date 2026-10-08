--!strict
local TestKit = require("@tools/lib/TestKit")
local AnomalyScheduler = require("@shared/Domain/Proto/AnomalyScheduler")
local NightLoop = require("@shared/Domain/Proto/NightLoop")
local ProtoConfig = require("@shared/Content/ProtoConfig")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

type ObjectRef = AnomalyScheduler.ObjectRef

local OBJECTS: { ObjectRef } = {
	{ objectId = "Vase", roomId = "Hall", category = "Vase" },
	{ objectId = "Statue", roomId = "Hall", category = "Statue" },
	{ objectId = "Globe", roomId = "Archives", category = "Artifact" },
	{ objectId = "Totem", roomId = "Galerie", category = "Statue" },
}

local function config(): any
	local cfg = table.clone(ProtoConfig)
	cfg.briefingSeconds = 5
	cfg.nightDurationSeconds = 360
	cfg.restartDelaySeconds = 10
	cfg.firstAnomalyDelaySeconds = 10
	return cfg
end

-- Avance de `seconds` secondes par pas de `dt` et accumule les événements.
local function advance(state: NightLoop.State, seconds: number, players: number?, dt: number?)
	local step = dt or 0.5
	local events: { NightLoop.Event } = {}
	local t = 0
	while t < seconds - 1e-9 do
		for _, event in NightLoop.step(state, step, OBJECTS, players or 1) do
			table.insert(events, event)
		end
		t += step
	end
	return events
end

local function kinds(events: { NightLoop.Event }): { string }
	local out = {}
	for _, event in events do
		table.insert(out, event.kind)
	end
	return out
end

-- Signale juste toutes les anomalies actives (équipe parfaite).
local function reportAll(state: NightLoop.State)
	for _, anomaly in AnomalyScheduler.activeList(state.scheduler) do
		NightLoop.report(state, { roomId = anomaly.roomId, objectId = anomaly.objectId, ruleId = anomaly.ruleId })
	end
end

describe("Domain/Proto/NightLoop", function()
	it("attend un joueur, puis lance la nuit après le briefing", function()
		local state = NightLoop.new(config(), 1)
		expect(#advance(state, 20, 0)).toBe(0)
		expect(state.phase).toBe("Briefing")
		local events = advance(state, 5)
		expect(state.phase).toBe("Running")
		expect(kinds(events)[1]).toBe("NightStarted")
	end)

	it("une équipe parfaite tient jusqu'à 6 h : victoire", function()
		local state = NightLoop.new(config(), 2)
		advance(state, 5)
		local spawned = 0
		local ended: string? = nil
		for _ = 1, 400 do
			for _, event in NightLoop.step(state, 1, OBJECTS, 2) do
				if event.kind == "AnomalySpawned" then
					spawned += 1
				elseif event.kind == "NightEnded" then
					ended = event.outcome
				end
			end
			reportAll(state)
			if ended then
				break
			end
		end
		expect(ended).toBe("Victory")
		expect(state.phase).toBe("Ended")
		expect(spawned >= 10 and spawned <= 15).toBeTruthy() -- ~1 toutes les 30 s sur 6 min
		expect(state.correctReports).toBe(spawned)
		expect(state.wrongReports).toBe(0)
		expect(state.score).toBe(spawned * ProtoConfig.scoreCorrectReport)
		expect(state.threat).toBeLessThan(10)
	end)

	it("une équipe qui ne signale rien perd avant la fin de la nuit", function()
		local state = NightLoop.new(config(), 3)
		advance(state, 5)
		local ended: string? = nil
		while state.phase == "Running" do
			for _, event in NightLoop.step(state, 1, OBJECTS, 1) do
				if event.kind == "NightEnded" then
					ended = event.outcome
				end
			end
		end
		expect(ended).toBe("Defeat")
		expect(state.outcome).toBe("Defeat")
		expect(state.threat).toBe(ProtoConfig.threatMax)
		expect(state.nightElapsed).toBeLessThan(ProtoConfig.nightDurationSeconds)
	end)

	it("un faux signalement fait monter la menace et compte une erreur", function()
		local state = NightLoop.new(config(), 4)
		advance(state, 5)
		local outcome = NightLoop.report(state, { roomId = "Hall", objectId = "Vase", ruleId = "Missing" })
		assert(outcome ~= nil, "signalement ignoré")
		expect(outcome.verdict.ok).toBe(false)
		expect(outcome.resolved).toBeNil()
		expect(state.threat).toBe(ProtoConfig.threatWrongReport)
		expect(state.wrongReports).toBe(1)
		expect(state.score).toBe(0) -- jamais négatif
	end)

	it("un signalement juste annule l'anomalie et la renvoie pour restauration", function()
		local state = NightLoop.new(config(), 5)
		advance(state, 5)
		advance(state, 11) -- première anomalie à 10 s
		local active = AnomalyScheduler.activeList(state.scheduler)
		expect(#active).toBe(1)
		local anomaly = active[1]
		local before = state.threat
		local outcome =
			NightLoop.report(state, { roomId = anomaly.roomId, objectId = anomaly.objectId, ruleId = anomaly.ruleId })
		assert(outcome ~= nil, "signalement ignoré")
		expect(outcome.verdict.ok).toBe(true)
		expect(outcome.resolved and outcome.resolved.key).toBe(anomaly.key)
		expect(state.scheduler.activeCount).toBe(0)
		expect(state.threat).toBe(math.max(0, before + ProtoConfig.threatCorrectReport))
	end)

	it("ignore les signalements hors de la phase Running", function()
		local state = NightLoop.new(config(), 6)
		expect(NightLoop.report(state, { roomId = "Hall", objectId = "Vase", ruleId = "Moved" })).toBeNil()
	end)

	it("relance une nuit après l'écran de fin, avec compteurs remis à zéro", function()
		local state = NightLoop.new(config(), 7)
		advance(state, 5)
		local guard = 0
		while state.phase == "Running" and guard < 1000 do
			NightLoop.step(state, 1, OBJECTS, 1) -- personne ne signale : défaite
			guard += 1
		end
		expect(state.phase).toBe("Ended")
		expect(math.ceil(NightLoop.secondsLeftInPhase(state))).toBeGreaterThan(0)
		local events = advance(state, 10)
		expect(table.find(kinds(events), "NightReset") ~= nil).toBeTruthy()
		expect(state.phase).toBe("Briefing")
		expect(state.threat).toBe(0)
		expect(state.scheduler.activeCount).toBe(0)
		advance(state, 5)
		expect(state.phase).toBe("Running")
	end)

	it("repart en briefing si tous les joueurs partent", function()
		local state = NightLoop.new(config(), 8)
		advance(state, 30)
		expect(state.phase).toBe("Running")
		local events = NightLoop.step(state, 0.5, OBJECTS, 0)
		expect(kinds(events)).toEqual({ "NightReset" })
		expect(state.phase).toBe("Briefing")
		expect(#NightLoop.step(state, 0.5, OBJECTS, 0)).toBe(0)
	end)
end)

return nil
