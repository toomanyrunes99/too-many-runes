-- Too Many Runes - Recipes: facts added by the developer
-- A few things the game's own data does not say (as far as the surveys could tell) were checked in the game by the developer and typed in:
-- which altar a rune is made at, and from what; how the six basic dyes are made; that the halberds and some moulds are bought; that an
-- armour set is exchanged for at the Grand Exchange. They are kept in recipes/exceptions.lua (playerFacts), each tagged source = "player", and
-- they are shown on the Recipe tab like any other recipe. The game always comes first: nothing here is used for an item the game already
-- says how to get.
-- (Moved over from the old plugin almost unchanged; recipes/compat.lua explains how it fits the new one.)
return { run = function(II)
local _ENV = II

-- The facts, or an empty table when the hand-written facts are switched off (USE_PLAYER_FACTS in settings.lua).
local function facts()
    if USE_PLAYER_FACTS == false then return {} end
    return Exceptions.playerFacts or {}
end

Recipes.playerFacts = facts -- (the other recipe files read the facts through this)

-- Is this item (by name) one the developer said is being removed from the game? Nothing then mentions it (see playerFacts.removed).
local removedSet, removedFrom = nil, nil
function Recipes.isRemoved(name)
    if type(name) ~= "string" then return false end
    local F = facts().removed
    if F == nil then return false end
    if removedSet == nil or removedFrom ~= F then
        removedSet, removedFrom = {}, F
        for _, n in ipairs(F.names or {}) do removedSet[string.lower(n)] = true end
    end
    return removedSet[string.lower(name)] == true
end

-- What the ritual window shows for a ritual (durability, light sources, every glyph), from the hand-written facts: nil if the ritual is not
-- listed there. The glyphs come as { name, count, id }.
function Recipes.ritualFacts(name)
    local F = facts().rituals
    if F == nil or type(name) ~= "string" then return nil end
    local entry = (F.byName or {})[string.lower(name)]
    if entry == nil then return nil end
    local glyphs = {}
    for _, g in ipairs(entry.glyphs or {}) do glyphs[#glyphs + 1] = { name = g[1], count = g[2], id = g[3] } end
    return { durability = entry.durability, light = entry.light, glyphs = glyphs, site = entry.site }
end

-- The water source fact as { set = { [lower container name] = true }, label =, sprite =, minimum = }, or nil (see playerFacts.water).
local waterSet, waterFrom = nil, nil
function Recipes.waterFact()
    local F = facts().water
    if F == nil then return nil end
    if waterSet == nil or waterFrom ~= F then
        waterSet, waterFrom = {}, F
        for _, n in ipairs(F.containers or {}) do waterSet[string.lower(n)] = true end
    end
    return { set = waterSet, label = F.label, sprite = F.sprite, minimum = F.minimum or 2 }
end

-- What the game itself says is filled at a water source: its list WATERSOURCE_FILL_TABLE (7053; the sinks survey found it: Vial of
-- water, Jug of water, Cup of water, Bowl of water, Watering can (8), Waterskin (4), Fishbowl, Juju vial of water, Dream vial (water), Golden bowl,
-- Bucket of water, Full kettle ...). Returns { names = { [lower name] = true }, ids = { item numbers }, count }; read once.
local fillTable, fillTries = nil, 0
function Recipes.waterFillTable()
    if fillTable ~= nil then return fillTable end
    local T = { names = {}, ids = {}, count = 0 }
    local en = nil
    pcall(function() en = config.Enum["WATERSOURCE_FILL_TABLE"] end)
    local entries, count = field(en, "values"), field(en, "valueCount")
    if entries ~= nil and type(count) == "number" then
        for e = 1, Recipes.listCount(count, 200, "WATERSOURCE_FILL_TABLE") do
            local entry = valueAt(entries, e)
            local obj = (entry ~= nil) and valueAt(entry, 2) or nil
            local name, id_ = field(obj, "name"), field(obj, "id")
            if type(name) == "string" and name ~= "" and type(id_) == "number" then
                T.names[string.lower(name)] = true
                T.ids[#T.ids + 1] = id_
                T.count = T.count + 1
            end
        end
    end
    fillTries = fillTries + 1
    if T.count > 0 or fillTries >= 3 then fillTable = T end -- (a list that cannot be read is tried again a few times, then left empty)
    return T
end

-- A container filled at a water source: { emptyId, emptyName } of its empty container ({} when the item list has none of the names the
-- hand-written fact gives,
-- or the fact gives none), or nil if the item is not filled at a water source. It is filled at one when the game's own list says so
-- (WATERSOURCE_FILL_TABLE,
-- by name: the copies of an item share its name) or the hand-written fact does (playerFacts.water.filled, which also names the empty containers).
function Recipes.waterFilled(lowerName)
    local W = facts().water
    if W == nil or W.filled == nil or type(lowerName) ~= "string" then return nil end
    local list = (W.filled.byName or {})[lowerName]
    if list == nil and Recipes.waterFillTable().names[lowerName] ~= true then return nil end
    for _, emptyName in ipairs(list or {}) do
        local emptyId, found = findByName(string.lower(emptyName))
        if emptyId ~= nil then return { emptyId = emptyId, emptyName = found } end
    end
    return { }
end

-- The station row ("Made at: Water source", the water picture, a click searches @water) for a filled container the game gives a recipe of its own
-- (Bucket of water: Cooking level 1 and a bucket): the recipe has no word on the water source, that is the hand-written fact. Or nil.
function Recipes.waterStationRows(lowerName)
    local W = facts().water
    if W == nil or W.filled == nil or Recipes.waterFilled(lowerName) == nil then return nil end
    return { { text = W.filled.madeAt .. W.label, sprite = W.sprite, query = "@water" } }
end

-- The numbers of every item filled at a water source (all the copies of the names above), for the @water search of the ones that have no material.
function Recipes.waterCandidates()
    local out = {}
    for slot = 1, #itemIds do
        if Recipes.waterFilled(itemLower[slot]) ~= nil then out[#out + 1] = itemIds[slot] end
    end
    return out
end

-- Does another item with exactly this name have recipe settings of its own in the game's data?
function Recipes.twinHasGameRecipe(itemId, lowerName)
    local slots = Recipes.slotsOf and Recipes.slotsOf(lowerName) or nil
    for _, slot in ipairs(slots or {}) do
        local other = itemIds[slot]
        if other ~= itemId then
            local obj = nil
            pcall(function() obj = config.Obj.FromID(other) end)
            if obj ~= nil and #fieldList(obj, "RECIPE_") > 0 then return true end
        end
    end
    return false
end

-- Does the item with this number have a Uses list of its own (playerFacts.usesByNumber)? lowerName: the ingredient's name (lower case).
function Recipes.usesOwn(lowerName, itemId)
    local F = facts().usesByNumber
    local list = F and type(lowerName) == "string" and (F.byName or {})[lowerName] or nil
    if list == nil or type(itemId) ~= "number" then return false end
    for _, n in ipairs(list) do
        if n == itemId then return true end
    end
    return false
end

-- One line for the console: how many items each of those Uses lists holds (a 0 for a number means no recipe in the game's data names it).
function Recipes.usesOwnReport()
    local F = facts().usesByNumber
    if F == nil then return end
    local U = Recipes.usedState
    local function size(key)
        local n = 0
        for _ in pairs(U.by[key] or {}) do n = n + 1 end
        return n
    end
    local names = {}
    for lower in pairs(F.byName or {}) do names[#names + 1] = lower end
    table.sort(names)
    for _, lower in ipairs(names) do
        local parts = {}
        for _, n in ipairs(F.byName[lower]) do parts[#parts + 1] = "number " .. n .. ": " .. size(lower .. "#" .. n) end
        detail("Too Many Runes: Uses of " .. lower .. " by item number: " .. table.concat(parts, ", ") .. "; every other " .. lower .. ": " .. size(lower))
    end
end

-- For the Uses lists: the name of the bar that is folded on the anvil to make this one (or nil).
function Recipes.playerFoldUse(lowerName)
    local FO = facts().folding
    local fold = FO and type(lowerName) == "string" and (FO.byName or {})[lowerName] or nil
    return fold ~= nil and fold.from or nil
end

-- For the Uses lists: the name of the empty container a filled one is made from (or nil).
function Recipes.playerWaterUse(lowerName)
    local filled = Recipes.waterFilled(lowerName)
    return filled ~= nil and filled.emptyName or nil
end

-- One line for the console: which filled containers were found in the item list and which empty container each is made from, and the names
-- that were not found (so a wrong guess at a name shows at once).
function Recipes.waterReport()
    local W = facts().water
    if W == nil or W.filled == nil then return end
    local made, missing = {}, {}
    local names = {}
    for lower in pairs(W.filled.byName or {}) do names[#names + 1] = lower end
    table.sort(names)
    for _, lower in ipairs(names) do
        local id, name = findByName(lower)
        if id == nil then
            missing[#missing + 1] = lower .. " (filled item)"
        else
            local filled = Recipes.waterFilled(lower)
            if filled.emptyId == nil then
                missing[#missing + 1] = table.concat(W.filled.byName[lower], " / ") .. " (empty container of " .. name .. ")"
            else
                made[#made + 1] = name .. " <- " .. filled.emptyName
            end
        end
    end
    -- (and the game's own list: how many entries it has, and the names it has that the hand-written fact does not)
    local T = Recipes.waterFillTable()
    local gameOnly = {}
    for lower in pairs(T.names) do
        if (W.filled.byName or {})[lower] == nil then gameOnly[#gameOnly + 1] = lower end
    end
    table.sort(gameOnly)
    detail("Too Many Runes: the game's WATERSOURCE_FILL_TABLE has " .. T.count .. " entries (" .. #gameOnly .. " names the hand-written fact does not have"
        .. ((#gameOnly > 0) and (": " .. table.concat(gameOnly, ", ")) or "") .. ")")
    local line = "Too Many Runes: made at a water source: " .. (#made > 0 and table.concat(made, ", ") or "none")
        .. ((#missing > 0) and ("; not found in the item list: " .. table.concat(missing, ", ")) or "")
    -- (a name that was not found is always told: it needs a different name in recipes/exceptions.lua)
    if #missing > 0 then print(line) else detail(line) end
end

-- ----- the rune altars (read from the game) -----
-- Called for each data row named RUNECRAFTING_ALTAR_* (see Recipes.rowsRow in guides.lua). Column 2 holds the altar's name ("Fire Altar");
-- some versions of the data keep it in column 1, so that is tried too. Files the altar under the word before "altar" ("fire").
function Recipes.altarRow(R, row, firstValue)
    local altar = firstValue(2)
    if type(altar) ~= "string" or altar == "" then altar = firstValue(1) end
    if type(altar) ~= "string" or altar == "" then return end
    local F = facts().runes
    local tail = (F and F.altarSuffix) or " altar"
    local lower = string.lower(altar)
    if string.sub(lower, -#tail) ~= tail then return end
    local word = string.sub(lower, 1, -#tail - 1)
    if word ~= "" and R.altars[word] == nil then
        R.altars[word] = altar
        R.altarCount = R.altarCount + 1
    end
end

-- Is this item a rune the hand-written fact covers? Returns the altar's name and the skill-guide entry, or nil.
-- (It must be in the Runecrafting skill guide: that is the game saying the item is made by Runecrafting.)
local function runeOf(itemId, lowerName)
    local F = facts().runes
    if F == nil or type(lowerName) ~= "string" then return nil end
    if string.sub(lowerName, -#F.suffix) ~= F.suffix then return nil end
    local altar = Recipes.rowsState.altars[string.sub(lowerName, 1, -#F.suffix - 1)]
    if altar == nil then return nil end
    local g = Recipes.guideMap[itemId]
    if g == nil or g.stat == nil then return nil end
    local skill = skillNames[g.stat]
    if type(skill) ~= "string" or string.sub(skill, 1, 9) ~= "RUNECRAFT" then return nil end
    return altar, g
end

-- Is this item an imbued eternal magic staff, wand or orb (playerFacts.imbued)? Returns the fact, or nil.
local function imbuedOf(lowerName)
    local F = facts().imbued
    if F == nil or type(lowerName) ~= "string" then return nil end
    if string.sub(lowerName, 1, #F.prefix) ~= F.prefix then return nil end
    for _, kind in ipairs(F.kinds) do
        if string.sub(lowerName, #F.prefix + 1, #F.prefix + #kind + 2) == kind .. " (" then return F end
    end
    return nil
end

-- The steps of the imbuing chain, read from the game's own data once (the list RUNECRAFTING_WEAPON_ID_TO_OBJ and the "next stage" and
-- "progress required" settings of every Eternal magic staff / wand / orb; Exceptions.imbuing): chain.from[itemId] = { id, name, progress,
-- byEssence }, the item it is made from, the progress it takes to reach this item (this item's OWN progress setting) and whether the step
-- is an imbuing with essence (the tier before is "imbuable"; the step after the saturated tier is not). Empty when the game does not hand
-- the data over.
local imbueChain = nil
local function imbueChainOf()
    if imbueChain ~= nil then return imbueChain end
    if #itemLower == 0 then return { from = {} } end -- (the item list is not built yet: ask again later)
    imbueChain = { from = {} }
    local E = Exceptions.imbuing
    if E == nil or facts().imbued == nil then return imbueChain end
    pcall(function()
        local en, pNext, pProgress, pImbuable = config.Enum[E.list], config.Param[E.nextStage], config.Param[E.progress], config.Param[E.imbuable]
        local entries, count = field(en, "values"), field(en, "valueCount")
        if entries == nil or type(count) ~= "number" or pNext == nil then return end
        local itemOfKey = {}
        for e = 1, Recipes.listCount(count, 200, E.list) do
            local entry = valueAt(entries, e)
            local key, item = valueAt(entry, 1), valueAt(entry, 2)
            if key ~= nil and field(item, "typeName") == "Obj" then itemOfKey[key] = field(item, "id") end
        end
        -- the progress a tier's own settings ask for (what it takes to reach that tier from the one before)
        local function progressOf(obj)
            if pProgress == nil or obj == nil or not Recipes.usedHas(obj, pProgress) then return nil end
            local okP, v = pcall(function() return obj:GetParamValue(pProgress) end)
            if okP and type(v) == "number" and v > 0 then return v end
            return nil
        end
        for idx = 1, #itemLower do
            if imbuedOf(itemLower[idx]) ~= nil then
                local obj = nil
                pcall(function() obj = config.Obj.FromID(itemIds[idx]) end)
                if obj ~= nil and Recipes.usedHas(obj, pNext) then
                    local okN, key = pcall(function() return obj:GetParamValue(pNext) end)
                    local target = okN and itemOfKey[key] or nil
                    if target ~= nil and target ~= itemIds[idx] then
                        local targetObj = nil
                        pcall(function() targetObj = config.Obj.FromID(target) end)
                        -- is the step from this tier an imbuing with essence? (the tier carries the "imbuable" setting; when the game does not
                        -- hand that setting over, every step is taken to be one)
                        local byEssence = true
                        if pImbuable ~= nil then
                            byEssence = false
                            if Recipes.usedHas(obj, pImbuable) then
                                local okI, v = pcall(function() return obj:GetParamValue(pImbuable) end)
                                byEssence = okI and isTrue(v)
                            end
                        end
                        imbueChain.from[target] = { id = itemIds[idx], name = itemNames[idx], progress = progressOf(targetObj), byEssence = byEssence }
                    end
                end
            end
        end
    end)
    return imbueChain
end

-- The item an Eternal magic staff / wand / orb is made from, by the game's own data: { id, name, progress, byEssence } or nil.
function Recipes.imbueFrom(itemId)
    return imbueChainOf().from[itemId]
end

-- The picture rows of the essences a rune is made from: { { id, name } ... } (an essence the item list does not have is left out).
local function essencesOf(F, lowerRune)
    local list = {}
    local word = (type(lowerRune) == "string") and string.sub(lowerRune, 1, -#F.suffix - 1) or nil
    local names = (word ~= nil and (F.impureRunes or {})[word]) and (F.impureEssences or F.essences) or F.essences
    for _, name in ipairs(names) do
        local id, found = findByName(string.lower(name))
        if id ~= nil then list[#list + 1] = { id = id, name = found } end
    end
    return list
end

-- What the hand-written facts say about this item, for an item the game gives no way to make or get: nil, or
--   { fact = "runes" | "bought" | "sets", sources = { entries for Recipes.parse } or nil, wear = { text lines } or nil }
-- "sources" are shown as the recipe; "wear" are lines that go with a toolbelt tool's note. gameWords is true when the game itself has
-- words on how the item is got (the toolbelt's text, or a skill guide's text): the game's words come first, so nothing is added then.
function Recipes.playerFact(itemId, itemObj, gameWords)
    if gameWords then return nil end
    local all = facts()
    local name = field(itemObj, "name")
    if type(name) ~= "string" or name == "" then return nil end
    local lower = string.lower(name)

    -- a rune: made at the altar of the same name, from Pure or Impure essence
    local altar = runeOf(itemId, lower)
    if altar ~= nil then
        local F = all.runes
        local sources = { { lines = Recipes.guideLines(F.madeAt .. altar), sprite = "altar" } }
        local essences = essencesOf(F, lower)
        for i, e in ipairs(essences) do
            sources[#sources + 1] = { label = (i == 1) and ((#essences > 1) and F.essenceLabel or "Materials:") or nil, name = e.name, id = e.id }
        end
        return { fact = "runes", sources = sources }
    end

    -- an imbued eternal magic staff, wand or orb: any Runecrafting altar, with Pure or Rune essence
    local imbued = imbuedOf(lower)
    local from = imbued ~= nil and Recipes.imbueFrom(itemId) or nil
    local chainKnown = imbued ~= nil and next(imbueChainOf().from) ~= nil
    if imbued ~= nil and from ~= nil and from.byEssence == false then
        -- the step after the saturated tier is not an imbuing with essence (the game calls those tiers "sacrificable"; what it asks for is not known)
        return { fact = "imbued", sources = { { label = "Made from:", name = from.name, id = from.id } } }
    elseif imbued ~= nil and from == nil and chainKnown then
        -- no step of the game's chain leads to this item (the inert ones): nothing is known about how it is got
    elseif imbued ~= nil then
        local sources = { { lines = { imbued.madeAt }, sprite = "altar" } }
        local found = {}
        for _, essenceName in ipairs(imbued.essences) do
            local id, name2 = findByName(string.lower(essenceName))
            if id ~= nil then found[#found + 1] = { id = id, name = name2 } end
        end
        -- the tier it is imbued from, and the progress that takes (the game's data; nothing when the game has no step before this item)
        if from ~= nil then
            local lines = nil
            if from.progress ~= nil then
                lines = { "Progress needed: " .. formatNumber(from.progress) }
                local per = imbued.progressPerEssence -- (a hand-written fact: how much progress one essence gives)
                if type(per) == "number" and per > 0 then
                    local count = math.ceil(from.progress / per)
                    local exact = (count * per == from.progress)
                    lines[2] = "Essence needed: " .. (exact and "" or "about ") .. formatNumber(count)
                end
            end
            sources[#sources + 1] = { label = "Imbued from:", name = from.name, id = from.id, lines = lines }
        end
        for i, e in ipairs(found) do
            sources[#sources + 1] = { label = (i == 1) and ((#found > 1) and imbued.essenceLabel or "Materials:") or nil, name = e.name, id = e.id }
        end
        return { fact = "imbued", sources = sources }
    end

    -- a basic dye: made at Aggie, or in the inventory from two other dyes (the game's data has no recipe for any of them)
    local D = all.dyes
    local dye = D and (D.byName or {})[lower] or nil
    if dye ~= nil then
        local atAggie = (dye.at == "aggie")
        local sources = {}
        if dye.at ~= nil then sources[1] = { lines = { atAggie and (D.madeAt .. D.aggie) or D.inventoryLine } } end
        if dye.needs ~= nil then sources[#sources + 1] = { lines = { dye.needs } } end
        -- one way to make it (the list itself), or several (dye.alternatives, each its own list)
        for g, mats in ipairs(dye.alternatives or { dye }) do
            for i, m in ipairs(mats) do
                local id, found = findByName(string.lower(m[2]))
                local label = nil
                if i == 1 then label = atAggie and D.materialsLabel or ((g == 1) and D.togetherLabel or D.orTogetherLabel) end
                sources[#sources + 1] = { label = label, name = formatNumber(m[1]) .. " x " .. (found or m[2]), id = id }
            end
        end
        return { fact = "dyes", sources = sources }
    end

    -- a bar made by folding another bar on the anvil (the Glorious bar: playerFacts.folding)
    local FO = all.folding
    local fold = FO and (FO.byName or {})[lower] or nil
    if fold ~= nil then
        local sources = { { lines = { FO.madeAt .. FO.station }, sprite = FO.sprite } }
        local fromId, fromName = findByName(string.lower(fold.from))
        if fromId ~= nil then
            sources[#sources + 1] = { label = FO.useLabel, name = "1 x " .. fromName, id = fromId, note = string.format(FO.progressLabel, formatNumber(fold.folds)) }
        end
        return { fact = "folding", sources = sources }
    end

    -- a container filled with water: made at a water source (fountain, well, sink) from the empty container
    -- (not when another item of that name has a recipe in the game's data: the game comes first, and this one is its plain copy, see copies.lua)
    local filled = Recipes.waterFilled(lower)
    if filled ~= nil and not Recipes.twinHasGameRecipe(itemId, lower) then
        local W = all.water
        local sources = { { lines = { W.filled.madeAt .. W.label }, sprite = W.sprite } }
        if filled.emptyId ~= nil then
            sources[#sources + 1] = { label = W.filled.materialsLabel, name = "1 x " .. filled.emptyName, id = filled.emptyId }
        end
        return { fact = "water", sources = sources }
    end

    local B = all.bought
    if B ~= nil then
        -- a halberd
        for _, halberd in ipairs(B.halberds) do
            if lower == halberd then return { fact = "bought", sources = { { lines = Recipes.guideLines(B.text) } } } end
        end
        -- a mould kept on the toolbelt (the game has no words of its own for it: that case returned above)
        if string.sub(lower, -#B.mouldSuffix) == B.mouldSuffix and Recipes.onToolbelt(itemObj) then
            return { fact = "bought", wear = Recipes.guideLines(B.text) }
        end
    end

    -- an armour set sold on the Grand Exchange: one of the game's own item sets (its list EXCHANGE_ITEM_SETS), or a Grand Exchange item
    -- with "armour set" in its name
    local S = all.sets
    if S ~= nil and isTrue(field(itemObj, "isStockmarket")) then
        local isSet = Recipes.gameSets[lower] == true
        for _, word in ipairs(S.words) do
            if string.find(lower, word, 1, true) then isSet = true end
        end
        if isSet then return { fact = "sets", sources = { { lines = Recipes.guideLines(S.text) } } } end
    end

    -- what the forge hands over (see recipes/stations.lua)
    return Recipes.stationItemFact(lower)
end

-- For the Uses lists: the rune an item is, if it is one the hand-written fact covers. Returns { essences = { names }, stat, level } or nil.
-- (Pure essence and Impure essence are "used to make" each such rune.)
function Recipes.playerRuneUse(itemId, lowerName)
    local altar, g = runeOf(itemId, lowerName)
    if altar == nil then return nil end
    local names = {}
    for _, e in ipairs(essencesOf(facts().runes, lowerName)) do names[#names + 1] = e.name end
    return { essences = names, stat = g.stat, level = g.level }
end

-- For the Uses lists: the names of the essences an imbued eternal magic item is made with (or nil).
function Recipes.playerImbueUse(lowerName, itemId)
    local F = imbuedOf(lowerName)
    if F == nil then return nil end
    if itemId ~= nil then -- (only an item an essence imbuing makes: not the inert ones nor the step after the saturated tier)
        local from = Recipes.imbueFrom(itemId)
        if (from ~= nil and from.byEssence == false) or (from == nil and next(imbueChainOf().from) ~= nil) then return nil end
    end
    return F.essences
end

-- For the Uses lists: the names of the items a basic dye is made from, if the item is one the hand-written dye fact covers (or nil).
function Recipes.playerDyeUse(lowerName)
    local D = facts().dyes
    local dye = D and type(lowerName) == "string" and (D.byName or {})[lowerName] or nil
    if dye == nil then return nil end
    local names = {}
    for _, mats in ipairs(dye.alternatives or { dye }) do
        for _, m in ipairs(mats) do names[#names + 1] = m[2] end
    end
    return names
end

-- CHIMES: items the Arc's traders buy for chimes (a currency). Told by the developer: an item sells for its base value divided by 10 chimes
-- (shark soup 850 -> 85, a mushroom 20 -> 2, golden bamboo 30 -> 3). Which items sell for chimes comes from the game (chimes survey, round 3):
-- the Wushanko items carry the setting ELR1_RESOURCE (88 items: mushrooms, golden bamboo, berries ...) or ELR1_COMMODITY (11 items: shark soup,
-- fish oil ...). The game's list ELR1_COMMODITY_SELLPRICE_INCREASE (10, 11, 12) looks like the price in percent of the base value for the three
-- upgrade levels, so a player with an upgrade may get a little more than shown here. Not every resource has been checked in the game.
-- Returns the text added after the base value, e.g. "  (85 chimes)", or "" for any other item (and for one worth less than 1 chime).
function Recipes.chimeText(item)
    if USE_PLAYER_FACTS == false then return "" end
    local ok, text = pcall(function()
        if #fieldList(item, "ELR1_RESOURCE") == 0 and #fieldList(item, "ELR1_COMMODITY") == 0 then return "" end
        local cost = field(item, "cost")
        if type(cost) ~= "number" then return "" end
        local chimes = cost // 10
        if chimes < 1 then return "" end
        return "  (" .. chimes .. ((chimes == 1) and " chime)" or " chimes)")
    end)
    if ok and type(text) == "string" then return text end
    return ""
end

end }
