--!strict
-- PROTOTYPE P0.5 — simulation d'équilibrage hors Studio : `lune run tools/proto-sim`
-- Joue des nuits avec Content/ProtoConfig et une équipe fictive qui signale chaque
-- anomalie après `délai` secondes (et fait `faux` faux signalements par nuit).
-- Sert à vérifier l'effet d'un réglage avant de le tester en jeu.

local AnomalyScheduler = require("@shared/Domain/Proto/AnomalyScheduler")
local NightLoop = require("@shared/Domain/Proto/NightLoop")
local ProtoConfig = require("@shared/Content/ProtoConfig")

local OBJECTS: { AnomalyScheduler.ObjectRef } = {}
for i = 1, 12 do
	table.insert(OBJECTS, { objectId = `Obj{i}`, roomId = `Room{(i - 1) // 3 + 1}`, category = "Test" })
end

local NIGHTS = 50

-- Renvoie (victoires, durée moyenne tenue, menace max moyenne).
local function simulate(reactionDelay: number, wrongPerNight: number): (number, number, number)
	local victories, survived, peak = 0, 0, 0
	for seed = 1, NIGHTS do
		local state = NightLoop.new(ProtoConfig, seed)
		NightLoop.step(state, ProtoConfig.briefingSeconds, OBJECTS, 1)
		local wrongEvery = if wrongPerNight > 0 then ProtoConfig.nightDurationSeconds / (wrongPerNight + 1) else math.huge
		local nextWrong = wrongEvery
		local nightPeak = 0
		while state.phase == "Running" do
			NightLoop.step(state, 0.5, OBJECTS, 1)
			nightPeak = math.max(nightPeak, state.threat)
			for _, anomaly in AnomalyScheduler.activeList(state.scheduler) do
				if state.nightElapsed - anomaly.startedAt >= reactionDelay then
					NightLoop.report(state, {
						roomId = anomaly.roomId,
						objectId = anomaly.objectId,
						ruleId = anomaly.ruleId,
					})
				end
			end
			if state.nightElapsed >= nextWrong then
				nextWrong += wrongEvery
				NightLoop.report(state, { roomId = "Nowhere", objectId = "Nothing", ruleId = "Moved" })
			end
		end
		if state.outcome == "Victory" then
			victories += 1
		end
		survived += state.nightElapsed
		peak += nightPeak
	end
	return victories, survived / NIGHTS, peak / NIGHTS
end

print(`Simulation sur {NIGHTS} nuits (12 objets, réglages de Content/ProtoConfig)`)
print("délai de réaction | faux/nuit | victoires | tenu (s) | menace max moy.")
for _, delay in { 10, 20, 30, 45, 60, 90, 1e9 } do
	for _, wrong in { 0, 3 } do
		local victories, survived, peak = simulate(delay, wrong)
		local label = if delay >= 1e9 then "jamais" else `{delay} s`
		print(
			string.format(
				"%17s | %9d | %6d/%d | %8.0f | %6.1f",
				label,
				wrong,
				victories,
				NIGHTS,
				survived,
				peak
			)
		)
	end
end
