--!strict
-- PROTOTYPE P0.5 — juge des signalements. Module PUR.
-- Un signalement est juste si l'objet porte une anomalie active de la même règle
-- et dans la même salle. Sinon c'est un faux signalement (y compris mauvaise règle).

local AnomalyScheduler = require("./AnomalyScheduler")
local ProtoConfig = require("../../Content/ProtoConfig")
local Types = require("../../Types")

type ProtoConfig = ProtoConfig.ProtoConfig
type Anomaly = AnomalyScheduler.Anomaly

export type Verdict = {
	ok: boolean,
	anomalyKey: Types.AnomalyKey?,
	threatDelta: number,
	scoreDelta: number,
}

local ReportJudge = {}

function ReportJudge.isKnownRule(ruleId: string, cfg: ProtoConfig): boolean
	return table.find(cfg.rules, ruleId :: any) ~= nil
end

function ReportJudge.judge(
	active: { [Types.ObjectId]: Anomaly },
	report: Types.ReportPayload,
	cfg: ProtoConfig
): Verdict
	local anomaly = active[report.objectId]
	if anomaly ~= nil and anomaly.ruleId == report.ruleId and anomaly.roomId == report.roomId then
		return {
			ok = true,
			anomalyKey = anomaly.key,
			threatDelta = cfg.threatCorrectReport,
			scoreDelta = cfg.scoreCorrectReport,
		}
	end
	return {
		ok = false,
		anomalyKey = nil,
		threatDelta = cfg.threatWrongReport,
		scoreDelta = cfg.scoreWrongReport,
	}
end

return ReportJudge
