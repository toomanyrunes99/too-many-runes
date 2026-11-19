-- Too Many Runes - Filters, hide switches and favourites
-- Decides which items a list shows. The filter is All items or Favorites, picked with the Favorites tab (core/shelves.lua).
-- The hide switches (noted, broken, junk and so on) take clutter out. Favourites are the items starred in the info box,
-- saved in the game's storage for this plugin.
return { run = function(T)
local _ENV = T

Filters = { list = {}, byKey = {}, key = "all", hide = {}, fav = {}, view = {}, built = 0, dirty = true }

-- Adds a filter. test(slot) says whether an item gets through. Set ignoresHide to true when the hide switches should not
-- apply, as with Favorites, where the player picked every item.
function Filters.add(key, label, test, ignoresHide)
    local f = { key = key, label = label, test = test, ignoresHide = ignoresHide }
    Filters.list[#Filters.list + 1] = f
    Filters.byKey[key] = f
end
Filters.add("all", "All items", function() return true end)
Filters.add("fav", "Favorites", function(slot) return Filters.fav[Items.ids[slot]] == true end, true)
Filters.byKey.fav.list = function() return Filters.favouriteList() end -- newest favourite first, not in item order
-- Is the item made by a recipe? recipes/uses_tab.lua replaces this function once the recipes are known. Until then it
-- says no. The item groups in core/groups.lua use it.
function Filters.craftable() return false end

-- The hide switches. Each one uses its saved choice ("on" or "off"), or the setting when nothing is saved.
local SWITCH_FLAGS = { noted = Items.NOTED, broken = Items.BROKEN, junk = Items.JUNK,
                       dungeoneering = Items.DUNG, discontinued = Items.DISC }
-- Minigame items are the ones on the Misc > Minigames tab (core/shelves.lua). They have no flag of their own, so they
-- are not in SWITCH_FLAGS.
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

-- The hide switches that are on and keep this item out of the list, by their names in Settings.
-- Used for the "Hidden by" line under the item's name in the details.
local SWITCH_NAMES = { noted = "Noted items", broken = "Broken items", dungeoneering = "Dungeoneering items",
                       discontinued = "Discontinued items", minigames = "Minigame items", junk = "Junk filter" }
function Filters.hiddenBy(slot)
    local names, f = {}, Items.flags[slot] or 0
    for _, name in ipairs(SWITCHES) do
        if Filters.hide[name] then
            local flag = SWITCH_FLAGS[name]
            local hit = (flag ~= nil and (f & flag) ~= 0)
            if name == "minigames" then hit = (Shelves ~= nil and Shelves.of[slot] == "misc.minigames") end
            if hit then names[#names + 1] = SWITCH_NAMES[name] or name end
        end
    end
    return names
end

-- Does the item get through the filter and the hide switches?
function Filters.passes(slot)
    local f = Filters.byKey[Filters.key]
    if not f.ignoresHide and not Filters.shown(slot) then return false end
    if Shelves ~= nil and not Shelves.passes(slot) then return false end -- the group tab picked above the list (core/shelves.lua)
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

-- Called when something changes what passes. Runs the search again so every tab shows the new list.
local function changed()
    Filters.invalidate()
    if Search ~= nil then Search.refresh(true) end -- another tab: its list starts at page 1
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
    -- Recipes and uses already worked out either leave hidden junk out or keep it in, so they are worked out again.
    -- The item open on the right is drawn again too. Otherwise it would keep the old answer until a reload.
    if name == "junk" then
        if Recipes ~= nil and Recipes.forgetAnswers ~= nil then pcall(Recipes.forgetAnswers) end
        if Recipes ~= nil and Recipes.usedState ~= nil then Recipes.usedState.lists = {} end
        if Details ~= nil and Details.refreshAll ~= nil then pcall(Details.refreshAll) end
    end
end

-- Favourites are saved as item numbers in the order they were added, like "68,1511,...". The Favorites list shows the
-- newest first.
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
