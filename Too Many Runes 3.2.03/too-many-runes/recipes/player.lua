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
-- ITEMS AN NPC MAKES (Exceptions.npcMade): item number -> { by = "patchy" | "furshop", mats = { { amount, item number, name }, ... } },
-- read from the game's lists once. (Not a typed-in fact: the items and materials are the game's; only the words and pictures are not.)
local npcTable, npcTries = nil, 0
local function listPairs(name)
    local en = nil
    pcall(function() en = config.Enum[name] end)
    local entries, count = field(en, "values"), field(en, "valueCount")
    local out = {}
    if entries == nil or type(count) ~= "number" then return out end
    for e = 1, math.min(count, 2000) do
        local entry = valueAt(entries, e)
        if entry ~= nil then out[#out + 1] = { valueAt(entry, 1), valueAt(entry, 2) } end
    end
    return out
end
local function objOf(v)
    if v == nil or type(v) == "number" or type(v) == "string" or type(v) == "boolean" then return nil end
    if field(v, "typeName") ~= "Obj" then return nil end
    local id = field(v, "id")
    if type(id) ~= "number" then return nil end
    local name = field(v, "name")
    return id, (type(name) == "string" and name ~= "") and name or ("item " .. id)
end
function Recipes.npcMadeTable()
    if npcTable ~= nil then return npcTable end
    if npcTries >= 3 then return {} end -- (the game handed nothing over three times: no such items)
    npcTries = npcTries + 1
    local T = {}
    local N = Exceptions.npcMade or {}
    local P = N.patchy
    if P ~= nil then
        for _, listName in ipairs(P.lists or {}) do
            for _, kv in ipairs(listPairs(listName)) do
                local id = objOf(kv[2])
                if id ~= nil and T[id] == nil then
                    local mats = {}
                    for _, e in ipairs(fieldList(try(config.Obj.FromID, id), P.prefix)) do
                        local mid, mname = objOf(e.value)
                        if mid ~= nil then mats[#mats + 1] = { 1, mid, mname, sort = e.name } end
                    end
                    table.sort(mats, function(a, b) return a.sort < b.sort end)
                    if #mats > 0 then T[id] = { by = "patchy", mats = mats } end
                end
            end
        end
    end
    local F = N.furshop
    if F ~= nil then
        local counts, second = {}, {}
        for _, kv in ipairs(listPairs(F.quantity)) do
            local id = objOf(kv[1])
            if id ~= nil and type(kv[2]) == "number" then counts[id] = kv[2] end
        end
        for _, kv in ipairs(listPairs(F.material2)) do
            local id = objOf(kv[1])
            local mid, mname = objOf(kv[2])
            if id ~= nil and mid ~= nil then second[id] = { 1, mid, mname } end
        end
        for _, kv in ipairs(listPairs(F.material)) do
            local id = objOf(kv[1])
            local mid, mname = objOf(kv[2])
            if id ~= nil and mid ~= nil and T[id] == nil then
                local mats = { { counts[id] or 1, mid, mname } }
                if second[id] ~= nil then mats[2] = second[id] end
                T[id] = { by = "furshop", mats = mats }
            end
        end
    end
    local n = 0
    for _ in pairs(T) do n = n + 1 end
    if n > 0 then
        npcTable = T
        detail("Too Many Runes: items made by an NPC read (" .. n .. ": Patchy and the fur shop)")
    end -- (nothing read: try again the next time, up to three times)
    return T
end
-- The materials' names of an item an NPC makes (for the Uses lists), or nil.
function Recipes.npcMadeUse(itemId)
    local e = Recipes.npcMadeTable()[itemId]
    if e == nil then return nil end
    local names = {}
    for _, m in ipairs(e.mats) do names[#names + 1] = m[3] end
    return names
end

-- A creature's binding contract (playerFacts.bindingContracts): returns the creature's name as the item's name gives it, or nil.
function Recipes.bindingContractOf(itemObj)
    local C = facts().bindingContracts
    local name = field(itemObj, "name")
    if C == nil or type(name) ~= "string" then return nil end
    if string.sub(string.lower(name), 1, #C.prefix) ~= C.prefix then return nil end
    return string.match(name, "%((.+)%)%s*$")
end

-- A god's piece of anima core armour (playerFacts.animaCrests): { dormant = {id, name}, crest = {id, name} }, or nil. (lower: the item's name)
local function realItem(lower) -- (of the items with this name: a tradeable one first, then any that is not a noted copy)
    local best = nil
    for _, slot in ipairs(Recipes.slotsOf(lower) or {}) do
        if (Items.flags[slot] or 0) & Items.NOTED == 0 then
            local obj = try(config.Obj.FromID, itemIds[slot])
            local tradeable = field(obj, "isTradeable") == true or field(obj, "isTradeable") == 1
            if tradeable then return itemIds[slot], itemNames[slot] end
            if best == nil then best = slot end
        end
    end
    if best ~= nil then return itemIds[best], itemNames[best] end
    return nil
end
function Recipes.animaCrestOf(lower)
    local C = facts().animaCrests
    if C == nil or type(lower) ~= "string" then return nil end
    local piece, god = string.match(lower, C.pattern)
    if piece == nil then return nil end
    local dId, dName = realItem(string.format(C.dormant, piece))
    local cId, cName = realItem(string.format(C.crest, god))
    if dId == nil or cId == nil then return nil end
    return { dormant = { id = dId, name = dName }, crest = { id = cId, name = cName } }
end

function Recipes.playerFact(itemId, itemObj, gameWords)
    -- a creature's binding contract: defeat the creature with a plain contract in the backpack (this comes before anything else)
    local creature = Recipes.bindingContractOf(itemObj)
    if creature ~= nil then
        local C = facts().bindingContracts
        local id, found = findByName(string.lower(C.material))
        local article = string.find(string.lower(creature), "^[aeiou]") and "an " or "a "
        return { fact = "bindingContracts", sources = { { lines = { string.format(C.line, article .. creature) } },
                                                        { label = "Materials:", name = "1 x " .. (found or C.material), id = id } } }
    end
    if gameWords then return nil end
    -- an item an NPC makes from materials the game lists (Patchy, the fur shop)
    local npc = Recipes.npcMadeTable()[itemId]
    if npc ~= nil then
        local spec = (Exceptions.npcMade or {})[npc.by] or {}
        local sources = { { lines = { spec.line }, sprite = spec.sprite } }
        for i, m in ipairs(npc.mats) do
            sources[#sources + 1] = { label = (i == 1) and "Materials:" or nil, name = formatNumber(m[1]) .. " x " .. m[3], id = m[2] }
        end
        return { fact = "npc", sources = sources }
    end
    local all = facts()
    local name = field(itemObj, "name")
    if type(name) ~= "string" or name == "" then return nil end
    local lower = string.lower(name)

    -- a god's piece of anima core armour: the dormant piece and the god's crest, in the backpack
    local anima = Recipes.animaCrestOf(lower)
    if anima ~= nil then
        return { fact = "animaCrests", sources = { { lines = { all.animaCrests.line } },
            { label = "Materials:", name = "1 x " .. anima.dormant.name, id = anima.dormant.id },
            { name = "1 x " .. anima.crest.name, id = anima.crest.id } } }
    end

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

    -- an energy: converted at an energy rift from the memories of the same kind (it is harvested from the wisps too: its Source tab)
    local energy = Recipes.energyRecipe(itemId, lower)
    if energy ~= nil then return energy end

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
        -- (Aggie's picture, a click lists her dyes; the others: the backpack's picture and @backpack)
        if dye.at ~= nil then
            sources[1] = atAggie and { lines = { D.madeAt .. D.aggie }, sprite = "aggie", query = "@aggie" }
                         or { lines = { D.inventoryLine }, sprite = "backpack", query = "@backpack" }
        end
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

-- ENERGY AND MEMORIES (playerFacts.energy): "pale energy" <-> "pale memory" and "enriched pale memory" (only the ones the game has).
-- Several items share each name. The real Divination memories have the debug names DIV_MEMORY12 and, enriched, DIV_MEMORY_SUPER4 (EDIV_ for
-- Elder); the RAND_DIVINATION_... ones are Dungeoneering's. So: Dungeoneering's are left out (RAND_, or on the RuneScape Wiki's list of
-- Dungeoneering items), and of the rest the one whose debug name fits is taken (want), else a tradeable one, else the first that is not
-- noted.
local function isDung(slot)
    return slot ~= nil and (Items.is(slot, Items.DUNG) or string.sub(Items.debug[slot] or "", 1, 5) == "rand_")
end
local function realOutsideDung(lower, want)
    -- (not while the item list is still loading: Recipes.slotsOf would build its list of every name again each time the list has grown -
    -- with an energy open at a reload, that would be every refresh. Nothing is kept from before the list is complete, so it is asked
    -- again.)
    if not Items.loaded then return nil end
    local first, tradeable = nil, nil
    for _, slot in ipairs(Recipes.slotsOf(lower) or {}) do
        if not Items.is(slot, Items.NOTED) and not isDung(slot) then
            if want ~= nil and string.find(Items.debug[slot] or "", want) then return itemIds[slot], itemNames[slot] end
            if tradeable == nil then
                local obj = try(config.Obj.FromID, itemIds[slot])
                if field(obj, "isTradeable") == true or field(obj, "isTradeable") == 1 then tradeable = slot end
            end
            if first == nil then first = slot end
        end
    end
    local best = tradeable or first
    if best ~= nil then return itemIds[best], itemNames[best] end
    return nil
end
-- The memories of an energy, as { id, name } (nil if it is no energy, a Dungeoneering one, or has none). itemId: the energy's number.
function Recipes.memoriesOfEnergy(lowerName, itemId)
    local F = facts().energy
    if F == nil or type(lowerName) ~= "string" or string.sub(lowerName, -#F.suffix) ~= F.suffix then return nil end
    if itemId ~= nil and isDung(Items.slotOf[itemId]) then return nil end
    local word = string.sub(lowerName, 1, -#F.suffix - 1)
    local list = {}
    local kinds = { { word .. F.memorySuffix, F.memoryDebug }, { F.enrichedPrefix .. word .. F.memorySuffix, F.enrichedDebug } }
    for _, kind in ipairs(kinds) do
        local id, name = realOutsideDung(kind[1], kind[2])
        if id ~= nil then list[#list + 1] = { id = id, name = name } end
    end
    return (#list > 0) and list or nil
end
-- The energy a memory is converted into (its item number), or nil (a Dungeoneering memory: nil). itemId: the memory's number.
function Recipes.energyOfMemory(lowerName, itemId)
    local F = facts().energy
    if F == nil or type(lowerName) ~= "string" or string.sub(lowerName, -#F.memorySuffix) ~= F.memorySuffix then return nil end
    if itemId ~= nil and isDung(Items.slotOf[itemId]) then return nil end
    local word = string.sub(lowerName, 1, -#F.memorySuffix - 1)
    if string.sub(word, 1, #F.enrichedPrefix) == F.enrichedPrefix then word = string.sub(word, #F.enrichedPrefix + 1) end
    return (realOutsideDung(word .. F.suffix, F.energyDebug))
end
-- The energy's conversion at an energy rift, as a recipe { fact, sources } (nil if it is no energy). Shown as the recipe of an energy the
-- game gives none, and under the game's own recipe of one it does give one (Brilliant energy from Remnant energy: recipes/get.lua).
function Recipes.energyRecipe(itemId, lower)
    local memories = Recipes.memoriesOfEnergy(lower, itemId)
    if memories == nil then return nil end
    local F = facts().energy
    local sources = { { lines = { F.madeAt }, sprite = "rift", query = F.station and ("@" .. F.station) or nil } }
    for i, m in ipairs(memories) do
        sources[#sources + 1] = { label = (i == 1) and ((#memories > 1) and F.memoryLabel or "Materials:") or nil, name = m.name, id = m.id }
    end
    return { fact = "energy", sources = sources }
end
-- A Dungeoneering energy or memory (RAND_..., or on the wiki's Dungeoneering list): the real one of the same name, which its Recipe tab
-- points at instead of a recipe. Returns { id, name } or nil.
function Recipes.dungTwinOf(itemId, lower)
    local F = facts().energy
    if F == nil or type(lower) ~= "string" or not isDung(Items.slotOf[itemId]) then return nil end
    local want = nil
    if string.sub(lower, -#F.suffix) == F.suffix then want = F.energyDebug
    elseif string.sub(lower, -#F.memorySuffix) ~= F.memorySuffix then return nil
    elseif string.sub(lower, 1, #F.enrichedPrefix) == F.enrichedPrefix then want = F.enrichedDebug
    else want = F.memoryDebug end
    local id, name = realOutsideDung(lower, want)
    if id == nil then return nil end
    return { id = id, name = name }
end
-- The station words the hand-written facts add to the search ("energy-rift": core/query.lua knows it as a station).
Recipes.factStations = { aggie = true } -- (@aggie, the dyes she makes)
if (facts().energy or {}).station ~= nil then Recipes.factStations[facts().energy.station] = true end
-- For the Uses lists: the names of the memories an energy is converted from (or nil).
function Recipes.playerEnergyUse(lowerName, itemId)
    local list = Recipes.memoriesOfEnergy(lowerName, itemId)
    if list == nil then return nil end
    local names = {}
    for _, m in ipairs(list) do names[#names + 1] = m.name end
    return names
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

end }
