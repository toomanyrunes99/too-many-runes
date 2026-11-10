-- Too Many Runes - Recipes: where an item is made (the crafting station)
-- Adds the "Made at:" rows to a recipe. Which items the furnace makes, and which the forge and anvil make, is read from the game's own
-- smelting and smithing lists (see recipes/reading.lua); the NAMES of the stations, and what the forge hands over, are facts the developer
-- supplied (recipes/exceptions.lua, playerFacts.stations, tagged source = "player"). The rows look like any other row of the recipe.
-- (Moved over from the old plugin almost unchanged; recipes/compat.lua explains how it fits the new one.)
return { run = function(II)
local _ENV = II

local function facts()
    if USE_PLAYER_FACTS == false then return nil end
    return Recipes.playerFacts().stations
end

-- The game's number for a skill (learned from the skill guides, see learnSkills in reading.lua), or nil. word: "SMITHING", "COOKING" ...
local skillNumbers = {}
local function skillNumberOf(word)
    local known = skillNumbers[word]
    if known ~= nil then return known or nil end
    if next(skillNames) == nil then return nil end -- (the skills are not learned yet: ask again later)
    skillNumbers[word] = false
    for n, name in pairs(skillNames) do
        if type(n) == "number" and type(name) == "string" and string.upper(name) == word then skillNumbers[word] = n end
    end
    return skillNumbers[word] or nil
end

Recipes.skillNumberOf = skillNumberOf -- (the search by skill uses it for the rituals, recipes/uses.lua)

-- Does the recipe need this skill (its number), or give XP in it?
local function usesSkill(fields, s)
    if s == nil then return false end
    for n = 1, 6 do
        if getField(fields, "RECIPE_REQUIREMENT_TYPE_" .. n) == s then return true end
    end
    for n = 1, 3 do
        if getField(fields, "RECIPE_XP_TYPE_" .. n) == s then return true end
    end
    return false
end

local function usesSmithing(fields)
    return usesSkill(fields, skillNumberOf("SMITHING"))
end

-- ----- the game's cooking tables -----
-- Cooking has its own lists in the game: COOKING_OVEN_TABLES (a list of lists, one per kind of food: what a range cooks) and
-- COOKING_FIRE_TABLES (the same for a bonfire), found by the survey cookingtables. Each inner list holds the finished foods.
-- A food in an oven list only is cooked at a range; in a fire list too, at a range or a bonfire. (The mixing, churning and drinks lists are
-- not read: they are made in the inventory.) Which lists are read is in Exceptions.cookingLists; nothing here is a guess from names.
local cookingTable = nil
local cookingTries = 0

-- Every item under a list: an item is added, a list inside the list is read too (depth limited, each list once). A list inside a list is
-- only a reference to it, so that one is fetched by its number.
local function collectProducts(en, into, seen, depth)
    local listId = field(en, "id") or en
    if en == nil or seen[listId] or depth > 3 then return end
    seen[listId] = true
    local entries, count = field(en, "values"), field(en, "valueCount")
    if entries == nil or type(count) ~= "number" then return end
    for e = 1, count do
        local entry = valueAt(entries, e)
        local value = valueAt(entry, 2)
        if value ~= nil and type(value) ~= "number" and type(value) ~= "string" then
            local id = field(value, "id")
            if field(value, "typeName") == "Enum" then
                local inner = nil
                if type(id) == "number" then pcall(function() inner = config.Enum.FromID(id) end) end
                collectProducts(inner, into, seen, depth + 1)
            elseif type(id) == "number" and field(value, "typeName") ~= "Struct" then -- (a struct has a number of its own: not an item)
                into[id] = true
            end
        end
    end
end

-- { oven = { [itemId] = true }, fire = { ... }, ready = true }, read once (nil when the game would not hand the lists over).
function Recipes.cookingTables()
    if cookingTable ~= nil then return cookingTable end
    if cookingTries >= 3 then return nil end
    cookingTries = cookingTries + 1
    local L = Exceptions.cookingLists or {}
    local T = { oven = {}, fire = {}, ready = true }
    for kind, names in pairs({ oven = L.oven or {}, fire = L.fire or {} }) do
        for _, name in ipairs(names) do
            local root = nil
            pcall(function() root = config.Enum[name] end)
            collectProducts(root, T[kind], {}, 0)
        end
    end
    local both, ovenOnly, fireOnly = 0, 0, 0
    for id in pairs(T.oven) do if T.fire[id] then both = both + 1 else ovenOnly = ovenOnly + 1 end end
    for id in pairs(T.fire) do if not T.oven[id] then fireOnly = fireOnly + 1 end end
    if both + ovenOnly + fireOnly == 0 then return nil end -- (nothing read: try again the next time)
    T.counts = { both = both, ovenOnly = ovenOnly, fireOnly = fireOnly }
    cookingTable = T
    detail("Too Many Runes: cooking tables read (" .. (both + ovenOnly + fireOnly) .. " foods: " .. ovenOnly .. " at a range only, "
        .. both .. " at a range or a bonfire, " .. fireOnly .. " at a bonfire only)")
    return T
end

-- Where is this item cooked? The words for it (playerFacts.stations.cooking), or nil when it is in neither table.
local function cookingPlace(F, itemId)
    local C = F.cooking
    if type(C) ~= "table" or type(itemId) ~= "number" then return nil end
    local T = Recipes.cookingTables()
    if T == nil then return nil end
    local oven, fire = T.oven[itemId], T.fire[itemId]
    if oven and fire then return C.both end
    if oven then return C.range end
    if fire then return C.fire end
    return nil
end

-- The rows for an item made at the furnace.
local function furnaceRows(F)
    return { kind = "furnace", fact = "stations", rows = { { text = F.madeAt .. F.furnace, sprite = "furnace" } } }
end

-- The rows for an item made at the forge and finished at the anvil. In between the forge hands over the "Unfinished smithing item" (shown
-- with its picture, so it can be clicked, when the item list has one by that name).
local function forgeRows(F, itemObj)
    -- (the forge has no picture of its own: the developer asked for the furnace's)
    local rows = { { text = F.madeAt .. F.forge, sprite = "furnace", query = "@forge" } }
    if type(F.unfinished) == "string" then
        local id, name = findByName(string.lower(F.unfinished))
        if id ~= nil then rows[#rows + 1] = { text = F.becomes .. name, icon = id } end
    end
    -- (burial armour and weapons are finished at the burial anvil: the item's own SMITHING_BURIAL_ITEM setting - 3.0.92)
    local burial = type(F.burialAnvil) == "string" and isTrue(getField(fieldList(itemObj, "SMITHING_BURIAL_ITEM"), "SMITHING_BURIAL_ITEM"))
    rows[#rows + 1] = { text = F.finishedAt .. (burial and F.burialAnvil or F.anvil), sprite = "anvil" }
    return { kind = "forge", fact = "stations", rows = rows }
end

-- Does the recipe use the Invention skill, or an Invention material (the game's stand-in item "Invention material")? Those are made at the
-- Inventor's workbench (from the developer, 2026-10-29; the name of the station is a hand-written fact, the test is the game's own data).
local function isInventionRecipe(fields)
    if usesSkill(fields, skillNumberOf("INVENTION")) then return true end
    for n = 1, 10 do
        local obj = getField(fields, "RECIPE_INGREDIENT_TYPE_" .. n)
        if obj ~= nil and field(obj, "name") == "Invention material" then return true end
    end
    return false
end

-- The row for an item made at the Inventor's workbench (its map icon beside the words; a click searches for what is made there).
local function inventionRows(F)
    return { kind = "inventor", fact = "stations", rows = { { text = F.madeAt .. F.inventor, sprite = "inventor", query = "@invention" } } }
end

-- Is the item an Archaeology artefact restored at the workbench? The game keeps one data row per artefact (ARCH_RESTORATION_<name>, read in
-- guides.lua): column 6 the damaged item, column 7 the restored one, column 5 the Archaeology level.
function Recipes.restorationOf(itemId)
    return Recipes.rowsState.restoredOf[itemId]
end

local function isRestoration(itemId)
    return Recipes.restorationOf(itemId) ~= nil
end

-- The row for an item restored at the Archaeologist's workbench.
local function restorationRows(F)
    return { kind = "archaeologist", fact = "stations", rows = { { text = F.madeAt .. F.archaeologist, sprite = "archaeologist", query = "@archaeology" } } }
end

-- The rows for a cooked food: the range, or the range or the bonfire (the game's cooking range picture beside the words).
local function cookingRows(F, place)
    -- (a click on the row searches for the range's foods; a food that can also be cooked on a bonfire is found under @bonfire too)
    local C = F.cooking or {}
    local query, also = "@range", nil
    if place == C.fire then query = "@bonfire"
    elseif place == C.both then also = { "bonfire" } end
    return { kind = "cooking", fact = "stations", rows = { { text = F.madeAt .. place, sprite = "range", query = query, also = also } } }
end

-- ----- the benches (sawmill, spinning wheel, pottery, fletching workbench ...) -----
-- The game keeps a list of the items for most of them (Exceptions.benchLists): read once, the lists inside the lists too.
local benchTable = nil
local benchTries = 0
local BENCH_ORDER = { "sawmill", "spinning", "pottery", "oven", "fletchbench", "loom", -- (an item in two lists belongs to the first)
                      -- (3.0.68)
                      "furniture", "obelisk", "dunganvil", "dungfurnace", "dungspinning", "dungaltar", "pedestal", "portbench", "portanvil",
                      "scrimshaw", "soulforge", "tailoring", "lectern", "singingbowl", "brewery", "ritualsite", "elemental", "dragonkin",
                      "tanner", "churn", "cradle",
                      -- (3.0.70: the small stations)
                      "clockmaker", "robustglass", "sandpit", "compost", "blessaltar", "naturealtar", "soupstation", "applebarrel", "stump",
                      "colossus", "dungglyph", "elemfurnace", "doricanvil", "doricfurnace", "eternaltree", "jadfirepit", "pigmachine",
                      "airobelisk", "waterobelisk", "earthobelisk", "fireobelisk",
                      -- (3.0.93)
                      "drafting", "trough", "jalarast", "botanist" }
Recipes.BENCH_ORDER = BENCH_ORDER -- (the search words: core/query.lua)

-- Both sides of a list's entries that are items (Exceptions.benchKeyLists: lists whose keys are items too).
local function collectKeysAndValues(en, into)
    local entries, count = field(en, "values"), field(en, "valueCount")
    if entries == nil or type(count) ~= "number" then return end
    for e = 1, math.min(count, 5000) do
        local entry = valueAt(entries, e)
        for side = 1, 2 do
            local v = valueAt(entry, side)
            if v ~= nil and type(v) ~= "number" and type(v) ~= "string" and field(v, "typeName") == "Obj" then
                local id = field(v, "id")
                if type(id) == "number" then into[id] = true end
            end
        end
    end
end

-- { sawmill = { [itemId] = true }, ... }, or nil when the game would not hand the lists over.
function Recipes.benchTables()
    if benchTable ~= nil then return benchTable end
    if benchTries >= 3 then return nil end
    benchTries = benchTries + 1
    local T, total, counts = {}, 0, {}
    -- (the lists found by the start of their names: Exceptions.benchListPrefixes)
    local byPrefix = {}
    if next(Exceptions.benchListPrefixes or {}) ~= nil then
        local all = idNames("Enum")
        for key, prefixes in pairs(Exceptions.benchListPrefixes) do
            byPrefix[key] = {}
            for _, e in ipairs(all) do
                for _, pre in ipairs(prefixes) do
                    if string.sub(e.name, 1, #pre) == pre then byPrefix[key][#byPrefix[key] + 1] = e.name; break end
                end
            end
        end
    end
    for key, listed in pairs(Exceptions.benchLists or {}) do
        local set, n = {}, 0
        local names = {}
        for _, name in ipairs(listed) do names[#names + 1] = name end
        for _, name in ipairs(byPrefix[key] or {}) do names[#names + 1] = name end
        for _, name in ipairs(names) do
            local root = nil
            pcall(function() root = config.Enum[name] end)
            collectProducts(root, set, {}, 0)
        end
        for _ in pairs(set) do n = n + 1 end
        T[key] = set
        total = total + n
        counts[#counts + 1] = key .. " " .. n
    end
    for key, names in pairs(Exceptions.benchKeyLists or {}) do
        local set, n = T[key] or {}, 0
        for _, name in ipairs(names) do
            local root = nil
            pcall(function() root = config.Enum[name] end)
            collectKeysAndValues(root, set)
        end
        for _ in pairs(set) do n = n + 1 end
        T[key] = set
        total = total + n
        counts[#counts + 1] = key .. " " .. n
    end
    if total == 0 then return nil end -- (nothing read: try again the next time)
    table.sort(counts)
    benchTable = T
    detail("Too Many Runes: bench lists read (" .. table.concat(counts, ", ") .. ")")
    return T
end

-- Which bench makes this item? A key of playerFacts.stations.benches, or nil. lower: the item's name in lower case.
function Recipes.benchOf(F, itemId, lower, fields)
    local B = F.benches
    if type(B) ~= "table" then return nil end
    local T = Recipes.benchTables()
    local rowSets = Recipes.rowsState and Recipes.rowsState.rowBench or {} -- (the stations kept in data rows: recipes/guides.lua)
    if T ~= nil or next(rowSets) ~= nil then
        for _, key in ipairs(BENCH_ORDER) do
            if ((T ~= nil and T[key] ~= nil and T[key][itemId]) or (rowSets[key] ~= nil and rowSets[key][itemId])) and B[key] ~= nil then
                -- (some items on a bench's list are not made there, e.g. the masterwork bow's sapphire chains / grip supports)
                local skip = false
                for _, word in ipairs((type(B.exclude) == "table" and B.exclude[key]) or {}) do
                    if string.find(lower, word, 1, true) then skip = true end
                end
                if not skip then return key end
            end
        end
    end
    if B.loom ~= nil and type(B.loomItems) == "table" then
        for _, name in ipairs(B.loomItems) do
            if lower == name then return "loom" end
        end
    end
    if B.woodworking ~= nil and type(B.frameWord) == "string" and string.find(lower, B.frameWord, 1, true)
       and usesSkill(fields, skillNumberOf("CONSTRUCTION")) then
        return "woodworking"
    end
    return nil
end

-- Every item that might be made at a bench, for the search by station: the benches' lists, the restored artefacts, the loom's items and the
-- items with the frame word in their name (the recipe check one by one in uses.lua only visits names that some recipe makes). A list of item numbers.
function Recipes.benchCandidates()
    local list, seen = {}, {}
    local function add(id)
        if type(id) == "number" and not seen[id] then
            seen[id] = true
            list[#list + 1] = id
        end
    end
    local F = facts()
    if F == nil or type(F.benches) ~= "table" then return list end
    for _, set in pairs(Recipes.benchTables() or {}) do
        for id in pairs(set) do add(id) end
    end
    for _, set in pairs(Recipes.rowsState.rowBench or {}) do
        for id in pairs(set) do add(id) end
    end
    for id in pairs(Recipes.rowsState.restoredOf) do add(id) end
    for _, name in ipairs(F.benches.loomItems or {}) do
        for _, slot in ipairs(Recipes.slotsOf and Recipes.slotsOf(name) or {}) do add(itemIds[slot]) end
    end
    local word = F.benches.frameWord
    if type(word) == "string" then
        for k = 1, #itemIds do
            if string.find(itemLower[k], word, 1, true) then add(itemIds[k]) end
        end
    end
    table.sort(list)
    return list
end

-- The row for an item made at a bench (its picture beside the words; a click searches for what is made there).
local function benchRows(F, key)
    local B = F.benches[key]
    return { kind = key, fact = "stations", rows = { { text = (B.by and "Made by: " or F.madeAt) .. B.name, sprite = B.sprite, query = "@" .. key } } }
end

-- An item that is on a bench's list but has no recipe in the game's data: just where it is made (so that it still shows, and is found by the
-- bench's search). Returns the "sources" for Recipes.parse, or nil.
function Recipes.benchOnly(itemId, itemObj)
    local F = facts()
    if F == nil then return nil end
    local name = field(itemObj, "name")
    if type(name) ~= "string" then return nil end
    local key = Recipes.benchOf(F, itemId, string.lower(name), {})
    if key == nil then return nil end
    local B = F.benches[key]
    return { fact = "stations", kind = key, sources = { { lines = { (B.by and "Made by: " or F.madeAt) .. B.name }, sprite = B.sprite, query = "@" .. key } } }
end

-- The recipe of a restored artefact: the damaged item it is restored from and the Archaeology level (as the fields a recipe has), or nil.
function Recipes.restorationRecipe(itemId)
    local r = Recipes.restorationOf(itemId)
    if r == nil then return nil end
    local sources = nil
    if r.from ~= nil and type(r.fromName) == "string" then sources = { { label = "Restored from:", name = r.fromName, id = r.from } } end
    local arch = skillNumberOf("ARCHAEOLOGY")
    return { sources = sources, skill = arch, level = r.level }
end

-- Where is this item made? Returns nil, or { kind = "furnace" | "forge" | "cooking", fact = "stations", rows = { { text, icon } ... } } for
-- the recipe's rows. "fields" are the item's RECIPE_ settings (the smithing screen's copy of the item, for a smithed one).
-- The order matters: what the smelting lists make is the furnace's; then what the smithing screen makes is the forge's; then a bar (a metal
-- the smithing and smelting lists file products under) whose recipe needs Smithing is the furnace's; last, a food the game's cooking
-- tables list is cooked at the range (or the range or the bonfire); last of all, a recipe that uses Invention (the skill, or an Invention
-- material) is made at the Inventor's workbench; after that an Archaeology recipe is restored at the Archaeologist's workbench.
function Recipes.stationFor(itemId, itemObj, fields)
    local F = facts()
    if F == nil then return nil end
    local name = field(itemObj, "name")
    if type(name) ~= "string" or name == "" then return nil end
    local lower = string.lower(name)
    if Recipes.smelted[lower] then return furnaceRows(F) end
    if Recipes.smithed[lower] then return forgeRows(F, itemObj) end
    if Recipes.barNames[lower] and usesSmithing(fields) then return furnaceRows(F) end
    local place = cookingPlace(F, itemId)
    if place ~= nil then return cookingRows(F, place) end
    if type(F.inventor) == "string" and isInventionRecipe(fields) then return inventionRows(F) end
    if type(F.archaeologist) == "string" and isRestoration(itemId) then return restorationRows(F) end
    local bench = Recipes.benchOf(F, itemId, lower, fields)
    if bench ~= nil then return benchRows(F, bench) end
    return nil
end

-- ----- the stations' pictures -----
-- A row with  sprite = "furnace"  gets the furnace's map icon beside its words (ui/details.lua asks Recipes.stationSprite). The sprite
-- numbers are read from the game: a background pass looks through config.MapElement for the elements named in Exceptions.stationIcons.
Recipes.stationSprites = {}
Recipes.stationScan = { pos = 0, done = false, found = 0, wanted = 0 }
function Recipes.stationSprite(key)
    return Recipes.stationSprites[key]
end

local MAP_ELEMENT_LIMIT = 8000 -- the numbered search for map elements gives up here (and says which pictures it did not find)
function Recipes.stationIconStep()
    local S = Recipes.stationScan
    if S.done or not linkState.ready then return end -- (starts after the item links, so the passes do not compete)
    if S.byName == nil then
        local names = {} -- (a copy: a station that has its picture from a list is taken out)
        for key, configName in pairs(Exceptions.stationIcons or {}) do names[key] = configName end
        S.byName = {}
        -- the pictures the developer picked by number (Exceptions.stationSpriteNumbers) come first
        for key, sprite in pairs(Exceptions.stationSpriteNumbers or {}) do
            if type(sprite) == "number" then
                Recipes.stationSprites[key] = sprite
                S.picked = (S.picked or 0) + 1
                names[key] = nil
            end
        end
        -- a picture the game lists itself (the world map key's lists, Exceptions.stationIconLists): the list's first entry is the current
        -- style picture (the second is the old one). Read now; a station whose list cannot be read falls back to its map element's name.
        for key, listName in pairs(Exceptions.stationIconLists or {}) do
            local en, sprite = nil, nil
            pcall(function() en = config.Enum[listName] end)
            if en ~= nil then sprite = valueAt(valueAt(field(en, "values"), 1), 2) end
            if type(sprite) == "number" and sprite >= 0 then
                Recipes.stationSprites[key] = sprite
                S.fromList = (S.fromList or 0) + 1
                names[key] = nil
            end
        end
        for key, configName in pairs(names) do
            S.byName[configName] = key
            S.wanted = S.wanted + 1
        end
        -- the map elements are asked for by name first; only those the game does not hand over by name are looked for one number at a time
        for configName, key in pairs(S.byName) do
            local el = nil
            pcall(function() el = config.MapElement[configName] end)
            local sprite = field(el, "spriteID")
            if type(sprite) == "number" and sprite >= 0 then
                Recipes.stationSprites[key] = sprite
                S.found = S.found + 1
                S.byName[configName] = nil
            end
        end
    end
    if next(S.byName) ~= nil then
        local last = S.pos + Scan.full(250) - 1
        for n = S.pos, last do
            local el = nil
            pcall(function() el = config.MapElement.FromID(n) end)
            if el ~= nil then
                S.seen = n
                local key = S.byName[field(el, "configName")]
                local sprite = field(el, "spriteID")
                if key ~= nil and type(sprite) == "number" and sprite >= 0 and Recipes.stationSprites[key] == nil then
                    Recipes.stationSprites[key] = sprite
                    S.found = S.found + 1
                end
            end
        end
        S.pos = last + 1
    end
    if S.found >= S.wanted or S.pos > MAP_ELEMENT_LIMIT then
        S.done = true
        for configName, key in pairs(S.byName) do
            if Recipes.stationSprites[key] == nil then
                print("Too Many Runes: no map icon " .. configName .. " was found for the " .. key .. " picture (looked at map element numbers up to " .. MAP_ELEMENT_LIMIT .. ")")
            end
        end
        local list = {}
        for key, sprite in pairs(Recipes.stationSprites) do list[#list + 1] = key .. "=" .. sprite end
        table.sort(list)
        detail("Too Many Runes: station pictures read from the game's map icons: " .. S.found .. " of " .. S.wanted .. " and " .. (S.fromList or 0) .. " from the map key's lists (" .. table.concat(list, ", ") .. ")")
        if Recipes.onDataReady then pcall(Recipes.onDataReady) end
    end
end
Passes.add("station pictures", Recipes.stationIconStep, function() return Recipes.stationScan.done end, function()
    Recipes.stationScan.done = true
end)

-- The "Unfinished smithing item" itself: what the forge makes it from, what it keeps and where it is finished.
-- Used by Recipes.playerFact (player.lua) for an item the game gives no way to make. lowerName: the item's name in lower case.
function Recipes.stationItemFact(lowerName)
    local F = facts()
    if F == nil or type(F.unfinished) ~= "string" or lowerName ~= string.lower(F.unfinished) then return nil end
    local lines = { F.madeAt .. F.forge, F.holdsLabel }
    for _, held in ipairs(F.holds) do lines[#lines + 1] = "  " .. held end
    -- (two entries: the anvil's picture belongs to the last row only)
    return { fact = "stations", sources = { { lines = lines, sprite = "furnace" }, { lines = { F.finishedAt .. F.anvil }, sprite = "anvil" } } }
end

-- BENCH NAMES FROM THE GAME (3.1.15): Exceptions.benchNamesFromGame. A background pass goes through the game's list of scenery names a
-- few thousand a tick, then reads the found ones' names.
local benchNames = { done = false }
Passes.add("bench names", function()
    if benchNames.run == nil then
        local words = Exceptions.benchNamesFromGame or {}
        local found = {}
        benchNames.found = found
        benchNames.run = coroutine.wrap(function()
            local n = 0
            for k, v in pairs(id.Loc) do
                local name, num = k, v
                if type(k) ~= "string" then name, num = v, k end
                if type(name) == "string" and type(num) == "number" then
                    local upper = string.upper(name)
                    for key, parts in pairs(words) do
                        local all = true
                        for _, part in ipairs(parts) do if not string.find(upper, part, 1, true) then all = false; break end end
                        if all then
                            local list = found[key] or {}
                            found[key] = list
                            if #list < 40 then list[#list + 1] = num end
                        end
                    end
                end
                n = n + 1
                if n % 4000 == 0 then coroutine.yield(false) end
            end
            return true
        end)
        return
    end
    if not benchNames.run() then return end
    local benches = Exceptions.playerFacts and Exceptions.playerFacts.stations and Exceptions.playerFacts.stations.benches or {}
    for key in pairs(Exceptions.benchNamesFromGame or {}) do
        local counts, best, bestN = {}, nil, 0
        for _, num in ipairs(benchNames.found[key] or {}) do
            local nm = field(try(function() return config.Loc.FromID(num) end), "name")
            if type(nm) == "string" then nm = (string.gsub(nm, "<[^>]*>", "")) end
            if type(nm) == "string" and nm ~= "" and string.lower(nm) ~= "null" then
                counts[nm] = (counts[nm] or 0) + 1
                if counts[nm] > bestN then best, bestN = nm, counts[nm] end
            end
        end
        local B = benches[key]
        if B ~= nil and best ~= nil then
            detail("Too Many Runes: the " .. key .. " bench's name from the game: " .. best)
            B.name = best
        elseif B ~= nil then
            detail("Too Many Runes: the game has no name for the " .. key .. " bench; it stays \"" .. tostring(B.name) .. "\"") -- (3.1.33: not in the log any more - the developer)
        end
    end
    benchNames.done = true
end, function() return benchNames.done end, function() benchNames.done = true end)

end }
