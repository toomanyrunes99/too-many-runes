-- Too Many Runes - Background work
-- The plugin reads the game's data a little at a time so the game never stalls. Each job is a "pass". One handler on the game's tick
-- (50 a second) runs every pass that is not finished, in the order they were added. A finished pass is dropped; one that stops with an
-- error is reported once and dropped (unless it is marked keep, like the clock).
return { run = function(T)
local _ENV = T

tickCount = 0 -- goes up by 1 every game tick: the plugin's clock

Passes = { list = {} }

-- HOW FAST THE BACKGROUND WORK GOES. The recipe passes ask Scan.of(n) how many things to do this tick (n = their number at full speed).
-- If the game gives Lua a clock (os.clock), the speed follows how long the passes took: over BACKGROUND_MS in a tick it slows down, well
-- under it speeds up again (never above full speed), so the game keeps its frame rate whatever the computer. Without a clock it stays at
-- SCAN_SPEED (a share of full speed).
Scan = { factor = SCAN_SPEED or 0.5, boost = 1 }
local clock = (type(os) == "table" and type(os.clock) == "function") and os.clock or nil
if clock ~= nil and not pcall(clock) then clock = nil end
if clock ~= nil then Scan.factor = 1 end
Scan.timed = (clock ~= nil)
function Scan.of(base)
    local n = math.floor(base * Scan.factor + 0.5)
    return (n < 1) and 1 or n
end
-- The passes that ran at full speed without making the game stutter (item links, skill guides, furniture plans, station pictures: 3.0.07
-- to 3.0.15) keep it: only the heavier ones added in 3.0.16 (the uses, and checking each recipe one by one) go at the gentler speed.
-- (Scan.full: the passes that are smooth at full speed - item links, skill guides, station pictures. Scan.boost is 1, except with the
-- secret *Instant* speed on the Settings page, which makes these faster too.)
function Scan.full(base)
    local n = math.floor(base * (Scan.boost or 1) + 0.5)
    return (n < 1) and 1 or n
end
local function pace(seconds)
    local budget = (BACKGROUND_MS or 5) / 1000
    if seconds > budget then Scan.factor = math.max(0.02, Scan.factor * 0.7)
    elseif seconds < budget / 2 then Scan.factor = math.min(1, Scan.factor * 1.05) end
end

-- step(): does a little of the work. isDone(): true once it is finished. keep: carry on after an error instead of dropping it.
-- onError(err) (optional, before keep): what to do when the pass is dropped because of an error (the recipe passes use it to say "carry on
-- without me", so nothing waits for them for ever).
function Passes.add(name, step, isDone, onError, keep)
    if type(onError) ~= "function" then onError, keep = nil, onError end
    Passes.list[#Passes.list + 1] = { name = name, step = step, isDone = isDone, onError = onError, keep = keep }
end

local stopped = false
Event.Logic.Subscribe("tmr3_tick", function()
    if stopped then return end
    tickCount = tickCount + 1
    local list, i = Passes.list, 1
    local started = clock and clock() or nil
    while i <= #list do
        local pass = list[i]
        if pass.isDone ~= nil and pass.isDone() then
            table.remove(list, i)
        else
            local ok, err = pcall(pass.step)
            if ok or pass.keep then
                if not ok then trouble("the " .. pass.name .. " pass", err) end
                i = i + 1
            else
                say("the " .. pass.name .. " pass stopped because of an error: " .. tostring(err))
                if pass.onError ~= nil then pcall(pass.onError, err) end
                table.remove(list, i)
            end
        end
    end
    if started ~= nil then pace(clock() - started) end
end)

function Passes.stop()
    stopped = true
    Passes.list = {}
end

end }
