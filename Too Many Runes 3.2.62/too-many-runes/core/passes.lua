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
-- Scan.pace (0.2 - 3, below): the share of that work done per tick - less while the game is struggling, more while it copes easily;
-- *Instant* (Scan.boost) is not paced.
function Scan.paced() return ((Scan.boost or 1) > 1) and 1 or Scan.pace end
function Scan.of(base)
    local n = math.floor(base * Scan.factor * Scan.paced() + 0.5)
    return (n < 1) and 1 or n
end
-- The light passes run at full speed without making the game stutter (Scan.full: item links, skill guides, furniture plans, station
-- pictures); only the heavier ones (the uses, and checking each recipe one by one) go at the gentler speed. Scan.boost is 1, except with
-- the secret *Instant* speed on the Settings page, which makes the full-speed passes faster too.
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

-- PACING BY THE FRAME RATE (without it the game lagged for about 4 seconds at every reload, while the item list was read). The game gives
-- plugins no clock, but it reports every frame it draws (Event.Draw) and every tick (Event.Logic, 50 a second), so the frames drawn per
-- tick show how smoothly it runs. Every half second they are compared with the best seen lately: below 70% of it, Scan.pace is cut (never
-- below a fifth of the work, so start-up cannot stall); above 85%, it goes up again, to the full speed chosen on the Settings page. It
-- starts at 0.3, so a reload starts gently and speeds up while the game copes. (The best fades slowly and rises at most 30% each half
-- second, so one moment of unusually many frames cannot hold the work down for long; the frames before the first tick - the files loading -
-- are not counted.)
local PACE_WINDOW, PACE_LOW, PACE_HIGH, PACE_MIN = 25, 0.7, 0.85, 0.2
-- While the game copes easily - above 92% of its best frames - the work climbs past the chosen speed, up to PACE_MAX times it; below 85% it
-- eases back to the chosen speed, and below 70% it is cut as above. (Without the climb, "Smooth" took about a minute to read everything
-- while the game kept 80 - 105 frames a second.)
local PACE_MAX, OVER_LOW, OVER_HIGH = 3, 0.85, 0.92
local paceFrames, paceTicks, paceBest = 0, 0, nil
Event.Draw.Subscribe("tmr3_pace", function() if not stopped then paceFrames = paceFrames + 1 end end)
local function pace()
    if tickCount == 1 then paceFrames = 0 end
    paceTicks = paceTicks + 1
    if paceTicks < PACE_WINDOW then return end
    local perTick = paceFrames / paceTicks
    paceFrames, paceTicks = 0, 0
    if paceBest == nil or paceBest <= 0 then
        -- Why zero frames are ignored: no frames yet (the game minimized, or *Instant* freezing it) is nothing to compare with - a best of
        -- 0 made every later check look easy, and the work stayed at its fastest.
        if perTick <= 0 then return end
        paceBest = perTick
    else
        paceBest = math.max(paceBest * 0.98, math.min(perTick, paceBest * 1.3))
    end
    if Scan.pace > 1 then
        if perTick < PACE_LOW * paceBest then Scan.pace = 1
        elseif perTick < OVER_LOW * paceBest then Scan.pace = math.max(1, Scan.pace * 0.75)
        elseif perTick > OVER_HIGH * paceBest then Scan.pace = math.min(PACE_MAX, Scan.pace * 1.2) end
    elseif perTick < PACE_LOW * paceBest then Scan.pace = math.max(PACE_MIN, Scan.pace * 0.6)
    elseif perTick > PACE_HIGH * paceBest then
        Scan.pace = math.min(1, Scan.pace * 1.25)
        if Scan.pace >= 1 and perTick > OVER_HIGH * paceBest then Scan.pace = 1.2 end
    end
end
-- (3.2.61) BACKING OFF WHEN THE GAME IS BEHIND. A tick that comes with no frame drawn since the last one means the game is catching up on
-- ticks it missed - it runs them back to back without drawing. Work done in those ticks only pushes it further behind: the hitch check
-- (3.2.59 - 3.2.61, since taken out) found freezes of 40 - 75 ticks (about a second) after "recipes ready", each a chain of catch-up ticks that all did more
-- work. So such a tick does none of the passes' work. At most BEHIND_SKIP in a row are skipped, so the work still goes on while the game
-- draws nothing at all (minimized). (The first ticks, before any frame, are not skipped.)
local BEHIND_SKIP = 7
local drawnSinceTick, behindRun, everDrawn = 0, 0, false
Event.Draw.Subscribe("tmr3_behind", function() if not stopped then drawnSinceTick = drawnSinceTick + 1; everDrawn = true end end)

Event.Logic.Subscribe("tmr3_tick", function()
    if stopped then return end
    tickCount = tickCount + 1
    local behind = everDrawn and drawnSinceTick == 0
    drawnSinceTick = 0
    if behind then behindRun = behindRun + 1 else behindRun = 0 end
    pace()
    if behind and behindRun <= BEHIND_SKIP then return end -- (the game is behind: let it catch up and draw)
    local list, i = Passes.list, 1
    while i <= #list do
        local pass = list[i]
        local okDone, done = true, false
        if pass.isDone ~= nil then okDone, done = pcall(pass.isDone) end -- (an error here does not stop every pass)
        if okDone and done then
            table.remove(list, i)
        else
            local ok, err
            if okDone then ok, err = pcall(pass.step) else ok, err = false, done end
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
