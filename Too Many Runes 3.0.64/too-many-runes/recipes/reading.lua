-- Too Many Runes - Recipes: reading the game's data
-- Helpers that read fields from the game's items, names for skills and quests, and the smithing screen's item index.
-- (Moved over from the old plugin almost unchanged; recipes/compat.lua explains how it fits the new one.)
return { run = function(II)
local _ENV = II

----------------------------------------------------------------
-- CRAFTING RECIPES (the files in this folder, recipes)
----------------------------------------------------------------
-- The game keeps a recipe on the item that it makes, as fields whose names start with "RECIPE_":
--   RECIPE_REQUIREMENT_TYPE_1 / _VALUE_1   a skill number and the level needed (then _2, _3...)
--   RECIPE_TOOL_TYPE_1                     a tool you must have (hammer, ring mould...)
--   RECIPE_XP_TYPE_1 / _VALUE_1            the skill, and the XP in tenths (1000 means 100 xp)
--   RECIPE_INGREDIENT_TYPE_n / _NUMBER_n   a material, and how many of it
--   RECIPE_INGREDIENT_n_MULTIPLE           a little record for a material that comes in more than one
--                                          form (smithing: the bar itself, or bars in the metal bank)
-- The smithing screen uses its own copies of the items (item 45543 is the smithing screen's
-- "Rune platebody"; the ordinary one is 1127), so for those we find the copy by NAME.
Recipes.materialOf = {} -- product name (lowercase) -> the bars the smithing / smelting lists say it is made from
-- Where an item is made, as far as the game's lists say (all by lower-case name; filled by buildSmithingIndex below):
Recipes.smithed  = {} -- products of the smithing screen (the forge and anvil): the rows of SMITHING_MATERIAL_TO_ITEM_DBROW, and SMITHING_ID_TO_OBJ
Recipes.smelted  = {} -- products of the smelting screen (the furnace): the rows of SMELTING_MATERIAL_TO_ITEM_DBROW and the smelting tables
Recipes.barNames = {} -- the materials those two lists file products under (bars, ores...)
Recipes.gameSets = {} -- the Grand Exchange's item sets (Exceptions.exchangeSetLists)

-- The toolbelt. The game keeps lists of the tools that have a place on the belt (Exceptions.toolbeltLists: TOOLBELT_V2_CATEGORY_CRAFTING
-- ...). Each entry is either the tool itself or a little record that names the tool in its TOOLBELT_OBJECT setting (the survey
-- "sources" found this). Recipes do not mention these tools: they are kept on the belt, not carried. Read once, the first time a recipe is
-- built (Recipes.prepare). Recipes.onToolbelt(obj) says whether a tool is one of them.
Recipes.toolbeltIds, Recipes.toolbeltNames, Recipes.toolbeltCount = {}, {}, 0
-- The game also keeps a few words on how some of the tools are got (TOOLBELT_UNLOCK_INFO: "Bought from a Crafting shop."...): by item
-- number, and by name (lower case) for the same tool under another number.
Recipes.toolbeltInfo, Recipes.toolbeltInfoNames = {}, {}

function Recipes.readToolbelt()
    local ids, names, count = {}, {}, 0
    local info, infoNames = {}, {}
    local listsRead, listsMissing = 0, {}
    local seenLists = {}
    local function addTool(obj, text)
        local id, name = field(obj, "id"), field(obj, "name")
        if type(id) == "number" and not ids[id] then
            ids[id] = true
            count = count + 1
            if type(name) == "string" and name ~= "" then names[string.lower(name)] = true end
        end
        if type(id) == "number" and text ~= nil then
            info[id] = text
            if type(name) == "string" and name ~= "" and infoNames[string.lower(name)] == nil then infoNames[string.lower(name)] = text end
        end
    end
    local function readList(en, depth)
        local listId = field(en, "id")
        if depth > 1 and type(listId) == "number" then -- (a list reached through another list: never read the same one twice)
            if seenLists[listId] then return end
            seenLists[listId] = true
        end
        local entries, entryCount = field(en, "values"), field(en, "valueCount")
        if entries == nil and type(listId) == "number" then -- (a list reached through another list may come without its entries)
            local full = nil
            pcall(function() full = config.Enum.FromID(listId) end)
            entries, entryCount = field(full, "values"), field(full, "valueCount")
        end
        if entries == nil or type(entryCount) ~= "number" then return end
        for e = 1, Recipes.listCount(entryCount, 400, "a toolbelt list") do
            local entry = valueAt(entries, e)
            local value = nil
            if entry ~= nil then value = valueAt(entry, 2) end
            local kind = field(value, "typeName")
            if kind == "Obj" then
                addTool(value)
            elseif kind == "Enum" then
                if depth < 3 then readList(value, depth + 1) end
            elseif value ~= nil and type(value) ~= "number" and type(value) ~= "string" and type(value) ~= "boolean" then
                local params = field(value, "params")
                local tool, text = nil, nil
                for i = 1, MAX_PARAMS do
                    local p = valueAt(params, i)
                    if p == nil then break end
                    local pname = field(p, "configName")
                    if not BAD_TYPES[tostring(field(p, "valueType"))] then
                        if pname == "TOOLBELT_OBJECT" then
                            local ok, t = pcall(function() return value:GetParamValue(p) end)
                            if ok and field(t, "typeName") == "Obj" then tool = t end
                        elseif pname == "TOOLBELT_UNLOCK_INFO" then
                            local ok, t = pcall(function() return value:GetParamValue(p) end)
                            if ok and type(t) == "string" and t ~= "" then text = t end
                        end
                    end
                end
                if tool ~= nil then addTool(tool, text) end
            end
        end
    end
    for _, listName in ipairs(Exceptions.toolbeltLists) do
        local en = nil
        pcall(function() en = config.Enum[listName] end)
        if en ~= nil then
            listsRead = listsRead + 1
            readList(en, 1)
        else
            listsMissing[#listsMissing + 1] = listName
        end
    end
    Recipes.toolbeltIds, Recipes.toolbeltNames, Recipes.toolbeltCount = ids, names, count
    Recipes.toolbeltInfo, Recipes.toolbeltInfoNames = info, infoNames
    if count > 0 then
        detail("Too Many Runes: the toolbelt holds " .. count .. " tools (read from " .. listsRead .. " of the game's lists); recipes do not mention these.")
    else
        print("Too Many Runes: could not read the toolbelt from the game's lists, so recipes will list every tool they use.")
    end
end

-- The lines the Recipe tab shows for a tool kept on the toolbelt: that it is one, and the game's own words on how it is got (if it has any).
-- (Empty for anything else.)
function Recipes.toolbeltRows(obj)
    if not Recipes.onToolbelt(obj) then return {} end
    local id, name = field(obj, "id"), field(obj, "name")
    local text = Recipes.toolbeltInfo[id]
    if text == nil and type(name) == "string" then text = Recipes.toolbeltInfoNames[string.lower(name)] end
    local rows = { "A tool kept on the toolbelt." }
    if text ~= nil then
        for _, line in ipairs(Recipes.guideLines(text)) do rows[#rows + 1] = line end
    end
    return rows
end

-- Is this tool (an item) kept on the toolbelt?
function Recipes.onToolbelt(obj)
    local id, name = field(obj, "id"), field(obj, "name")
    if type(id) == "number" and Recipes.toolbeltIds[id] then return true end
    return type(name) == "string" and Recipes.toolbeltNames[string.lower(name)] == true
end

BAD_TYPES = Exceptions.unreadableTypes -- data the game will not hand to a plugin (the list is in recipes/exceptions.lua)

local function index(thing, key) return thing[key] end

-- Read one property of a game object (or one place of a game list) without crashing if it does not exist: nil when it cannot be read.
function field(thing, name)
    local ok, value = pcall(index, thing, name)
    if ok then return value end
    return nil
end
valueAt = field

-- An item or a record never holds this many settings: the loops over them stop at the first empty place anyway.
MAX_PARAMS = 1000

-- How many entries of a game list to read: all of them, up to the ceiling that was set for that list. A list that goes over its ceiling
-- (the game grew it) is reported once instead of being cut off without a word.
local warnedLists = {}
function Recipes.listCount(count, ceiling, what)
    if count > ceiling then
        if not warnedLists[what] then
            warnedLists[what] = true
            print("Too Many Runes: the game's list " .. what .. " holds " .. count .. " entries; only the first " .. ceiling .. " are read.")
        end
        return ceiling
    end
    return count
end

-- A yes / no setting of an item: some are stored as true / false, others as 1 / 0.
function isTrue(v) return v == true or (type(v) == "number" and v ~= 0) end

-- The named fields of an item or record, as a list of { name, value }.
-- With a prefix, only the fields whose name starts with it.
function fieldList(thing, prefix)
    local result = {}
    local params = field(thing, "params")
    if params == nil then return result end
    for i = 1, MAX_PARAMS do
        local p = valueAt(params, i)
        if p == nil then break end
        local name = tostring(field(p, "configName") or "?")
        local valueType = tostring(field(p, "valueType"))
        if (prefix == nil or string.sub(name, 1, #prefix) == prefix) and not BAD_TYPES[valueType] then
            local okV, v = pcall(function() return thing:GetParamValue(p) end)
            if okV and v ~= nil then result[#result + 1] = { name = name, value = v } end
        end
    end
    return result
end

function getField(list, name)
    for _, e in ipairs(list) do
        if e.name == name then return e.value end
    end
    return nil
end

-- An item's name, as text.
function nameOf(obj)
    if type(obj) == "number" then return "item " .. tostring(obj) end
    local n = field(obj, "name")
    if type(n) == "string" and n ~= "" then return n end
    return "item " .. tostring(field(obj, "id"))
end

-- Requirement type 61 is "must have done this quest". Its number is a place in the game's list
-- QL4_QUESTS (found by the survey: 8 = The Knight's Sword for the Blurite sword, 70 = Lunar Diplomacy
-- for the Moonclan teleport). Built once: number -> quest name.
function Recipes.questName(v)
    if Recipes.questMap == nil then
        Recipes.questMap = {}
        local en = nil
        pcall(function() en = config.Enum["QL4_QUESTS"] end)
        local entries = field(en, "values")
        local count = field(en, "valueCount")
        if entries ~= nil and type(count) == "number" then
            for e = 1, Recipes.listCount(count, 1000, "QL4_QUESTS") do
                local entry = valueAt(entries, e)
                if entry ~= nil then
                    local key, quest = valueAt(entry, 1), valueAt(entry, 2)
                    local questName = nil
                    if quest ~= nil and type(quest) ~= "number" and type(quest) ~= "string" then questName = field(quest, "name") end
                    if type(key) == "number" and type(questName) == "string" and questName ~= "" then
                        Recipes.questMap[key] = questName
                    end
                end
            end
        end
    end
    return Recipes.questMap[v]
end

-- Names of the stats used by "to wear" requirements (0 = Attack, 1 = Defence ...): the game's list STAT_TO_STRING.
-- (These are numbered from 0; the numbers recipes use are numbered from 1.)
function Recipes.statName(n)
    if Recipes.statMap == nil then
        Recipes.statMap = {}
        local en = nil
        pcall(function() en = config.Enum["STAT_TO_STRING"] end)
        local entries, count = field(en, "values"), field(en, "valueCount")
        if entries ~= nil and type(count) == "number" then
            for e = 1, Recipes.listCount(count, 60, "STAT_TO_STRING") do
                local entry = valueAt(entries, e)
                local key, name = nil, nil
                if entry ~= nil then key, name = valueAt(entry, 1), valueAt(entry, 2) end
                if type(key) == "number" and type(name) == "string" and name ~= "" then Recipes.statMap[key] = name end
            end
        end
    end
    return Recipes.statMap[n] or ("skill #" .. tostring(n))
end

-- What an item needs before you can wear or wield it. The item itself stores this:
--   WEAR_REQUIRES_STAT1 / WEAR_REQUIRES_STAT_LEVEL1   a stat and its level (up to a few pairs)
--   WEAR_REQUIRES_QUEST1                              a quest
-- Returns a list of the requirements as short texts ("Attack level 50", "Quest: ..."; empty if it needs nothing).
function Recipes.wearRows(itemObj)
    local rows = {}
    local fields = fieldList(itemObj, "WEAR_REQUIRES_")
    if #fields == 0 then return rows end
    for n = 1, 5 do
        local stat = getField(fields, "WEAR_REQUIRES_STAT" .. n)
        local level = getField(fields, "WEAR_REQUIRES_STAT_LEVEL" .. n)
        if type(stat) == "number" and type(level) == "number" and level > 0 then
            rows[#rows + 1] = Recipes.statName(stat) .. " level " .. level
        end
    end
    for n = 1, 4 do
        local quest = getField(fields, "WEAR_REQUIRES_QUEST" .. n)
        if type(quest) == "number" then
            -- (a quest needed to wear an item is stored as a place in the game's quest list QL4_QUESTS, the same numbering the recipes use for the
            -- quest they need: the survey "sources" settled this in the real game. Of the 43 items that need a quest both to be made and to be
            -- worn, 13 have the SAME number for both, where by chance about one in thirty-five would.)
            local name = Recipes.questName(quest)
            if name ~= nil then rows[#rows + 1] = "Quest: " .. name end
        end
    end
    return rows
end

-- The lines the Info tab shows for these requirements (at most WEAR_LINES): one line "Requirements to wear/wield: Attack level 50" when it is
-- a single requirement and fits the box, else that title on a line of its own and each requirement under it.
Recipes.WEAR_TITLE = "Requirements to wear/wield:"
function Recipes.wearLines(reqs)
    if #reqs == 0 then return {} end
    local clean = {}
    for i, r in ipairs(reqs) do clean[i] = (r:gsub("<", "<lt>")) end -- (the game treats "<" as the start of a tag)
    if #clean == 1 then
        local one = Recipes.WEAR_TITLE .. " " .. clean[1]
        if Filters ~= nil and Filters.textWidth(one) <= 310 then return { one } end
    end
    local lines = { Recipes.WEAR_TITLE }
    local room = WEAR_LINES - 1
    if #clean <= room then
        for _, r in ipairs(clean) do lines[#lines + 1] = r end
    else
        for i = 1, room - 1 do lines[#lines + 1] = clean[i] end
        lines[#lines + 1] = (#clean - room + 1) .. " more"
    end
    return lines
end

-- The words on the Recipe tab: "Recipe", "Source" when all it holds is where the item is gathered, or "Guide" / "Needs" / "Tool" when all
-- it holds is a skill guide's text, requirements or the note on a toolbelt tool.
function Recipes.recipeTabLabel(data)
    -- (where the item is mined, cut, caught, grown ...: recipes/gather.lua)
    if data ~= nil and data.gathered and not data.recipe then return "Source" end
    if data ~= nil and data.wear ~= nil and data.wear > 0 and not data.recipe then
        return (data.guide ~= nil) and "Guide" or "Needs"
    end
    return "Recipe"
end

-- The alloy bars are made tier by tier (Concentrated, Enriched, Immaculate...). A recipe only says
-- "Metal bank object" for its ingredient, but the game's list SMELTING_MASTERWORK_TABLE puts the tiers
-- in order, so the ingredient is the tier below. (The glorious bars are made another way: not covered.)
function Recipes.alloyBelow(lowerName)
    if Recipes.alloyMap == nil then
        Recipes.alloyMap = {}
        local en = nil
        pcall(function() en = config.Enum["SMELTING_MASTERWORK_TABLE"] end)
        local entries, count = field(en, "values"), field(en, "valueCount")
        local tiers = {}
        if entries ~= nil and type(count) == "number" then
            for e = 1, Recipes.listCount(count, 50, "SMELTING_MASTERWORK_TABLE") do
                local entry = valueAt(entries, e)
                local key, bar = nil, nil
                if entry ~= nil then key, bar = valueAt(entry, 1), valueAt(entry, 2) end
                local barName = nil
                if bar ~= nil and type(bar) ~= "number" and type(bar) ~= "string" then barName = field(bar, "name") end
                if type(key) == "number" and type(barName) == "string" then
                    tiers[key] = { id = field(bar, "id"), name = barName }
                end
            end
        end
        for key, tier in pairs(tiers) do
            local below = tiers[key - 1]
            if below ~= nil and not string.find(string.lower(tier.name), "glorious", 1, true) then
                Recipes.alloyMap[string.lower(tier.name)] = { below }
            end
        end
    end
    return Recipes.alloyMap[lowerName]
end

-- A recipe slot that says "Metal bank object" (the furnace takes a bar from your metal bank) names its bar in
-- RECIPE_INGREDIENT_EXTRA_INFO_<slot>: a place in the furnace's own item list SMITHING_HOPPER_ID_TO_OBJ.
-- (The Concentrated alloy bar has ten slots, 18 19 20 22 23 25 26 27 28 29 = bronze ... elder rune, without
-- silver and gold; the Enriched bar's one slot is 30 = the Concentrated bar.) Returns { id, name } or nil.
function Recipes.hopperItem(key)
    if type(key) ~= "number" then return nil end
    if Recipes.hopperMap == nil then
        Recipes.hopperMap = {}
        local en = nil
        pcall(function() en = config.Enum["SMITHING_HOPPER_ID_TO_OBJ"] end)
        local entries, count = field(en, "values"), field(en, "valueCount")
        if entries ~= nil and type(count) == "number" then
            for e = 1, Recipes.listCount(count, 200, "SMITHING_HOPPER_ID_TO_OBJ") do
                local entry = valueAt(entries, e)
                local k, obj = nil, nil
                if entry ~= nil then k, obj = valueAt(entry, 1), valueAt(entry, 2) end
                local name, id = field(obj, "name"), field(obj, "id")
                if type(k) == "number" and type(name) == "string" and type(id) == "number" then
                    Recipes.hopperMap[k] = { id = id, name = name }
                end
            end
        end
    end
    return Recipes.hopperMap[key]
end

----- skill numbers -----
-- The game's own order of its skills (checked against the 22 numbers the skill guides gave us;
-- the survey then showed that 12 is Runecrafting). Used to fill in any the guides did not mention.
function Recipes.fillSkills(known)
    -- the game's own list of skill names; its numbers are the ones recipes use (found by the survey)
    local en = nil
    pcall(function() en = config.Enum["STATSTRING"] end)
    local entries, count = field(en, "values"), field(en, "valueCount")
    if entries ~= nil and type(count) == "number" then
        for e = 1, Recipes.listCount(count, 60, "STATSTRING") do
            local entry = valueAt(entries, e)
            local key, name = nil, nil
            if entry ~= nil then key, name = valueAt(entry, 1), valueAt(entry, 2) end
            if type(key) == "number" and key >= 1 and type(name) == "string" and name ~= "" then
                known[key] = string.upper(name)
            end
        end
    end
    for i, name in ipairs(Exceptions.skillOrder) do
        if known[i] == nil then known[i] = name end
    end
end

-- The game numbers its skills its own way (Attack = 1, Herblore = 9 ...). Every skill guide knows
-- which skill it belongs to, so we learn the numbers from them instead of guessing.
skillNames = {}

local function learnSkills()
    local pSkill = nil
    pcall(function() pSkill = config.Param.SKILLGUIDE_SKILL end)
    if pSkill == nil then return end
    for _, name in ipairs(Exceptions.guideLookupSkills) do
        local en = nil
        pcall(function() en = config.Enum["SKILLGUIDE_" .. name] end)
        local count = field(en, "valueCount")
        local list = field(en, "values")
        if type(count) == "number" and count > 0 and list ~= nil then
            for i = 1, math.min(count, 5) do
                local pair = valueAt(list, i)
                local st = nil
                if pair ~= nil then st = valueAt(pair, 2) end
                if st ~= nil then
                    local okH, has = pcall(function() return st:HasParam(pSkill) end)
                    local okV, n = false, nil
                    if okH and has == true then okV, n = pcall(function() return st:GetParamValue(pSkill) end) end
                    if okV and type(n) == "number" then
                        skillNames[n] = name
                        break
                    end
                end
            end
        end
    end
end

-- "Smithing" for the game's skill number 14 ("skill #14" if we do not know it).
function skillLabel(n)
    local name = skillNames[n]
    if name ~= nil then return string.upper(string.sub(name, 1, 1)) .. string.lower(string.sub(name, 2)) end
    return "skill #" .. tostring(n)
end

----- the smithing screen's copies of items -----
smithingIndex = {} -- item name (lowercase) -> the item numbers the smithing screen uses for it

local function indexEnum(en, material, kind)
    local entries = field(en, "values")
    local entryCount = field(en, "valueCount")
    if entries == nil or type(entryCount) ~= "number" then return end
    for e = 1, Recipes.listCount(entryCount, 300, tostring(field(en, "configName"))) do
        local entry = valueAt(entries, e)
        local product = nil
        if entry ~= nil then product = valueAt(entry, 2) end
        if product ~= nil and field(product, "typeName") == "Obj" then
            local productName = field(product, "name")
            local productId = field(product, "id")
            if type(productName) == "string" and productName ~= "" and type(productId) == "number" then
                local key = string.lower(productName)
                if kind ~= nil then Recipes[kind][key] = true end
                local ids = smithingIndex[key]
                if ids == nil then
                    ids = {}
                    smithingIndex[key] = ids
                end
                ids[#ids + 1] = productId
                if material ~= nil then -- remember which bar this product is filed under
                    local list = Recipes.materialOf[key]
                    if list == nil then
                        list = {}
                        Recipes.materialOf[key] = list
                    end
                    local known = false
                    for _, m in ipairs(list) do
                        if m.id == material.id then known = true end
                    end
                    if not known then list[#list + 1] = material end
                end
            end
        end
    end
end

-- metal bar -> its data row -> its categories (Armour, Weapons...) -> the products of each category
local function buildSmithingIndex()
    -- The bar a list is filed under, as { id, name } (only if the game hands us an item).
    local function materialInfo(key)
        if key == nil or type(key) == "number" or type(key) == "string" then return nil end
        if field(key, "typeName") ~= "Obj" then return nil end
        local materialName, materialId = field(key, "name"), field(key, "id")
        if type(materialName) ~= "string" or materialName == "" or type(materialId) ~= "number" then return nil end
        Recipes.barNames[string.lower(materialName)] = true
        return { id = materialId, name = materialName }
    end
    for _, enumName in ipairs({ "SMITHING_MATERIAL_TO_ITEM_DBROW", "SMELTING_MATERIAL_TO_ITEM_DBROW" }) do
        local kind = (string.sub(enumName, 1, 8) == "SMELTING") and "smelted" or "smithed"
        local en = nil
        pcall(function() en = config.Enum[enumName] end)
        local count = field(en, "valueCount")
        local list = field(en, "values")
        if type(count) == "number" and list ~= nil then
            for i = 1, Recipes.listCount(count, 100, enumName) do
                local pair = valueAt(list, i)
                local row = nil
                if pair ~= nil then row = valueAt(pair, 2) end
                local material = nil
                if pair ~= nil then material = materialInfo(valueAt(pair, 1)) end
                local columns = nil
                if row ~= nil then columns = field(row, "columnCount") end
                if type(columns) == "number" then
                    for c = 1, math.min(columns, 30) do
                        local okT, types = pcall(function() return row:GetColumnValueTypes(c) end)
                        local okN, n = pcall(function() return row:GetColumnValueCount(c) end)
                        if okT and types ~= nil and okN and type(n) == "number" and n > 0 and n <= 10 then
                            local bad = false
                            for k = 1, n do
                                if BAD_TYPES[tostring(valueAt(types, k))] then bad = true end
                            end
                            local values = nil
                            if not bad then
                                local okV, v = pcall(function() return row:GetColumnValues(c) end)
                                if okV then values = v end
                            end
                            if values ~= nil then
                                for k = 1, n do
                                    local v = valueAt(values, k)
                                    if v ~= nil and field(v, "typeName") == "Enum" then indexEnum(v, material, kind) end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

-- A plain list of items that says where they are made (Exceptions.stationLists): every item in it goes into the set (Recipes.smithed / smelted).
local function markList(enumName, set)
    local en = nil
    pcall(function() en = config.Enum[enumName] end)
    local entries, count = field(en, "values"), field(en, "valueCount")
    if entries == nil or type(count) ~= "number" then return end
    for e = 1, Recipes.listCount(count, 3000, enumName) do
        local entry = valueAt(entries, e)
        local obj = nil
        if entry ~= nil then obj = valueAt(entry, 2) end
        local name = nil
        if field(obj, "typeName") == "Obj" then name = field(obj, "name") end
        if type(name) == "string" and name ~= "" then set[string.lower(name)] = true end
    end
end

local function readStationLists()
    local L = Exceptions.stationLists or {}
    for _, enumName in ipairs(L.smithed or {}) do markList(enumName, Recipes.smithed) end
    for _, enumName in ipairs(L.smelted or {}) do markList(enumName, Recipes.smelted) end
    for _, enumName in ipairs(Exceptions.exchangeSetLists or {}) do markList(enumName, Recipes.gameSets) end
end

local prepared = false
function Recipes.prepare()
    if prepared then return end
    prepared = true
    pcall(learnSkills)
    Recipes.fillSkills(skillNames)
    pcall(buildSmithingIndex)
    pcall(readStationLists)
    pcall(Recipes.readToolbelt)
end

end }
