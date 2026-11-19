-- Too Many Runes - The item stats: the game's hover box for a weapon, armour, cape or jewellery
-- Damage, Accuracy, Style, Type, Range, Tier, Armour, the damage bonuses, life points, the passive's name, the effect's text and
-- the item set, worked out from the item's own settings. Shown in a hover box like the game's, over the item's picture at the top
-- of the details (ui/details.lua).
-- The rules were checked word for word against the game's hover box on more than 60 items, and the accuracy rule fits all 6,731
-- weapons. Per-copy things (charges, Item Level, perks) are not in the settings, so the box shows the item's own numbers, as the
-- game's does.
return { run = function(T)
local _ENV = T

Stats = {}

local NAMES = { "MINING_PICKAXE_STAT_DATA", "POP_LIFESPAN", "AMMOCATEGORY", "COMBATV2_ITEM_ENCHANTMENT_EFFECT_STRUCT_INACTIVE", "COMBATV2_ITEM_ENCHANTMENT_ITEM", "TOOLTIP_EXTRA_INFO", "OBJ_INFO_EXTRA", "HERB_BOMB_STRUCT", "WEAPON_CATEGORY", "MELEE_STRENGTH", "RANGED_STRENGTH", "MAGIC_STRENGTH", "NECROMANCY_STRENGTH", "MELEEATTACK", "RANGEATTACK",
    "MAGICATTACK", "NECROMANCYATTACK", "ATTACKRANGE", "COMBATV2_ITEM_TIER", "WEAR_REQUIRES_STAT1", "WEAR_REQUIRES_STAT_LEVEL1", "WEAR_REQUIRES_STAT2",
    "WEAR_REQUIRES_STAT_LEVEL2", "WEAR_REQUIRES_STAT3", "WEAR_REQUIRES_STAT_LEVEL3", "COMBATV2_SPECIAL_ATTACK_NAME",
    "COMBATV2_SPECIAL_ATTACK", "COMBATV2_PRAYER_DRAIN_RESIST", "COMBATV2_MELEE_WEAPON", "COMBATV2_RANGED_WEAPON", "COMBATV2_MAGIC_WEAPON",
    "COMBATV2_NECROMANCY_WEAPON", "COMBATV2_MELEE_ITEM", "COMBATV2_RANGED_ITEM", "COMBATV2_MAGIC_ITEM", "COMBATV2_NECROMANCY_ITEM",
    "COMBATV2_GENERIC_ITEM", "COMBATV2_GENERICDEFENCE", "COMBATV2_PLAYER_ARMOUR", "CONSTITUTION_INCREASE", "COMBATV2_ITEM_IS_SHIELD",
    "COMBATV2_ITEM_IS_DEFENDER", "COMBATV2_ITEM_SET_STRUCT", "COMBATV2_NECROMANCY_UNDERWORLD_CONDUIT", "COMBATV2_ITEM_EFFECT_STRUCT",
    "COMBATV2_ITEM_PASSIVE_STRUCT",
    -- The special attack's description, cost, the items it needs and its kind. A copy (dyed, augmented, superior ...) has none of
    -- these itself, but names the weapon it copies in COMBATV2_SPECIAL_ATTACK_BASE_ITEM.
    "COMBATV2_SPECIAL_ATTACK_DESCRIPTION", "COMBATV2_SPECIAL_ATTACK_BASE_ITEM", "COMBATV2_SPECIAL_ATTACK_ADREN_REQ",
    "COMBATV2_SPECIAL_ATTACK_REQUIRES_ITEM", "COMBATV2_SPECIAL_ATTACK_REQUIRES_ITEM_ALTERNATIVE", "COMBATV2_SPECIAL_ATTACK_REQUIRES_ITEM_ALTERNATIVE2",
    "COMBATV2_SPECIAL_ATTACK_REQUIRES_ITEM_ALTERNATIVE3", "COMBATV2_INSTANT_SPECIAL_ATTACK", "COMBATV2_NO_TARGET_SPECIAL_ATTACK",
    "COMBATV2_CHANNELED_SPECIAL_ATTACK", "COMBATV2_SPECIAL_ATTACK_PVP_DISABLED" }
-- The game's settings, looked up the first time an item is opened.
local P, PS, P_ATTACK_TYPE, P_NAME, P_INFO, P_SET_COUNT = nil, nil, nil, nil, nil, nil
local function lookUp()
    if P ~= nil then return end
    P, PS = {}, {}
    for _, n in ipairs(NAMES) do pcall(function() P[n] = config.Param[n] end) end
    pcall(function() P_ATTACK_TYPE = config.Param.COMBATV2_ATTACK_TYPE end)
    pcall(function() P_NAME = config.Param.COMBATV2_ABILITY_NAME end)
    pcall(function() P_INFO = config.Param.COMBATV2_ABILITY_INFO end)
    pcall(function() P_SET_COUNT = config.Param.COMBATV2_NUMBER_OF_ITEMS_FOR_SET_EFFECT_1 end)
    for _, n in ipairs({ "COMBATV2_SET_REQUIRED_ITEM_ALTERNATE_NAME", "COMBATV2_SET_REQUIRED_ITEM_DESCRIPTION", "COMBATV2_ABILITY_INFO_ONDAMAGE_ACTIVATION",
        "COMBATV2_ABILITY_INFO_ONKILL_ACTIVATION", "COMBATV2_ITEM_ANTI_SWITCH_CHARGE_TIME" }) do pcall(function() PS[n] = config.Param[n] end) end
    for k = 2, 5 do -- a set's further bonuses
        for _, n in ipairs({ "COMBATV2_ABILITY_INFO_" .. k, "COMBATV2_NUMBER_OF_ITEMS_FOR_SET_EFFECT_" .. k }) do pcall(function() PS[n] = config.Param[n] end) end
    end
end
-- A setting inside a struct. An empty word counts as none, or the Deathdealer set's pieces would show as "-" and its count as 2.
local function inside(st, p) local v = nil; if p ~= nil then pcall(function() v = st:GetParamValue(p) end) end if v == "" then v = nil end return v end
local function valuesOf(obj)
    local t = {}
    for n, p in pairs(P) do
        pcall(function() if obj:HasParam(p) then t[n] = obj:GetParamValue(p) end end)
    end
    return t
end
local catNames = {}
local function catName(n)
    if type(n) ~= "number" or n < 0 then return nil end
    local c = catNames[n]
    if c == nil then
        c = false
        pcall(function() local s = id.Category.FromID(n); if type(s) == "string" then c = s end end)
        catNames[n] = c
    end
    return c or nil
end
local function num(v) return (type(v) == "number") and v or nil end
local function fmt(n) -- 1125 gives "1,125"
    local s = tostring(math.floor(n))
    local k
    repeat s, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2") until k == 0
    return s
end
local function tenth(n) -- 262 gives "26.2", 300 gives "30" (a damage bonus is kept x10)
    if n % 10 == 0 then return fmt(n // 10) end
    return fmt(n // 10) .. "." .. tostring(n % 10)
end
local function pct(x) -- 1.2 gives "1.2%", 1 gives "1%"
    local s = string.format("%.2f", x):gsub("0+$", ""):gsub("%.$", "")
    return s .. "%"
end
-- the value of a tier: 0.0008 x tier^3 + 4 x tier + 40 (accuracy = 2.5 x this; armour = this x the slot's share)
-- HAND-TYPED (not read from the game: check again after a game update): the tier formula
local function tierValue(t) return 0.0008 * t * t * t + 4 * t + 40 end
local function accuracyTier(acc)
    for t = 1, 120 do if math.abs(2.5 * tierValue(t) - acc) <= 1 then return t end end
    return nil
end
-- HAND-TYPED (not read from the game: check again after a game update): each armour slot's share (SHARE_OF, SHARES)
local SHARE_OF = { ARMOUR_BODY = 0.575, ARMOUR_LEGS = 0.55, ARMOUR_HELMET = 0.5, ARMOUR_SHIELD = 0.5, ARMOUR_HANDS = 0.125, ARMOUR_FEET = 0.125,
    ARMOUR_CAPE = 0.075, ARMOUR_WEAPON = 0.25 } -- a defender: Rune defender 850 = a quarter at tier 50
local SHARES = { 0.575, 0.55, 0.5, 0.125, 0.075 }
-- Amulets, rings, pockets, auras, ammo and so on have armour of their own: no slot share, no tier label, no Tank / Power.
local function noShare(cat) return cat ~= nil and (cat:find("NECK") or cat:find("RING") or cat:find("AMULET") or cat:find("POCKET")
    or cat:find("AURA") or cat:find("^AMMO")) ~= nil end
-- the tier and slot share that give this armour number (x10 in the game's data; within 3 for the game's rounding), the item's own tier first
local function armourTier(stored, tier, cat)
    if noShare(cat) then return nil, nil end
    local share = SHARE_OF[cat or ""]
    if share == nil and cat ~= nil and (cat:find("CAPE") or cat:find("CLOAK")) then share = 0.075 end -- Ardougne cloak: ATAR_CLOAK
    local shares = share and { share } or SHARES
    local function fits(t, s) return math.abs(s * tierValue(t) * 10 - stored) <= 3 end
    if tier ~= nil then for _, s in ipairs(shares) do if fits(tier, s) then return tier, s end end end
    -- The slot is not known from the category: take the fit whose tier is nearest the item's own (Ardougne cloak 4 is tier 45 as a
    -- cape, not 1 as a helmet).
    local bestT, bestS = nil, nil
    for t = 1, 120 do for _, s in ipairs(shares) do
        if fits(t, s) and (bestT == nil or math.abs(t - (tier or t)) < math.abs(bestT - (tier or bestT))) then bestT, bestS = t, s end
    end end
    return bestT, bestS
end
local attackTypes = {} -- attack type number (or false), by weapon kind struct id
local function attackTypeOf(kind)
    local kid = field(kind, "id")
    if kid == nil then return nil end
    local a = attackTypes[kid]
    if a == nil then
        a = false
        pcall(function() local v = kind:GetParamValue(P_ATTACK_TYPE); if type(v) == "number" then a = v end end)
        attackTypes[kid] = a
    end
    return a or nil
end
local STYLE = { [5] = "Style: Stabbing", [6] = "Style: Slashing", [7] = "Style: Crushing", [8] = "Ammo: Arrow", [9] = "Ammo: Bolt", [10] = "Ammo: Thrown" }
local CLASSES = { { "Melee", "MELEE" }, { "Ranged", "RANGED" }, { "Magic", "MAGIC" }, { "Necromancy", "NECROMANCY" } }
local STRENGTH = { Melee = "MELEE_STRENGTH", Ranged = "RANGED_STRENGTH", Magic = "MAGIC_STRENGTH", Necromancy = "NECROMANCY_STRENGTH" }
local ATTACK = { Melee = "MELEEATTACK", Ranged = "RANGEATTACK", Magic = "MAGICATTACK", Necromancy = "NECROMANCYATTACK" }

-- An item set's lines: its name, its pieces (the required one first), the set bonus. A piece's line starts with PIECE, a mark that
-- is never shown: the hover box draws those lines dim grey, as the game does (Stats.lines). The game's own effect text can start
-- with "- " too, and stays in the normal colour.
local PIECE = "\1"
local WHITE_LINE = "\2" -- a line in plain white ("Charging (9s) ..."), brighter than the other words in the game's box
local function setLines(set)
    local lines = {}
    local name = nil
    pcall(function() name = set:GetParamValue(P_NAME) end)
    if type(name) ~= "string" then return lines end
    lines[#lines + 1] = "Item Set: " .. name
    local required = inside(set, PS.COMBATV2_SET_REQUIRED_ITEM_ALTERNATE_NAME)
    if type(required) == "string" then lines[#lines + 1] = PIECE .. "- " .. required end
    local alt = {}
    pcall(function() for i = 1, 12 do local p = config.Param["COMBATV2_SET_ITEM_" .. i .. "_ALTERNATE_NAME"]; if p ~= nil then alt[i] = inside(set, p) end end end)
    local params = field(set, "params")
    for i = 1, 60 do
        local p = field(params, i)
        if p == nil then break end
        local pname = tostring(field(p, "configName") or "")
        local n = tonumber(pname:match("^COMBATV2_SET_ITEM_(%d+)$"))
        if n ~= nil then
            local v = nil
            pcall(function() v = set:GetParamValue(p) end)
            local nm = (type(alt[n]) == "string" and alt[n]) or field(v, "name") -- Void: "Any Void Knight top"
            if type(nm) == "string" and nm ~= "" then lines[#lines + 1] = PIECE .. "- " .. nm end
        end
    end
    -- A set that charges up after it is put on (Elite sirenic hauberk): its time is in game ticks of 0.6 seconds (15 = 9s).
    local charge = inside(set, PS.COMBATV2_ITEM_ANTI_SWITCH_CHARGE_TIME)
    if type(charge) == "number" and charge > 0 then
        local s = charge * 6 / 10
        local w = (s == math.floor(s)) and string.format("%d", s) or string.format("%.1f", s)
        lines[#lines + 1] = WHITE_LINE .. "Charging (" .. w .. "s) - Set bonuses will be active after equipped for " .. w .. "s."
    end
    -- Every bonus the set has: the first in COMBATV2_ABILITY_INFO, more in _2 to _5 (Lumberjack: +2%, +3%, +5% Woodcutting XP), each
    -- with how many pieces it needs.
    local needs = inside(set, PS.COMBATV2_SET_REQUIRED_ITEM_DESCRIPTION)
    local blank = false
    for k = 1, 5 do
        local info, count = nil, nil
        if k == 1 then
            pcall(function() info = set:GetParamValue(P_INFO) end)
            pcall(function() count = set:GetParamValue(P_SET_COUNT) end)
        else
            info = inside(set, PS["COMBATV2_ABILITY_INFO_" .. k])
            count = inside(set, PS["COMBATV2_NUMBER_OF_ITEMS_FOR_SET_EFFECT_" .. k])
        end
        if type(info) == "string" and info ~= "" then
            -- Void needs 3 pieces and a helm: "Set Bonus (4) while wearing a Void Knight helm: ..."
            if type(count) == "number" and type(needs) == "string" then count = count + 1 end
            if not blank then lines[#lines + 1] = ""; blank = true end -- a blank line before the bonuses, as in the game's box
            lines[#lines + 1] = "Set Bonus" .. (type(count) == "number" and (" (" .. count .. ")") or "") ..
                (type(needs) == "string" and (" " .. needs .. ": ") or " : ") .. info
        end
    end
    return lines
end

-- A special attack's lines. Its name and description are on the weapon itself, or for a copy on the weapon it copies
-- (COMBATV2_SPECIAL_ATTACK_BASE_ITEM). Recipes.augmentedFrom, which knows only the augmented ones, is the last try. Only settings
-- the item has are read (valuesOf), since a weapon without a description would give the setting's own "This weapon has a special
-- attack.". Augmented Abyssal scourge points at Abyssal scourge, which has no special, so nothing is shown. The cost is in tenths
-- of a percent (250 = 25%). The cooldown and target type are left out until their units are known.
local function itemOf(x)
    if type(x) == "number" then return try(config.Obj.FromID, x) end
    if x ~= nil and field(x, "name") == nil and type(field(x, "id")) == "number" then return try(config.Obj.FromID, field(x, "id")) end
    return x
end
local function cleanText(text)
    text = string.gsub(text, "<br>", "\n")
    text = string.gsub(text, "<[^>]*>", "")
    return text
end
local function specialLines(v, itemId)
    if num(v.COMBATV2_SPECIAL_ATTACK) ~= 1 and type(v.COMBATV2_SPECIAL_ATTACK_NAME) ~= "string" then return {} end
    local s = v
    if type(v.COMBATV2_SPECIAL_ATTACK_NAME) ~= "string" then
        local base = itemOf(v.COMBATV2_SPECIAL_ATTACK_BASE_ITEM)
        if base == nil and itemId ~= nil and Recipes and Recipes.augmentedFrom then
            local b = nil
            pcall(function() b = Recipes.augmentedFrom(itemId) end)
            base = itemOf(b)
        end
        if base == nil then return {} end
        local ok, bv = pcall(valuesOf, base)
        if not ok or type(bv.COMBATV2_SPECIAL_ATTACK_NAME) ~= "string" then return {} end
        s = bv
    end
    local lines = { "Special Attack: " .. s.COMBATV2_SPECIAL_ATTACK_NAME }
    local desc = s.COMBATV2_SPECIAL_ATTACK_DESCRIPTION
    if type(desc) == "string" and desc ~= "" then
        for part in string.gmatch(cleanText(desc), "[^\n]+") do lines[#lines + 1] = part end
    end
    local cost = num(v.COMBATV2_SPECIAL_ATTACK_ADREN_REQ) or num(s.COMBATV2_SPECIAL_ATTACK_ADREN_REQ)
    if cost ~= nil and cost > 0 then lines[#lines + 1] = "Adrenaline: " .. pct(cost / 10) end
    local needs, seen = {}, {}
    for _, key in ipairs({ "COMBATV2_SPECIAL_ATTACK_REQUIRES_ITEM", "COMBATV2_SPECIAL_ATTACK_REQUIRES_ITEM_ALTERNATIVE",
        "COMBATV2_SPECIAL_ATTACK_REQUIRES_ITEM_ALTERNATIVE2", "COMBATV2_SPECIAL_ATTACK_REQUIRES_ITEM_ALTERNATIVE3" }) do
        local it = itemOf(s[key])
        local n = it and field(it, "name")
        if type(n) == "string" and n ~= "" and not seen[n] then seen[n] = true; needs[#needs + 1] = n end
    end
    if #needs > 0 then lines[#lines + 1] = "Needs: " .. table.concat(needs, " or ") end
    local kinds = {}
    if num(s.COMBATV2_INSTANT_SPECIAL_ATTACK) == 1 then kinds[#kinds + 1] = "instant" end
    if num(s.COMBATV2_NO_TARGET_SPECIAL_ATTACK) == 1 then kinds[#kinds + 1] = "needs no target" end
    if num(s.COMBATV2_CHANNELED_SPECIAL_ATTACK) == 1 then kinds[#kinds + 1] = "channelled" end
    if num(s.COMBATV2_SPECIAL_ATTACK_PVP_DISABLED) == 1 then kinds[#kinds + 1] = "not in PvP" end
    if #kinds > 0 then
        local t = table.concat(kinds, ", ") -- as in "Instant, needs no target, not in PvP"
        lines[#lines + 1] = string.upper(string.sub(t, 1, 1)) .. string.sub(t, 2)
    end
    return lines
end

-- The game's words as lines: its <br> breaks a line, its other marks (<col=...>) are not shown, and a sentence that ends with no space
-- after it starts a new line, as in the game's box.
local function addWords(lines, text)
    text = string.gsub(text, "<br>", "\n")
    text = string.gsub(text, "<[^>]*>", "")
    text = string.gsub(text, "([%.!%?])([^%s%d%.])", "%1\n%2")
    for part in string.gmatch(text, "[^\n]+") do lines[#lines + 1] = part end
end
-- The box for one item: a list of lines (empty for an item with no combat settings).
function Stats.box(obj, name, itemId)
    lookUp()
    local v = valuesOf(obj)
    local cat = catName(field(obj, "category"))
    local kind = v.WEAPON_CATEGORY
    local kindName = kind and (field(kind, "configName") or field(kind, "name")) or nil
    local class = nil
    for _, c in ipairs(CLASSES) do
        if num(v["COMBATV2_" .. c[2] .. "_WEAPON"]) == 1 or num(v["COMBATV2_" .. c[2] .. "_ITEM"]) == 1 then class = c[1] break end
    end
    -- "All" is for every style, with the all-styles defence setting (Void knight top, Cape of legends). "Hybrid" is without it
    -- (Battle-mage robe, Ring of death).
    if class == nil and num(v.COMBATV2_GENERIC_ITEM) == 1 then class = (v.COMBATV2_GENERICDEFENCE ~= nil) and "All" or "Hybrid" end
    local ammo = cat ~= nil and cat:find("^AMMO_") ~= nil
    if class == nil and ammo and num(v.RANGED_STRENGTH) then class = "Ranged" end
    local weapon = kind ~= nil or ammo
    for _, c in ipairs(CLASSES) do if num(v["COMBATV2_" .. c[2] .. "_WEAPON"]) == 1 then weapon = true end end
    local lname = string.lower(name or "")
    local defender = num(v.COMBATV2_ITEM_IS_DEFENDER) == 1
    local offhand = defender or lname:find("^off%-hand") ~= nil or lname:find(" off%-hand") ~= nil
        or (type(kindName) == "string" and (kindName:find("OFFHAND") or kindName:find("LANTERN")) ~= nil)
    -- The tier: its tier setting; otherwise the level needed to wear it, for a weapon in any skill and for anything else only Defence
    -- (1) or Necromancy (28). Ranger boots need Ranged 40 and show no tier; Battle-mage robe needs Magic, Strength and Defence 85: Tier 85.
    local tier = num(v.COMBATV2_ITEM_TIER)
    if tier == nil then
        for i = 1, 3 do
            local skill, level = num(v["WEAR_REQUIRES_STAT" .. i]), num(v["WEAR_REQUIRES_STAT_LEVEL" .. i])
            if level ~= nil and (weapon or skill == 1 or skill == 28) then tier = level break end
        end
    end
    local lines = {}
    local stored = num(v.COMBATV2_PLAYER_ARMOUR)
    local function armourLine()
        local t, s = armourTier(stored, tier, cat)
        local label = ""
        local isShield = num(v.COMBATV2_ITEM_IS_SHIELD) == 1 or cat == "ARMOUR_SHIELD" -- Dragon sq shield shows no tier label
        if not isShield and tier ~= nil and t ~= nil and t ~= tier then label = " (Tier " .. t .. ")" end
        if not isShield and tier ~= nil and t == nil and not noShare(cat) then label = " (Tier ?)" end
        lines[#lines + 1] = "Armour: " .. fmt(math.floor(stored / 10)) .. label
        return s
    end
    if weapon then
        local s = class and STRENGTH[class] and num(v[STRENGTH[class]])
        -- A weapon that takes ammo and keeps 0 here gets its damage from the ammo (Malachi's tooth), and the game shows no line.
        if s and (s > 0 or v.AMMOCATEGORY == nil) then lines[#lines + 1] = "Damage: " .. fmt(math.floor(s / (offhand and 20 or 10))) end
        local acc = class and ATTACK[class] and num(v[ATTACK[class]])
        -- A pickaxe: its mining numbers are in a game table row (rock penetration, lowest damage, level). With no accuracy of its own the
        -- game shows tier 1's ("Accuracy: 110 (Tier 1)") and "Level : 60" in place of the Tier line (Dragon pickaxe).
        local pick = nil
        if v.MINING_PICKAXE_STAT_DATA ~= nil then
            local row = v.MINING_PICKAXE_STAT_DATA
            local function col(c) local x = nil; pcall(function() x = row:GetColumnValues(c)[1] end); return num(x) end
            pick = { pen = col(1), low = col(2), level = col(3) }
            if acc == nil then acc = math.floor(2.5 * tierValue(1)) end
        end
        if acc and not offhand then
            local t = accuracyTier(acc)
            lines[#lines + 1] = "Accuracy: " .. fmt(acc) .. ((t == nil and " (Tier ?)") or (tier ~= nil and t ~= tier and (" (Tier " .. t .. ")")) or "")
        end
        local a = kind and attackTypeOf(kind)
        if a and STYLE[a] then lines[#lines + 1] = STYLE[a] end
        if stored and stored > 0 then armourLine() end
        if num(v.COMBATV2_PRAYER_DRAIN_RESIST) then lines[#lines + 1] = "Prayer Bonus: " .. v.COMBATV2_PRAYER_DRAIN_RESIST end
        lines[#lines + 1] = "Type: " .. tostring(class or "?")
        if not ammo then lines[#lines + 1] = "Range: " .. tostring(num(v.ATTACKRANGE) or 1) end
        if pick ~= nil and pick.level ~= nil then
            -- The top damage is the lowest plus the level: Dragon 33 to 93, Elder rune 45 to 135, Earth and song 50 to 140.
            lines[#lines + 1] = "Level : " .. pick.level
            if pick.low ~= nil then lines[#lines + 1] = "Mining damage : " .. pick.low .. " - " .. (pick.low + pick.level) end
            if pick.pen ~= nil then lines[#lines + 1] = "Rock penetration : " .. pick.pen end
        else
            lines[#lines + 1] = "Tier: " .. tostring(tier or "?")
        end
        if defender then lines[#lines + 1] = "Acts as a shield" end
        if num(v.COMBATV2_NECROMANCY_UNDERWORLD_CONDUIT) == 1 then lines[#lines + 1] = "Underworld Conduit" end
    else
        local shield = num(v.COMBATV2_ITEM_IS_SHIELD) == 1 or cat == "ARMOUR_SHIELD"
        local share = nil
        if stored then share = armourLine() end
        local power = false
        for _, c in ipairs(CLASSES) do
            local s = num(v[STRENGTH[c[1]]])
            if s and s > 0 then power = true; lines[#lines + 1] = c[1] .. " Damage Bonus: " .. tenth(s) end
        end
        -- Tank / Power, damage reduction and the worked-out life points: one style, one of the five armour slots
        local slotted = stored ~= nil and share ~= nil and share >= 0.125 and not shield and class ~= nil and class ~= "All" and class ~= "Hybrid"
        local tank = slotted and not power
        if tank and tier then lines[#lines + 1] = "Damage Reduction: " .. pct(tier * 0.02) end
        local lp = num(v.CONSTITUTION_INCREASE)
        if lp == nil and tank and tier and share then lp = tier * ((share >= 0.55 and 15) or (share >= 0.5 and 10) or 5) end
        if lp and lp > 0 then lines[#lines + 1] = "Life Points Bonus: " .. fmt(lp) end
        if num(v.COMBATV2_PRAYER_DRAIN_RESIST) then lines[#lines + 1] = "Prayer Bonus: " .. v.COMBATV2_PRAYER_DRAIN_RESIST end
        if class then lines[#lines + 1] = "Type: " .. class .. (slotted and (power and " (Power)" or " (Tank)") or "") end
        if tier then lines[#lines + 1] = "Tier: " .. tier end
        if shield then lines[#lines + 1] = "Shield" end
    end
    -- the passive's name (its text is not in the game's data) and the effect's text
    if v.COMBATV2_ITEM_PASSIVE_STRUCT ~= nil then
        local pn = inside(v.COMBATV2_ITEM_PASSIVE_STRUCT, P_NAME)
        if type(pn) == "string" then lines[#lines + 1] = "Passive: " .. pn end
    end
    if v.COMBATV2_ITEM_EFFECT_STRUCT ~= nil then
        local e = v.COMBATV2_ITEM_EFFECT_STRUCT
        local text = inside(e, P_INFO)
        if type(text) == "string" and text ~= "" then
            local when = (inside(e, PS.COMBATV2_ABILITY_INFO_ONDAMAGE_ACTIVATION) == 1 and "When damaged: ")
                or (inside(e, PS.COMBATV2_ABILITY_INFO_ONKILL_ACTIVATION) == 1 and "Upon killing a target: ") or ""
            -- The effect's name first, when it has one, as in the game's box: "Soul Gaze: Increases your base ability damage ..."
            local en = inside(e, P_NAME)
            if type(en) == "string" and en ~= "" then when = en .. ": " .. when end
            text = string.gsub(text, "<br>", "\n") -- the game's line break mark
            text = string.gsub(text, "<[^>]*>", "") -- and its other marks, <col=...>, are not shown as text
            -- A sentence that ends with no space after it starts a new line, as in the game's box: the defender's "...+20% accuracy.+3%
            -- accuracy.", Ring of death's "...5% adrenaline.On death: ...".
            text = string.gsub(text, "([%.!%?])([^%s%d%.])", "%1\n%2")
            local first = true
            for part in string.gmatch(text, "[^\n]+") do
                lines[#lines + 1] = (first and when or "") .. part
                first = false
            end
        end
    end
    -- An enchantment it can take (Hexhunter bow), dim as in the game's box while the item has none: "Enchantment Effect:", "Requires:
    -- Enchantment of dispelling." and what it does. These are the game's words for it not being on, which is how the item comes.
    if v.COMBATV2_ITEM_ENCHANTMENT_EFFECT_STRUCT_INACTIVE ~= nil then
        local text = inside(v.COMBATV2_ITEM_ENCHANTMENT_EFFECT_STRUCT_INACTIVE, P_INFO)
        if type(text) == "string" and text ~= "" then
            lines[#lines + 1] = PIECE .. "Enchantment Effect:"
            local need = field(v.COMBATV2_ITEM_ENCHANTMENT_ITEM, "name")
            if type(need) == "string" and need ~= "" then lines[#lines + 1] = PIECE .. "Requires: " .. need .. "." end
            local words = {}
            addWords(words, text)
            for _, w in ipairs(words) do lines[#lines + 1] = PIECE .. w end
        end
    end
    -- a herb bomb: what it does when thrown
    if v.HERB_BOMB_STRUCT ~= nil then
        local text = inside(v.HERB_BOMB_STRUCT, P_INFO)
        if type(text) == "string" and text ~= "" then addWords(lines, text) end
    end
    -- The special attack, after the passive as in the game's box: only its name (Fractured Staff of Armadyl, Malachi's tooth). What it
    -- does and its cost are not in the game's box.
    if weapon then for _, l in ipairs(specialLines(v, itemId)) do if string.sub(l, 1, 15) == "Special Attack:" then lines[#lines + 1] = l end end end
    if v.COMBATV2_ITEM_SET_STRUCT ~= nil then
        if #lines > 0 then lines[#lines + 1] = "" end -- a blank line before the set, as in the game's box
        for _, l in ipairs(setLines(v.COMBATV2_ITEM_SET_STRUCT)) do lines[#lines + 1] = l end
    end
    -- A scrimshaw's life, as in the game's box: "3:00:00 remaining" (POP_LIFESPAN is in game ticks of 0.6 seconds: 18000 = 3 hours).
    local life = num(v.POP_LIFESPAN)
    if life ~= nil and life > 0 then
        local secs = life * 6 // 10
        lines[#lines + 1] = string.format("%d:%02d:%02d remaining", secs // 3600, (secs % 3600) // 60, secs % 60)
    end
    -- The game's own extra hover words, on any item, worn or not: "Illuminates dark areas.", "Provides limited teleports to various
    -- resource locations." (TOOLTIP_EXTRA_INFO), "Note: has a chance to be destroyed..." (OBJ_INFO_EXTRA).
    local blank = #lines > 0
    for _, n in ipairs({ "TOOLTIP_EXTRA_INFO", "OBJ_INFO_EXTRA" }) do
        local text = v[n]
        if type(text) == "string" and text ~= "" then
            if blank then lines[#lines + 1] = ""; blank = false end
            addWords(lines, text)
        end
    end
    return lines
end

-- Food, worded as the game's hover box: "Heals: 1,400" and "Consumes up to 3% Adrenaline while in combat." (Swordfish, Jug of
-- wine). The game keeps the amount itself (FOOD_HEAL: Swordfish 1400). A few foods heal a share of the life points too
-- (FOODHEALPERCENT), heal more over time (Baron shark), can heal above the most life points (COMBATV2_CONSTITUTION_BOOST_PERCENT:
-- Rocktail), restore prayer, or are eaten with no wait (COMBATV2_FOOD_NO_DELAY: Cooked karambwan, whose own effect words say
-- "Doesn't drain adrenaline."). Returns the lines and whether the item is food that heals.
local FOOD = { "FOOD_PORTIONS", "FOOD_HEAL", "FOODHEALPERCENT", "FOOD_PRAYER_PERCENT", "FOOD_PRAYER_ABS", "COMBATV2_CONSTITUTION_BOOST_PERCENT",
    "FOOD_HEALTH_REGEN_PER_TWO_TICKS", "FOOD_HEALTH_REGEN_DURATION_SECONDS", "COMBATV2_FOOD_NO_DELAY", "COMBATV2_RANDOM_HEALING",
    "COMBATV2_ITEM_EFFECT_STRUCT" }
local FP = nil
local GREEN = "00ff00"
function Stats.foodLines(obj)
    if FP == nil then FP = {}; for _, n in ipairs(FOOD) do pcall(function() FP[n] = config.Param[n] end) end end
    local f = {}
    for n, p in pairs(FP) do pcall(function() if obj:HasParam(p) then f[n] = obj:GetParamValue(p) end end) end
    local heal, pct = num(f.FOOD_HEAL), num(f.FOODHEALPERCENT)
    -- Food eaten in bites shows one bite's heal, as in the game's Summer pie box: 2,375 in 2 bites = "Heals: 1,187".
    local bites = num(f.FOOD_PORTIONS)
    if heal ~= nil and bites ~= nil and bites > 1 then heal = heal // bites end
    local lines = {}
    local function add(text, markup) lines[#lines + 1] = { text = text, markup = markup } end
    local function green(w) return "<col=" .. GREEN .. ">" .. w .. "</col>" end
    local heals = (heal ~= nil and heal > 0) or (pct ~= nil and pct > 0)
    if heals then
        local w = ((heal ~= nil and heal > 0) and withCommas(heal) or "") .. ((pct ~= nil and pct > 0) and (((heal ~= nil and heal > 0) and " + " or "") .. pct .. "%") or "")
        if num(f.COMBATV2_RANDOM_HEALING) == 1 then w = "up to " .. w end
        add("Heals: " .. w, "Heals: " .. green(w))
        -- As in the game's Rocktail box, the over-heal line comes before the adrenaline line, with "Life Points" and "Adrenaline" in their
        -- own colours.
        local over = num(f.COMBATV2_CONSTITUTION_BOOST_PERCENT)
        if over ~= nil and over > 0 then
            add("Allows overhealing up to " .. over .. "% of your maximum Life Points.",
                "Allows overhealing up to " .. green(over .. "%") .. " of your maximum <col=ed705a>Life Points</col>.")
        end
        if num(f.COMBATV2_FOOD_NO_DELAY) == 1 then
            -- HAND-TYPED (not read from the game: check again after a game update): the words "Doesn't drain adrenaline."
            if f.COMBATV2_ITEM_EFFECT_STRUCT == nil then add("Doesn't drain adrenaline.", "Doesn't drain <col=00ffff>adrenaline</col>.") end
        else
            add("Consumes up to 3% Adrenaline while in combat.", "Consumes up to 3% <col=deac18>Adrenaline</col> while in combat.")
        end
    end
    local regen, secs = num(f.FOOD_HEALTH_REGEN_PER_TWO_TICKS), tonumber(f.FOOD_HEALTH_REGEN_DURATION_SECONDS)
    if regen ~= nil and regen > 0 then
        local w = withCommas(regen)
        add("Then heals " .. w .. " every 2 ticks" .. (secs and (" for " .. secs .. " seconds") or "") .. ".",
            "Then heals " .. green(w) .. " every 2 ticks" .. (secs and (" for " .. secs .. " seconds") or "") .. ".")
    end
    local pa, pp = num(f.FOOD_PRAYER_ABS), num(f.FOOD_PRAYER_PERCENT)
    if pa ~= nil and pa > 0 then add("Restores " .. withCommas(pa) .. " prayer points.", "Restores " .. green(withCommas(pa)) .. " prayer points.") end
    if pp ~= nil and pp > 0 then add("Restores " .. pp .. "% prayer points.", "Restores " .. green(pp .. "%") .. " prayer points.") end
    return lines, heals
end

-- The words in the normal colour and the numbers in the game's light blue, like its hover box (ui/details.lua shows .markup when the line
-- does not need wrapping).
local VALUE_COLOUR = "00ff00" -- green, as in the game's box
local COLOURED = { Adrenaline = true, Damage = true, Accuracy = true, Style = true, Ammo = true, ["Prayer Bonus"] = true, Type = true, Range = true, -- not Tier, which is white in the game's box
    Armour = true, ["Damage Reduction"] = true, ["Life Points Bonus"] = true,
    ["Level "] = true, ["Mining damage "] = true, ["Rock penetration "] = true } -- a pickaxe's "Level : 60"
local function markup(line, col)
    local label, value = string.match(line, "^([^:]+): (.+)$")
    if label == nil or not (COLOURED[label] or label:find(" Damage Bonus$")) then return nil end
    return plain(label) .. ": <col=" .. (col or VALUE_COLOUR) .. ">" .. plain(value) .. "</col>"
end

-- The game's comparison colours. The game colours a number by the item worn in the same place: green when it is higher, white
-- when the same, red when lower (Dragon dagger with an Abyssal whip wielded: 576 and 1,132 red). A word (Style, Type, Ammo) is
-- white when the same and light blue when different (Stabbing against the whip's Slashing). With nothing worn there, numbers are
-- compared with nothing (an empty hand's range is 1: "Range: 1" white) and words are green. Tier lines are never coloured.
-- The game does not tell a plugin which place an item goes in: a weapon is the main hand (worn slot 4), a shield, defender or
-- off-hand weapon the off-hand (6), armour by its kind (ARMOUR_BODY ...), anything else by a worn item of the same kind.
local WORN_SLOT = { ARMOUR_HELMET = 1, ARMOUR_CAPE = 2, ARMOUR_BODY = 5, ARMOUR_SHIELD = 6, ARMOUR_LEGS = 8, ARMOUR_HANDS = 10, ARMOUR_FEET = 11 }
local COMPARE = { Damage = true, Accuracy = true, Range = true, Armour = true, ["Prayer Bonus"] = true, ["Life Points Bonus"] = true,
    ["Damage Reduction"] = true }
local COMPARE_WORDS = { Style = true, Type = true, Ammo = true }
local BASE = { Range = 1 }
local wornMaps = {} -- a worn item's lines by label, by its item number; they never change
local function wornObjAt(inv, i)
    local o = nil
    pcall(function() local s = inv:GetSlot(i); local ob = s and s.obj; if ob ~= nil and type(ob.id) == "number" and ob.id >= 0 then o = ob end end)
    return o
end
local function statMap(o)
    local oid = field(o, "id")
    if oid ~= nil and wornMaps[oid] ~= nil then return wornMaps[oid] end
    local map = {}
    local ok, lines = pcall(Stats.box, o, field(o, "name") or "", oid)
    if ok and type(lines) == "table" then
        for _, l in ipairs(lines) do
            local label, value = string.match(l, "^([^:]+): (.+)$")
            if label ~= nil and map[label] == nil then map[label] = value end
        end
    end
    if oid ~= nil then wornMaps[oid] = map end
    return map
end
-- true and the worn item's lines, false when that place is empty, or nil when it cannot be told
local function wornFor(obj)
    lookUp()
    local v = valuesOf(obj)
    local cat = catName(field(obj, "category"))
    local lname = string.lower(tostring(field(obj, "name") or ""))
    local kind = v.WEAPON_CATEGORY
    local kindName = kind and (field(kind, "configName") or field(kind, "name")) or nil
    local slot = nil
    if num(v.COMBATV2_ITEM_IS_DEFENDER) == 1 or num(v.COMBATV2_ITEM_IS_SHIELD) == 1 or cat == "ARMOUR_SHIELD" or lname:find("^off%-hand") ~= nil
        or lname:find(" off%-hand") ~= nil or (type(kindName) == "string" and (kindName:find("OFFHAND") or kindName:find("LANTERN")) ~= nil) then
        slot = 6
    else
        for _, c in ipairs(CLASSES) do if num(v["COMBATV2_" .. c[2] .. "_WEAPON"]) == 1 then slot = 4 end end
    end
    if slot == nil and cat ~= nil then slot = WORN_SLOT[cat] end
    -- Amulets and rings mostly have no kind in the game's data (Amulet of fury, Warrior ring), so they are told by their name.
    if slot == nil then
        if lname:find("amulet") or lname:find("necklace") or lname:find("pendant") or lname:find("stole") then slot = 3
        elseif lname:find("%f[%a]ring%f[%A]") then slot = 13 end
    end
    local inv = nil
    pcall(function() inv = Inventory.Find(config.Inv.WORN) end)
    if inv == nil then return nil end
    if slot ~= nil then
        local o = wornObjAt(inv, slot)
        if o ~= nil then return true, statMap(o) end
        return false, nil
    end
    if cat == nil then return nil end
    for i = 1, 20 do
        local o = wornObjAt(inv, i)
        if o ~= nil and catName(field(o, "category")) == cat then return true, statMap(o) end
    end
    return false, nil
end
local function leadNum(s)
    local n = type(s) == "string" and string.match(s, "^%-?[%d,]+%.?%d*") or nil
    return n and tonumber((string.gsub(n, ",", ""))) or nil
end
local function compareColours(out, obj)
    local any = false
    for _, o in ipairs(out) do
        local lb = string.match(o.text, "^([^:]+): ")
        if lb ~= nil and (COMPARE[lb] or COMPARE_WORDS[lb] or lb:find(" Damage Bonus$")) then any = true break end
    end
    if not any then return end
    local ok, found, map = pcall(wornFor, obj)
    if not ok or found == nil then return end
    -- When the two are of a different Type ("All" against "Melee"), the game does not compare them and every value is light blue
    -- (Obsidian cape against a worn Fire cape).
    local typeDiffers = false
    if found and map ~= nil and map.Type ~= nil then
        for _, o in ipairs(out) do
            local t = string.match(o.text, "^Type: (.+)$")
            if t ~= nil and t ~= map.Type then typeDiffers = true end
        end
    end
    for _, o in ipairs(out) do
        local lb, val = string.match(o.text, "^([^:]+): (.+)$")
        if lb ~= nil and (COMPARE[lb] or COMPARE_WORDS[lb] or lb:find(" Damage Bonus$")) then
            local col = VALUE_COLOUR
            local w = (found and map ~= nil) and map[lb] or nil
            if typeDiffers then
                col = "00ffff"
            elseif COMPARE_WORDS[lb] then
                if found and w ~= nil then
                    if w == val then col = nil else col = "00ffff" end
                end
            else
                local n = leadNum(val)
                local base = (w ~= nil and leadNum(w)) or BASE[lb] or 0
                if n ~= nil then
                    if n > base then col = VALUE_COLOUR elseif n == base then col = nil else col = "ff0000" end
                end
            end
            o.markup = col and (plain(lb) .. ": <col=" .. col .. ">" .. plain(val) .. "</col>") or nil
        end
    end
end

-- The stats lines for an item: { text = the plain words, markup = the coloured version or nil }.
function Stats.lines(itemId, obj)
    obj = obj or try(config.Obj.FromID, itemId)
    if obj == nil then return {} end
    local ok, lines = pcall(Stats.box, obj, field(obj, "name") or "", itemId)
    if not ok or type(lines) ~= "table" then return {} end
    local out = {}
    local col = VALUE_COLOUR -- green for worn and wielded alike, as in the game's Blood amulet of fury box
    for _, l in ipairs(lines) do
        if string.sub(l, 1, 1) == WHITE_LINE then
            local t = string.sub(l, 2)
            out[#out + 1] = { text = t, markup = "<col=ffffff>" .. plain(t) .. "</col>", colour = "ffffff" }
        elseif string.sub(l, 1, 1) == PIECE then -- a set's piece: dim grey
            local t = string.sub(l, 2)
            out[#out + 1] = { text = t, markup = "<col=909090>" .. plain(t) .. "</col>", colour = "909090" } -- kept when it wraps
        else
            local label, rest = string.match(l, "^(Set Bonus[^:]-:)%s?(.*)$")
            if label ~= nil then -- "Set Bonus (1) :" dim, as in the game's box
                out[#out + 1] = { text = l, markup = "<col=909090>" .. plain(label) .. "</col> " .. plain(rest) }
            else
                out[#out + 1] = { text = l, markup = markup(l, col) }
            end
        end
    end
    compareColours(out, obj) -- colours the numbers by comparison with the item worn
    return out
end
-- The hover box's title: the item's name, with no "Wield" or "Use" in front.
function Stats.title(obj)
    -- Just the item's name, in light gold: "Clean harralander", "Headless arrow", with no "Use", "Wield" or "Drink" in front.
    local name = tostring(field(obj, "name") or "")
    return name, "<col=f8d56b>" .. plain(name) .. "</col>"
end

end }
