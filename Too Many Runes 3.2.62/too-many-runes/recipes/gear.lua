-- Too Many Runes - Equipment: what can be worn or wielded
-- The game's item objects have no "wear position", but two things on them tell what an item is for (a survey of all 58,328 items found this):
--   * the inventory menu (obj.interfaceOpNames): "Wear" (armour, jewellery, capes; some replicas spell it "wear") and "Wield" (weapons, arrows)
--   * the category (obj.category, named by id.Category.FromID): ARMOUR_FEET, ARMOUR_HANDS, ARMOUR_CAPE, WEAPON_DAGGER, WEAPON_STAFF, WEAPON_BOW,
--     WEAPON_WHIP, AMMO_ARROW ... (not every item has one: Climbing boots have none, the rune gear has SMITHING_DEPRECATED and the op "Convert")
-- A category with one of the prefixes ARMOUR_ / WEAPON_ / AMMO_ decides the kind; else the menu does ("Wear" = armour, "Wield" = weapon).
-- The search words are @armour @weapon @ammo, and one word for the rest of every such category's name (@feet @hands @cape @dagger @staff @bow ...):
-- those are made from the names the game has, so nothing is typed in by hand (a word the search already uses for a skill or a station is skipped).
-- (How the files fit together is explained at the top of main.lua.)
return { run = function(T)
local _ENV = T

Recipes.gearState = { pos = 1, ready = false, count = 0 }
Recipes.gearIndex = {}   -- word -> { [item number] = true }
Recipes.gearSlots = {}   -- the words made from category names -> true
Recipes.gearCounts = {}  -- word -> how many items

local PREFIXES = { { "ARMOUR_", "armour" }, { "WEAPON_", "weapon" }, { "AMMO_", "ammo" } }
local categoryInfo = {} -- category number -> { kind, slot } or false

local function infoOf(n)
    local c = categoryInfo[n]
    if c ~= nil then return c or nil end
    local name = nil
    pcall(function() name = id.Category.FromID(n) end)
    c = false
    if type(name) == "string" then
        local upper = string.upper(name)
        if upper == "POTION" then c = { potion = true } end -- (the game's own category of potions: the survey showed Attack potion (3) in it)
        for _, p in ipairs(PREFIXES) do
            if c == false and string.sub(upper, 1, #p[1]) == p[1] and #upper > #p[1] then
                local slot = string.lower(string.sub(upper, #p[1] + 1))
                slot = string.gsub(slot, "_", "-")
                c = { kind = p[2], slot = slot }
                break
            end
        end
    end
    categoryInfo[n] = c
    return c or nil
end

-- Slot words from the NAME of a wearable item, for the slots the game's category names do not cover (rings and necklaces have none, some
-- gloves and boots have no ARMOUR_ category): slot word = { whole words in the name }. (So @ring, @neck and the synonyms in settings.lua's
-- SEARCH_SYNONYMS - @necklace, @amulet, @boots, @helmet - always have a word to find.)
local NAME_SLOTS = {
    ring = { "ring" },
    neck = { "necklace", "amulet", "pendant", "ammy", "choker", "torque", "scarf" },
    feet = { "boots", "boot", "shoes", "sandals", "slippers" },
    hands = { "gloves", "gauntlets", "vambraces", "vambrace", "bracelet", "bracers", "mitts" },
    head = { "helm", "helmet", "hat", "hood", "mask", "coif", "headband", "tiara", "crown", "cowl", "circlet", "headdress" },
    body = { "platebody", "chainbody", "body", "top", "shirt", "torso", "cuirass", "chestplate", "brassard", "hauberk" },
    legs = { "platelegs", "plateskirt", "legs", "chaps", "skirt", "trousers", "leggings", "tassets", "greaves", "bottoms", "cuisse" },
    cape = { "cape", "cloak" },
    shield = { "shield", "kiteshield", "defender", "buckler", "ward", "book", "orb" },
}
local function nameSlots(lowerName)
    local out = {}
    for slot, words in pairs(NAME_SLOTS) do
        for _, w in ipairs(words) do
            if string.find(lowerName, "%f[%w]" .. w .. "%f[%W]") then out[#out + 1] = slot break end
        end
    end
    return out
end

-- What a worn or wielded item needs (its WEAR_REQUIRES_STATn / _LEVELn settings, the "To wear:" line of the Info box): Recipes.wearIndex
-- [item number] = { [the game's stat number] = level }. Read by the @ skill words (core/query.lua): @attack, @ranged, @magic, @defence,
-- @necromancy ... also list the gear that needs that skill, at that level.
Recipes.wearIndex = {}
local wearP = nil
local function wearRequirements(obj)
    if wearP == nil then
        wearP = { stat = {}, level = {} }
        for n = 1, 5 do
            pcall(function() wearP.stat[n] = config.Param["WEAR_REQUIRES_STAT" .. n] end)
            pcall(function() wearP.level[n] = config.Param["WEAR_REQUIRES_STAT_LEVEL" .. n] end)
        end
    end
    local req = nil
    for n = 1, 5 do
        local ps, pl = wearP.stat[n], wearP.level[n]
        if ps ~= nil and pl ~= nil and Recipes.usedHas(obj, ps) then
            local okS, s = pcall(function() return obj:GetParamValue(ps) end)
            local okL, l = pcall(function() return obj:GetParamValue(pl) end)
            if okS and okL and type(s) == "number" and type(l) == "number" and l > 0 then
                req = req or {}
                req[s] = math.max(req[s] or 0, l)
            end
        end
    end
    return req
end

-- (3.2.31) THE STYLE. The game marks every combat item with its style: armour with COMBATV2_MELEE_ITEM / _RANGED_ITEM / _MAGIC_ITEM /
-- _NECROMANCY_ITEM (Elite sirenic mask: COMBATV2_RANGED_ITEM = 1, though it only needs Defence to wear), weapons with COMBATV2_MELEE_WEAPON
-- / _RANGED_WEAPON / _MAGIC_WEAPON (Noxious longbow: COMBATV2_RANGED_WEAPON = 1; TMR-survey 1.0.28). Recipes.styleIndex[item number] =
-- "melee", "ranged", "magic", "necromancy", or "hybrid" when it is marked with more than one. Items without a mark (jewellery - Amulet of
-- glory has none -, most cosmetics, tools) are not in it. Read by core/shelves.lua (the Gear groups).
Recipes.styleIndex = {}
-- (3.2.34) For the item groups too (core/shelves.lua): every item's category number (Recipes.catIndex[item number]; its name is
-- Recipes.categoryName(n): POH_FURNITURE, MTX_PET, ARCH_MATERIAL ...) and its Grand Exchange category (Recipes.geIndex[item number]: the
-- GE_CATEGORY setting - 6 Cooking ingredients, 33 Seeds, 39 Salvage ...; only items sold on the Grand Exchange have one).
Recipes.catIndex, Recipes.geIndex = {}, {}
local geParam, geTried = nil, false
local catNames = {}
function Recipes.categoryName(n)
    if type(n) ~= "number" or n < 0 then return nil end
    local c = catNames[n]
    if c == nil then
        c = false
        pcall(function() local s = id.Category.FromID(n); if type(s) == "string" then c = s end end)
        catNames[n] = c
    end
    return c or nil
end
local STYLE_PARAMS = { { "melee", "MELEE" }, { "ranged", "RANGED" }, { "magic", "MAGIC" }, { "necromancy", "NECROMANCY" } }
local styleP = nil
local function styleMark(obj)
    if styleP == nil then
        styleP = {}
        for _, s in ipairs(STYLE_PARAMS) do
            for _, what in ipairs({ "ITEM", "WEAPON" }) do
                local p = nil
                pcall(function() p = config.Param["COMBATV2_" .. s[2] .. "_" .. what] end)
                if p ~= nil then styleP[#styleP + 1] = { s[1], p } end
            end
        end
    end
    local found = nil
    for _, e in ipairs(styleP) do
        if found ~= e[1] and Recipes.usedHas(obj, e[2]) then
            local ok, v = pcall(function() return obj:GetParamValue(e[2]) end)
            if ok and (v == 1 or v == true) then
                if found ~= nil then return "hybrid" end
                found = e[1]
            end
        end
    end
    return found
end

local function put(word, itemId)
    local set = Recipes.gearIndex[word]
    if set == nil then
        set = {}
        Recipes.gearIndex[word] = set
        Recipes.gearCounts[word] = 0
    end
    if not set[itemId] then
        set[itemId] = true
        Recipes.gearCounts[word] = Recipes.gearCounts[word] + 1
    end
end

-- Read the next items (Scan.full(1000) a tick) once the item list is complete.
function Recipes.gearStep()
    local G = Recipes.gearState
    if G.ready or not Items.loaded then return end
    if G.startTick == nil then G.startTick = tickCount end
    -- (3.2.29: at the light passes' speed - Scan.full - not the gentle one: the item list's groups wait for it, core/shelves.lua)
    local last = math.min(G.pos + Scan.full(1000) - 1, #Items.ids)
    for k = G.pos, last do
        local itemId = Items.ids[k]
        local obj = nil
        pcall(function() obj = config.Obj.FromID(itemId) end)
        if obj ~= nil then
            local wears, wields, cat = false, false, nil
            pcall(function()
                for _, op in pairs(obj.interfaceOpNames) do
                    if type(op) == "string" then
                        local l = string.lower(op)
                        if l == "wear" then wears = true elseif l == "wield" then wields = true end
                    end
                end
            end)
            pcall(function() cat = obj.category end)
            if type(cat) == "number" and cat >= 0 then Recipes.catIndex[itemId] = cat end
            if not geTried then geTried = true; pcall(function() geParam = config.Param["GE_CATEGORY"] end) end
            if geParam ~= nil and Recipes.usedHas(obj, geParam) then
                local okG, ge = pcall(function() return obj:GetParamValue(geParam) end)
                if okG and type(ge) == "number" and ge >= 0 then Recipes.geIndex[itemId] = ge end
            end
            local info = (type(cat) == "number" and cat >= 0) and infoOf(cat) or nil
            if info ~= nil and info.potion then put("potion", itemId); info = nil end -- (read by @potion, core/query.lua)
            local kind = info and info.kind or (wears and "armour") or (wields and "weapon") or nil
            if kind ~= nil then
                put(kind, itemId)
                G.count = G.count + 1
                if info ~= nil then
                    put(info.slot, itemId)
                    Recipes.gearSlots[info.slot] = true
                end
                local req = wearRequirements(obj) -- (what it needs to be worn or wielded)
                if req ~= nil then Recipes.wearIndex[itemId] = req end
                local style = styleMark(obj)
                if style ~= nil then Recipes.styleIndex[itemId] = style end
                if wears or kind == "armour" then -- (worn things: the slot words their names give, see NAME_SLOTS)
                    local name = nil
                    pcall(function() name = obj.name end)
                    if type(name) == "string" then
                        for _, slot in ipairs(nameSlots(string.lower(name))) do
                            put(slot, itemId)
                            Recipes.gearSlots[slot] = true
                        end
                    end
                end
            end
        end
    end
    G.pos = last + 1
    if G.pos > #Items.ids then
        G.ready = true
        local words = {}
        for w in pairs(Recipes.gearSlots) do words[#words + 1] = w end
        table.sort(words)
        for i, w in ipairs(words) do words[i] = w .. " " .. Recipes.gearCounts[w] end
        detail("Too Many Runes: " .. G.count .. " items can be worn or wielded ("
            .. (Recipes.gearCounts.armour or 0) .. " armour, " .. (Recipes.gearCounts.weapon or 0) .. " weapons, " .. (Recipes.gearCounts.ammo or 0)
            .. " ammo); words from the game's category names: " .. table.concat(words, ", "))
        if Recipes.onDataReady then pcall(Recipes.onDataReady) end
    end
end
Passes.add("equipment", Recipes.gearStep, function() return Recipes.gearState.ready end, function()
    Recipes.gearState.ready = true -- (carry on without it)
end)

end }
