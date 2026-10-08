--!strict
-- PROTOTYPE P0.5 — déroulé complet d'une nuit. Module PUR : le serveur appelle `step`
-- à chaque Heartbeat et `report` à chaque signalement validé, puis applique les
-- événements renvoyés (effets visuels, restauration des objets, attributs NightState).
--
-- Phases : Briefing (attente d'au moins 1 joueur + compte à rebours)
--        → Running (anomalies, menace, horloge)
--        → Ended (écran de fin, `restartDelaySeconds`) → Briefing…

local AnomalyScheduler = require("./AnomalyScheduler")
local NightClock = require("./NightClock")
local ProtoConfig = require("../../Content/ProtoConfig")
local ReportJudge = require("./ReportJudge")
local Rng = require("../Rng")
local Threat = require("./Threat")
local Types = require("../../Types")

type ProtoConfig = ProtoConfig.ProtoConfig
type Anomaly = AnomalyScheduler.Anomaly
type ObjectRef = AnomalyScheduler.ObjectRef
type Scheduler = AnomalyScheduler.Scheduler
type Verdict = ReportJudge.Verdict

export type Outcome = "Victory" | "Defeat"

export type Event =
	{ kind: "NightStarted" }
	| { kind: "AnomalySpawned", anomaly: Anomaly }
	| { kind: "NightEnded", outcome: Outcome }
	| { kind: "NightReset" } -- le serveur doit restaurer tous les objets

export type State = {
	cfg: ProtoConfig,
	rng: Rng.Rng,
	phase: Types.NightPhase,
	phaseElapsed: number, -- secondes passées dans la phase courante
	nightElapsed: number, -- secondes de nuit écoulées (phase Running)
	threat: number,
	score: number,
	correctReports: number,
	wrongReports: number,
	outcome: Outcome?,
	scheduler: Scheduler,
}

export type ReportOutcome = {
	verdict: Verdict,
	resolved: Anomaly?, -- anomalie annulée (le serveur restaure l'objet)
}

local NightLoop = {}

local function resetCounters(state: State)
	state.phaseElapsed = 0
	state.nightElapsed = 0
	state.threat = 0
	state.score = 0
	state.correctReports = 0
	state.wrongReports = 0
	state.outcome = nil
	state.scheduler = AnomalyScheduler.new(0, state.cfg)
end

function NightLoop.new(cfg: ProtoConfig, seed: number): State
	local state: State = {
		cfg = cfg,
		rng = Rng.new(seed),
		phase = "Briefing",
		phaseElapsed = 0,
		nightElapsed = 0,
		threat = 0,
		score = 0,
		correctReports = 0,
		wrongReports = 0,
		outcome = nil,
		scheduler = AnomalyScheduler.new(0, cfg),
	}
	return state
end

-- Remet la nuit en Briefing (objets à restaurer par le serveur).
local function reset(state: State, events: { Event })
	resetCounters(state)
	state.phase = "Briefing"
	local event: Event = { kind = "NightReset" }
	table.insert(events, event)
end

local function finish(state: State, outcome: Outcome, events: { Event })
	state.phase = "Ended"
	state.phaseElapsed = 0
	state.outcome = outcome
	local event: Event = { kind = "NightEnded", outcome = outcome }
	table.insert(events, event)
end

-- Avance la nuit de `dt` secondes. `playerCount` : joueurs présents sur le serveur.
function NightLoop.step(state: State, dt: number, objects: { ObjectRef }, playerCount: number): { Event }
	assert(dt >= 0, "NightLoop.step: dt négatif")
	local cfg = state.cfg
	local events: { Event } = {}

	if playerCount <= 0 then
		-- Plus personne : on repart de zéro dès que quelqu'un revient.
		if state.phase ~= "Briefing" or state.phaseElapsed > 0 then
			reset(state, events)
		end
		return events
	end

	if state.phase == "Briefing" then
		state.phaseElapsed += dt
		if state.phaseElapsed >= cfg.briefingSeconds then
			resetCounters(state)
			state.phase = "Running"
			local event: Event = { kind = "NightStarted" }
			table.insert(events, event)
		end
	elseif state.phase == "Running" then
		state.phaseElapsed += dt
		state.nightElapsed += dt
		state.threat = Threat.tick(state.threat, dt, state.scheduler.activeCount, cfg)
		if Threat.isMaxed(state.threat, cfg) then
			finish(state, "Defeat", events)
		elseif NightClock.isOver(state.nightElapsed, cfg) then
			finish(state, "Victory", events)
		else
			local anomaly = AnomalyScheduler.update(state.scheduler, state.nightElapsed, objects, state.rng, cfg)
			if anomaly ~= nil then
				local event: Event = { kind = "AnomalySpawned", anomaly = anomaly }
				table.insert(events, event)
			end
		end
	elseif state.phase == "Ended" then
		state.phaseElapsed += dt
		if state.phaseElapsed >= cfg.restartDelaySeconds then
			reset(state, events)
		end
	end
	return events
end

-- Juge un signalement déjà validé (contrat, distance, salle) par le serveur.
-- Renvoie nil hors phase Running (signalement ignoré, sans pénalité).
function NightLoop.report(state: State, report: Types.ReportPayload): ReportOutcome?
	if state.phase ~= "Running" then
		return nil
	end
	local cfg = state.cfg
	local verdict = ReportJudge.judge(state.scheduler.active, report, cfg)
	local resolved: Anomaly? = nil
	if verdict.ok then
		resolved = AnomalyScheduler.resolve(state.scheduler, report.objectId)
		state.correctReports += 1
	else
		state.wrongReports += 1
	end
	state.threat = Threat.applyDelta(state.threat, verdict.threatDelta, cfg)
	state.score = math.max(0, state.score + verdict.scoreDelta)
	return { verdict = verdict, resolved = resolved }
end

-- Secondes restantes avant la fin de la phase courante (pour l'affichage).
function NightLoop.secondsLeftInPhase(state: State): number
	local cfg = state.cfg
	if state.phase == "Briefing" then
		return math.max(0, cfg.briefingSeconds - state.phaseElapsed)
	elseif state.phase == "Running" then
		return math.max(0, cfg.nightDurationSeconds - state.nightElapsed)
	elseif state.phase == "Ended" then
		return math.max(0, cfg.restartDelaySeconds - state.phaseElapsed)
	end
	return 0
end

return NightLoop
