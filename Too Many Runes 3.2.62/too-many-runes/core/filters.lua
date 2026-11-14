-- Too Many Runes - Filters, hide switches and favourites
-- Which items a list shows: All items or the Favorites (3.2.47: picked with the Favorites tab, core/shelves.lua - the dropdown beside the
-- search box is gone), the hide switches (noted, broken, junk ...) and the favourites (the star in the info box, remembered in the game's
-- storage for this plugin).
return { run = function(T)
local _ENV = T

Filters = { list = {}, byKey = {}, key = "all", hide = {}, fav = {}, view = {}, built = 0, dirty = true }

-- Add a filter. test(slot) says whether an item gets through; ignoresHide = true when the hide switches do not apply
-- (Favorites: you picked those yourself).
function Filters.add(key, label, test, ignoresHide)
    local f = { key = key, label = label, test = test, ignoresHide = ignoresHide }
    Filters.list[#Filters.list + 1] = f
    Filters.byKey[key] = f
end
Filters.add("all", "All items", function() return true end)
Filters.add("fav", "Favorites", function(slot) return Filters.fav[Items.ids[slot]] == true end, true)
Filters.byKey.fav.list = function() return Filters.favouriteList() end -- (newest favourite first, not in item order)
-- Is the item made by a recipe? (made by recipes/uses_tab.lua; false until then - the item groups use it, core/groups.lua)
-- (3.2.47: the Craftable, Uncraftable, Gathered and Wiki choices went with the dropdown; a reload starts on All, as the tabs do)
function Filters.craftable() return false end

-- The hide switches: the saved choice ("on" / "off"), or the setting.
local SWITCH_FLAGS = { noted = Items.NOTED, broken = Items.BROKEN, junk = Items.JUNK,
                       dungeoneering = Items.DUNG, discontinued = Items.DISC }
-- (3.2.50) and minigame items: the ones on Misc > Minigames (core/shelves.lua) - no flag of their own, so not in SWITCH_FLAGS
local SWITCHES = { "noted", "broken", "junk", "dungeoneering", "discontinued", "minigames" }
for _, name in ipairs(SWITCHES) do
    local s = Saved.get("hide_" .. name)
    if s == "on" then Filters.hide[name] = true elseif s == "off" then Filters.hide[name] = false else Filters.hide[name] = (HIDE or {})[name] == true end
end

-- Does the item get past the hide switches?
function Filters.shown(slot)
    local f = Items.flags[slot]
    if f == nil then return true end
    for name, flag in pairs(SWITCH_FLAGS) do
        if Filters.hide[name] and (f & flag) ~= 0 then return false end
    end
    if Filters.hide.minigames and Shelves ~= nil and Shelves.of[slot] == "misc.minigames" then return false end
    return true
end

-- Does the item get through the filter and the hide switches?
function Filters.passes(slot)
    local f = Filters.byKey[Filters.key]
    if not f.ignoresHide and not Filters.shown(slot) then return false end
    if Shelves ~= nil and not Shelves.passes(slot) then return false end -- (3.2.12: the bank tab above the list - core/shelves.lua)
    return f.test(slot)
end

-- The slots that pass, in item order. Grows while the item list loads; built again from the start after invalidate().
function Filters.invalidate() Filters.dirty = true end
function Filters.current()
    local f = Filters.byKey[Filters.key]
    if f.list ~= nil then return f.list() end
    if Filters.dirty then Filters.view, Filters.built, Filters.dirty = {}, 0, false end
    local view, n = Filters.view, #Items.ids
    for slot = Filters.built + 1, n do
        if Filters.passes(slot) then view[#view + 1] = slot end
    end
    Filters.built = n
    return view
end

-- Something changed what passes: run the search again so every tab shows the new list.
local function changed()
    Filters.invalidate()
    if Search ~= nil then Search.refresh() end
end

function Filters.setKey(key)
    if Filters.byKey[key] == nil or key == Filters.key then return end
    Filters.key = key
    changed()
end

function Filters.setHide(name, flag)
    if SWITCH_FLAGS[name] == nil and name ~= "minigames" then return end
    Filters.hide[name] = (flag == true)
    Saved.set("hide_" .. name, flag and "on" or "off")
    changed()
    -- The recipes and uses already worked out leave hidden junk out (or keep it in): they are worked out again, and the item open on the
    -- right is drawn again (otherwise an item opened earlier keeps the old answer until a reload).
    if name == "junk" then
        if Recipes ~= nil and Recipes.forgetAnswers ~= nil then pcall(Recipes.forgetAnswers) end
        if Recipes ~= nil and Recipes.usedState ~= nil then Recipes.usedState.lists = {} end
        if Details ~= nil and Details.refreshAll ~= nil then pcall(Details.refreshAll) end
    end
end

-- FAVOURITES: saved as "68,1511,..." (item numbers, in the order they were added). The Favorites list shows the newest first.
Filters.favOrder = {}
for n in string.gmatch(Saved.get("favourites") or "", "%d+") do
    n = tonumber(n)
    if not Filters.fav[n] then Filters.fav[n] = true; Filters.favOrder[#Filters.favOrder + 1] = n end
end

function Filters.favouriteList()
    if Filters.dirty or Filters.built ~= #Items.ids then
        local view = {}
        for k = #Filters.favOrder, 1, -1 do
            local slot = Items.slotOf[Filters.favOrder[k]]
            if slot ~= nil then view[#view + 1] = slot end
        end
        Filters.view, Filters.built, Filters.dirty = view, #Items.ids, false
    end
    return Filters.view
end

function Filters.isFavourite(itemId) return Filters.fav[itemId] == true end
function Filters.toggleFavourite(itemId)
    if type(itemId) ~= "number" then return end
    if Filters.fav[itemId] then
        Filters.fav[itemId] = nil
        for k, n in ipairs(Filters.favOrder) do if n == itemId then table.remove(Filters.favOrder, k) break end end
    else
        Filters.fav[itemId] = true
        Filters.favOrder[#Filters.favOrder + 1] = itemId
    end
    Saved.set("favourites", table.concat(Filters.favOrder, ","))
    if Filters.key == "fav" then changed() end
end

end }
