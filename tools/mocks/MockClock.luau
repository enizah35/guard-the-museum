--!strict
-- Horloge contrôlable pour tester le code temporel sans attendre.
-- Le code testé reçoit `clock.now` (au lieu de os.clock / workspace:GetServerTimeNow)
-- et `clock.delay` (au lieu de task.delay). Le test fait avancer le temps avec `advance`.

export type MockClock = {
	now: () -> number,
	delay: (seconds: number, fn: () -> ()) -> number,
	cancel: (id: number) -> (),
	advance: (seconds: number) -> (),
	pendingCount: () -> number,
}

type Timer = { id: number, at: number, fn: () -> () }

local MockClock = {}

function MockClock.new(start: number?): MockClock
	local current = start or 0
	local nextId = 0
	local timers: { Timer } = {}

	local clock = {} :: MockClock

	function clock.now(): number
		return current
	end

	function clock.delay(seconds: number, fn: () -> ()): number
		assert(seconds >= 0, "MockClock.delay : durée négative")
		nextId += 1
		table.insert(timers, { id = nextId, at = current + seconds, fn = fn })
		return nextId
	end

	function clock.cancel(id: number)
		for i, timer in timers do
			if timer.id == id then
				table.remove(timers, i)
				return
			end
		end
	end

	-- Avance le temps ; déclenche les minuteurs échus dans l'ordre (échéance, puis création).
	function clock.advance(seconds: number)
		assert(seconds >= 0, "MockClock.advance : durée négative")
		local target = current + seconds
		while true do
			local bestIndex: number? = nil
			for i, timer in timers do
				if timer.at <= target then
					local best = if bestIndex then timers[bestIndex] else nil
					if best == nil or timer.at < best.at or (timer.at == best.at and timer.id < best.id) then
						bestIndex = i
					end
				end
			end
			if bestIndex == nil then
				break
			end
			local timer = table.remove(timers, bestIndex) :: Timer
			current = timer.at
			timer.fn()
		end
		current = target
	end

	function clock.pendingCount(): number
		return #timers
	end

	return clock
end

return MockClock
