-- Too Many Runes - Recipes: rituals, ensouling and donor items
-- Ritual recipes (Necromancy), the ensouled cloth and thread, and items whose recipe sits on a related item.
-- (Moved over from the old plugin almost unchanged; recipes/compat.lua explains how it fits the new one.)
return { run = function(II)
local _ENV = II


-- ----- rituals (Necromancy) -----
-- The game keeps one data row per ritual recipe, in the list NECRO_RITUAL_RECIPE_SELECTION_SORT_ALPHABETICAL.
-- Its columns (read from the survey; the numbers are checked against the wiki):
--   1 name   4 the item put in (item, how many)   5 time in ticks   6 skill and level   8 ritual site tier - 1
--   10 quest   11 other requirement (text)   12 main glyph (name, how many)   14 / 16 what it makes   15 skill and XP
-- (The "rituals" survey printed all 18 columns of all 25 rows: column 2 is the kind of ritual, 7 and 9 are 1 and the site row, and
-- 17 and 18 are never used. The other glyphs a ritual site needs, and its light sources, are not in the row or in any list the game hands
-- to a plugin.) A column's values, or nil if it is empty or the game will not hand it over.
function Recipes.rowValues(row, c)
    local columns = field(row, "columnCount")
    if type(columns) == "number" and c > columns then return nil end -- (the game prints an error for a column that is not there)
    local okT, types = pcall(function() return row:GetColumnValueTypes(c) end)
    local okN, n = pcall(function() return row:GetColumnValueCount(c) end)
    if not (okT and types ~= nil and okN and type(n) == "number" and n > 0) then return nil end
    for k = 1, math.min(n, 12) do
        if BAD_TYPES[tostring(valueAt(types, k))] then return nil end
    end
    local okV, values = pcall(function() return row:GetColumnValues(c) end)
    if okV then return values, n end
    return nil
end

-- The item a glyph is, found in the game's own glyph lists (so that it can be clicked), or nil.
function Recipes.glyphId(name)
    if Recipes.glyphMap == nil then
        Recipes.glyphMap = {}
        for _, listName in ipairs({ "NECRO_RITUAL_MAKEX_GLYPHS_FOUNDATIONAL", "NECRO_RITUAL_MAKEX_GLYPHS_ALTERATION" }) do
            local en = nil
            pcall(function() en = config.Enum[listName] end)
            local entries, count = field(en, "values"), field(en, "valueCount")
            if entries ~= nil and type(count) == "number" then
                for e = 1, Recipes.listCount(count, 60, listName) do
                    local entry = valueAt(entries, e)
                    local obj = nil
                    if entry ~= nil then obj = valueAt(entry, 2) end
                    local glyphName, glyphId = field(obj, "name"), field(obj, "id")
                    if type(glyphName) == "string" and type(glyphId) == "number" then Recipes.glyphMap[glyphName] = glyphId end
                end
            end
        end
    end
    return Recipes.glyphMap[name]
end

-- Read one ritual row into a table (or nil if it is not a ritual we understand).
function Recipes.readRitual(row)
    local values = Recipes.rowValues(row, 1)
    local name = nil
    if values ~= nil then name = valueAt(values, 1) end
    if type(name) ~= "string" or name == "" then return nil end
    local ritual = { name = name, outputs = {}, row = field(row, "configName") }

    local v = Recipes.rowValues(row, 4)
    if v ~= nil then
        local obj, number = valueAt(v, 1), valueAt(v, 2)
        local itemId, itemName = field(obj, "id"), field(obj, "name")
        if type(itemId) == "number" and type(itemName) == "string" then
            ritual.input = { id = itemId, name = itemName, count = (type(number) == "number") and number or 1 }
        end
    end
    v = Recipes.rowValues(row, 5)
    if v ~= nil and type(valueAt(v, 1)) == "number" then ritual.ticks = valueAt(v, 1) end
    v = Recipes.rowValues(row, 6)
    if v ~= nil and type(valueAt(v, 1)) == "number" and type(valueAt(v, 2)) == "number" then
        ritual.skill, ritual.level = Recipes.statName(valueAt(v, 1)), valueAt(v, 2)
    end
    v = Recipes.rowValues(row, 8)
    if v ~= nil and type(valueAt(v, 1)) == "number" then ritual.tier = valueAt(v, 1) + 1 end
    v = Recipes.rowValues(row, 10)
    if v ~= nil then
        local questName = field(valueAt(v, 1), "name")
        if type(questName) == "string" and questName ~= "" then ritual.quest = questName end
    end
    v = Recipes.rowValues(row, 11)
    if v ~= nil and type(valueAt(v, 1)) == "string" then ritual.requirement = valueAt(v, 1) end
    v = Recipes.rowValues(row, 12)
    if v ~= nil then
        local glyphName, number = field(valueAt(v, 1), "name"), valueAt(v, 2)
        if type(glyphName) == "string" and type(number) == "number" then
            ritual.glyph = { name = glyphName, count = number, id = Recipes.glyphId(glyphName) }
        end
    end
    v = Recipes.rowValues(row, 15)
    if v ~= nil and type(valueAt(v, 2)) == "number" then
        ritual.xp = valueAt(v, 2)
        if ritual.skill == nil and type(valueAt(v, 1)) == "number" then ritual.skill = Recipes.statName(valueAt(v, 1)) end
    end
    -- what it makes: column 14 is (item, how many); column 16 is (the input's number, item, how many)
    v = Recipes.rowValues(row, 14)
    if v ~= nil then
        local obj, number = valueAt(v, 1), valueAt(v, 2)
        local itemId = field(obj, "id")
        if type(itemId) == "number" then ritual.outputs[#ritual.outputs + 1] = { id = itemId, count = (type(number) == "number") and number or 1 } end
    end
    v = Recipes.rowValues(row, 16)
    if v ~= nil then
        local obj, number = valueAt(v, 2), valueAt(v, 3)
        local itemId = field(obj, "id")
        if type(itemId) == "number" then ritual.outputs[#ritual.outputs + 1] = { id = itemId, count = (type(number) == "number") and number or 1 } end
    end
    if #ritual.outputs == 0 then return nil end
    local unique, seenOutput = {}, {}
    for _, out in ipairs(ritual.outputs) do -- (the same item may be listed in both columns)
        if not seenOutput[out.id] then
            seenOutput[out.id] = true
            unique[#unique + 1] = out
        end
    end
    ritual.outputs = unique
    ritual.skill = ritual.skill or "Necromancy"
    return ritual
end

-- Ensouled cloth and thread are made in the SAME rituals as the ensouled bars, with a different item selected as the input. The game's ritual
-- rows name only the bar, so the input options come from the ritual window, which lists every one of them: they are the hand-written facts in
-- recipes/exceptions.lua (playerFacts.rituals.ensoul, read from the window by the survey ritualui; nothing from the wiki). Switched off with
-- USE_PLAYER_FACTS. The ritual itself - level, time, XP, site tier, quest, glyph - is read from the game's row for the bar of the same tier:
-- "Lesser ensouled cloth" uses the ritual that makes the "Lesser ensouled bar".

-- The cloth and thread facts: item name (lower case) -> { bar = the bar's name, inputs = { { item number, name } ... } }. Empty when the hand-written
-- facts are switched off.
function Recipes.ensoulFacts()
    local all = Recipes.playerFacts and Recipes.playerFacts() or {}
    local rituals = all.rituals
    return (rituals and rituals.ensoul) or {}
end

-- The ritual that makes a cloth or thread item (a list with one ritual, or nil). Built on first use, then remembered.
function Recipes.ensoulFamily(itemId)
    local slot = idToSlot[itemId]
    if slot == nil then return nil end
    local lower = itemLower[slot]
    local fact = Recipes.ensoulFacts()[lower]
    if fact == nil then return nil end
    if Recipes.ensoulCache == nil then Recipes.ensoulCache = {} end
    local cached = Recipes.ensoulCache[lower]
    if cached == nil then
        cached = false
        local base = Recipes.ritualByOutput[fact.bar]
        if base ~= nil then
            local inputs = {}
            for _, input in ipairs(fact.inputs or {}) do
                local inputSlot = idToSlot[input[1]] -- (an option the item list does not have is left out)
                if inputSlot ~= nil then inputs[#inputs + 1] = { id = input[1], name = itemNames[inputSlot], count = 1 } end
            end
            if #inputs > 0 then
                local copy = {}
                for k, val in pairs(base) do copy[k] = val end
                copy.input = nil
                copy.inputs = inputs
                copy.makes = 1
                cached = { copy }
            end
        end
        Recipes.ensoulCache[lower] = cached
    end
    return cached or nil
end

-- The rituals that make an item (a list, or nil). Built once from the game's ritual recipes.
function Recipes.ritualsFor(itemId)
    if Recipes.ritualMap == nil then
        Recipes.ritualMap = {}
        Recipes.ritualByOutput = {} -- lowercase name of what a ritual makes -> that ritual
        local rituals, products = 0, 0
        local ok, err = pcall(function()
            local en = nil
            pcall(function() en = config.Enum["NECRO_RITUAL_RECIPE_SELECTION_SORT_ALPHABETICAL"] end)
            local entries, count = field(en, "values"), field(en, "valueCount")
            if entries == nil or type(count) ~= "number" then return end
            for e = 1, Recipes.listCount(count, 300, "NECRO_RITUAL_RECIPE_SELECTION_SORT_ALPHABETICAL") do
                local entry = valueAt(entries, e)
                local row = nil
                if entry ~= nil then row = valueAt(entry, 2) end
                local ritual = nil
                if row ~= nil then ritual = Recipes.readRitual(row) end
                if ritual ~= nil then
                    rituals = rituals + 1
                    for _, out in ipairs(ritual.outputs) do
                        local list = Recipes.ritualMap[out.id]
                        if list == nil then
                            list = {}
                            Recipes.ritualMap[out.id] = list
                            products = products + 1
                        end
                        local copy = {}
                        for k, val in pairs(ritual) do copy[k] = val end
                        copy.makes = out.count
                        list[#list + 1] = copy
                        local outObj = nil
                        pcall(function() outObj = config.Obj.FromID(out.id) end)
                        local outName = field(outObj, "name")
                        if type(outName) == "string" and Recipes.ritualByOutput[string.lower(outName)] == nil then
                            Recipes.ritualByOutput[string.lower(outName)] = copy
                        end
                    end
                end
            end
        end)
        if not ok then print("Too Many Runes: could not read the ritual recipes: " .. tostring(err)) end
        detail("Too Many Runes: ritual recipes read from the game: " .. rituals .. " (making " .. products .. " different items)")
    end
    local direct = Recipes.ritualMap[itemId]
    if direct ~= nil then return direct end
    return Recipes.ensoulFamily(itemId)
end

-- Does this list of RECIPE_ settings name any ingredient?
function Recipes.hasIngredients(fields)
    for _, e in ipairs(fields) do
        if string.find(e.name, "^RECIPE_INGREDIENT_TYPE_%d+$") or string.find(e.name, "^RECIPE_INGREDIENT_%d+_MULTIPLE$") then
            return true
        end
    end
    return false
end

-- Some items have a few RECIPE_ settings (a level, the XP) but no ingredients, because the game keeps the real recipe
-- on a TWIN of the item (survey rounds 11 and 12):
--   * the old superior scrimshaws point to the new version of themselves (POP_NEW_VERSION), which holds the recipe;
--   * a worn or broken piece of Dinosaurhide armour points to the fresh piece (ITEM_DEGRADE_FIXEDSTATE), which holds it.
-- So if an item has no ingredients of its own, look at the item these settings point to. Returns the twin's RECIPE_
-- settings (an empty list if it has no ingredients either) and the twin's item number.
-- (The settings that point at a twin are listed in recipes/exceptions.lua: Exceptions.donorSettings.)
function Recipes.donorFields(itemObj, itemId)
    for _, settingName in ipairs(Exceptions.donorSettings) do
        local p = nil
        pcall(function() p = config.Param[settingName] end)
        if p ~= nil then
            local okH, has = pcall(function() return itemObj:HasParam(p) end)
            if okH and has == true then
                local okV, v = pcall(function() return itemObj:GetParamValue(p) end)
                local donorId = nil
                if okV and v ~= nil and type(v) ~= "number" and type(v) ~= "string" and type(v) ~= "boolean"
                   and field(v, "typeName") == "Obj" then
                    donorId = field(v, "id")
                end
                if type(donorId) == "number" and donorId ~= itemId then
                    local donor = nil
                    pcall(function() donor = config.Obj.FromID(donorId) end)
                    if donor ~= nil then
                        local donorFields = fieldList(donor, "RECIPE_")
                        if Recipes.hasIngredients(donorFields) then return donorFields, donorId end
                    end
                end
            end
        end
    end
    return {}, nil
end

end }
