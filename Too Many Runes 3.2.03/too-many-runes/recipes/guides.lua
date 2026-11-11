-- Too Many Runes - Recipes: skill guides, plans and blueprints
-- The background passes that read the skill guides and the data rows for furniture plans and Invention blueprints.
-- (Moved over from the old plugin almost unchanged; recipes/compat.lua explains how it fits the new one.)
return { run = function(II)
local _ENV = II


-- ----- the game's skill guides -----
-- Every skill has a guide (the lists SKILLGUIDE_RUNECRAFT, SKILLGUIDE_HERBLORE ...): one entry per thing the skill makes or does, with a
-- level, an item and sometimes a line of text (survey rounds 16 and 17). For a few dozen items - the runes, the weapon poisons, the
-- Perfect juju potions, the wines... - the guide is the ONLY place that gives a level or says what goes into them, as text. So the
-- guides of the skills that make things are read in the background, and used for items that have no ingredients of their own.
Recipes.GUIDE_SKILLS = Exceptions.guideSkills -- (the skills whose guides are read; the list is in recipes/exceptions.lua)
Recipes.guideMap = {}      -- item number -> { level =, stat = (the skill's number), info = (the guide's text), extra = (its extra
                           -- requirement, as text) }
Recipes.guideReady = false -- true once every guide has been read
Recipes.guideState = { lists = nil, listPos = 1, entryPos = 0, count = 0 }

-- One small step of reading the guides (called every game tick; waits for the item links first so the two do not compete).
function Recipes.guideStep()
    local G = Recipes.guideState
    if Recipes.guideReady or not linkState.ready then return end
    if G.lists == nil then
        -- each guide is a list of the game's called SKILLGUIDE_ and the skill's name (a list whose values are structs, output type 73)
        G.lists = {}
        for _, word in ipairs(Recipes.GUIDE_SKILLS) do
            local en = nil
            pcall(function() en = config.Enum["SKILLGUIDE_" .. word] end)
            if en ~= nil and tostring(field(en, "outputValueType")) == "73" then G.lists[#G.lists + 1] = en end
        end
    else
        local list = G.lists[G.listPos]
        if list == nil then
            Recipes.guideReady = true
            detail("Too Many Runes: skill guides read (" .. G.count .. " items with a guide level or text)")
            if Recipes.onDataReady then pcall(Recipes.onDataReady) end
            return
        end
        local entries, count = field(list, "values"), field(list, "valueCount")
        if entries == nil or type(count) ~= "number" or BAD_TYPES["73"] then
            G.listPos, G.entryPos = G.listPos + 1, 0
            return
        end
        for _ = 1, Scan.full(40) do
            local idx = G.entryPos + 1
            if idx > Recipes.listCount(count, 800, tostring(field(list, "configName"))) then
                G.listPos, G.entryPos = G.listPos + 1, 0
                return
            end
            G.entryPos = idx
            local entry = valueAt(entries, idx)
            local struct = nil
            if entry ~= nil then struct = valueAt(entry, 2) end
            local params = field(struct, "params")
            if params ~= nil then
                local itemId, level, stat, info, extra = nil, nil, nil, nil, nil
                for i = 1, MAX_PARAMS do
                    local p = valueAt(params, i)
                    if p == nil then break end
                    local pname = field(p, "configName")
                    if (pname == "SKILLGUIDE_ITEM" or pname == "SKILLGUIDE_LEVEL" or pname == "SKILLGUIDE_SKILL" or pname == "SKILLGUIDE_INFO"
                        or pname == "SKILLGUIDE_EXTRAREQ")
                       and not BAD_TYPES[tostring(field(p, "valueType"))] then
                        local okV, v = pcall(function() return struct:GetParamValue(p) end)
                        if okV and v ~= nil then
                            if pname == "SKILLGUIDE_ITEM" and field(v, "typeName") == "Obj" then itemId = field(v, "id") end
                            if pname == "SKILLGUIDE_LEVEL" and type(v) == "number" then level = v end
                            if pname == "SKILLGUIDE_SKILL" and type(v) == "number" then stat = v end
                            if pname == "SKILLGUIDE_INFO" and type(v) == "string" and v ~= "" then info = v end
                            if pname == "SKILLGUIDE_EXTRAREQ" and type(v) == "string" and v ~= "" then extra = v end
                        end
                    end
                end
                if type(itemId) == "number" then
                    local known = Recipes.guideMap[itemId]
                    if known == nil then
                        Recipes.guideMap[itemId] = { level = level, stat = stat, info = info, extra = extra }
                        G.count = G.count + 1
                    else
                        if known.info == nil and info ~= nil then known.info = info end
                        if known.extra == nil and extra ~= nil then known.extra = extra end
                    end
                end
            end
        end
    end
end
Passes.add("skill guides", Recipes.guideStep, function() return Recipes.guideReady end, function()
    Recipes.guideReady = true -- (carry on without the rest of the guides rather than make the other passes wait for ever)
end)

----- furniture plans and Invention blueprints (read from the game's data rows) -----
-- Since the house rework, some furniture (the Safe, the Vault door, the altars...) cannot be built until you have learned a
-- "Furniture plans: ..." item. The game keeps one data row per piece of furniture, in rows named CONSTRUCTION_HOUSE_...:
-- column 5 is the furniture item, column 17 the plans item that unlocks it (the Magic tree, which needs none, has no column 17)
-- and column 10 the Construction level (survey round 19).
-- The numbers that Invention recipes use for "needs this blueprint" (requirement type 63) are column 1 of the rows named
-- INVENT_BLUEPRINT_...; column 2 is the blueprint's name (row INVENT_BLUEPRINT_RUNECRAFTING_ROD: 158 = "Binding rod",
-- and "Binding rod (new)" needs blueprint number 158).
-- The kinds of Invention material ("Spiritual parts", "Delicate parts"...) are rows named INVENT_MATERIAL_...: column 1 is the
-- material's number and column 2 its name (row 420 INVENT_MATERIAL_SPIRITUAL_PARTS: 7 = "Spiritual parts"). An Invention recipe
-- lists every material as the one stand-in item "Invention material"; which kind it is has to come from the recipe's
-- RECIPE_INGREDIENT_EXTRA_INFO_n setting, the way the stand-in "Metal bank object" names its bar (a guess that the survey
-- "invention" checks: until it is confirmed, a number that matches no material leaves the line as "Invention material").
-- All three are found by the NAMES of the data rows, in one background pass over the data row numbers.
-- The rune altars are found in the same pass: the rows named RUNECRAFTING_ALTAR_*, whose column 2 holds the altar's name ("Fire Altar"; see
-- recipes/player.lua).
Recipes.rowsState = { ready = false, pos = 0, gap = 0, plansOf = {}, plansCount = 0, blueprints = {}, blueprintCount = 0,
                      materials = {}, materialCount = 0, altars = {}, altarCount = 0,
                      -- (restoredOf: restored item number -> { from = the damaged item's number, fromName, level }; materialPictures: kind
                      -- number -> the kind's picture, a sprite number: the 5th column of its data row)
                      materialPictures = {}, restoredOf = {}, restorationCount = 0,
                      -- (rowBench: station key -> { [item number] = true }, the stations kept in data rows: Exceptions.benchRows)
                      rowBench = {} }

-- Is this data row one of a station's (Exceptions.benchRows)? Returns its entry, or nil.
local function benchRowOf(name)
    for _, spec in ipairs(Exceptions.benchRows or {}) do
        if string.sub(name, 1, #spec.prefix) == spec.prefix then return spec end
    end
    return nil
end

-- One data row we are interested in.
function Recipes.rowsRow(R, name, row)
    local function firstValue(c)
        local values = Recipes.rowValues(row, c)
        return valueAt(values, 1)
    end
    local spec = benchRowOf(name)
    if spec ~= nil then -- (a station's row: every item in its columns is made there)
        local set = R.rowBench[spec.key] or {}
        R.rowBench[spec.key] = set
        for _, c in ipairs(spec.columns) do
            local v = firstValue(c)
            if field(v, "typeName") == "Obj" and type(field(v, "id")) == "number" then set[field(v, "id")] = true end
        end
    end
    if string.sub(name, 1, 19) == "CONSTRUCTION_HOUSE_" then
        local furniture, plans = firstValue(5), firstValue(17)
        local furnitureId, plansId, plansName = field(furniture, "id"), field(plans, "id"), field(plans, "name")
        if field(furniture, "typeName") == "Obj" and field(plans, "typeName") == "Obj" and type(furnitureId) == "number"
           and type(plansId) == "number" and type(plansName) == "string"
           and string.find(string.lower(plansName), "plans", 1, true) and R.plansOf[furnitureId] == nil then
            local level = firstValue(10)
            R.plansOf[furnitureId] = { id = plansId, name = plansName, furniture = field(furniture, "name"),
                                       level = (type(level) == "number") and level or nil }
            R.plansCount = R.plansCount + 1
        end
    elseif string.sub(name, 1, 19) == "RUNECRAFTING_ALTAR_" then
        Recipes.altarRow(R, row, firstValue)
    elseif string.sub(name, 1, 17) == "ARCH_RESTORATION_" then
        -- an Archaeology artefact restored at the Archaeologist's workbench (found by the survey benchtables, 239 rows named
        -- ARCH_RESTORATION_<name>): column 5 the Archaeology level, column 6 the damaged item, column 7 the restored item
        local level, damaged, restored = firstValue(5), firstValue(6), firstValue(7)
        local restoredId, damagedId = field(restored, "id"), field(damaged, "id")
        if field(restored, "typeName") == "Obj" and type(restoredId) == "number" and R.restoredOf[restoredId] == nil then
            local cols = {}
            for _, c in ipairs({ 1, 2, 3, 8, 9, 10, 11, 12 }) do
                local v = firstValue(c)
                if v ~= nil then cols[#cols + 1] = "c" .. c .. "=" .. ((type(v) == "table") and tostring(field(v, "name") or field(v, "id")) or string.sub(tostring(v), 1, 40)) end
            end
            R.restoredOf[restoredId] = { from = (field(damaged, "typeName") == "Obj" and type(damagedId) == "number") and damagedId or nil,
                                         fromName = field(damaged, "name"), level = (type(level) == "number") and level or nil,
                                         rowName = name, cols = table.concat(cols, " ") }
            R.restorationCount = R.restorationCount + 1
        end
    elseif string.sub(name, 1, 16) == "INVENT_MATERIAL_" then
        local number, material = firstValue(1), firstValue(2)
        if type(number) == "number" and type(material) == "string" and material ~= "" and R.materials[number] == nil then
            R.materials[number] = material
            R.materialCount = R.materialCount + 1
            -- the row's 5th column is a plain number, one per kind: the kind's own picture, a sprite (shown in the game, the Recipe tab
            -- drew it beside "Clear parts" and "Organic parts" and they were right; the 6th column is not a picture)
            local picture = firstValue(5)
            if type(picture) == "number" then R.materialPictures[number] = picture end
            Recipes.materialWords[Recipes.materialSlug(material)] = true -- (a search word of its own: "@clear-parts")
        end
    else
        local number, blueprint = firstValue(1), firstValue(2)
        if type(number) == "number" and type(blueprint) == "string" and blueprint ~= "" and R.blueprints[number] == nil then
            R.blueprints[number] = blueprint
            R.blueprintCount = R.blueprintCount + 1
        end
    end
end

-- A kind of Invention material as a search word: "Clear parts" -> "clear-parts" (lower case, no spaces: the search splits on spaces).
-- A click on the kind's row in a recipe types "@clear-parts" and lists the items whose recipes use it (the @ search words, a later build).
Recipes.materialWords = {} -- slug -> true, for every kind read from the game's data rows
function Recipes.materialSlug(name)
    local slug = string.gsub(string.lower(name), "[^%w]+", "-")
    slug = string.gsub(slug, "^%-+", "")
    slug = string.gsub(slug, "%-+$", "")
    return slug
end

-- The name of an Invention material from its number (the recipe's RECIPE_INGREDIENT_EXTRA_INFO_n), or nil.
function Recipes.inventionMaterial(key)
    if type(key) ~= "number" then return nil end
    return Recipes.rowsState.materials[key]
end

-- The picture for a kind of Invention material ("Clear parts"): its sprite number (the game's own picture of the kind), or nil.
function Recipes.inventionPicture(number)
    return Recipes.rowsState.materialPictures[number]
end

-- The data rows are searched by number until a long run of empty numbers (or this limit, which is reported) ends the search.
local ROWS_LIMIT = 80000
-- One small step of the pass (called every game tick; starts once the skill guides are read, so the passes do not compete).
function Recipes.rowsStep()
    local R = Recipes.rowsState
    if R.ready or not Recipes.guideReady then return end
    if R.startTick == nil then R.startTick = tickCount end
    for _ = 1, Scan.full(250) do
        local n = R.pos
        R.pos = n + 1
        if n > ROWS_LIMIT or (n > 20000 and R.gap > 4000) then
            R.ready = true
            if n > ROWS_LIMIT then print("Too Many Runes: the game's data rows go on past number " .. ROWS_LIMIT .. "; the search for furniture plans and blueprints stopped there.") end
            detail("Too Many Runes: furniture plans and Invention blueprints read (" .. R.plansCount .. " pieces of furniture need plans, "
                .. R.blueprintCount .. " blueprints, " .. R.materialCount .. " kinds of Invention material, in about "
                .. math.floor((tickCount - R.startTick) / 50) .. " seconds)")
            detail("Too Many Runes: rune altars read from the game: " .. R.altarCount)
            if Recipes.onDataReady then pcall(Recipes.onDataReady) end
            return
        end
        local row = nil
        pcall(function() row = config.DBRow.FromID(n) end)
        local name = field(row, "configName")
        if type(name) ~= "string" then
            R.gap = R.gap + 1
        else
            R.gap = 0
            local gatherKind = (Gather ~= nil) and Gather.kindOf(name, n) or nil -- (rocks, trees, fishing spots ... : recipes/gather.lua)
            if gatherKind ~= nil then
                local okG, errG = pcall(Gather.read, gatherKind, name, row)
                if not okG and not R.gatherWarned then
                    R.gatherWarned = true
                    print("Too Many Runes: could not read the gathering row " .. name .. ": " .. tostring(errG))
                end
            end
            if string.sub(name, 1, 19) == "CONSTRUCTION_HOUSE_" or string.sub(name, 1, 17) == "INVENT_BLUEPRINT_"
               or string.sub(name, 1, 16) == "INVENT_MATERIAL_" or string.sub(name, 1, 19) == "RUNECRAFTING_ALTAR_"
               or string.sub(name, 1, 17) == "ARCH_RESTORATION_" or benchRowOf(name) ~= nil then
                local ok, err = pcall(Recipes.rowsRow, R, name, row)
                if not ok and not R.warned then
                    R.warned = true
                    print("Too Many Runes: could not read the data row " .. name .. ": " .. tostring(err))
                end
            end
        end
    end
end
Passes.add("furniture plans", Recipes.rowsStep, function() return Recipes.rowsState.ready end, function()
    Recipes.rowsState.ready = true -- (carry on without them rather than wait for ever)
end)

-- "Furniture plans: Vault door" -> "Needs plans: Vault door" (the picture of the plans sits beside it; a long name drops the word "Needs").
function Recipes.plansLine(name)
    local base = string.match(name, "^.-[Pp]lans:%s*(.+)$") or name
    local line = "Needs plans: " .. base
    if #line > 38 then line = "Plans: " .. base end
    return line
end

-- "Needs blueprint: Binding rod" (a long name drops the word "Needs"; a very long one is cut).
function Recipes.blueprintLine(name)
    local line = "Needs blueprint: " .. name
    if #line > 36 then line = "Blueprint: " .. name end
    if #line > 36 then line = string.sub(line, 1, 34) .. ".." end
    return line
end

-- What an item needs that is not a skill, a quest or an achievement: { plans = { id, name }, blueprints = { [number] = name } }, or nil.
-- (Nothing until the data rows are read; the recipe is then worked out again.)
function Recipes.needsOf(itemId, fields)
    local R = Recipes.rowsState
    if not R.ready then return nil end
    local needs = nil
    local plans = R.plansOf[itemId]
    if plans ~= nil then needs = { plans = plans } end
    for n = 1, 6 do
        local t = getField(fields, "RECIPE_REQUIREMENT_TYPE_" .. n)
        local v = getField(fields, "RECIPE_REQUIREMENT_VALUE_" .. n)
        if t == Exceptions.requirementTypes.blueprint and type(v) == "number" and R.blueprints[v] ~= nil then
            needs = needs or {}
            needs.blueprints = needs.blueprints or {}
            needs.blueprints[v] = R.blueprints[v]
        end
    end
    return needs
end

-- Does a guide's text tell how to make the item?
function Recipes.guideSaysHow(info)
    local lower = string.lower(info)
    return string.find(lower, "ingredient", 1, true) ~= nil or string.find(lower, "materials", 1, true) ~= nil
        or string.find(lower, "to make", 1, true) ~= nil
end

-- Short text lines (for the info box) made from a guide's text.
function Recipes.guideLines(info)
    local text = string.gsub(info, "<[^>]*>", " ")
    text = string.gsub(text, "(%.)(%d%.)", "%1 %2") -- (the guide runs its numbered steps together: "water.2. Add")
    text = string.gsub(text, "(%a)(%d%.)", "%1 %2")
    local lines, line = {}, ""
    for word in string.gmatch(text, "%S+") do
        if #line > 0 and #line + 1 + #word > 34 then
            lines[#lines + 1] = line
            line = word
        else
            line = (#line > 0) and (line .. " " .. word) or word
        end
    end
    if #line > 0 then lines[#lines + 1] = line end
    return lines
end

-- The extra requirement a skill guide lists for an item (its SKILLGUIDE_EXTRAREQ: plain text such as "Quest requirement: Plague's End",
-- "Also requires: 80 Defence" or "Unlocked at the Livid Farm", found by survey round 20), as short lines in the same words as the other
-- requirement rows. Empty if there is none, or if the recipe's own requirements already show it.
function Recipes.extraLines(itemId, fields)
    local g = Recipes.guideMap[itemId]
    if g == nil or g.extra == nil then return {} end
    local text = g.extra
    local quest = string.match(text, "^Quest requirement:%s*(.+)$")
    local level, skill = string.match(text, "^Also requires:%s*(%d+)%s+(.+)$")
    for n = 1, 6 do
        local t = getField(fields, "RECIPE_REQUIREMENT_TYPE_" .. n)
        local v = getField(fields, "RECIPE_REQUIREMENT_VALUE_" .. n)
        if quest ~= nil and t == Exceptions.requirementTypes.quest and type(v) == "number" then
            local known = Recipes.questName(v)
            if known ~= nil and string.lower(known) == string.lower(quest) then return {} end
        end
        if skill ~= nil and type(t) == "number" and skillNames[t] ~= nil and tostring(v) == level
           and string.lower(skillLabel(t)) == string.lower(skill) then
            return {}
        end
    end
    if quest ~= nil then return { ((#quest > 28) and "Quest: " or "Needs quest: ") .. quest } end
    if level ~= nil then return { "Needs: " .. skill .. " level " .. level } end
    return Recipes.guideLines(text)
end

-- What the skill guide adds for an item that has no ingredients of its own: its level (if the item does not say), and its text
-- when that text says how the item is made. A list of lines (empty if there is nothing).
function Recipes.guideRows(itemId, fields)
    local g = Recipes.guideMap[itemId]
    if g == nil then return {} end
    local says = (g.info ~= nil and Recipes.guideSaysHow(g.info))
    if #fields == 0 and not says then return {} end -- (an item with no recipe settings and a guide text that is not about making it)
    local rows = {}
    if g.level ~= nil and g.stat ~= nil then
        local known = false
        for n = 1, 6 do
            if getField(fields, "RECIPE_REQUIREMENT_TYPE_" .. n) == g.stat then known = true end
        end
        -- (the skill guides number skills the way recipes do - skillLabel - not like STAT_TO_STRING, which gave "Dungeoneering" for the
        -- Summoning of binding contracts and "Agility" for the Cooking of wine)
        local skill = skillLabel(g.stat)
        if not known and skill ~= nil then rows[#rows + 1] = "Needs: " .. skill .. " level " .. tostring(g.level) end
    end
    for _, line in ipairs(Recipes.extraLines(itemId, fields)) do rows[#rows + 1] = line end
    if says then
        rows[#rows + 1] = "From the skill guide:"
        for _, line in ipairs(Recipes.guideLines(g.info)) do rows[#rows + 1] = line end
    end
    return rows
end

end }
