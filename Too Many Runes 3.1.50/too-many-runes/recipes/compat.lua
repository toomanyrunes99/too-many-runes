-- Too Many Runes - Recipes: fitting the old recipe code into the new plugin
-- The files in this folder (reading, parse, links ... stations) are the old plugin's recipe readers, moved over almost unchanged: they have
-- been tested in the game for a long time and know a lot of small facts. They were written for the old plugin's names (itemIds, Scan,
-- formatNumber ...), so this file gives those names to them, pointing at the new plugin's own lists. Load order (see main.lua):
--   compat -> reading -> parse -> links -> manual -> unlocks -> rituals -> guides -> get -> copies -> doses -> player -> stations -> uses
--   -> recipe_tab -> uses_tab
-- The hand-written facts the code reads (the ones the game does not record) are in recipes/exceptions.lua: plain data.
return { run = function(T)
local _ENV = T

-- The hand-written facts (a plain table; the game's loader once answered "nothing" for a file, so it is asked again a few times).
local ok, data = pcall(require, "recipes/exceptions")
for _ = 1, 3 do
    if ok and type(data) == "table" then break end
    ok, data = pcall(require, "recipes/exceptions")
end
if not ok or type(data) ~= "table" then error("could not load recipes/exceptions.lua (" .. tostring(data) .. ")", 0) end
Exceptions = data

Recipes = {} -- everything the recipe files know (each file adds its part)

-- The old names for the item list: the same tables as Items.ids / names / lower / slotOf (they are filled in place, never replaced).
itemIds, itemNames, itemLower, idToSlot = Items.ids, Items.names, Items.lower, Items.slotOf

-- Small helpers under their old names.
formatNumber = withCommas
-- (Scan.of, how many things a pass may do this tick, is in core/passes.lua: it slows down when the game's frames would suffer)
-- Is this item junk? And is it junk that the "hide junk" switch is hiding? (The recipes and uses leave such items out.)
function Filters.isJunk(itemId)
    local slot = Items.slotOf[itemId]
    return slot ~= nil and Items.is(slot, Items.JUNK)
end
function Filters.junkHidden(itemId)
    local slot = Items.slotOf[itemId]
    return Filters.hide.junk == true and slot ~= nil and Items.is(slot, Items.JUNK)
end

-- Two small helpers of the old Uses file, for the recipe files loaded before it (recipes/uses.lua makes the real ones).
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

-- The old window's sizes, which the recipe code uses to count how tall a recipe is (the new Recipe tab lays its rows out itself).
LINE_HEIGHT, ROW_HEIGHT = LINE_H, 26
RECIPE_MAX_LINES = rawget(T, "RECIPE_MAX_LINES") or 40

end }
