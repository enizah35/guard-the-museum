--!strict
local TestKit = require("@tools/lib/TestKit")
local AnomalyScheduler = require("@shared/Domain/Proto/AnomalyScheduler")
local ProtoConfig = require("@shared/Content/ProtoConfig")
local Rng = require("@shared/Domain/Rng")

local describe, it, expect = TestKit.describe, TestKit.it, TestKit.expect

type ObjectRef = AnomalyScheduler.ObjectRef

local cfg = table.clone(ProtoConfig)
cfg.firstAnomalyDelaySeconds = 10
cfg.anomalyIntervalMinSeconds = 25
cfg.anomalyIntervalMaxSeconds = 35
cfg.maxActiveAnomalies = 4

local function objects(count: number): { ObjectRef }
	local list: { ObjectRef } = {}
	for i = 1, count do
		table.insert(list, { objectId = `Obj{i}`, roomId = if i % 2 == 0 then "Hall" else "Galerie", category = "Vase" })
	end
	return list
end

-- Fait tourner le planificateur seconde par seconde et renvoie les anomalies créées.
local function run(seconds: number, objs: { ObjectRef }, seed: number, c: any?)
	local conf = c or cfg
	local rng = Rng.new(seed)
	local scheduler = AnomalyScheduler.new(0, conf)
	local spawned = {}
	for t = 0, seconds do
		local anomaly = AnomalyScheduler.update(scheduler, t, objs, rng, conf)
		if anomaly then
			table.insert(spawned, anomaly)
		end
	end
	return spawned, scheduler
end

describe("Domain/Proto/AnomalyScheduler", function()
	it("attend le délai initial avant la première anomalie", function()
		local rng = Rng.new(1)
		local scheduler = AnomalyScheduler.new(0, cfg)
		expect(AnomalyScheduler.update(scheduler, 9.9, objects(5), rng, cfg)).toBeNil()
		expect(AnomalyScheduler.update(scheduler, 10, objects(5), rng, cfg) ~= nil).toBeTruthy()
	end)

	it("espace les anomalies de 25 à 35 s", function()
		local many = table.clone(cfg)
		many.maxActiveAnomalies = 100
		local spawned = run(2000, objects(100), 7, many)
		expect(#spawned).toBeGreaterThan(50)
		for i = 2, #spawned do
			local gap = spawned[i].startedAt - spawned[i - 1].startedAt
			-- Pas d'une seconde dans la simulation : on tolère l'arrondi au pas suivant.
			expect(gap >= 25 and gap <= 36).toBeTruthy()
		end
	end)

	it("ne met jamais deux anomalies sur le même objet en même temps", function()
		local many = table.clone(cfg)
		many.maxActiveAnomalies = 10
		local _, scheduler = run(1000, objects(3), 3, many)
		-- 3 objets seulement : au plus 3 anomalies actives, toutes sur des objets différents.
		expect(scheduler.activeCount).toBe(3)
		local seen: { [string]: boolean } = {}
		for _, anomaly in AnomalyScheduler.activeList(scheduler) do
			expect(seen[anomaly.objectId]).toBeNil()
			seen[anomaly.objectId] = true
		end
	end)

	it("respecte le plafond d'anomalies actives", function()
		local _, scheduler = run(3000, objects(20), 11)
		expect(scheduler.activeCount).toBe(cfg.maxActiveAnomalies)
	end)

	it("libère l'objet quand l'anomalie est résolue", function()
		local spawned, scheduler = run(10, objects(1), 5)
		expect(#spawned).toBe(1)
		local resolved = AnomalyScheduler.resolve(scheduler, "Obj1")
		expect(resolved and resolved.key).toBe(spawned[1].key)
		expect(scheduler.activeCount).toBe(0)
		expect(AnomalyScheduler.resolve(scheduler, "Obj1")).toBeNil()
	end)

	it("construit une clé règle:objet:salle et des paramètres Moved dans les bornes", function()
		local many = table.clone(cfg)
		many.maxActiveAnomalies = 100
		local spawned = run(4000, objects(200), 21, many)
		local rules: { [string]: number } = {}
		for _, anomaly in spawned do
			rules[anomaly.ruleId] = (rules[anomaly.ruleId] or 0) + 1
			expect(anomaly.key).toBe(`{anomaly.ruleId}:{anomaly.objectId}:{anomaly.roomId}`)
			local move = anomaly.move
			if anomaly.ruleId == "Moved" then
				assert(move ~= nil, "Moved sans paramètres")
				local distance = math.sqrt(move.offsetX ^ 2 + move.offsetZ ^ 2)
				expect(distance >= cfg.moveOffsetMinStuds - 1e-9 and distance <= cfg.moveOffsetMaxStuds + 1e-9).toBeTruthy()
				local yaw = math.abs(move.yawDegrees)
				expect(yaw >= cfg.moveYawMinDegrees and yaw <= cfg.moveYawMaxDegrees).toBeTruthy()
			else
				expect(move).toBeNil()
			end
		end
		expect((rules.Moved or 0) > 0 and (rules.Missing or 0) > 0).toBeTruthy()
	end)

	it("est déterministe pour une graine donnée", function()
		local a = run(600, objects(12), 99)
		local b = run(600, objects(12), 99)
		expect(#a).toBe(#b)
		for i = 1, #a do
			expect(a[i].key).toBe(b[i].key)
			expect(a[i].startedAt).toBe(b[i].startedAt)
		end
	end)

	it("ne crée rien sans objet", function()
		local spawned = run(300, {}, 1)
		expect(#spawned).toBe(0)
	end)
end)

return nil
