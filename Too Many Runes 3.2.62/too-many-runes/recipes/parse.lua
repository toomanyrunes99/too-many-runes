-- Too Many Runes - Recipes: turning the fields into a recipe
-- Recipes.parse: takes the recipe fields of one item and builds the lines the Recipe tab shows.
-- (Moved over from the old plugin almost unchanged; recipes/compat.lua explains how it fits the new one.)
return { run = function(T)
local _ENV = T


----- turning the RECIPE_ fields into lines of text -----
local function countText(num)
    if type(num) == "number" then return withCommas(num) end
    return "1"
end

-- 12000 -> "1,200"   (the game stores XP in tenths)
local function xpText(tenths)
    local xp = tenths / 10
    if xp == math.floor(xp) then return withCommas(xp) end
    return withCommas(math.floor(xp)) .. "." .. string.format("%d", math.floor(tenths) % 10)
end

-- The item number behind an item value (so its picture can be drawn).
local function idOf(obj)
    if type(obj) == "number" then return obj end
    local n = field(obj, "id")
    if type(n) == "number" then return n end
    return nil
end

-- A material that comes in more than one form. Returns a list of rows { text, icon }.
--   * smithing: the bar itself, or the same bars in the metal bank  -> one row, "5 x Rune bar"
--   * otherwise (two kinds of the same ingredient)                   -> one row for each choice (an item being removed from the game is
--   left out)
-- (A water container choice, "bucket / jug / bowl of water", is not a material row: it comes back as the second result, a crafting station
-- row "Made at: Water source" that readMaterials passes on to Recipes.parse. Water source is a crafting station with a button.)
local function multiMaterial(record)
    local entries = fieldList(record, nil)
    local overrideName = getField(entries, "RECIPE_MULTI_NAME_OVERRIDE")
    local overrideObj = getField(entries, "RECIPE_MULTI_OBJECT_OVERRIDE")
    local items = {}
    for n = 1, 8 do
        local obj = getField(entries, "RECIPE_INGREDIENT_TYPE_" .. n)
        if obj == nil then break end
        items[#items + 1] = { obj = obj, num = getField(entries, "RECIPE_INGREDIENT_NUMBER_" .. n) or 1 }
    end
    if #items == 0 then return {} end

    local main = nil
    for _, it in ipairs(items) do
        if overrideObj ~= nil and idOf(it.obj) == idOf(overrideObj) then main = it end
    end
    -- A label that names two or more of the choices ("Immaculate alloy bar or partially folded alloy bar") is one button that can open only
    -- one of them (the Partially folded alloy bar's own: a click did nothing). Those get one row for each choice instead.
    if main ~= nil then
        local lowerLabel = string.lower((type(overrideName) == "string" and overrideName ~= "") and overrideName or tostring(nameOf(main.obj)))
        local named = 0
        for _, it in ipairs(items) do
            local n = string.lower(tostring(nameOf(it.obj)))
            if n ~= "metal bank object" and string.find(lowerLabel, n, 1, true) then named = named + 1 end
        end
        if string.find(lowerLabel, " or ", 1, true) and named >= 2 then main = nil end
    end
    if main ~= nil then
        local label = nameOf(main.obj)
        if type(overrideName) == "string" and overrideName ~= "" then label = overrideName end
        return { { text = countText(main.num) .. " x " .. label, icon = idOf(main.obj) } }
    end

    -- (two or more water containers in the choice: one row for a water source - a fountain or a well - in the place of the first of them)
    local water = Recipes.waterFact and Recipes.waterFact() or nil
    local waterCount = 0
    if water ~= nil then
        for _, it in ipairs(items) do
            if water.set[string.lower(tostring(nameOf(it.obj)))] then waterCount = waterCount + 1 end
        end
        if waterCount < water.minimum then water = nil end
    end
    local out = {}
    local waterDone = false
    local waterRow = nil
    for _, it in ipairs(items) do
        local itemName = nameOf(it.obj)
        if water ~= nil and water.set[string.lower(tostring(itemName))] then
            if not waterDone then
                waterDone = true
                waterRow = { label = water.label, sprite = water.sprite }
            end
        elseif itemName ~= "Metal bank object" and not Recipes.isRemoved(itemName) then
            out[#out + 1] = { text = ((#out > 0) and "or " or "") .. countText(it.num) .. " x " .. itemName,
                              icon = idOf(it.obj) }
        end
    end
    if #out == 0 and not waterDone then
        for _, it in ipairs(items) do
            if not Recipes.isRemoved(nameOf(it.obj)) then
                out[1] = { text = countText(it.num) .. " x " .. nameOf(it.obj), icon = idOf(it.obj) }
                break
            end
        end
    end
    -- (the "or" of the first remaining choice is dropped when the water row that came before it is gone)
    if waterDone and out[1] ~= nil and string.sub(out[1].text, 1, 3) == "or " then out[1].text = string.sub(out[1].text, 4) end
    return out, waterRow
end

-- Is this a worn or broken copy of an item the recipe already lists ("Broken X" / "X (broken)")?
-- Those would only add noise to the "Upgraded from" rows.
local function isWornForm(sourceName, materials)
    local lower = string.lower(sourceName)
    local base = nil
    if string.sub(lower, 1, 7) == "broken " then
        base = string.sub(lower, 8)
    elseif string.sub(lower, -9) == " (broken)" then
        base = string.sub(lower, 1, -10)
    end
    if base == nil then return false end
    local tail = " x " .. base
    for _, m in ipairs(materials) do
        if string.sub(string.lower(m.text), -#tail) == tail then return true end
    end
    return false
end

-- "Needs quest: <name>" (a long quest name would run out of the box, so the word "Needs" is dropped for those)
local function questRow(quest) return ((#quest > 28) and "Quest: " or "Needs quest: ") .. quest end

-- What a ritual is made from: its list of inputs (cloth and thread: any one of several items), or its one input, or nothing.
local function ritualInputs(r)
    if r.inputs ~= nil then return r.inputs end
    if r.input ~= nil then return { r.input } end
    return nil
end

-- The materials the recipe lists, as { text = "2 x Plank", icon = an item number }. (The metal bank's stand-in is still "Metal bank object" here.)
local function readMaterials(fields)
    local materials = {}
    local waterRow = nil
    for n = 1, 10 do
        local obj = getField(fields, "RECIPE_INGREDIENT_TYPE_" .. n)
        -- (an item that is being removed from the game is left out; so is one the recipe needs 0 of - "0 x Bones" on the Dungeoneering
        -- summoning pouches)
        if obj ~= nil and getField(fields, "RECIPE_INGREDIENT_NUMBER_" .. n) ~= 0 and not Recipes.isRemoved(field(obj, "name")) then
            local name = nameOf(obj)
            local count = countText(getField(fields, "RECIPE_INGREDIENT_NUMBER_" .. n))
            -- "Metal bank object" stands for bars from the metal bank, and the extra-info setting says which bar
            local bar = nil
            if name == "Metal bank object" then
                bar = Recipes.hopperItem(getField(fields, "RECIPE_INGREDIENT_EXTRA_INFO_" .. n))
            end
            -- "Invention material" is the game's stand-in for the kinds of part and component an Invention recipe uses;
            -- which kind it is comes from the same extra-info setting; its picture is the kind's own sprite (Recipes.inventionPicture)
            local kind, kindKey = nil, nil
            if name == "Invention material" then
                kindKey = getField(fields, "RECIPE_INGREDIENT_EXTRA_INFO_" .. n)
                kind = Recipes.inventionMaterial(kindKey)
            end
            if bar ~= nil then
                materials[#materials + 1] = { text = count .. " x " .. bar.name, icon = bar.id }
            elseif kind ~= nil then
                -- (pic: a sprite number, drawn beside the words, see layoutRecipeRows; the row is not an item, so a click does nothing)
                -- (query: a click types "@clear-parts", the items whose recipes use this kind; the same station-style index, see uses.lua)
                materials[#materials + 1] = { text = count .. " x " .. kind, pic = Recipes.inventionPicture(kindKey), query = "@" .. Recipes.materialSlug(kind) }
            else
                materials[#materials + 1] = { text = count .. " x " .. name, icon = idOf(obj) }
            end
        end
    end
    for n = 1, 6 do
        local record = getField(fields, "RECIPE_INGREDIENT_" .. n .. "_MULTIPLE")
        if record ~= nil then
            local list, water = multiMaterial(record)
            for _, m in ipairs(list) do materials[#materials + 1] = m end
            if water ~= nil and waterRow == nil then waterRow = water end
        end
    end
    return materials, waterRow
end

-- "Metal bank object" is the game's stand-in for "bars taken from the metal bank". The recipe does not
-- say which bars, but the smithing / smelting lists file each product under the bar it is made from.
-- Returns the materials with that stand-in replaced by the bars (or, when the bars are not known, one row with the total), and that
-- one row (nil when there is none).
local function namedMaterials(materials, bars)
    local named = {}
    local unknownRow, unknownTotal = nil, 0
    for _, m in ipairs(materials) do
        if string.find(m.text, "Metal bank object", 1, true) then
            local count = string.match(m.text, "^([%d,]+) x ") or "1"
            if bars ~= nil and #bars > 0 then
                for _, b in ipairs(bars) do named[#named + 1] = { text = count .. " x " .. b.name, icon = b.id } end
            else
                -- the bars are not known: say it once, with the total, rather than once per slot
                unknownTotal = unknownTotal + (tonumber((string.gsub(count, ",", ""))) or 1)
                if unknownRow == nil then
                    unknownRow = { text = "" }
                    named[#named + 1] = unknownRow
                end
                unknownRow.text = withCommas(unknownTotal) .. " x bars from the metal bank"
            end
        else
            named[#named + 1] = m
        end
    end
    return named, unknownRow
end

-- The items this one is made from by an upgrade that are worth a row of their own: not one the recipe already lists as a material.
-- (An entry may also be plain text with no item: { lines = {...} }, or an item with no label.)
local function extraSources(sources, materials)
    local extra = {}
    for _, s in ipairs(sources or {}) do
        local listed = false
        if s.name ~= nil then
            local tail = " x " .. s.name
            for _, m in ipairs(materials) do
                -- (the recipe may list the smithing screen's copy of the same item, so compare names too)
                if m.icon == s.id or string.sub(m.text, -#tail) == tail then listed = true end
            end
        end
        if not listed and (s.name == nil or not isWornForm(s.name, materials)) then extra[#extra + 1] = s end
    end
    return extra
end

-- The rows of one ritual that makes the item (a little recipe of its own). Returns true when the hand-written facts gave some of them.
local function addRitualRows(r, addRow)
    addRow("Ritual: " .. r.name, nil, "ritual") -- (the ritual site's picture; a click searches @ritual)
    if r.level ~= nil then addRow("Needs: " .. r.skill .. " level " .. tostring(r.level)) end
    if r.quest ~= nil then addRow(questRow(r.quest)) end
    if r.requirement ~= nil then addRow(r.requirement) end
    if r.tier ~= nil then addRow("Ritual site tier: " .. tostring(r.tier)) end
    if r.ticks ~= nil then addRow("Time: " .. tostring(r.ticks) .. " ticks (" .. string.format("%.1f", r.ticks * 0.6) .. " s)") end
    local inputs = ritualInputs(r)
    if inputs ~= nil and #inputs > 0 then
        addRow((#inputs > 1) and "Materials (any one of):" or "Materials:")
        for _, input in ipairs(inputs) do addRow(withCommas(input.count) .. " x " .. input.name, input.id) end
    end
    local window = Recipes.ritualFacts and Recipes.ritualFacts(r.name) or nil -- (what the ritual window shows: the hand-written facts)
    if window ~= nil then
        if window.site ~= nil then addRow("Only at: " .. window.site) end
        -- (one row for both: the info box only has room for so many rows)
        if window.durability ~= nil and window.light ~= nil then
            addRow("Durability: " .. tostring(window.durability) .. ",  Light sources: " .. tostring(window.light))
        elseif window.durability ~= nil then addRow("Durability: " .. tostring(window.durability))
        elseif window.light ~= nil then addRow("Light sources: " .. tostring(window.light)) end
        if #window.glyphs > 0 then
            addRow("Glyphs:")
            for _, g in ipairs(window.glyphs) do addRow(tostring(g.count) .. " x " .. g.name, g.id) end
        end
    elseif r.glyph ~= nil then
        addRow("Main glyph: " .. tostring(r.glyph.count) .. " x " .. r.glyph.name, r.glyph.id)
        addRow("Other glyphs: not in game data") -- the game's ritual data names only the first glyph
    end
    if r.makes ~= nil and r.makes > 1 then addRow("Makes: " .. withCommas(r.makes)) end
    if r.xp ~= nil then addRow("XP: " .. xpText(r.xp) .. " " .. r.skill) end
    return window ~= nil
end

-- How many things the recipe is made from (not counting the "bars from the metal bank" stand-in): the Craftable filter wants at least one.
local function countIngredients(named, unknownRow, extra, rituals)
    local ingredients = 0
    for _, m in ipairs(named) do if m ~= unknownRow then ingredients = ingredients + 1 end end
    for _, s in ipairs(extra) do if s.name ~= nil then ingredients = ingredients + 1 end end
    for _, r in ipairs(rituals or {}) do ingredients = ingredients + #(ritualInputs(r) or {}) end
    return ingredients
end

-- Cut the rows down to what the info box can show (saying so, rather than cutting the rest off silently), make their words safe for the
-- game and add up their height.
local function finishRows(rows)
    if #rows > RECIPE_MAX_LINES then
        local hidden = #rows - RECIPE_MAX_LINES + 1
        for i = #rows, RECIPE_MAX_LINES, -1 do rows[i] = nil end
        rows[RECIPE_MAX_LINES] = { text = "(" .. hidden .. " more rows not shown)" }
    end
    local height = 0
    for _, row in ipairs(rows) do
        -- a button only fits about 38 letters: cut anything longer
        if row.icon ~= nil and #row.text > 38 then row.text = string.sub(row.text, 1, 36) .. ".." end
        row.text = (row.text:gsub("<", "<lt>")) -- the game treats "<" as the start of a tag
        -- rows with an item (or a station to click) are taller
        height = height + ((row.icon ~= nil or row.query ~= nil or row.pic ~= nil) and ROW_HEIGHT or LINE_H)
    end
    return height
end

-- Turn an item's RECIPE_ fields into the rows shown in the info box. Each row is { text = "...", icon = an item number or nil }; a row with
-- an item number gets a picture and can be clicked. Returns { rows, height, materials }, or nil if there is nothing worth showing (a recipe
-- with no materials and no earlier stage, such as a rune, is not shown).
-- "sources" (optional) is a list of the items this one is made from by an upgrade: { id, name, label, note }. An entry may also be plain
-- text ({ lines = {...} }) or an item with no label.
-- "needs" (optional) is { plans = { id, name } (the furniture plans to learn first), blueprints = { [number] = name }, extra = { lines }
-- (an extra requirement from the skill guide) }.
-- "station" (optional) is a list of rows { text, icon } that say where it is made ("Made at: Furnace"); they come right after the levels
-- and the way it is made, and are dropped when there is nothing to make it from.
-- The search a click on a crafting station's row types (the @ search words): the key of the station's picture -> the search.
local STATION_QUERY = { furnace = "@furnace", anvil = "@anvil", range = "@range", altar = "@altar", inventor = "@invention", archaeologist = "@archaeology", ritual = "@ritual",
                       water = "@water", backpack = "@backpack" }

-- selfId (optional) is the item's own number: a material row for the item itself (a bar folded again and again) has no picture button, a
-- click on it would open the page that is already open.
-- Is the item made in the backpack, by the RuneScape Wiki's recipes? Only asked when the game's data names no station.
function Recipes.madeInBackpack(id)
    local set = WikiLists ~= nil and WikiLists.is ~= nil and WikiLists.is.backpack or nil
    return set ~= nil and set[id] == true
end

function Recipes.parse(fields, sources, bars, wear, unlocks, rituals, needs, station, selfId)
    local rows = {}
    -- (sprite: a crafting station's picture, see stations.lua. query: the search a click on the row types, "@furnace"; a station's sprite
    -- gives its own unless the caller says otherwise. also: more station words the item is found under, for a row that names two stations)
    local function addRow(text, icon, sprite, query, also)
        rows[#rows + 1] = { text = text, icon = icon, sprite = sprite, query = query or (sprite ~= nil and STATION_QUERY[sprite]) or nil, also = also }
    end
    local blueprintTexts = {} -- the "Needs blueprint" lines (kept to show them when there is nothing to make it from)
    local methodTexts = {}    -- the "Method: ..." / "Built in your house" lines (only shown for a real recipe)

    for _, w in ipairs(wear or {}) do addRow(w) end -- what is needed to wear it comes first

    for n = 1, 6 do
        local t = getField(fields, "RECIPE_REQUIREMENT_TYPE_" .. n)
        local v = getField(fields, "RECIPE_REQUIREMENT_VALUE_" .. n)
        if type(t) == "number" and skillNames[t] ~= nil and v ~= nil then
            addRow("Needs: " .. skillLabel(t) .. " level " .. tostring(v))
        elseif t == Exceptions.requirementTypes.quest and type(v) == "number" then
            local quest = Recipes.questName(v)
            if quest ~= nil then addRow(questRow(quest)) end
        elseif t == Exceptions.requirementTypes.achievement and type(v) == "number" then
            local achievement = unlocks and unlocks[v]
            if achievement ~= nil then addRow("Achievement: " .. achievement) end -- (short, so "Kili's Knowledge V (power)" fits the box)
        elseif t == Exceptions.requirementTypes.blueprint and type(v) == "number" then
            local blueprint = needs and needs.blueprints and needs.blueprints[v]
            if blueprint ~= nil then
                local line = Recipes.blueprintLine(blueprint)
                blueprintTexts[#blueprintTexts + 1] = line
                addRow(line)
            end
        elseif t == Exceptions.requirementTypes.method and type(v) == "number" then
            local method = Exceptions.methods[v]
            if method ~= nil then methodTexts[#methodTexts + 1] = Exceptions.methodRowStart .. method end
        elseif t == Exceptions.requirementTypes.house then
            methodTexts[#methodTexts + 1] = Exceptions.houseRow
        end
    end
    local planRow = nil
    if needs ~= nil and needs.plans ~= nil then
        planRow = { text = Recipes.plansLine(needs.plans.name), icon = needs.plans.id }
        addRow(planRow.text, planRow.icon)
    end
    -- how it is made: after the levels, quests and plans (and, like the XP, dropped below when there is nothing to make it from)
    for _, line in ipairs(methodTexts) do addRow(line) end
    for _, line in ipairs((needs ~= nil and needs.extra) or {}) do addRow(line) end -- (an extra requirement from the skill guide)

    -- made somewhere other than the backpack: a station, a water source, a way of making it (a method, the house), a ritual
    local placed = (#methodTexts > 0) or (rituals ~= nil and #rituals > 0) or (station ~= nil and #station > 0)
    local backpackAt = #rows + 1 -- (where "Made in: Backpack" goes: the place of a station's row)
    for _, s in ipairs(station or {}) do addRow(s.text, s.icon, s.sprite, s.query, s.also) end
    -- a water source (fountain, well, sink) is a crafting station too: "Made at: Water source", the water picture, a click searches @water
    local rawMaterials, waterRow = readMaterials(fields)
    if waterRow ~= nil then addRow("Made at: " .. waterRow.label, nil, waterRow.sprite, "@water"); placed = true end

    for n = 1, 4 do
        local obj = getField(fields, "RECIPE_TOOL_TYPE_" .. n)
        -- (tools every player has on the toolbelt are not worth mentioning)
        if obj ~= nil and not Recipes.onToolbelt(obj) then
            addRow("Tool: " .. nameOf(obj), idOf(obj))
        end
    end

    local named, unknownRow = namedMaterials(rawMaterials, bars)
    local materials = named

    -- the item(s) this one is made from (unless the recipe already lists one as a material)
    local extra = extraSources(sources, materials)
    local hasRecipe = (#materials > 0 or #extra > 0 or (rituals ~= nil and #rituals > 0))
    local extraNeeds = #blueprintTexts + ((planRow ~= nil) and 1 or 0)
    if not hasRecipe then
        -- nothing to make it from: show only what is needed to wear it, or the blueprint / plans it needs (if anything)
        if (wear == nil or #wear == 0) and extraNeeds == 0 then return nil end
        rows = {}
        for _, w in ipairs(wear or {}) do addRow(w) end
        for _, line in ipairs(blueprintTexts) do addRow(line) end
        if planRow ~= nil then addRow(planRow.text, planRow.icon) end
    end
    for _, s in ipairs(extra) do
        if s.label ~= nil then addRow(s.label) end
        if s.name ~= nil then addRow(s.name, s.id) end
        for i, line in ipairs(s.lines or {}) do
            addRow(line, nil, (i == 1) and s.sprite or nil, (i == 1) and s.query or nil)
            if s.noIndex then rows[#rows].noIndex = true end -- (a click searches, but the item is not one of what it finds: recipes/uses.lua)
        end
        if s.note ~= nil then addRow(s.note) end
    end
    if #materials > 0 then
        addRow("Materials:")
        for _, m in ipairs(materials) do
            addRow(m.text, (m.icon ~= selfId) and m.icon or nil, m.sprite, m.query)
            rows[#rows].pic = m.pic -- (an Invention material's own picture: a sprite number)
        end
    end

    if hasRecipe then
        -- how many the recipe makes at once (cannonballs: 4, arrowheads: 15...)
        local stack = getField(fields, "RECIPE_MAKE_STACK_SIZE")
        if type(stack) == "number" and stack > 1 then addRow("Makes: " .. withCommas(stack)) end

        for n = 1, 3 do
            local t = getField(fields, "RECIPE_XP_TYPE_" .. n)
            local v = getField(fields, "RECIPE_XP_VALUE_" .. n)
            if t ~= nil and type(v) == "number" then
                addRow("XP: " .. xpText(v) .. " " .. skillLabel(t))
            end
        end
    end

    -- rituals that make this item (each is a little recipe of its own)
    local usedPlayerFact = false
    for _, r in ipairs(rituals or {}) do
        if addRitualRows(r, addRow) then usedPlayerFact = true end
    end

    -- "Made in: Backpack": the game's data names no station for the recipe, and the RuneScape Wiki's recipes say the backpack
    -- (data/wiki_lists.lua, WikiLists.backpack). A click searches @backpack.
    for _, s in ipairs(extra) do if s.sprite ~= nil or s.query ~= nil then placed = true end end -- (a station row that came with the item it is made from)
    if hasRecipe and not placed and selfId ~= nil and Recipes.madeInBackpack(selfId) then
        table.insert(rows, backpackAt, { text = "Made in: Backpack", sprite = "backpack", query = "@backpack" })
    end
    local ingredients = countIngredients(named, unknownRow, extra, rituals)
    local height = finishRows(rows)
    -- the skills the recipe needs a level in (and gives experience in): skill number -> level, 0 when it only gives experience (the search
    -- by skill, the @ search words, a later build)
    local skills = {}
    for n = 1, 6 do
        local t = getField(fields, "RECIPE_REQUIREMENT_TYPE_" .. n)
        local v = getField(fields, "RECIPE_REQUIREMENT_VALUE_" .. n)
        if type(t) == "number" and skillNames[t] ~= nil and type(v) == "number" then skills[t] = v end
    end
    for n = 1, 3 do
        local t = getField(fields, "RECIPE_XP_TYPE_" .. n)
        if type(t) == "number" and skillNames[t] ~= nil and skills[t] == nil then skills[t] = 0 end
    end
    return { rows = rows, height = height, materials = #materials, ingredients = ingredients, wear = #(wear or {}) + (hasRecipe and 0 or extraNeeds), recipe = hasRecipe,
             fromPlayer = usedPlayerFact and "rituals" or nil, skills = next(skills) ~= nil and skills or nil }
end

end }
