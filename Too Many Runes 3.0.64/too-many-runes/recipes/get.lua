-- Too Many Runes - Recipes: putting a recipe together
-- Recipes.get: collects everything known about how an item is made, and remembers the answer.
-- (Moved over from the old plugin almost unchanged; recipes/compat.lua explains how it fits the new one.)
return { run = function(II)
local _ENV = II


-- The RECIPE_ fields to read an item's recipe from: its own; failing that, the ones of its smithing-screen copy (found by name); and when
-- those name nothing to make it from, the ones of a donor item (see Recipes.donorFields).
local function recipeFields(itemId, itemObj)
    local fields = fieldList(itemObj, "RECIPE_")
    if #fields == 0 then
        local name = field(itemObj, "name")
        local copies = nil
        if type(name) == "string" then copies = smithingIndex[string.lower(name)] end
        for _, copyId in ipairs(copies or {}) do
            local copy = nil
            pcall(function() copy = config.Obj.FromID(copyId) end)
            if copy ~= nil then
                fields = fieldList(copy, "RECIPE_")
                if #fields > 0 then break end
            end
        end
    end
    if not Recipes.hasIngredients(fields) then
        local twinFields = Recipes.donorFields(itemObj, itemId)
        if #twinFields > 0 then fields = twinFields end
    end
    return fields
end

-- The items this one is made from by an upgrade: the game's own links, with the hand-written entries (which say more) in place of the links
-- to the same items, and without any item that is hidden junk. (nil if there are none.)
local function madeFromSources(itemId, itemObj)
    local sources = sourcesOf(itemId)
    local manual = manualSource(itemObj, sources ~= nil, itemId)
    if manual ~= nil then
        -- A hand-written entry says more than the game's own link to the same item ("Upgraded from: X" next to
        -- "made in steps, then ... from X"): keep only the hand-written one.
        if sources ~= nil then
            local kept = {}
            for _, s in ipairs(sources) do
                local duplicate = false
                for _, m in ipairs(manual) do
                    if m.name ~= nil and (m.id == s.id or string.lower(m.name) == string.lower(s.name)) then duplicate = true end
                end
                if not duplicate then kept[#kept + 1] = s end
            end
            sources = (#kept > 0) and kept or nil
        end
        sources = sources or {}
        for _, m in ipairs(manual) do sources[#sources + 1] = m end
    end
    if sources ~= nil and Filters ~= nil then
        local kept = {}
        for _, s in ipairs(sources) do
            if not (type(s.id) == "number" and Filters.junkHidden(s.id)) then kept[#kept + 1] = s end
        end
        sources = (#kept > 0) and kept or nil
    end
    return sources
end

-- Answers are only remembered once everything they depend on has been read: the item links, the skill guides and the furniture plans.
local function dataComplete()
    return linkState.ready and Recipes.guideReady and Recipes.rowsState.ready
end

-- What is the recipe for this item on its own? (false if it has none.) The item itself is checked first, then its
-- smithing-screen copy (found by name), then its twin (see above). Answers are remembered once the item links are ready.
local ownCache = {}
local function ownAnswer(itemId, itemObj)
    if ownCache[itemId] ~= nil then return ownCache[itemId] end
    local result = false
    local ok, err = pcall(function()
        Recipes.prepare()
        local fields = recipeFields(itemId, itemObj)
        local sources = madeFromSources(itemId, itemObj)
        -- an Archaeology artefact restored at the workbench: restored from its damaged version, at an Archaeology level (the game's own rows)
        local restoration = Recipes.restorationRecipe(itemId)
        if restoration ~= nil then
            if sources == nil then sources = restoration.sources end
            if restoration.skill ~= nil and restoration.level ~= nil and getField(fields, "RECIPE_REQUIREMENT_TYPE_1") == nil then
                local copy = {}
                for _, e in ipairs(fields) do copy[#copy + 1] = e end -- (a copy: the list may be shared)
                copy[#copy + 1] = { name = "RECIPE_REQUIREMENT_TYPE_1", value = restoration.skill }
                copy[#copy + 1] = { name = "RECIPE_REQUIREMENT_VALUE_1", value = restoration.level }
                fields = copy
            end
        end

        local bars = nil
        local ownName = field(itemObj, "name")
        if type(ownName) == "string" then
            bars = Recipes.alloyBelow(string.lower(ownName)) or Recipes.materialOf[string.lower(ownName)]
        end
        local wear = {} -- (extra lines shown with the recipe: a skill guide's text, a toolbelt tool's note, a hand-written fact. The wear
                        -- requirements are on the Info tab, see openItem)
        local rituals = Recipes.ritualsFor(itemId)
        local needs = Recipes.needsOf(itemId, fields)
        local bare = (sources == nil and rituals == nil and not Recipes.hasIngredients(fields)) -- (nothing it is made from)
        -- an extra requirement from the skill guide ("Quest requirement: ...", "Also requires: ..."), for a real recipe
        -- (an item that only has a guide text gets it from Recipes.guideRows below)
        if Recipes.guideReady and not bare then
            local extra = Recipes.extraLines(itemId, fields)
            if #extra > 0 then
                needs = needs or {}
                needs.extra = extra
            end
        end
        local guideCount = 0
        if Recipes.guideReady and bare then
            local guide = Recipes.guideRows(itemId, fields)
            if #guide > 0 then
                guideCount = #guide
                for _, line in ipairs(guide) do wear[#wear + 1] = line end -- (shown like the "to wear" lines)
            end
        end
        -- a tool kept on the toolbelt (and nothing to make it from): the game's own words on how it is got
        local toolCount = 0
        local playerFact = nil
        if bare then
            local toolRows = {} -- (the toolbelt's own note, "A tool kept on the toolbelt.", is no longer shown: such a tool is shown like any
                                -- other item with no recipe. Recipes.toolbeltRows(itemObj) still gives the note if it is ever wanted back.)
            for _, line in ipairs(toolRows) do wear[#wear + 1] = line end
            toolCount = #toolRows
            -- Still nothing from the game on how it is got: a fact the developer supplied (recipes/exceptions.lua, playerFacts), if there is one.
            -- The game's words come first: the toolbelt's text (more than the one line saying it is a tool) or a skill guide's text.
            local guide = Recipes.guideMap[itemId]
            local gameWords = (#toolRows > 1) or (guide ~= nil and guide.info ~= nil and Recipes.guideSaysHow(guide.info))
            playerFact = Recipes.playerFact(itemId, itemObj, gameWords)
            if playerFact ~= nil then
                for _, line in ipairs(playerFact.wear or {}) do wear[#wear + 1] = line end
                toolCount = toolCount + #(playerFact.wear or {})
                sources = playerFact.sources -- (shown as the recipe)
            end
        end
        -- an item that is on a bench's list but has no recipe in the game's data: just where it is made (the row comes with it, see benchOnly)
        local benchOnly = nil
        if bare and sources == nil and playerFact == nil then
            benchOnly = Recipes.benchOnly(itemId, itemObj)
            if benchOnly ~= nil then sources = benchOnly.sources end
        end
        -- where it is made (the furnace, or the forge and then the anvil), for an item the smithing and smelting lists name
        local station = (benchOnly == nil) and Recipes.stationFor(itemId, itemObj, fields) or nil
        -- a container filled with water that the game gives a recipe for: the water source it is made at is added to the station rows
        local waterRows = (not bare and type(ownName) == "string") and Recipes.waterStationRows(string.lower(ownName)) or nil
        if waterRows ~= nil then
            local merged = { rows = {}, kind = station and station.kind or nil, fact = (station and station.fact) or "water" }
            for _, r in ipairs(station and station.rows or {}) do merged.rows[#merged.rows + 1] = r end
            for _, r in ipairs(waterRows) do merged.rows[#merged.rows + 1] = r end
            station = merged
        end
        if #fields > 0 or sources ~= nil or #wear > 0 or rituals ~= nil or needs ~= nil then
            result = Recipes.parse(fields, sources, bars, wear, Recipes.unlocksOf(itemId, fields), rituals, needs, station and station.rows, itemId) or false
            if result and station ~= nil and result.recipe then
                result.station = station.kind          -- "furnace" or "forge"
                result.stationFromPlayer = station.fact -- (the tag: the names of the stations were added by the developer)
            end
            if result and benchOnly ~= nil and result.recipe then
                result.station = benchOnly.kind
                result.stationFromPlayer = benchOnly.fact
            end
            if result and guideCount > 0 then result.guide = guideCount end
            if result and toolCount > 0 then result.tool = toolCount end
            if result and playerFact ~= nil then result.fromPlayer = playerFact.fact end -- (the tag: this was added by the developer)
        end
    end)
    if not ok then print("Too Many Runes: could not read the recipe for item " .. tostring(itemId) .. ": " .. tostring(err)) end
    if dataComplete() then ownCache[itemId] = result end
    return result
end

-- What is the recipe for this item? (nil if it has none.) An item with no recipe of its own that is a plain copy of a made item
-- shows that item's recipe (see recipes/copies.lua).
local recipeCache = {}
function Recipes.getBase(itemId, itemObj)
    if recipeCache[itemId] ~= nil then return recipeCache[itemId] or nil end
    if Recipes.isRemoved(field(itemObj, "name")) then return nil end -- (being removed from the game: no recipe is shown for it)
    local result = ownAnswer(itemId, itemObj)
    if result == false then
        local ok, copy = pcall(Recipes.copyOfTwin, itemId, itemObj, ownAnswer)
        if ok and copy ~= nil then result = copy end
        if not ok then print("Too Many Runes: could not check the copies of item " .. tostring(itemId) .. ": " .. tostring(copy)) end
    end
    if result == false then
        -- one level of a potion / flask / salve family: points at the level that is made (see recipes/doses.lua)
        local ok, dose = pcall(Recipes.doseFamily, itemId, itemObj, ownAnswer)
        if ok and dose ~= nil then result = dose end
        if not ok then print("Too Many Runes: could not check the doses of item " .. tostring(itemId) .. ": " .. tostring(dose)) end
    end
    if dataComplete() then recipeCache[itemId] = result end
    return result or nil
end


-- Items with exactly the same name (a second item number for the same thing: a quest's copy, an older version): when this item has no
-- recipe of its own, the Recipe tab lists up to SAME_NAME_MAX of the others, those with a recipe first, and a click opens one.
-- Noted copies are left out (the game's CERT_ items; they already show the recipe of the real item). Returns rows, or nil.
local SAME_NAME_MAX = 4
local sameCache = {}
local function sameNameRows(itemId, itemObj)
    local name = field(itemObj, "name")
    if type(name) ~= "string" or name == "" then return nil end
    local slots = Recipes.slotsOf and Recipes.slotsOf(string.lower(name)) or nil
    if slots == nil or #slots < 2 then return nil end
    local withRecipe, without = {}, {}
    for _, slot in ipairs(slots) do
        local id = itemIds[slot]
        if id ~= itemId and not (Filters ~= nil and Filters.junkHidden(id)) then
            local obj = nil
            pcall(function() obj = config.Obj.FromID(id) end)
            local cfg = field(obj, "configName")
            if obj ~= nil and not (type(cfg) == "string" and string.sub(cfg, 1, 5) == "CERT_") then
                local okR, data = pcall(Recipes.getBase, id, obj)
                if okR and data ~= nil and (data.ingredients or 0) > 0 then withRecipe[#withRecipe + 1] = id
                else without[#without + 1] = id end
            end
        end
    end
    local list = (#withRecipe > 0) and withRecipe or without
    if #list == 0 then return nil end
    local rows = { { text = (#withRecipe > 0) and "Same name, with a recipe:" or "Other items with this name:" } }
    for i = 1, math.min(#list, SAME_NAME_MAX) do
        local text = name .. " (" .. list[i] .. ")"
        if #text > 38 then text = string.sub(text, 1, 36) .. ".." end
        rows[#rows + 1] = { text = (text:gsub("<", "<lt>")), icon = list[i] }
    end
    return rows
end

-- Forget every remembered answer (used by the tests after they change a setting).
function Recipes.clearCaches()
    for k in pairs(ownCache) do ownCache[k] = nil end
    for k in pairs(recipeCache) do recipeCache[k] = nil end
    for k in pairs(sameCache) do sameCache[k] = nil end
    if Recipes.clearUsedLists then Recipes.clearUsedLists() end
end

-- What the Recipe tab shows. Like getBase, but an item with no recipe of its own (nothing it is made from) also lists the other items with
-- its exact name, the ones with a recipe first. The answer carries  sameName = true  then (and  sameNameOnly = true  when that is all there is).
local function getWithSameName(itemId, itemObj)
    local base = Recipes.getBase(itemId, itemObj)
    if base ~= nil and (base.ingredients or 0) > 0 then return base end
    if sameCache[itemId] ~= nil then return sameCache[itemId] or nil end
    local extra = nil
    local ok, err = pcall(function() extra = sameNameRows(itemId, itemObj) end)
    if not ok then print("Too Many Runes: could not look for items with the same name as " .. tostring(itemId) .. ": " .. tostring(err)) end
    local result = base
    if extra ~= nil and ((base and #base.rows or 0) + #extra) <= RECIPE_MAX_LINES then
        local rows = {}
        for _, r in ipairs(base and base.rows or {}) do rows[#rows + 1] = r end
        for _, r in ipairs(extra) do rows[#rows + 1] = r end
        local height = 0
        for _, r in ipairs(rows) do height = height + ((r.icon ~= nil or r.query ~= nil or r.pic ~= nil) and ROW_HEIGHT or LINE_HEIGHT) end
        result = { rows = rows, height = height, materials = base and base.materials or 0, ingredients = 0, wear = base and base.wear or 0,
                   recipe = base and base.recipe or false, fromPlayer = base and base.fromPlayer or nil,
                   station = base and base.station or nil, guide = base and base.guide or nil, tool = base and base.tool or nil,
                   sameName = true, sameNameOnly = (base == nil) }
    end
    if dataComplete() then sameCache[itemId] = result or false end
    return result
end

-- What the Recipe tab shows: the recipe only. (Where an item is gathered is on its own Source tab, recipes/source_tab.lua.)
function Recipes.get(itemId, itemObj)
    return getWithSameName(itemId, itemObj)
end

end }
