-- Too Many Runes - More facts about an item, read from the game's own tables
-- Read while the plugin walks every data row once (recipes/guides.lua, Recipes.rowsStep, calls Extras.row for each), then shown
-- when an item is opened (the hover box in ui/details.lua calls Extras.lines and the hover functions below). All of it is the
-- game's data:
--   Familiars (table LORE): column 4 what the familiar does, 6 the pouch, 7 the scroll, 8 what the scroll does, 15 the familiar.
--   Potions (HERBLORE_POTION): column 2 the potion's dose bundle (the struct an item's POTION_STRUCT points at), 3 its effects (a struct
--     of POTION_INFO_ settings; some items point at that struct themselves, with POTION_INFO).
--   Teleport jewellery (TELEPORT_LIST_CATEGORY): column 1 its name, 2 the item; its places are the rows TELEPORT_JEWELLERY_<same name>_...
--     (table TELEPORT_DESTINATIONS, column 1 the place).
--   Monolith relics (ARCH_RELIC): column 2 the relic, 3 what it does, 10 the item it is tied to.
--   Currencies (CURRENCY_TABLE): column 5 the item, 6 the currency's name.
--   Archaeology books (BOOK): column 4 the tablet or page; mysteries (ARCH_MYSTERY): column 2 the mystery, 4 its dig site, 5 its books.
--   Farm animals: the item's own POF_ANIMAL_DB setting points at its row in POF_ANIMAL_TABLE: column 6 the animal, 7 its description.
-- Not here: the Invention perks (no item links to them) and the farm animals' foods (no link from an animal to its food type).
return { run = function(T)
local _ENV = T

Extras = { familiars = {}, potionInfo = {}, jewellery = {}, places = {}, relics = {}, currencies = {}, books = {}, mysteries = {},
           sites = {}, cache = {} }
local TEXT_MAX = 220 -- a long description is cut here, so the box stays a sensible size

local function cut(s)
    if type(s) ~= "string" then return nil end
    s = string.gsub(s, "<br>", " ")
    s = string.gsub(s, "<[^>]*>", "") -- the game's colour marks, <col=0x00ffff> ... </col>, are not shown as text
    s = string.gsub(s, "%s+", " ")
    if #s > TEXT_MAX then s = string.sub(s, 1, TEXT_MAX - 3) .. "..." end
    return s
end
local function first(row, c)
    local values = Recipes.rowValues(row, c)
    if values == nil then return nil end
    return valueAt(values, 1)
end
local function all(row, c)
    local values, n = Recipes.rowValues(row, c)
    local list = {}
    if values ~= nil and type(n) == "number" then for k = 1, math.min(n, 40) do list[#list + 1] = valueAt(values, k) end end
    return list
end
local function objId(v) if field(v, "typeName") == "Obj" then return field(v, "id") end return nil end
local function startsWith(s, p) return string.sub(s, 1, #p) == p end
local function tableOf(row) return field(field(row, "ownerDBTable"), "configName") end

-- A familiar's row of the game's LORE table, kept for its pouch and its scroll. Returns it.
function Extras.keepFamiliar(row)
    local pouch, scroll = objId(first(row, 6)), objId(first(row, 7))
    local npcName = field(first(row, 15), "name")
    local f = { familiar = (type(npcName) == "string" and npcName ~= "") and npcName or nil, does = cut(first(row, 4)),
                pouch = pouch, scroll = scroll, scrollDoes = cut(first(row, 8)),
                -- More LORE table columns: 2 the Summoning level, 3 the minutes it lasts, 5 its default combat mode, 11 the scroll's familiar spell
                -- points. Columns 4 and 8 are kept whole, with the game's colours and line breaks.
                level = first(row, 2), minutes = first(row, 3), mode = first(row, 5), points = first(row, 11),
                doesRaw = first(row, 4), scrollDoesRaw = first(row, 8) }
    if pouch ~= nil then Extras.familiars[pouch] = f end
    if scroll ~= nil and Extras.familiars[scroll] == nil then Extras.familiars[scroll] = f end
    return f
end
-- Finds a familiar's row at once, for its pouch or scroll, without waiting for the data pass, so its hover box is not empty until
-- the recipes are ready. A pouch's game name is its row's name (LORE_MINOTAUR_4). A scroll is made from its pouch (its recipe's
-- first ingredient), whose row is then found the same way. Only items whose game name starts LORE_ are looked at, and a miss is
-- remembered.
local notFamiliar = {}
local function loreRow(cfg)
    local row = nil
    if type(cfg) == "string" and cfg ~= "" then pcall(function() row = config.DBRow[cfg] end) end
    if row ~= nil and tableOf(row) == "LORE" then return row end
    return nil
end
function Extras.familiarNow(itemId, obj)
    if Extras.familiars[itemId] ~= nil then return Extras.familiars[itemId] end
    if notFamiliar[itemId] then return nil end
    obj = obj or try(config.Obj.FromID, itemId)
    local cfg = field(obj, "configName")
    if type(cfg) ~= "string" or not startsWith(string.upper(cfg), "LORE_") then notFamiliar[itemId] = true; return nil end
    local row = loreRow(cfg)
    if row ~= nil and objId(first(row, 6)) == itemId then return Extras.keepFamiliar(row) end
    -- a scroll: the pouch it is made from
    local pouchObj = nil
    for _, e in ipairs(fieldList(obj, "RECIPE_INGREDIENT_TYPE_1")) do
        if e.name == "RECIPE_INGREDIENT_TYPE_1" then pouchObj = e.value end
    end
    row = loreRow(field(pouchObj, "configName"))
    if row ~= nil and objId(first(row, 7)) == itemId then return Extras.keepFamiliar(row) end
    notFamiliar[itemId] = true
    return nil
end

-- One data row (called for every row the plugin walks). Only the rows of the tables above are kept.
function Extras.row(name, row, rowId)
    if startsWith(name, "HERBLORE_POTION_") then
        if tableOf(row) ~= "HERBLORE_POTION" then return end
        local doses, info = first(row, 2), first(row, 3)
        local id = field(doses, "id")
        if type(id) == "number" and info ~= nil then Extras.potionInfo[id] = info end
    elseif startsWith(name, "LORE_") then
        if tableOf(row) ~= "LORE" then return end
        Extras.keepFamiliar(row)
    elseif startsWith(name, "TELEPORT_LIST_CATEGORY_JEWELLERY_") then
        -- Also the 4 lists that name no item (Traveller's Necklace, Ferocious Ring, Dig Site pendant, Delver's anklet): their own name,
        -- column 1, finds the items (see settle).
        local item, label = objId(first(row, 2)), first(row, 1)
        Extras.jewellery[#Extras.jewellery + 1] = { item = item, key = "TELEPORT_" .. string.sub(name, 24),
            label = (type(label) == "string" and label ~= "") and string.lower(label) or nil }
    elseif startsWith(name, "TELEPORT_JEWELLERY_") then
        local place = first(row, 1)
        if type(place) == "string" and place ~= "" then Extras.places[#Extras.places + 1] = { name = name, place = place, id = rowId } end
    elseif startsWith(name, "ARCH_RELIC_") then
        if tableOf(row) ~= "ARCH_RELIC" then return end
        local item, relic = objId(first(row, 10)), first(row, 2)
        if item ~= nil and type(relic) == "string" then Extras.relics[item] = { name = relic, does = cut(first(row, 3)) } end
    elseif startsWith(name, "CURRENCY_") then
        if tableOf(row) ~= "CURRENCY_TABLE" then return end
        local item, label = objId(first(row, 5)), first(row, 6)
        if item ~= nil then Extras.currencies[item] = (type(label) == "string" and label ~= "") and label or true end
    elseif startsWith(name, "BOOK_") then
        if tableOf(row) ~= "BOOK" then return end
        local item = objId(first(row, 4))
        if item ~= nil then Extras.books[rowId] = item end
    elseif startsWith(name, "ARCH_MYSTERY_") then
        if tableOf(row) ~= "ARCH_MYSTERY" then return end
        local mystery = first(row, 2)
        if type(mystery) == "string" then
            local books = {}
            for _, b in ipairs(all(row, 5)) do local id = field(b, "id"); if type(id) == "number" then books[#books + 1] = id end end
            Extras.mysteries[#Extras.mysteries + 1] = { name = mystery, site = field(first(row, 4), "configName"), books = books }
        end
    elseif startsWith(name, "ARCH_SITE_") then
        local siteName = first(row, 3)
        if type(siteName) == "string" and siteName ~= "" then Extras.sites[name] = siteName end
    end
end

-- Worked out once, when first needed: the jewellery's places, and which mystery each tablet belongs to.
local function settle()
    if Extras.settled then return end
    Extras.settled = true
    Extras.teleports, Extras.tablets = {}, {}
    local wanted = {} -- the places, by the jewellery's name without its charges; its other charges are found in one pass below
    for _, j in ipairs(Extras.jewellery) do
        local list = {}
        for _, p in ipairs(Extras.places) do
            if p.name == j.key or startsWith(p.name, j.key .. "_") then list[#list + 1] = p end
        end
        table.sort(list, function(a, b) return a.id < b.id end)
        local names = {}
        for _, p in ipairs(list) do names[#names + 1] = p.place end
        if #names > 0 then
            -- The item the game names ("Skills necklace (4)") and its other charges ("Skills necklace (1)" ...), and the empty one. For a list
            -- that names no item, its own name is used ("Ferocious ring" finds "Ferocious ring (5)" ...).
            local base = j.label
            if j.item ~= nil then
                Extras.teleports[j.item] = names
                local slot = Items.slotOf[j.item]
                base = slot and string.match(Items.lower[slot] or "", "^(.-) %(%w+%)$") or base
            end
            if base ~= nil then wanted[base] = names end
        end
    end
    if next(wanted) ~= nil then
        -- Also "(new)" (Delver's anklet (new)), not only numbers, and never over the places the game gives an item itself. The copy with
        -- no charge in brackets ("Ferocious ring", "Skills necklace") gets them too.
        for s = 1, #Items.lower do
            local b = string.match(Items.lower[s] or "", "^(.-) %(%w+%)$") or Items.lower[s]
            if b ~= nil and wanted[b] ~= nil and Extras.teleports[Items.ids[s]] == nil then Extras.teleports[Items.ids[s]] = wanted[b] end
        end
    end
    for _, m in ipairs(Extras.mysteries) do
        local site = m.site and Extras.sites[m.site] or nil
        for _, b in ipairs(m.books) do
            local item = Extras.books[b]
            if item ~= nil then Extras.tablets[item] = { mystery = m.name, site = site } end
        end
    end
end

-- A potion's effects as words: "Strength +1 and +8%, Attack ..." and how long it lasts.
local SAY = {
    POTION_INFO_LIFE_ABS = "Life points +%s", POTION_INFO_LIFE_PCENT_CURRENT = "Life points %s%%", POTION_INFO_RUN_ENERGY = "Run energy +%s%%",
    POTION_INFO_ADRENALINE_PCENT = "Adrenaline +%s%%", POTION_INFO_ANTI_POISON = "Cures poison", POTION_INFO_CAMOUFLAGE = "Camouflage",
    POTION_INFO_ANTIFIRE_TYPE = "Dragonfire protection (level %s)", POTION_INFO_WEAPON_POISON_TIER = "Weapon poison (level %s)",
    POTION_INFO_LUCK_TIER = "Luck (level %s)", POTION_INFO_AGGRESSION = "Makes monsters aggressive",
}
local PAIRS = { PRAYER = "Prayer", SUMMONING = "Summoning", STAT_RESTORE_ALL = "Restores all stats", STAT_RESTORE_BASIC = "Restores stats" }
local function signed(n) return (n >= 0 and "+" or "") .. withCommas(n) end
local function both(abs, pct)
    local parts = {}
    if type(abs) == "number" and abs ~= 0 then parts[#parts + 1] = signed(abs) end
    if type(pct) == "number" and pct ~= 0 then parts[#parts + 1] = signed(pct) .. "%" end
    return table.concat(parts, " and ")
end
local function titleCase(word)
    return (string.gsub(string.lower(word), "(%a)([%w]*)", function(a, b) return string.upper(a) .. b end))
end
-- A potion's hover box, worded as the game's: "Temporarily increases Ranged +21" (one skill) or "Temporarily increases:" and a
-- line for each, "Temporarily reduces Attack -2", then "Stat changes are diminished by 1 point per minute." or, with a set time,
-- "Lasts 6 minutes, stat changes are static for the duration." The game works the numbers out for the player's own level: the
-- potion's settings are a number and a percent of the level (Overload: +3 and +15%, so Attack 120 gives +21 and Defence 99 gives
-- +17). So the player's level is read too (Player.GetLevelCapped: the level from XP, as in the game's box).
local GREEN, RED, BLUE = "00ff00", "ff0000", "00ffff" -- the game's own colours: its potion words say <col=0x00ffff>, and its red is FF0000
local SKILL_NAME = { HITPOINTS = "Constitution", CONSTITUTION = "Constitution" }
local function levelOf(skill)
    local lv = nil
    pcall(function() lv = Player.GetLevelCapped(SkillType[skill]) end)
    if type(lv) ~= "number" or lv <= 0 then pcall(function() lv = Player.GetLevelCapped(SkillType[string.upper(skill)]) end) end
    return (type(lv) == "number" and lv > 0) and lv or nil
end
-- Times as in the game's boxes: "6 seconds", "1 minute", "2.50 minutes" (Weapon poison, 150 seconds), "1 hour" (Luck potion).
local function timeWords(secs)
    local function say(n, one, many)
        if n == math.floor(n) then return string.format("%d", n) .. (n == 1 and one or many) end
        return string.format("%.2f", n) .. many
    end
    if secs < 60 then return say(secs, " second", " seconds") end
    if secs < 3600 then return say(secs / 60, " minute", " minutes") end
    return say(secs / 3600, " hour", " hours")
end
-- The game lists the combat skills in this order (Overload, Saradomin brew); any others come after, as stored.
local SKILL_ORDER = { ATTACK = 1, STRENGTH = 2, RANGED = 3, MAGIC = 4, DEFENCE = 5, NECROMANCY = 6 }
local function potionHover(info, isFood)
    local stats, order, pairsSeen, effects, custom, duration, life = {}, {}, {}, {}, nil, nil, nil
    local renewA, renewP = nil, nil -- prayer given back over the duration (Prayer renewal, Elder overload salve)
    local lifePct, sumRenewA, sumRenewP, specNow, specRenew = nil, nil, nil, nil, nil -- a share of life points, summoning renewal, and special attack energy now and over time
    for _, e in ipairs(fieldList(info, "POTION_INFO_")) do
        local n, v = e.name, e.value
        local pct = string.match(n, "^POTION_INFO_STAT_BONUS_PCENT_(.+)$")
        local abs = (pct == nil) and string.match(n, "^POTION_INFO_STAT_BONUS_(.+)$") or nil
        if abs ~= nil and (string.sub(abs, 1, 9) == "XP_SCALE_" or abs == "DECAY") then abs = nil end -- DECAY means the boost wears off; it is not a skill
        local skill = pct or abs
        if skill ~= nil and type(v) == "number" then
            if stats[skill] == nil then stats[skill] = {}; order[#order + 1] = skill end
            if pct then stats[skill].p = v else stats[skill].a = v end
        elseif n == "POTION_INFO_DURATION" and type(v) == "number" then duration = v
        elseif n == "POTION_INFO_CUSTOM_TEXT" and type(v) == "string" then custom = v -- kept whole: its colours and line breaks are shown
        elseif n == "POTION_INFO_LIFE_PCENT_CURRENT" and type(v) == "number" and v ~= 0 then lifePct = v -- Zamorak brew
        elseif n == "POTION_INFO_SUMMONING_GRADUAL_ABS" and type(v) == "number" then sumRenewA = v
        elseif n == "POTION_INFO_SUMMONING_GRADUAL_PCENT" and type(v) == "number" then sumRenewP = v
        elseif n == "POTION_INFO_SUMMONING_SPECIAL_MOVE_INSTANT_ABS" and type(v) == "number" and v ~= 0 then specNow = v
        elseif n == "POTION_INFO_SUMMONING_SPECIAL_MOVE_GRADUAL_ABS" and type(v) == "number" and v ~= 0 then specRenew = v
        elseif n == "POTION_INFO_ANTISANGUINE_TYPE" and type(v) == "number" and v ~= 0 then effects[#effects + 1] = { n = n, v = v, text = "" }
        elseif n == "POTION_INFO_PRAYER_GRADUAL_ABS" and type(v) == "number" then renewA = v
        elseif n == "POTION_INFO_PRAYER_GRADUAL_PCENT" and type(v) == "number" then renewP = v
        elseif n == "POTION_INFO_LIFE_ABS" and type(v) == "number" and v > 0 then life = v -- "Restores 1000 health." comes first, as in the game's box
        elseif SAY[n] ~= nil and v ~= nil and v ~= 0 and v ~= false then effects[#effects + 1] = { n = n, v = v, text = string.format(SAY[n], tostring(v)) }
        else
            for key, label in pairs(PAIRS) do
                if n == "POTION_INFO_" .. key .. "_ABS" or n == "POTION_INFO_" .. key .. "_PCENT" then pairsSeen[key] = label end
            end
        end
    end
    local up, down = {}, {}
    local place = {} for i, skill in ipairs(order) do place[skill] = i end
    table.sort(order, function(x, y)
        local a, b = SKILL_ORDER[x] or (100 + place[x]), SKILL_ORDER[y] or (100 + place[y])
        return a < b
    end)
    for _, skill in ipairs(order) do
        local a, p = stats[skill].a or 0, stats[skill].p or 0
        local name = SKILL_NAME[skill] or titleCase(skill)
        local lv = (p ~= 0) and levelOf(skill) or nil
        local words, sign
        if p == 0 or lv ~= nil then
            -- As in the game: the percent of the level with the part after the point dropped (-3.6 is -3, as Saradomin brew's -5 at 120),
            -- plus the number.
            local part = (p ~= 0) and (lv * p / 100) or 0
            part = (part >= 0) and math.floor(part) or math.ceil(part)
            local n = a + part
            words, sign = name .. " " .. signed(n), n
        else
            words, sign = name .. " " .. both(a, p), a + p -- the level could not be read: use the potion's own settings
        end
        if sign > 0 then up[#up + 1] = words elseif sign < 0 then down[#down + 1] = words end
    end
    local lines = {}
    local function add(text, markup) lines[#lines + 1] = { text = text, markup = markup } end
    local function blue(w) return "<col=" .. BLUE .. ">" .. w .. "</col>" end
    -- Prayer given back over the duration: 120 and 43% at Prayer 99 is 120 + 425 = 545 (Elder overload salve).
    local renewDone = false
    local function renewPoints()
        if renewA == nil and renewP == nil then return nil end
        local lv = (type(renewP) == "number" and renewP ~= 0) and levelOf("PRAYER") or nil
        if renewP ~= nil and renewP ~= 0 and lv == nil then return nil end
        local r = (renewA or 0) + ((lv ~= nil) and math.floor(lv * 10 * renewP / 100) or 0)
        return (r > 0) and r or nil
    end
    -- As in the game's box (Elder overload salve): what it restores and cures first, then the stat changes, then how long.
    if life ~= nil then add("Restores " .. life .. " health.", "Restores <col=" .. GREEN .. ">" .. life .. " health</col>.") end -- "1000 health" in green, as in the game's Saradomin brew box
    if lifePct ~= nil then
        -- The game's box says "Deals 648 damage.": its share of the player's life points, which a plugin cannot read.
        if lifePct < 0 then
            add("Deals " .. (-lifePct) .. "% of your life points as damage.", "Deals <col=" .. RED .. ">" .. (-lifePct) .. "% of your life points as damage</col>.")
        else
            add("Restores " .. lifePct .. "% of your life points.", "Restores <col=" .. GREEN .. ">" .. lifePct .. "%</col> of your life points.")
        end
    end
    -- In the game's order (Super restore): stats, then prayer, then summoning.
    for _, key in ipairs({ "STAT_RESTORE_ALL", "STAT_RESTORE_BASIC", "PRAYER", "SUMMONING" }) do
      local label = pairsSeen[key]
      if label ~= nil then
        local a, p = nil, nil
        for _, e in ipairs(fieldList(info, "POTION_INFO_" .. key .. "_")) do
            if e.name == "POTION_INFO_" .. key .. "_ABS" then a = e.value elseif e.name == "POTION_INFO_" .. key .. "_PCENT" then p = e.value end
        end
        local lv = (key == "PRAYER" and type(p) == "number" and p ~= 0) and levelOf("PRAYER") or nil
        local slv = (key == "SUMMONING" and type(p) == "number" and p ~= 0) and levelOf("SUMMONING") or nil
        if key == "PRAYER" and (lv ~= nil or p == nil or p == 0) then
            -- The game counts prayer points as the level x 10: 70 and 25% at Prayer 99 is 70 + 247, "Restores 317 prayer points.".
            local n = (type(a) == "number" and a or 0) + ((lv ~= nil) and math.floor(lv * 10 * p / 100) or 0)
            local r = renewPoints()
            if n > 0 and r ~= nil then
                add("Restores " .. n .. " prayer points, and renews " .. r .. " prayer points over the duration.",
                    "Restores <col=" .. GREEN .. ">" .. n .. "</col> prayer points, and renews <col=" .. GREEN .. ">" .. r .. " prayer points</col> over the duration.")
                renewDone = true
            elseif n > 0 then
                add("Restores " .. n .. " prayer points.", "Restores <col=" .. GREEN .. ">" .. n .. "</col> prayer points.")
            end
        elseif key == "SUMMONING" and (slv ~= nil or p == nil or p == 0) then
            -- Summoning points are worked out the same way as prayer points (Super restore: "Restores 327 summoning points."). The game keeps
            -- the summoning amount in tens: Summoning potion's 7 is 70, so 70 + 247 gives "Restores 317 summoning points.".
            local n = (type(a) == "number" and a * 10 or 0) + ((slv ~= nil) and math.floor(slv * 10 * p / 100) or 0)
            if n > 0 then add("Restores " .. n .. " summoning points.", "Restores <col=" .. GREEN .. ">" .. n .. "</col> summoning points.") end
        elseif key == "STAT_RESTORE_ALL" or key == "STAT_RESTORE_BASIC" then
            -- As in the game's Super restore box: "Restores negative stat changes in all stats by 8 + 25% of total level."
            local parts, marks = {}, {}
            if type(a) == "number" and a ~= 0 then parts[#parts + 1] = tostring(a); marks[#marks + 1] = blue(tostring(a)) end
            if type(p) == "number" and p ~= 0 then parts[#parts + 1] = p .. "%"; marks[#marks + 1] = blue(p .. "%") end
            if #parts > 0 then
                if key == "STAT_RESTORE_ALL" then
                    add("Restores negative stat changes in all stats by " .. table.concat(parts, " + ") .. " of total level.",
                        "Restores negative stat changes in " .. blue("all stats") .. " by " .. table.concat(marks, " + ") .. " of total level.")
                else -- as in the game's Restore potion box; "Defense" is the game's own spelling
                    -- HAND-TYPED (not read from the game: check again after a game update): the Restore potion's skill list
                    local skills = { "Attack", "Constitution", "Defense", "Magic", "Necromancy", "Prayer", "Ranged" }
                    local bl = {} for i, k in ipairs(skills) do bl[i] = blue(k) end
                    add("Restores negative stat changes in " .. table.concat(skills, ", ") .. " and Strength by " .. table.concat(parts, " + ") .. " of total level.",
                        "Restores negative stat changes in " .. table.concat(bl, ", ") .. " and " .. blue("Strength") .. " by " .. table.concat(marks, " + ") .. " of total level.")
                end
            end
        else
            local w = both(a, p)
            if w ~= "" then add(label .. " " .. w) end
        end
      end
    end
    local EFFECT_ORDER = { POTION_INFO_ANTI_POISON = 1, POTION_INFO_ANTIFIRE_TYPE = 2 } -- poison before dragonfire, as in the game's box
    for i, e in ipairs(effects) do e.i = i end
    table.sort(effects, function(x, y) return (EFFECT_ORDER[x.n] or (10 + x.i)) < (EFFECT_ORDER[y.n] or (10 + y.i)) end)
    if specNow ~= nil then add("Restores " .. specNow .. " special move points.", "Restores <col=" .. GREEN .. ">" .. specNow .. "</col> special move points.") end
    if sumRenewA ~= nil or sumRenewP ~= nil then -- Summoning renewal: "Renews 545 summoning points over the duration."
        local lv = (type(sumRenewP) == "number" and sumRenewP ~= 0) and levelOf("SUMMONING") or nil
        if lv ~= nil or not (type(sumRenewP) == "number" and sumRenewP ~= 0) then
            local r = (sumRenewA or 0) + ((lv ~= nil) and math.floor(lv * 10 * sumRenewP / 100) or 0)
            if r > 0 then add("Renews " .. r .. " summoning points over the duration.", "Renews <col=" .. GREEN .. ">" .. r .. "</col> summoning points over the duration.") end
        end
    end
    if specRenew ~= nil then add("Renews " .. specRenew .. " special move points over the duration.", "Renews <col=" .. GREEN .. ">" .. specRenew .. "</col> special move points over the duration.") end
    if not renewDone then -- a potion that only renews: Prayer renewal
        local r = renewPoints()
        if r ~= nil then add("Renews " .. r .. " prayer points over the duration.", "Renews <col=" .. GREEN .. ">" .. r .. " prayer points</col> over the duration.") end
    end
    for _, e in ipairs(effects) do
        if e.n == "POTION_INFO_ANTI_POISON" then
            add("Immediately removes poison, and grants immunity to poison.",
                "Immediately " .. blue("removes poison") .. ", and grants " .. blue("immunity") .. " to " .. blue("poison") .. ".")
        elseif e.n == "POTION_INFO_ANTIFIRE_TYPE" and tonumber(e.v) == 3 then
            add("Grants immunity from Dragonfire and Wyvernfire.", "Grants " .. blue("immunity") .. " from " .. blue("Dragonfire") .. " and " .. blue("Wyvernfire") .. ".")
        -- The rest as in the game's boxes (Antifire, Super antifire, Super energy, Adrenaline, Luck, Aggression, Camouflage, Antisanguine).
        elseif e.n == "POTION_INFO_ANTIFIRE_TYPE" and tonumber(e.v) == 2 then
            add("Grants immunity from Dragonfire.", "Grants " .. blue("immunity") .. " from " .. blue("Dragonfire") .. ".")
        elseif e.n == "POTION_INFO_ANTIFIRE_TYPE" and tonumber(e.v) == 1 then
            add("Grants slight protection from Dragonfire.", "Grants " .. blue("slight protection") .. " from " .. blue("Dragonfire") .. ".")
        elseif e.n == "POTION_INFO_RUN_ENERGY" then
            add("Restores " .. e.v .. "% run energy.", "Restores <col=" .. GREEN .. ">" .. e.v .. "% run energy</col>.")
        elseif e.n == "POTION_INFO_ADRENALINE_PCENT" then
            add("Provides " .. e.v .. "% adrenaline.", "Provides <col=" .. GREEN .. ">" .. e.v .. "% adrenaline</col>.")
        elseif e.n == "POTION_INFO_WEAPON_POISON_TIER" then
            -- Weapon poison tier 1 is 12.5%, as in the game's Weapon poison (4) box. The other tiers' numbers are not known yet.
            -- HAND-TYPED (not read from the game: check again after a game update): "12.5%"
            local pct = (tonumber(e.v) == 1) and "12.5%" or nil
            local mid = pct and (" " .. pct .. " chance per hit") or " chance per hit"
            add("Coats your weapons with poison, giving a" .. mid .. " to deal extra damage to the enemy.",
                "Coats your weapons with poison, giving a " .. blue(pct and (pct .. " chance per hit") or "chance per hit") .. " to deal extra damage to the enemy.")
        elseif e.n == "POTION_INFO_LUCK_TIER" then
            add("Grants tier " .. e.v .. " luck, which improves your chances to receive rare rewards from various activities.",
                "Grants tier " .. e.v .. " " .. blue("luck") .. ", which improves your chances to receive rare rewards from various activities.")
        elseif e.n == "POTION_INFO_AGGRESSION" then
            add("Causes nearby enemies to attack the player.", "Causes nearby enemies to " .. blue("attack the player") .. ".")
        elseif e.n == "POTION_INFO_CAMOUFLAGE" then
            add("Stops you from appearing on other player's minimaps.")
        elseif e.n == "POTION_INFO_ANTISANGUINE_TYPE" then
            -- Antisanguine type 1 is 20%, as in the game's Antisanguine (4) box. The stronger ones are type 2, and their number is not known yet.
            -- HAND-TYPED (not read from the game: check again after a game update): "by 20%"
            if tonumber(e.v) == 1 then
                add("Reduces damage from Sanguine attacks by 20%.", "Reduces damage from " .. blue("Sanguine") .. " attacks by " .. blue("20%") .. ".")
            else
                add("Reduces damage from Sanguine attacks.", "Reduces damage from " .. blue("Sanguine") .. " attacks.")
            end
        else
            add(e.text)
        end
    end
    if custom ~= nil then
        -- The game's own colours in its words (<col=0x00ffff>Surge</col>) are kept, and <br> starts a new line (Powerburst of acceleration).
        local s = string.gsub(custom, "<br%s*/?>", "\n")
        for part in string.gmatch(s, "[^\n]+") do
            local mk = string.gsub(part, "<col=0x(%x%x%x%x%x%x)>", "<col=%1>")
            local txt = cut(part)
            if txt ~= nil and txt ~= "" and txt ~= " " then add(txt, mk ~= txt and mk or nil) end
        end
    end
    local function changes(list, verb, col)
        if #list == 1 then
            add("Temporarily " .. verb .. " " .. list[1], "Temporarily " .. verb .. " <col=" .. col .. ">" .. list[1] .. "</col>")
        elseif #list > 1 then
            add("Temporarily " .. verb .. ":")
            for _, w in ipairs(list) do add(w, "<col=" .. col .. ">" .. w .. "</col>") end
        end
    end
    changes(up, "increases", GREEN)
    changes(down, "reduces", RED)
    -- A potion that heals takes no adrenaline (Saradomin brew). Food says what it takes itself (recipes/stats.lua, Stats.foodLines).
    -- HAND-TYPED (not read from the game: check again after a game update): the words "Doesn't drain adrenaline."
    if life ~= nil and not isFood then add("Doesn't drain adrenaline.", "Doesn't drain <col=" .. BLUE .. ">adrenaline</col>.") end
    local statChanges = #up + #down > 0
    if duration ~= nil and duration > 0 then
        local t = timeWords(math.floor(duration)) -- in seconds: Overload's 360 is its 6 minutes
        if statChanges then
            add("Lasts " .. t .. ", stat changes are static for the duration.",
                "Lasts <col=" .. BLUE .. ">" .. t .. ", stat changes are static</col> for the duration.")
        else
            add("Lasts " .. t .. ".", "Lasts <col=" .. BLUE .. ">" .. t .. ".</col>")
        end
    elseif statChanges then
        add("Stat changes are diminished by 1 point per minute.", "Stat changes are <col=" .. BLUE .. ">diminished</col> by 1 point per minute.")
    end
    return lines
end
-- The potion's hover lines for an item (its dose bundle's, or its own POTION_INFO); {} for anything else.
function Extras.potionHover(itemId, item, isFood)
    local ready = Recipes ~= nil and Recipes.rowsState ~= nil and Recipes.rowsState.ready
    if ready then settle() end
    local info = nil
    for _, e in ipairs(fieldList(item, "POTION_")) do
        if e.name == "POTION_INFO" and field(e.value, "typeName") ~= nil then info = e.value
        elseif e.name == "POTION_STRUCT" and info == nil then
            info = Extras.potionInfo[field(e.value, "id")]
            if info == nil then -- Powerbursts and Adrenaline renewal: their bundle holds its own POTION_INFO
                for _, s in ipairs(fieldList(e.value, "POTION_INFO")) do
                    if s.name == "POTION_INFO" and field(s.value, "typeName") ~= nil then info = s.value end
                end
            end
        end
    end
    if info == nil then return {} end
    return potionHover(info, isFood)
end

local function nameOf(itemId)
    local slot = itemId and Items.slotOf[itemId]
    return slot and Items.names[slot] or nil
end

-- The places an item teleports to (the game's teleport lists), or nil, shown in the hover box over the item's picture.
function Extras.teleportsOf(itemId)
    if Recipes ~= nil and Recipes.rowsState ~= nil and Recipes.rowsState.ready then settle() end
    return Extras.teleports and Extras.teleports[itemId]
end
-- The hover box's teleport line: "Teleports to: ..." from the game's lists. Otherwise, for an item that teleports (an option with
-- tele, rub, break, operate or travel in it) and names its places only in its options when worn (the Ardougne cloaks, the Karamja
-- gloves): "When worn: <those options>".
-- Between the two come the places from the RuneScape Wiki (data/wiki_teleports.lua), under a heading with the wiki's button
-- ({ wiki = true, text = "Info:" }, as the tabs mark wiki information), only when the game's lists give the item nothing.
local TELE_WORDS = { "tele", "rub", "break", "operate", "travel" }
local function isTeleOp(op)
    local l = string.lower(op)
    for _, w in ipairs(TELE_WORDS) do if l:find(w, 1, true) then return true end end
    return false
end
local P_WEAR_OP = nil
function Extras.teleportLines(itemId, obj)
    local places = Extras.teleportsOf(itemId)
    if places ~= nil and #places > 0 then return { "Teleports to: " .. table.concat(places, ", ") } end
    local wiki = WikiTeleports and WikiTeleports[itemId]
    if wiki ~= nil and #wiki > 0 then return { { wiki = true, text = "Info:" }, "Teleports to: " .. table.concat(wiki, ", ") } end
    obj = obj or try(config.Obj.FromID, itemId)
    if obj == nil then return {} end
    if P_WEAR_OP == nil then
        P_WEAR_OP = {}
        for i = 1, 5 do pcall(function() P_WEAR_OP[i] = config.Param["WEAR_OP" .. i] end) end
    end
    local worn, any = {}, false
    pcall(function() for _, op in pairs(obj.interfaceOpNames) do
        if type(op) == "string" and op ~= "" and isTeleOp(op) then any = true end
    end end)
    for i = 1, 5 do
        local op = nil
        if P_WEAR_OP[i] ~= nil then pcall(function() if obj:HasParam(P_WEAR_OP[i]) then op = obj:GetParamValue(P_WEAR_OP[i]) end end) end
        if type(op) == "string" and op ~= "" then worn[#worn + 1] = op; if isTeleOp(op) then any = true end end
    end
    if any and #worn > 0 then return { "When worn: " .. table.concat(worn, ", ") } end
    return {}
end
-- A Summoning pouch's or scroll's hover box lines, as in the game's boxes (War tortoise pouch, Macaw pouch, Compost Mound scroll
-- ...): { text, markup } each, or an empty list. The words in colour are the game's own; its colour marks and line breaks are kept.
-- The game's default combat modes: 0 and 1 Aggressive (Mithril minotaur, War tortoise), 2 Passive (Bunyip), 3 Cannot fight (Macaw,
-- Fruit bat).
-- "1.8s cooldown." is in every scroll's box in the game but not in the table, so it is written here.
-- HAND-TYPED (not read from the game: check again after a game update): "1.8s cooldown." (twice below) and the combat mode words
local MODE_WORDS = { [0] = "Aggressive", [1] = "Aggressive", [2] = "Passive", [3] = "Cannot fight" } -- 0 and 2 as in the game's Mithril minotaur and Bunyip pouch boxes
local function gameLines(raw, out)
    if type(raw) ~= "string" then return end
    local s = string.gsub(raw, "<br%s*/?>", "\n")
    for part in string.gmatch(s, "[^\n]+") do
        local mk = string.gsub(part, "<col=0x(%x%x%x%x%x%x)>", "<col=%1>")
        local txt = cut(part)
        if txt ~= nil and txt ~= "" and txt ~= " " then out[#out + 1] = { text = txt, markup = (mk ~= txt) and mk or nil } end
    end
end
local function gold(w) return "<col=f8d56b>" .. plain(w) .. "</col>" end
function Extras.familiarHover(itemId)
    if Recipes ~= nil and Recipes.rowsState ~= nil and Recipes.rowsState.ready then settle() end
    local f = Extras.familiars[itemId]
    if f == nil then local okN, fn = pcall(Extras.familiarNow, itemId); if okN then f = fn end end -- not waiting for the data pass
    if f == nil then return {} end
    local out = {}
    local function add(t, m) out[#out + 1] = { text = t, markup = m } end
    if itemId == f.pouch then
        if type(f.level) == "number" then add("Summoning level: " .. f.level) end
        if type(f.minutes) == "number" then add("Duration: " .. f.minutes .. " minutes") end
        gameLines(f.doesRaw, out)
        local scroll = nameOf(f.scroll)
        if scroll ~= nil or f.scrollDoesRaw ~= nil then
            add("")
            if scroll ~= nil then add(scroll, gold(scroll)) end
            gameLines(f.scrollDoesRaw, out)
            add("1.8s cooldown.")
        end
        local mode = MODE_WORDS[tonumber(f.mode) or -1]
        if mode ~= nil then add(""); add("Default combat mode: " .. mode) end
    else -- its scroll
        local pouch = nameOf(f.pouch)
        if pouch ~= nil then add("Familiar: " .. pouch, "Familiar: " .. gold(pouch)) end
        if type(f.points) == "number" then add("Familiar spell points: " .. f.points) end
        gameLines(f.scrollDoesRaw, out)
        add("1.8s cooldown.")
    end
    return out
end
function Extras.lines(itemId, item)
    if Extras.cache[itemId] ~= nil then return Extras.cache[itemId] end
    local lines = {}
    local ready = Recipes ~= nil and Recipes.rowsState ~= nil and Recipes.rowsState.ready
    if ready then settle() end
    -- Not here, but in the hover box as in the game: potions (Extras.potionHover), familiars (Extras.familiarHover) and teleport
    -- jewellery (Extras.teleportsOf, ui/details.lua).
    -- monolith relics
    local r = Extras.relics[itemId]
    if r ~= nil then lines[#lines + 1] = "Monolith relic: " .. r.name .. (r.does and (" - " .. r.does) or "") end
    -- currencies
    local c = Extras.currencies[itemId]
    if c ~= nil then
        local own = nameOf(itemId)
        lines[#lines + 1] = (type(c) == "string" and own ~= nil and string.lower(c) ~= string.lower(own)) and ("Currency: " .. c) or "Currency: yes"
    end
    -- Archaeology tablets and pages
    local t = Extras.tablets and Extras.tablets[itemId]
    if t ~= nil then lines[#lines + 1] = "Mystery: " .. t.mystery .. (t.site and (" (" .. t.site .. ")") or "") end
    -- farm animals
    for _, e in ipairs(fieldList(item, "POF_ANIMAL_DB")) do
        if e.name == "POF_ANIMAL_DB" and field(e.value, "typeName") == "DBRow" then
            local row = nil
            pcall(function() row = config.DBRow.FromID(field(e.value, "id")) end)
            local animal = row and first(row, 6)
            if type(animal) == "string" and animal ~= "" then
                local about = cut(first(row, 7))
                lines[#lines + 1] = "Farm animal: " .. animal .. (about and (" - " .. about) or "")
            end
        end
    end
    if ready then Extras.cache[itemId] = lines end -- before the tables are read, ask again next time
    return lines
end

end }
