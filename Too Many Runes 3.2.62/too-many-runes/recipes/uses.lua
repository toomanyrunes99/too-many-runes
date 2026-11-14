-- Too Many Runes - Uses: what an item is used to make
-- The background pass that works out the Uses tab, and the pages it shows.
-- (Moved over from the old plugin almost unchanged; recipes/compat.lua explains how it fits the new one.)
return { run = function(T)
local _ENV = T

----- "used to make": what each item is an ingredient of -----
-- The recipes read the other way round: the bowstring lists every bow, a bar lists everything smithed from it.
-- One background pass asks every item about its ingredient settings (found by name, like the link settings), then the
-- other places that join one item to another are added: the upgrade links, the rituals, the by-name rules above.
-- Everything is filed under the ingredient's NAME (so a noted or copied version of an item finds the same list).
-- The names (lower case) of the items some recipe makes, filled in by usedAdd below: the "Craftable" filter (recipes/uses_tab.lua) reads it.
Recipes.craftableNames, Recipes.craftableCount = {}, 0
Recipes.usedState = { ready = false, started = false, phase = "scan", position = 1, by = {}, lists = {}, count = 0, perTick = 150 }

-- Does this item have this setting? (Asked only about the settings found by name.)
function Recipes.usedHas(obj, p)
    if p == nil then return false end
    local ok, has = pcall(function() return obj:HasParam(p) end)
    return ok and has == true
end

-- The ingredient settings, found by name (a missing one stays nil and is skipped).
function Recipes.usedParams()
    local P = { type = {}, multiple = {}, extra = {} }
    for n = 1, 10 do
        pcall(function() P.type[n] = config.Param["RECIPE_INGREDIENT_TYPE_" .. n] end)
        pcall(function() P.extra[n] = config.Param["RECIPE_INGREDIENT_EXTRA_INFO_" .. n] end)
    end
    for n = 1, 6 do pcall(function() P.multiple[n] = config.Param["RECIPE_INGREDIENT_" .. n .. "_MULTIPLE"] end) end
    pcall(function() P.reqType = config.Param["RECIPE_REQUIREMENT_TYPE_1"] end)
    pcall(function() P.reqValue = config.Param["RECIPE_REQUIREMENT_VALUE_1"] end)
    for _, group in ipairs({ P.type, P.multiple }) do -- (settings the game will not hand to a plugin are left out)
        for n, p in pairs(group) do
            if BAD_TYPES[tostring(field(p, "valueType"))] then group[n] = nil end
        end
    end
    return P
end

-- Remember that productName is made from ingredientName. stat/level (optional): the skill and level that make it.
-- pin = true: the product's number comes from the game's own data for exactly this link (a ritual's output), so that very item is the one
-- that is opened, even if another item has the same name (two items are called "Ectoplasm").
-- ingredientId (optional): the ingredient's own item number, when the game's recipe gives it. An item with a Uses list of its own
-- (playerFacts.usesByNumber: Vial of water 17492, the Dungeoneering one) has that list filed under "<name>#<number>", and the products in
-- it are opened by their own numbers.
function Recipes.usedAdd(ingredientName, productName, productId, stat, level, pin, ingredientId)
    if type(ingredientName) ~= "string" or type(productName) ~= "string" or type(productId) ~= "number" then return end
    if Recipes.isRemoved(ingredientName) or Recipes.isRemoved(productName) then return end -- (being removed from the game)
    local ing, prod = string.lower(ingredientName), string.lower(productName)
    if ing == prod or ing == "metal bank object" or ing == "" then return end
    -- (worn and broken copies would only add noise)
    if string.sub(prod, 1, 7) == "broken " or string.sub(prod, -8) == "(broken)" then return end
    if not Recipes.craftableNames[prod] then
        Recipes.craftableNames[prod] = true
        Recipes.craftableCount = Recipes.craftableCount + 1
    end
    local U = Recipes.usedState
    if ingredientId ~= nil and Recipes.usesOwn(ing, ingredientId) then
        ing = ing .. "#" .. ingredientId
        pin = true
    end
    local set = U.by[ing]
    if set == nil then
        set = {}
        U.by[ing] = set
    end
    local entry = set[prod]
    local isJunk = Filters ~= nil and Filters.isJunk(productId) or false
    if entry == nil then
        entry = { id = productId, name = productName, stat = stat, level = level, pin = pin and productId or nil, junk = isJunk }
        set[prod] = entry
        U.count = U.count + 1
    else
        if not isJunk then entry.junk = false end -- (junk only while every item of that name that is made is junk)
        if productId < entry.id then entry.id = productId end
        if pin and (entry.pin == nil or productId < entry.pin) then entry.pin = productId end
        if entry.level == nil and level ~= nil then entry.stat, entry.level = stat, level end
    end
end

-- The bars a "Metal bank object" slot stands for (the same way the recipe box works them out), as a list of names.
function Recipes.usedBarNames(obj, P, slot, lowerProduct)
    local names = {}
    local key = nil
    if Recipes.usedHas(obj, P.extra[slot]) then pcall(function() key = obj:GetParamValue(P.extra[slot]) end) end
    local bar = Recipes.hopperItem(key)
    if bar ~= nil then
        names[1] = bar.name
    else
        for _, b in ipairs(Recipes.alloyBelow(lowerProduct) or Recipes.materialOf[lowerProduct] or {}) do names[#names + 1] = b.name end
    end
    return names
end

-- Read one item: if it has ingredients, file it under each of them.
function Recipes.usedItem(id, P)
    local obj = nil
    pcall(function() obj = config.Obj.FromID(id) end)
    if obj == nil then return end
    if not (Recipes.usedHas(obj, P.type[1]) or Recipes.usedHas(obj, P.multiple[1])) then return end
    local name = field(obj, "name")
    if type(name) ~= "string" or name == "" then return end
    local lower = string.lower(name)

    local stat, level = nil, nil -- (its main skill and level: the list is put in that order)
    if Recipes.usedHas(obj, P.reqType) and Recipes.usedHas(obj, P.reqValue) then
        local okT, t = pcall(function() return obj:GetParamValue(P.reqType) end)
        local okV, v = pcall(function() return obj:GetParamValue(P.reqValue) end)
        if okT and okV and type(t) == "number" and type(v) == "number" and skillNames[t] ~= nil then stat, level = t, v end
    end

    for n = 1, 10 do
        if Recipes.usedHas(obj, P.type[n]) then
            local ok, v = pcall(function() return obj:GetParamValue(P.type[n]) end)
            if ok and field(v, "typeName") == "Obj" then
                local ingredient = field(v, "name")
                if ingredient == "Metal bank object" then
                    for _, barName in ipairs(Recipes.usedBarNames(obj, P, n, lower)) do
                        Recipes.usedAdd(barName, name, id, stat, level)
                    end
                else
                    Recipes.usedAdd(ingredient, name, id, stat, level, nil, field(v, "id"))
                end
            end
        end
    end
    for n = 1, 6 do
        if Recipes.usedHas(obj, P.multiple[n]) then -- (any one of several items)
            local ok, record = pcall(function() return obj:GetParamValue(P.multiple[n]) end)
            if ok and record ~= nil then
                local entries = fieldList(record, nil)
                -- The list may name the one item it really means (RECIPE_MULTI_OBJECT_OVERRIDE): a bar's list names EVERY ore, and only
                -- its own ore is meant. Then only that one is used - the same rule as the Recipe tab (multiMaterial in recipes/parse.lua),
                -- including its exception: a label naming two or more of the choices with " or " means all of them.
                local choices = {}
                for k = 1, 8 do
                    local o = getField(entries, "RECIPE_INGREDIENT_TYPE_" .. k)
                    if o == nil then break end
                    choices[#choices + 1] = o
                end
                local overrideObj = getField(entries, "RECIPE_MULTI_OBJECT_OVERRIDE")
                local main = nil
                if overrideObj ~= nil then
                    for _, o in ipairs(choices) do
                        if field(o, "id") ~= nil and field(o, "id") == field(overrideObj, "id") then main = o end
                    end
                end
                if main ~= nil then
                    local overrideName = getField(entries, "RECIPE_MULTI_NAME_OVERRIDE")
                    local label = string.lower((type(overrideName) == "string" and overrideName ~= "") and overrideName or tostring(field(main, "name")))
                    local named = 0
                    for _, o in ipairs(choices) do
                        local cn = string.lower(tostring(field(o, "name")))
                        if cn ~= "metal bank object" and string.find(label, cn, 1, true) then named = named + 1 end
                    end
                    if string.find(label, " or ", 1, true) and named >= 2 then main = nil end
                end
                if main ~= nil then choices = { main } end
                for _, o in ipairs(choices) do
                    local ingredient = field(o, "name")
                    if ingredient == "Metal bank object" then
                        for _, b in ipairs(Recipes.alloyBelow(lower) or Recipes.materialOf[lower] or {}) do
                            Recipes.usedAdd(b.name, name, id, stat, level)
                        end
                    else
                        Recipes.usedAdd(ingredient, name, id, stat, level, nil, field(o, "id"))
                    end
                end
            end
        end
    end
end

-- The item's name from its number (or nil).
function Recipes.usedName(itemId)
    local slot = Items.slotOf[itemId]
    if slot == nil then return nil end
    return Items.names[slot]
end

-- The upgrade links ("made from" in the recipe box) read the other way round.
function Recipes.usedFromLinks()
    for newId, list in pairs(links) do
        local productName = Recipes.usedName(newId)
        if productName ~= nil then
            for _, e in ipairs(list) do
                local fromName = Recipes.usedName(e.id)
                if fromName ~= nil then Recipes.usedAdd(fromName, productName, newId) end
                -- a dyed item is also made with its dye (the game's DYE_RESULT_<dye> setting names it): the dye is used to make it
                local _, dyeName = Recipes.dyeOfSetting(e.setting)
                if dyeName ~= nil then Recipes.usedAdd(dyeName, productName, newId) end
                -- an augmented item is also made with an Augmentor
                local _, augName = Recipes.augmentorOf(newId, e.setting)
                if augName ~= nil then Recipes.usedAdd(augName, productName, newId) end
            end
        end
    end
end

-- Furniture plans: the plans "make" the furniture they unlock (listed in the Construction order).
function Recipes.usedFromPlans()
    local stat = nil
    for number, skill in pairs(skillNames) do
        if skill == "CONSTRUCTION" then stat = number end
    end
    for furnitureId, plans in pairs(Recipes.rowsState.plansOf) do
        local furnitureName = plans.furniture
        if type(furnitureName) ~= "string" then furnitureName = Recipes.usedName(furnitureId) end
        Recipes.usedAdd(plans.name, furnitureName, furnitureId, (plans.level ~= nil) and stat or nil, plans.level)
    end
end

-- Rituals: what is put in (and the main glyph) makes what comes out.
function Recipes.usedFromRituals()
    Recipes.ritualsFor(0) -- (builds the ritual table the first time)
    local function fileRitual(r, outId)
        local productName = Recipes.usedName(outId)
        if productName == nil then return end
        if r.input ~= nil then Recipes.usedAdd(r.input.name, productName, outId, nil, nil, true) end
        for _, input in ipairs(r.inputs or {}) do Recipes.usedAdd(input.name, productName, outId, nil, nil, true) end
        if r.glyph ~= nil then Recipes.usedAdd(r.glyph.name, productName, outId, nil, nil, true) end
        local window = Recipes.ritualFacts and Recipes.ritualFacts(r.name) or nil -- (every glyph the ritual window lists: the hand-written facts)
        for _, g in ipairs(window and window.glyphs or {}) do Recipes.usedAdd(g.name, productName, outId, nil, nil, true) end
    end
    for outId, list in pairs(Recipes.ritualMap or {}) do
        for _, r in ipairs(list) do fileRitual(r, outId) end
    end
    for lowerName in pairs(Recipes.ensoulFacts()) do -- (cloth and thread: made in the bar rituals, from other things put in)
        local clothId = findByName(lowerName)
        local family = clothId and Recipes.ensoulFamily(clothId) or nil
        for _, r in ipairs(family or {}) do fileRitual(r, clothId) end
    end
end

-- The by-name rules (custom-fit armour ...) and the hand-written entries.
function Recipes.usedFromNames(first, last)
    for idx = first, last do
        local lower, name, id = Items.lower[idx], Items.names[idx], Items.ids[idx]
        local list = Recipes.madeFromByName(lower, false)
        for _, e in ipairs(list or {}) do
            if e.name ~= nil then Recipes.usedAdd(e.name, name, id) end
        end
    end
end
-- The runes and dyes the hand-written facts cover (recipes/player.lua): Pure essence and Impure essence are used to make each rune; the
-- dyes' materials are used to make the dye.
function Recipes.usedFromPlayer(first, last)
    for idx = first, last do
        local use = Recipes.playerRuneUse(Items.ids[idx], Items.lower[idx])
        if use ~= nil then
            for _, essence in ipairs(use.essences) do Recipes.usedAdd(essence, Items.names[idx], Items.ids[idx], use.stat, use.level) end
        end
        for _, essence in ipairs(Recipes.playerImbueUse(Items.lower[idx], Items.ids[idx]) or {}) do Recipes.usedAdd(essence, Items.names[idx], Items.ids[idx]) end
        local imbuedFrom = Recipes.playerImbueUse(Items.lower[idx]) and Recipes.imbueFrom(Items.ids[idx]) -- (the tier before is made into this one)
        if imbuedFrom ~= nil then Recipes.usedAdd(imbuedFrom.name, Items.names[idx], Items.ids[idx]) end
        for _, memory in ipairs(Recipes.playerEnergyUse(Items.lower[idx], Items.ids[idx]) or {}) do -- (an energy: its memories are converted into it)
            Recipes.usedAdd(memory, Items.names[idx], Items.ids[idx])
        end
        local dyeUse = Recipes.playerDyeUse(Items.lower[idx]) -- (a basic dye: redberries, onions ... and the other dyes are used to make it)
        for _, ingredient in ipairs(dyeUse or {}) do Recipes.usedAdd(ingredient, Items.names[idx], Items.ids[idx]) end
        local foldUse = Recipes.playerFoldUse(Items.lower[idx]) -- (a bar folded on the anvil: the bar that is folded is used to make it)
        if foldUse ~= nil then Recipes.usedAdd(foldUse, Items.names[idx], Items.ids[idx]) end
        local waterUse = Recipes.playerWaterUse(Items.lower[idx]) -- (a container filled at a water source: the empty container is used to make it)
        if waterUse ~= nil then Recipes.usedAdd(waterUse, Items.names[idx], Items.ids[idx]) end
        -- (a flask level the game's potion bundle names: the Potion flask and the potion are used to make it)
        if string.find(Items.lower[idx], " flask %(%d%)$") then
            for _, used in ipairs(Recipes.flaskUses(Items.ids[idx]) or {}) do Recipes.usedAdd(used, Items.names[idx], Items.ids[idx]) end
        end
        -- (a creature's binding contract: the plain Binding contract is used to get it)
        local obj = nil
        if string.sub(Items.lower[idx], 1, 18) == "binding contract (" then
            pcall(function() obj = config.Obj.FromID(Items.ids[idx]) end)
            if Recipes.bindingContractOf(obj) ~= nil then Recipes.usedAdd("Binding contract", Items.names[idx], Items.ids[idx]) end
        end
        -- (a god's anima core piece: the dormant piece and the crest are used to make it - playerFacts.animaCrests)
        if string.sub(Items.lower[idx], 1, 11) == "anima core " then
            local anima = Recipes.animaCrestOf(Items.lower[idx])
            if anima ~= nil then
                Recipes.usedAdd(anima.dormant.name, Items.names[idx], Items.ids[idx])
                Recipes.usedAdd(anima.crest.name, Items.names[idx], Items.ids[idx])
            end
        end
        -- (an item Patchy or the fur shop makes: its materials are used to make it)
        for _, material in ipairs(Recipes.npcMadeUse(Items.ids[idx]) or {}) do Recipes.usedAdd(material, Items.names[idx], Items.ids[idx]) end
    end
end
-- One small step of the background pass (called every game tick once the links, and then the guides, are done).
function Recipes.usedStep()
    local U = Recipes.usedState
    if U.ready or not linkState.ready then return end
    if not U.started then
        -- wait for the skill guides and the furniture plans (so the passes do not compete), but not for more than about 30 seconds
        if U.waitFrom == nil then U.waitFrom = tickCount end
        if not (Recipes.guideReady and Recipes.rowsState.ready) and tickCount - U.waitFrom < 1500 then return end
        U.started = true
        U.startTick = tickCount
        Recipes.prepare()
        U.params = Recipes.usedParams()
        detail("Too Many Runes: finding what each item is used to make (in the background)...")
        return
    end
    if U.phase == "scan" then
        local last = math.min(U.position + Scan.of(U.perTick) - 1, #Items.ids)
        for k = U.position, last do pcall(Recipes.usedItem, Items.ids[k], U.params) end
        U.position = last + 1
        if U.position > #Items.ids then U.phase = "links" end
    elseif U.phase == "links" then
        local ok, err = pcall(Recipes.usedFromLinks)
        if not ok then print("Too Many Runes: could not add the upgrade links to the uses: " .. tostring(err)) end
        pcall(Recipes.usedFromPlans)
        U.phase = "rituals"
    elseif U.phase == "rituals" then
        local ok, err = pcall(Recipes.usedFromRituals)
        if not ok then print("Too Many Runes: could not add the rituals to the uses: " .. tostring(err)) end
        U.phase = "names"
        U.position = 1
    else
        local last = math.min(U.position + Scan.of(4000) - 1, #Items.ids)
        pcall(Recipes.usedFromNames, U.position, last)
        pcall(Recipes.usedFromPlayer, U.position, last)
        U.position = last + 1
        if U.position > #Items.ids then
            U.ready = true
            local ingredients = 0
            for _ in pairs(U.by) do ingredients = ingredients + 1 end
            pcall(Recipes.waterReport)
            pcall(Recipes.usesOwnReport)
            detail("Too Many Runes: item uses ready (" .. ingredients .. " items are used to make others, " .. U.count .. " links, in about "
                .. math.floor((tickCount - U.startTick) / 50) .. " seconds).")
            if Recipes.onDataReady then pcall(Recipes.onDataReady) end
        end
    end
end
Passes.add("item uses", Recipes.usedStep, function() return Recipes.usedState.ready end, function() Recipes.usedState.failed = true end)

-- --- which items really have a recipe -----
-- The names above say that SOME item of that name is made. The Craftable filter wants this very item: so once the uses are known, every
-- item whose name is on the list is asked for its own Recipe tab, and counts only if that shows something it is made from (a material, an
-- item it is upgraded from, a ritual's input). A stool with no recipe beside a stool that is built, a smithed tool the game lists with no
-- bars, a plain item with only wear requirements: not craftable. (A potion's other levels are added by the filter, see
-- Filters.buildFamilies.)
-- The search by skill and by station (the @ search words) is built from the same answers: every item that shows a recipe is entered here.
Recipes.skillIndex = {}   -- item number -> { [skill number] = level } (0: the recipe only gives experience in that skill)
Recipes.stationIndex = {} -- station word ("furnace", "forge", "anvil", "range", "bonfire", "altar", "ritual", "invention", "archaeology",
                          -- "sawmill", "woodworking", "spinning", "loom", "pottery", "oven", "fletchbench", and the kinds of Invention
                          -- material, "clear-parts") -> { [item number] = true }
local function indexStation(key, id)
    local set = Recipes.stationIndex[key]
    if set == nil then
        set = {}
        Recipes.stationIndex[key] = set
    end
    set[id] = true
end
function Recipes.indexItem(id, data)
    local skills = nil
    if data.skills ~= nil then
        skills = {}
        for s, level in pairs(data.skills) do skills[s] = level end
    end
    -- the stations: every row of the recipe that a click turns into a search is one (rows.also: the station words besides the row's own)
    for _, row in ipairs(data.rows or {}) do
        if row.query ~= nil and not row.noIndex then
            indexStation(string.sub(row.query, 2), id)
            for _, key in ipairs(row.also or {}) do indexStation(key, id) end
        end
    end
    -- a Necromancy ritual: the ritual site, and the ritual's skill and level
    local rituals = Recipes.ritualsFor(id)
    if rituals ~= nil then
        indexStation("ritual", id)
        for _, r in ipairs(rituals) do
            local s = (type(r.skill) == "string") and Recipes.skillNumberOf(string.upper(r.skill)) or nil
            if s ~= nil and type(r.level) == "number" then
                skills = skills or {}
                if skills[s] == nil or skills[s] == 0 or r.level < skills[s] then skills[s] = r.level end
            end
        end
    end
    if skills ~= nil then Recipes.skillIndex[id] = skills end
end

Recipes.craftableIds = {}
Recipes.craftState = { ready = false, position = 1, count = 0, perTick = 4000, asks = 30 }
function Recipes.craftableStep()
    local C = Recipes.craftState
    if C.ready or not Recipes.usedState.ready then return end
    if C.startTick == nil then C.startTick = tickCount end
    local names = Recipes.craftableNames
    local asked = 0
    local last = math.min(C.position + Scan.of(C.perTick) - 1, #Items.ids)
    local k = C.position
    while k <= last and asked < Scan.of(C.asks) do
        if names[Items.lower[k]] then
            asked = asked + 1
            local id = Items.ids[k]
            local obj = nil
            pcall(function() obj = config.Obj.FromID(id) end)
            local ok, data = pcall(Recipes.getBase, id, obj)
            if ok and data ~= nil and (data.ingredients or 0) > 0 then
                pcall(Recipes.indexItem, id, data)
                if not Recipes.craftableIds[id] then
                    Recipes.craftableIds[id] = true
                    C.count = C.count + 1
                end
            else
                C.dropped = (C.dropped or 0) + 1 -- (its name is made by some recipe, but this item shows nothing it is made from)
                if C.dropped <= 40 then C.sample = (C.sample or "") .. ((C.sample and ", ") or "") .. tostring(Items.names[k]) .. "#" .. id end
            end
        end
        k = k + 1
    end
    C.position = k
    if C.position > #Items.ids then
        C.ready = true
        detail("Too Many Runes: " .. C.count .. " items checked one by one have a recipe, " .. (C.dropped or 0) .. " share a name with a made item but show no recipe (in about "
            .. math.floor((tickCount - C.startTick) / 50) .. " seconds).")
        if C.sample ~= nil then detail("Too Many Runes: the first of those: " .. C.sample) end
        -- the items made at a bench that the check above does not visit (see Recipes.benchCandidates)
        local indexed = 0
        local okB, candidates = pcall(Recipes.benchCandidates)
        for _, id in ipairs(okB and candidates or {}) do
            local obj = nil
            pcall(function() obj = config.Obj.FromID(id) end)
            local ok, data = pcall(Recipes.getBase, id, obj)
            if ok and data ~= nil and data.station ~= nil then
                pcall(Recipes.indexItem, id, data)
                indexed = indexed + 1
            end
        end
        detail("Too Many Runes: " .. indexed .. " items made at a bench are in the station search.")
        -- the items filled at a water source that have nothing they are made from (Cup of water, Fishbowl ...): their recipe is only "Made
        -- at: Water source"
        local watered = 0
        local okW, waterIds = pcall(Recipes.waterCandidates)
        for _, id in ipairs(okW and waterIds or {}) do
            local obj = nil
            pcall(function() obj = config.Obj.FromID(id) end)
            local ok, data = pcall(Recipes.getBase, id, obj)
            if ok and data ~= nil then
                for _, row in ipairs(data.rows or {}) do
                    if row.query == "@water" then
                        pcall(Recipes.indexItem, id, data)
                        watered = watered + 1
                        break
                    end
                end
            end
        end
        detail("Too Many Runes: " .. watered .. " items filled at a water source are in the station search.")
        if Recipes.onDataReady then pcall(Recipes.onDataReady) end
        if Recipes.forgetAnswers then pcall(Recipes.forgetAnswers) end -- (about 25 MB less: recipes/get.lua)
    end
end
Passes.add("recipe check", Recipes.craftableStep, function() return Recipes.craftState.ready end, function()
    Recipes.craftState.failed = true
    Recipes.craftState.ready = true -- (carry on with the names alone)
    Recipes.craftState.count = -1
end)

-- The item to open for a product's name. Of several items with that name, one whose game name starts with QUEST_ is a quest's own copy
-- (QUEST_NECROMANCY_NECROLORD_GREATER_CANDLE beside GREATER_RITUAL_CANDLE): the other one is opened. (Else the first item of that name.)
local function openTarget(prodLower, recordedId, pin)
    if pin ~= nil then -- (a ritual's own output: that item, if it still has this name)
        local obj = nil
        pcall(function() obj = config.Obj.FromID(pin) end)
        local name = field(obj, "name")
        if type(name) == "string" and string.lower(name) == prodLower then return pin end
    end
    local slots = Recipes.slotsOf and Recipes.slotsOf(prodLower) or nil
    if slots == nil or #slots < 2 then return findByName(prodLower) or recordedId end
    local first = nil
    for _, slot in ipairs(slots) do
        local id = Items.ids[slot]
        first = first or id
        local obj = nil
        pcall(function() obj = config.Obj.FromID(id) end)
        local cfg = field(obj, "configName")
        if type(cfg) == "string" and string.sub(cfg, 1, 6) ~= "QUEST_" then return id end
    end
    return first or recordedId
end

-- The items made from the item with this name, best order first: a list of { id, name, stat, level } (or nil if none).
function Recipes.usedList(itemName, itemId)
    local U = Recipes.usedState
    local lower = string.lower(itemName)
    if itemId ~= nil and Recipes.usesOwn(lower, itemId) then lower = lower .. "#" .. itemId end -- (an item with a list of its own, see usedAdd)
    local cached = U.lists[lower]
    if cached ~= nil then return cached or nil end
    local list = nil
    local set = U.by[lower]
    if set ~= nil then
        list = {}
        for prod, e in pairs(set) do
          if not (e.junk and Filters ~= nil and Filters.hide.junk) then -- (a hidden junk item is left out)
            -- (open the first item of that name that is not a quest's own copy; see openTarget)
            list[#list + 1] = { id = openTarget(prod, e.id, e.pin), name = e.name, stat = e.stat, level = e.level, key = prod }
          end
        end
        -- skill by skill, lowest level first; items with no skill at the end
        table.sort(list, function(a, b)
            local sa, sb = a.stat or 1000, b.stat or 1000
            if sa ~= sb then return sa < sb end
            local la, lb = a.level or 0, b.level or 0
            if la ~= lb then return la < lb end
            return a.key < b.key
        end)
        if #list == 0 then list = nil end
    end
    U.lists[lower] = list or false
    return list
end

-- What the info box needs for an item: { name, list, count } (nil while the uses are still being worked out, or if none).
function Recipes.usedFor(itemId, itemObj)
    if not Recipes.usedState.ready then return nil end
    local name = field(itemObj, "name")
    if type(name) ~= "string" or name == "" or Recipes.isRemoved(name) then return nil end
    local list = Recipes.usedList(name, itemId)
    if list == nil then return nil end
    return { name = name, list = list, count = #list }
end

-- A tab's words with a count: "Recipe (3)", "Source (99+)"; just the word when there is nothing to count (the Recipe and Source tabs count
-- like the Uses tab).
function Recipes.countLabel(word, n)
    if type(n) ~= "number" or n < 1 then return word end
    return word .. " (" .. ((n > 99) and "99+" or tostring(n)) .. ")"
end

-- The words on the Uses tab (with how many items, if the list is known).
function Recipes.usedTabLabel(used)
    if used == nil then return "Uses" end
    return "Uses (" .. ((used.count > 99) and "99+" or tostring(used.count)) .. ")"
end

end }
