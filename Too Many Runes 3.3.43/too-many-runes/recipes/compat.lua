-- Too Many Runes - Recipes: shared set-up for the recipe files
-- The files in this folder (reading, parse, links ... stations) are the recipe readers. They know a lot of small facts about the
-- game's data. This file loads the hand-written facts and a few shared helpers. Load order (see main.lua):
-- compat, reading, parse, links, manual, unlocks, rituals, guides, get, copies, doses, player, stations, uses, recipe_tab,
-- uses_tab
-- The hand-written facts the code reads (the ones the game does not record) are in recipes/exceptions.lua: plain data.
return { run = function(T)
local _ENV = T

-- The hand-written facts, a plain table. The game's loader can answer "nothing" for a file, so it is asked again a few times.
local ok, data = pcall(require, "recipes/exceptions")
for _ = 1, 3 do
    if ok and type(data) == "table" then break end
    ok, data = pcall(require, "recipes/exceptions")
end
if not ok or type(data) ~= "table" then error("could not load recipes/exceptions.lua (" .. tostring(data) .. ")", 0) end
Exceptions = data

-- The names typed by hand. recipes/exceptions.lua names many of the game's lists (enums) and settings (params) by hand. If a game
-- update renames one, its recipes quietly go missing. So every list and setting asked for by name is watched here, and once the
-- wiki recipes are read (the last of the start-up reading), one line names any of exceptions.lua's that the game did not have.
local missing = {}
do
    local realConfig = config
    local function watch(real, kind)
        return setmetatable({}, { __index = function(_, name)
            local ok, v = pcall(function() return real[name] end)
            if missing ~= nil and (not ok or v == nil) and type(name) == "string" then missing[name] = kind end
            if not ok then error(v, 0) end
            return v
        end })
    end
    local okE, realEnum = pcall(function() return realConfig.Enum end)
    local okP, realParam = pcall(function() return realConfig.Param end)
    if realConfig ~= nil and okE and okP and realEnum ~= nil and realParam ~= nil then
        local watched = { Enum = watch(realEnum, "list"), Param = watch(realParam, "setting") }
        config = setmetatable({}, { __index = function(t, k)
            local v = watched[k]
            if v == nil then v = realConfig[k] end
            if v ~= nil then rawset(t, k, v) end -- asked once: Obj, Enum ... are then found straight away
            return v
        end })
    end
end
local function handNames(t, out, depth)
    local function add(v) if type(v) == "string" and string.find(v, "_", 1, true) and string.match(v, "^[A-Z][A-Z0-9_]+$") then out[v] = true end end
    for k, v in pairs(t) do
        add(k); add(v)
        if type(v) == "table" and depth < 8 then handNames(v, out, depth + 1) end
    end
    return out
end
Passes.add("hand-typed names", function()
    if Wiki == nil or not Wiki.ready then return end
    local typed, gone = handNames(Exceptions, {}, 1), {}
    for name, kind in pairs(missing) do if typed[name] then gone[#gone + 1] = name .. " (" .. kind .. ")" end end
    table.sort(gone)
    if #gone > 0 then
        say(#gone .. " of the game's lists or settings named in recipes/exceptions.lua were not found (a game update may have renamed them): "
            .. table.concat(gone, ", "))
    end
    missing = nil
    -- Once done, the watcher goes: the game's own config is used again (no extra check on every look-up), and nothing of the game's
    -- is kept in our tables for main.lua's PluginShutdown to empty.
    rawset(_ENV, "config", nil)
end, function() return missing == nil end)

Recipes = {} -- everything the recipe files know (each file adds its part)

-- Scan.of, how many things a pass may do this tick, is in core/passes.lua; it slows down when the game's frames would suffer.
-- Is this item junk, and is it junk that the "hide junk" switch is hiding? The recipes and uses leave such items out.
function Filters.isJunk(itemId)
    local slot = Items.slotOf[itemId]
    return slot ~= nil and Items.is(slot, Items.JUNK)
end
function Filters.junkHidden(itemId)
    local slot = Items.slotOf[itemId]
    return Filters.hide.junk == true and slot ~= nil and Items.is(slot, Items.JUNK)
end

-- Two small helpers for the recipe files loaded before recipes/uses.lua, which makes the real ones.
Recipes.usedState = Recipes.usedState or { ready = false, by = {}, lists = {} }
function Recipes.usedHas(obj, p)
    if p == nil then return false end
    local okHas, has = pcall(function() return obj:HasParam(p) end)
    return okHas and has == true
end
function Recipes.usedName(itemId)
    local slot = Items.slotOf[itemId]
    return slot and Items.names[slot] or nil
end

-- The height of a row with a picture, which the recipe code uses to count how tall a recipe is (the Recipe tab lays its rows out itself;
-- a plain line is LINE_H). The most rows one recipe shows: RECIPE_MAX_LINES in settings.lua.
ROW_HEIGHT = 26

end }
