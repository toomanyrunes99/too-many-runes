-- Too Many Runes - Background work
-- The plugin reads the game's data a little at a time so the game never stalls. Each job is a "pass". One handler on the game's tick
-- (50 a second) runs every pass that is not finished, in the order they were added. A finished pass is dropped; one that stops with an
-- error is reported once and dropped (unless it is marked keep, like the clock).
return { run = function(T)
local _ENV = T

tickCount = 0 -- goes up by 1 every game tick: the plugin's clock

Passes = { list = {} }

-- HOW FAST THE BACKGROUND WORK GOES. The recipe passes ask Scan.of(n) how many things to do this tick (n = their number at full speed):
-- SCAN_SPEED, a share of full speed (the Settings page's "Speed of reading the game's data"; the game gives plugins no clock to measure with).
Scan = { factor = SCAN_SPEED or 0.5, boost = 1, pace = 0.3 }
-- Scan.pace (0.1 - 1, below): the share of that work done per tick while the game is struggling; *Instant* (Scan.boost) is not paced.
function Scan.paced() return ((Scan.boost or 1) > 1) and 1 or Scan.pace end
function Scan.of(base)
    local n = math.floor(base * Scan.factor * Scan.paced() + 0.5)
    return (n < 1) and 1 or n
end
-- The passes that ran at full speed without making the game stutter (item links, skill guides, furniture plans, station pictures: 3.0.07
-- to 3.0.15) keep it: only the heavier ones added in 3.0.16 (the uses, and checking each recipe one by one) go at the gentler speed.
-- (Scan.full: the passes that are smooth at full speed - item links, skill guides, station pictures. Scan.boost is 1, except with the
-- secret *Instant* speed on the Settings page, which makes these faster too.)
function Scan.full(base)
    local n = math.floor(base * (Scan.boost or 1) * Scan.paced() + 0.5)
    return (n < 1) and 1 or n
end

-- step(): does a little of the work. isDone(): true once it is finished. keep: carry on after an error instead of dropping it.
-- onError(err) (optional, before keep): what to do when the pass is dropped because of an error (the recipe passes use it to say "carry on
-- without me", so nothing waits for them for ever).
function Passes.add(name, step, isDone, onError, keep)
    if type(onError) ~= "function" then onError, keep = nil, onError end
    Passes.list[#Passes.list + 1] = { name = name, step = step, isDone = isDone, onError = onError, keep = keep }
end

local stopped = false

-- PACING BY THE FRAME RATE (3.1.49: the game lagged for about 4 seconds at every reload, while the item list was read). The game gives
-- plugins no clock, but it reports every frame it draws (Event.Draw) and every tick (Event.Logic, 50 a second), so the frames drawn per
-- tick show how smoothly it runs. Every half second they are compared with the best seen lately: below 70% of it, Scan.pace is cut (never
-- below a fifth of the work, so start-up cannot stall); above 85%, it goes up again, to the full speed chosen on the Settings page. It
-- starts at 0.3, so a reload starts gently and speeds up while the game copes. (The best fades slowly and rises at most 30% each half
-- second, so one moment of unusually many frames cannot hold the work down for long; the frames before the first tick - the files
-- loading - are not counted.)
local PACE_WINDOW, PACE_LOW, PACE_HIGH, PACE_MIN = 25, 0.7, 0.85, 0.2
local paceFrames, paceTicks, paceBest = 0, 0, nil
Event.Draw.Subscribe("tmr3_pace", function() if not stopped then paceFrames = paceFrames + 1 end end)
local function pace()
    if tickCount == 1 then paceFrames = 0 end
    paceTicks = paceTicks + 1
    if paceTicks < PACE_WINDOW then return end
    local perTick = paceFrames / paceTicks
    paceFrames, paceTicks = 0, 0
    paceBest = (paceBest == nil) and perTick or math.max(paceBest * 0.98, math.min(perTick, paceBest * 1.3))
    if perTick < PACE_LOW * paceBest then Scan.pace = math.max(PACE_MIN, Scan.pace * 0.6)
    elseif perTick > PACE_HIGH * paceBest then Scan.pace = math.min(1, Scan.pace * 1.25) end
end
Event.Logic.Subscribe("tmr3_tick", function()
    if stopped then return end
    tickCount = tickCount + 1
    pace()
    local list, i = Passes.list, 1
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
end)

function Passes.stop()
    stopped = true
    Passes.list = {}
end

end }
