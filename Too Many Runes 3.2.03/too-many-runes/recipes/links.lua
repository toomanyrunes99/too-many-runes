-- Too Many Runes - Recipes: items made from other items
-- The background pass that finds which items are upgrades, dyes or versions of other items.
-- (Moved over from the old plugin almost unchanged; recipes/compat.lua explains how it fits the new one.)
return { run = function(II)
local _ENV = II


----- "made from another item" links -----
-- Some items are made by changing another item rather than from a list of materials: a smithing
-- upgrade (+1, masterwork stages), adorned crafting armour, augmented gear, dyed items. The game stores
-- each of these as a setting on one of the two items that points at the other one. A survey of every
-- item showed which settings are real "made from" links (others, like worn / broken armour, are not).
--   forward = true : the setting is on the EARLIER item and points at what it becomes
--   forward = false: the setting is on the NEW item and points at what it was made from
-- A little index of "this item <- made from that item" is built once, in the background, from every item.
local LINK_PER_TICK = 100 -- items checked per game tick (Scan.full: this pass runs at full speed without trouble)
local LINK_RULES = Exceptions.linkRules -- (which settings count as "made from" links; the list is in recipes/exceptions.lua)
links = {}  -- item number -> list of { id = the item it was made from, label = "Upgraded from:" ..., role = (see below) }
linkState = { position = 1, ready = false, started = false, count = 0, mark = 10000 }

local function addLink(newId, fromId, label, role, setting)
    if type(newId) ~= "number" or type(fromId) ~= "number" or newId == fromId then return end
    if newId < 1 or fromId < 1 then return end -- (a setting that points at "item -1" means no item: some finished pieces name no draft)
    local list = links[newId]
    if list == nil then
        list = {}
        links[newId] = list
    end
    for _, e in ipairs(list) do
        if e.id == fromId then return end
    end
    list[#list + 1] = { id = fromId, label = label, role = role, setting = setting }
    linkState.count = linkState.count + 1
end

local function linkItem(id)
    local obj = nil
    pcall(function() obj = config.Obj.FromID(id) end)
    if obj == nil then return end
    local params = field(obj, "params")
    if params == nil then return end
    for i = 1, MAX_PARAMS do
        local p = valueAt(params, i)
        if p == nil then break end
        local name = field(p, "configName")
        if type(name) == "string" and not BAD_TYPES[tostring(field(p, "valueType"))] then
            local rule = nil
            for _, r in ipairs(LINK_RULES) do
                if string.find(name, r.find, 1, true) then
                    rule = r
                    break
                end
            end
            if rule ~= nil then
                local okV, v = pcall(function() return obj:GetParamValue(p) end)
                local kind = type(v)
                if okV and v ~= nil and kind ~= "number" and kind ~= "string" and kind ~= "boolean"
                   and field(v, "typeName") == "Obj" then
                    local other = field(v, "id")
                    if rule.forward then addLink(other, id, rule.label, rule.role, name) else addLink(id, other, rule.label, rule.role, name) end
                end
            end
        end
    end
end

-- The quick way to check one item: ask it only about the settings that link items (found by name below),
-- instead of reading every setting it has.
function Recipes.linkItemFast(id)
    local obj = nil
    pcall(function() obj = config.Obj.FromID(id) end)
    if obj == nil then return end
    for _, lp in ipairs(linkState.fast) do
        local okH, has = pcall(linkState.has, obj, lp.param)
        if okH and has == true then
            local okV, v = pcall(linkState.get, obj, lp.param)
            local kind = type(v)
            if okV and v ~= nil and kind ~= "number" and kind ~= "string" and kind ~= "boolean"
               and field(v, "typeName") == "Obj" then
                local other = field(v, "id")
                if lp.rule.forward then addLink(other, id, lp.rule.label, lp.rule.role, lp.name) else addLink(id, other, lp.rule.label, lp.rule.role, lp.name) end
            end
        end
    end
end

-- Masterwork magic and ranged armour is made in steps: a draft, then an unfinished piece, then the finished piece. The game links the
-- FINISHED piece to both of the others (its settings CRAFTING_ARMOUR_DRAFT_OBJECT and CRAFTING_ARMOUR_UPGRADE_OBJECT, role "draft" and
-- "unfinished" in Exceptions.linkRules), and nothing links the other two to each other or to the piece. This reads those links the other way
-- round, once all items have been checked:
--   Recipes.draftPieces[draft]          = the finished pieces made with that draft
--   Recipes.finishedOf[unfinishedPiece] = the finished piece it becomes
-- and adds the link the game leaves out: the unfinished piece was made from the draft its finished piece names.
function Recipes.deriveDrafts()
    local pieces, finished, toAdd = {}, {}, {}
    for finishedId, list in pairs(links) do
        local draft, unfinished = nil, nil
        for _, e in ipairs(list) do
            if e.role == "draft" then draft = e.id elseif e.role == "unfinished" then unfinished = e.id end
        end
        if draft ~= nil then
            pieces[draft] = pieces[draft] or {}
            pieces[draft][#pieces[draft] + 1] = finishedId
            if unfinished ~= nil then toAdd[#toAdd + 1] = { unfinished, draft } end
        end
        if unfinished ~= nil then
            finished[unfinished] = finished[unfinished] or {}
            finished[unfinished][#finished[unfinished] + 1] = finishedId
        end
    end
    for _, list in pairs(pieces) do table.sort(list) end
    for _, list in pairs(finished) do table.sort(list) end
    -- (added after the loop: the table must not change while it is read)
    for _, pair in ipairs(toAdd) do addLink(pair[1], pair[2], "Drafted from:") end
    Recipes.draftPieces, Recipes.finishedOf = pieces, finished
end

-- Called from the game clock (below) once the item list is built; does a little each time.
-- Step 1: find the game's link settings by NAME (so settings added in a later game update are found
-- too, with nothing to change here). Step 2: ask every item only about those few settings.
function Recipes.linkStep()
    if linkState.ready then return end
    if not linkState.started then
        linkState.started = true
        linkState.has = function(o, p) return o:HasParam(p) end
        linkState.get = function(o, p) return o:GetParamValue(p) end
        linkState.found = {}
        linkState.paramNext, linkState.paramMisses = 0, 0
        linkState.phase = "settings"
        detail("Too Many Runes: finding which items are made from other items (in the background)...")
    end
    if linkState.phase == "settings" then
        for _ = 1, Scan.full(400) do
            local n = linkState.paramNext
            linkState.paramNext = n + 1
            local p = nil
            pcall(function() p = config.Param.FromID(n) end)
            local name = field(p, "configName")
            if type(name) ~= "string" or name == "" then
                linkState.paramMisses = linkState.paramMisses + 1
            else
                linkState.paramMisses = 0
                if not BAD_TYPES[tostring(field(p, "valueType"))] then
                    for _, r in ipairs(LINK_RULES) do
                        if string.find(name, r.find, 1, true) then
                            linkState.found[#linkState.found + 1] = { param = p, rule = r, name = name }
                            break
                        end
                    end
                end
            end
            if linkState.paramMisses >= 2000 or linkState.paramNext > 100000 then
                if linkState.paramMisses < 2000 then
                    print("Too Many Runes: the game's settings go on past number 100000; the search for the link settings stopped there.")
                end
                local names = {}
                for _, lp in ipairs(linkState.found) do names[#names + 1] = lp.name end
                if #names > 0 then
                    linkState.fast = linkState.found
                    detail("Too Many Runes: found " .. #names .. " settings that link items: " .. table.concat(names, ", "))
                else
                    print("Too Many Runes: could not find the link settings by name; checking every setting of every item instead (slower).")
                end
                linkState.phase = "items"
                linkState.startTick = tickCount
                return
            end
        end
        return
    end
    local step, perTick = linkItem, Scan.full(40) -- (reading every setting of every item is slower, so fewer per tick)
    if linkState.fast ~= nil then step, perTick = Recipes.linkItemFast, Scan.full(LINK_PER_TICK) end
    local last = math.min(linkState.position + perTick - 1, #itemIds)
    for k = linkState.position, last do pcall(step, itemIds[k]) end
    linkState.position = last + 1
    if linkState.position > #itemIds then
        pcall(Recipes.deriveDrafts)
        linkState.ready = true
        -- (the dyed versions join their item's group - core/groups.lua - so the groups are made again)
        if Groups ~= nil and Groups.regroup ~= nil then pcall(Groups.regroup) end
        local took = ""
        if linkState.startTick ~= nil then took = " in about " .. math.floor((tickCount - linkState.startTick) / 50) .. " seconds" end
        detail("Too Many Runes: item links ready (" .. linkState.count .. " found" .. ")" .. took .. ".")
        if Recipes.onDataReady then pcall(Recipes.onDataReady) end
    elseif linkState.position > linkState.mark then
        linkState.mark = linkState.mark + 20000
        detail("Too Many Runes: item links: " .. linkState.position .. " of " .. #itemIds .. " items checked...")
    end
end
-- (starts once the item list is complete; if it fails, linkState.failed makes the item list stop waiting for the links)
Passes.add("item links", function() if Items.loaded then Recipes.linkStep() end end,
    function() return linkState.ready end, function() linkState.failed = true end)

-- The dye a dyeing setting stands for. The game keeps, on an item that can be dyed, one setting for each dye that points at the dyed
-- version (DYE_RESULT_SOUL, DYE_RESULT_ICE, TRAIL14_DYE_RESULT_THIRDAGE ...): the end of the setting's name is the dye's name. The dye is
-- the item whose name, with the spaces taken out, is that word followed by "dye" ("Third Age dye" <- THIRDAGE). Returns the dye's number
-- and name, or nil. The settings that count are the ones with DYE_RESULT in Exceptions.linkRules.
local dyeByWord = nil
function Recipes.dyeOfSetting(setting)
    if type(setting) ~= "string" then return nil end
    local word = string.match(setting, "DYE_RESULT_([%w_]+)$")
    if word == nil then return nil end
    if dyeByWord == nil or dyeByWord.count ~= #itemLower then
        dyeByWord = { count = #itemLower }
        for idx = 1, #itemLower do
            local lower = itemLower[idx]
            if string.sub(lower, -4) == " dye" then
                local key = string.upper((string.gsub(lower, "[^%a]", "")))
                if dyeByWord[key] == nil then dyeByWord[key] = idx end
            end
        end
    end
    local idx = dyeByWord[string.upper((string.gsub(word, "[^%a]", ""))) .. "DYE"]
    if idx == nil then return nil end
    return itemIds[idx], itemNames[idx]
end

-- An augmented item (its name starts "Augmented", and the game links it to the item it was made from: INVENT_BASE_OBJECT, or the item's
-- INVENT_AUGMENTED_VERSION): it was made with an Augmentor. Returns the Augmentor's item number and name, or nil. (The game's link does not
-- name the Augmentor, so it is found by its name.)
local augmentor = nil
function Recipes.augmentorOf(itemId, setting)
    if type(setting) ~= "string" or not (string.find(setting, "AUGMENTED_VERSION", 1, true) or setting == "INVENT_BASE_OBJECT") then return nil end
    local slot = idToSlot and idToSlot[itemId]
    local lower = slot and itemLower[slot]
    if lower == nil then
        local obj = nil
        pcall(function() obj = config.Obj.FromID(itemId) end)
        local n = field(obj, "name")
        lower = (type(n) == "string") and string.lower(n) or ""
    end
    if string.sub(lower, 1, 10) ~= "augmented " then return nil end
    if augmentor == nil or augmentor.count ~= #itemLower then
        augmentor = { count = #itemLower }
        for idx = 1, #itemLower do
            if itemLower[idx] == "augmentor" then augmentor.id, augmentor.name = itemIds[idx], itemNames[idx] break end
        end
    end
    return augmentor.id, augmentor.name
end

-- The item this one is the dyed version of (the game's DYE_RESULT_ settings), or the augmented version of (AUGMENTED_VERSION), or nil. For
-- core/groups.lua: a dyed item joins its item's group.
local function linkedBy(itemId, word)
    local list = links[itemId]
    if list == nil then return nil end
    for _, e in ipairs(list) do
        if type(e.setting) == "string" and string.find(e.setting, word, 1, true) then return e.id end
    end
    return nil
end
function Recipes.dyedFrom(itemId) return linkedBy(itemId, "DYE_RESULT") end
function Recipes.augmentedFrom(itemId) return linkedBy(itemId, "AUGMENTED_VERSION") end

-- What was this item made from? A list of { id, name, label } (at most 4), or nil. A dyed item also names the dye it was dyed with, an
-- augmented item the Augmentor.
function sourcesOf(itemId)
    local list = links[itemId]
    if list == nil then return nil end
    local out = {}
    for _, e in ipairs(list) do
        local obj = nil
        pcall(function() obj = config.Obj.FromID(e.id) end)
        local augId, augName = Recipes.augmentorOf(itemId, e.setting)
        out[#out + 1] = { id = e.id, label = (augId ~= nil) and "Augmented from:" or e.label, name = (obj ~= nil) and nameOf(obj) or ("item " .. e.id) }
        local dyeId, dyeName = Recipes.dyeOfSetting(e.setting)
        if dyeId ~= nil then out[#out + 1] = { id = dyeId, label = "Dyed with:", name = dyeName } end
        if augId ~= nil then out[#out + 1] = { id = augId, label = "Augmented with:", name = augName } break end
        if #out >= 4 then break end
    end
    if #out == 0 then return nil end
    return out
end

end }
