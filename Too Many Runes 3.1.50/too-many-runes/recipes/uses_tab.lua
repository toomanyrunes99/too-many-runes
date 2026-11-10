-- Too Many Runes - The Uses tab, and the Craftable / Uncraftable filters
-- The Uses tab lists what an item is used to make (worked out by the background pass in recipes/uses.lua), grouped by skill, lowest
-- level first; a click on one opens it (Back returns). The filters use the same pass: an item is craftable when its own Recipe tab
-- shows something it is made from.
return { run = function(T)
local _ENV = T

----------------------------------------------------------------
-- THE USES TAB
----------------------------------------------------------------
-- A seed's uses also list what it grows, in which patch (recipes/gather.lua: Gather.growsFrom), under Farming. (Recipes.usedFor is
-- wrapped, so the tab's count and the right-click "Uses:" entry count them too.)
local baseUsedFor = Recipes.usedFor
local withCrops, farmStat = {}, nil
-- (the Farming skill's number in the recipes' own numbering - skillNames, recipes/reading.lua - which the Uses tab's headings use. Until
-- 3.0.85 it was looked up in the game's other skill list, STAT_TO_STRING, whose numbers differ: a seed's crops showed under "Fletching".)
local function farmingStat()
    if farmStat == nil then
        for n, name in pairs(skillNames or {}) do
            if type(name) == "string" and string.lower(name) == "farming" then farmStat = n; break end
        end
    end
    return farmStat
end
function Recipes.usedFor(itemId, obj)
    local used = baseUsedFor(itemId, obj)
    if Gather == nil or not Gather.ready or Gather.growsFrom == nil then return used end
    local known = withCrops[itemId]
    if known ~= nil and known.base == used then return known.result end
    local slot = Items.slotOf[itemId]
    local grows = slot and Gather.growsFrom(Items.names[slot]) or nil
    local result = used
    if grows ~= nil and #grows > 0 then
        result = {}
        for k, v in pairs(used or {}) do result[k] = v end
        result.list, result.count = {}, (used and used.count) or 0
        for _, e in ipairs((used and used.list) or {}) do result.list[#result.list + 1] = e end
        local seen = {}
        for _, g in ipairs(grows) do
            local key = tostring(g.id) .. "|" .. tostring(g.patch)
            if not seen[key] then
                seen[key] = true
                local cropSlot = Items.slotOf[g.id]
                result.list[#result.list + 1] = { id = g.id, name = cropSlot and Items.names[cropSlot] or ("Item " .. g.id), level = g.level,
                                                  stat = farmingStat(), where = g.patch }
                result.count = result.count + 1
            end
        end
    end
    withCrops[itemId] = { base = used, result = result }
    return result
end

local function usesRows(itemId)
    local U = Recipes.usedState
    if U.failed then return { "Could not work out what items are used for (see the console)." }, "Uses" end
    if not U.ready then
        local done = (U.phase == "scan") and math.floor(100 * (U.position or 1) / math.max(1, #Items.ids)) or 99
        return { "Still working out what this is used to make... (" .. math.min(99, done) .. "%)" }, "Uses"
    end
    local obj = try(config.Obj.FromID, itemId)
    local used = (obj ~= nil) and Recipes.usedFor(itemId, obj) or nil
    if used == nil then return { "No available use(s) in the plugin's data." }, "Uses" end
    local rows = { (used.count == 1) and "Used to make 1 item:" or ("Used to make " .. withCommas(used.count) .. " items:") }
    local lastStat, lastPatch = false, nil
    for _, e in ipairs(used.list) do
        if e.where ~= nil then
            -- a crop the seed grows (3.0.85): under its patch, shown like a station - the Farming picture and "Grown in: Herb patch"; a
            -- click on the picture lists everything grown there ("@herb-patch", recipes/gather.lua)
            if e.where ~= lastPatch then
                local patch = string.upper(string.sub(e.where, 1, 1)) .. string.lower(string.sub(e.where, 2))
                local word = Gather ~= nil and Gather.wordOf and Gather.wordOf({ name = e.where }) or nil
                rows[#rows + 1] = { text = "Grown in: " .. patch, pic = Recipes.stationSprite("src_farming"), query = word and ("@" .. word) or nil }
                lastPatch = e.where
            end
            lastStat = false
            rows[#rows + 1] = { text = tostring(e.name) .. ((e.level ~= nil and e.level > 0) and ("  (Farming level " .. e.level .. ")") or ""), icon = e.id }
            goto continue
        end
        lastPatch = nil
        -- a heading for each skill (the list is in skill order, lowest level first)
        if e.stat ~= lastStat then
            local skill = (e.stat ~= nil) and skillLabel(e.stat) or nil -- (the same names as the Recipe tab's "Needs: Smithing level 35")
            if skill ~= nil then rows[#rows + 1] = skill .. ":"
            elseif lastStat ~= false then rows[#rows + 1] = "Other:" end
            lastStat = e.stat
        end
        local text = tostring(e.name)
        if e.level ~= nil and e.level > 0 then text = text .. "  (level " .. e.level .. (e.where and (", " .. e.where) or "") .. ")"
        elseif e.where ~= nil then text = text .. "  (" .. e.where .. ")" end
        rows[#rows + 1] = { text = text, icon = e.id }
        ::continue::
    end
    return rows, Recipes.usedTabLabel(used)
end
-- the words on the tab while another tab is open: "Uses (49)" (just "Uses" while the uses are still being worked out)
local function usesLabel(itemId)
    local obj = try(config.Obj.FromID, itemId)
    return Recipes.usedTabLabel((obj ~= nil) and Recipes.usedFor(itemId, obj) or nil)
end
Details.setTab("uses", "Uses", usesRows, "Uses (99+)", usesLabel)

----------------------------------------------------------------
-- THE CRAFTABLE / UNCRAFTABLE FILTERS
----------------------------------------------------------------
-- Potion / flask / salve families: "Prayer potion (1)" has no recipe of its own, but its Recipe tab points at the level that is made, so
-- it counts as craftable too (a family is the name with the level taken off, when levels 1 to 3 all exist). A potion's flask
-- ("Extreme prayer flask") counts when its potion does.
local families = nil
local function buildFamilies()
    local found, names, slotsOf = {}, Recipes.craftableNames or {}, Recipes.slotsOf
    if slotsOf == nil then return end
    local doses = USE_PLAYER_FACTS ~= false and (Exceptions.playerFacts or {}).doses or nil
    local flaskWord = doses and doses.flaskWord or nil
    local function levelsExist(base)
        for k = 1, 3 do if slotsOf(base .. " (" .. k .. ")") == nil then return false end end
        return true
    end
    for lower in pairs(names) do
        local base = string.match(lower, "^(.+) %(%d%)$")
        if base ~= nil and found[base] == nil and levelsExist(base) then
            found[base] = true
            if flaskWord ~= nil and string.sub(base, -7) == " potion" then
                local flask = string.sub(base, 1, -8) .. flaskWord
                if levelsExist(flask) then found[flask] = true end
            end
        end
    end
    families = found
    Filters.families = found -- (@potion reads it: core/query.lua)
end

-- Is this item (its slot) made by a recipe? While the uses are being worked out: any item whose NAME some recipe makes. Once every such
-- item has been asked for its own recipe (the "recipe check" pass): only the ones whose Recipe tab shows something they are made from.
function Filters.craftable(slot)
    local names = Recipes.craftableNames
    if names == nil then return false end
    local lower = Items.lower[slot]
    local C = Recipes.craftState
    if C ~= nil and C.ready and not C.failed then
        if Recipes.craftableIds[Items.ids[slot]] then return true end
    elseif names[lower] then
        return true
    end
    if families ~= nil and string.byte(lower, -1) == 41 then -- (ends in ")")
        local base = string.match(lower, "^(.+) %(%d%)$")
        if base ~= nil and families[base] then return true end
    end
    return false
end

local function filterUsesRecipes()
    return Filters.key == "craftable" or Filters.key == "non" or Filters.key == "gathered" or (Search ~= nil and Search.spec ~= nil and Search.active)
end
local function relist()
    Filters.invalidate()
    if Search ~= nil then Search.refresh() end
end

-- When a background pass finishes: the open item is shown again (recipes/recipe_tab.lua), and the craftable list may have changed.
local counted = false
local showAgain = Recipes.onDataReady
function Recipes.onDataReady()
    if showAgain ~= nil then pcall(showAgain) end
    if Recipes.usedState.ready and families == nil then pcall(buildFamilies) end
    local C = Recipes.craftState
    if C.ready and families ~= nil and not counted then
        counted = true
        local n = 0
        for slot = 1, #Items.ids do if Filters.craftable(slot) then n = n + 1 end end
        say("recipes ready (" .. withCommas(n) .. " of " .. withCommas(#Items.ids) .. " items are made by a recipe; about "
            .. math.floor(tickCount / 50) .. " seconds after start-up).")
    end
    if filterUsesRecipes() then relist() end
    pcall(Window.refreshStatus)
end

-- THE TOP BAR while the recipes are read: "recipes 40%" after the usual words (ui/window.lua). The share of each part of the work:
-- the item links 30%, working out the uses 35%, checking each recipe 35%. (nil once it is all done.)
function Window.loadingNote()
    local C, U, n = Recipes.craftState, Recipes.usedState, math.max(1, #Items.ids)
    if C.ready then return nil end
    local links = linkState.ready and 1 or math.min(1, (linkState.position or 1) / n)
    local uses = U.ready and 1 or ((U.phase == "scan") and math.min(1, (U.position or 1) / n) or 0.95)
    local check = math.min(1, (C.position or 1) / n)
    return "recipes " .. math.min(99, math.floor(100 * (0.30 * links + 0.35 * uses + 0.35 * check))) .. "%"
end
Passes.add("loading note", function()
    if tickCount % 25 == 0 then pcall(Window.refreshStatus) end
end, function()
    if Recipes.craftState.ready then pcall(Window.refreshStatus) return true end -- (once more at the end: "(N items hidden)" shows)
    return false
end)

-- Every two seconds while the uses are still being worked out: if the Craftable / Uncraftable list is open, show what is known so far.
local seen = -1
Passes.add("craftable so far", function()
    if tickCount % 100 ~= 0 or not filterUsesRecipes() then return end
    local n = Recipes.craftableCount or 0
    if n ~= seen then
        seen = n
        relist()
        pcall(Window.refreshStatus)
    end
end, function() return Recipes.craftState.ready end)

end }
