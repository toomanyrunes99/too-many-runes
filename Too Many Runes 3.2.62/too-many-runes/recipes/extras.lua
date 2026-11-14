-- Too Many Runes - More facts for the Info box, read from the game's own tables (3.2.07)
-- Read while the plugin walks every data row once (recipes/guides.lua, Recipes.rowsStep, calls Extras.row for each), then shown when an
-- item is opened (data/info.lua calls Extras.lines). All of it is the game's data, found by the surveys TMR-survey 1.0.20 - 1.0.25:
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
local TEXT_MAX = 220 -- (a long description is cut here, so the Info box stays a sensible size)

local function cut(s)
    if type(s) ~= "string" then return nil end
    s = string.gsub(s, "<br>", " ")
    s = string.gsub(s, "<[^>]*>", "") -- (3.2.08: the game's colour marks, <col=0x00ffff> ... </col>, are not shown as text)
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

-- One data row (called for every row the plugin walks). Only the rows of the tables above are kept.
function Extras.row(name, row, rowId)
    if startsWith(name, "HERBLORE_POTION_") then
        if tableOf(row) ~= "HERBLORE_POTION" then return end
        local doses, info = first(row, 2), first(row, 3)
        local id = field(doses, "id")
        if type(id) == "number" and info ~= nil then Extras.potionInfo[id] = info end
    elseif startsWith(name, "LORE_") then
        if tableOf(row) ~= "LORE" then return end
        local pouch, scroll = objId(first(row, 6)), objId(first(row, 7))
        local npcName = field(first(row, 15), "name")
        local f = { familiar = (type(npcName) == "string" and npcName ~= "") and npcName or nil, does = cut(first(row, 4)),
                    pouch = pouch, scroll = scroll, scrollDoes = cut(first(row, 8)) }
        if pouch ~= nil then Extras.familiars[pouch] = f end
        if scroll ~= nil and Extras.familiars[scroll] == nil then Extras.familiars[scroll] = f end
    elseif startsWith(name, "TELEPORT_LIST_CATEGORY_JEWELLERY_") then
        local item = objId(first(row, 2))
        if item ~= nil then Extras.jewellery[#Extras.jewellery + 1] = { item = item, key = "TELEPORT_" .. string.sub(name, 24) } end
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
    local wanted = {} -- (the jewellery's name without its charges -> its places: its other charges are found in one pass below)
    for _, j in ipairs(Extras.jewellery) do
        local list = {}
        for _, p in ipairs(Extras.places) do
            if p.name == j.key or startsWith(p.name, j.key .. "_") then list[#list + 1] = p end
        end
        table.sort(list, function(a, b) return a.id < b.id end)
        local names = {}
        for _, p in ipairs(list) do names[#names + 1] = p.place end
        if #names > 0 then
            -- the item the game names ("Skills necklace (4)") and its other charges ("Skills necklace (1)" ... ): not the empty one
            local slot = Items.slotOf[j.item]
            local base = slot and string.match(Items.lower[slot] or "", "^(.-) %(%w+%)$")
            Extras.teleports[j.item] = names
            if base ~= nil then wanted[base] = names end
        end
    end
    if next(wanted) ~= nil then
        for s = 1, #Items.lower do
            local b = string.match(Items.lower[s] or "", "^(.-) %(%d+%)$")
            if b ~= nil and wanted[b] ~= nil then Extras.teleports[Items.ids[s]] = wanted[b] end
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
local function potionLines(info)
    local stats, order, pairsSeen, effects, custom, duration = {}, {}, {}, {}, nil, nil
    for _, e in ipairs(fieldList(info, "POTION_INFO_")) do
        local n, v = e.name, e.value
        local pct = string.match(n, "^POTION_INFO_STAT_BONUS_PCENT_(.+)$")
        local abs = (pct == nil) and string.match(n, "^POTION_INFO_STAT_BONUS_(.+)$") or nil
        if abs ~= nil and (string.sub(abs, 1, 9) == "XP_SCALE_" or abs == "DECAY") then abs = nil end -- (DECAY: the boost wears off - not a skill)
        local skill = pct or abs
        if skill ~= nil and type(v) == "number" then
            if stats[skill] == nil then stats[skill] = {}; order[#order + 1] = skill end
            if pct then stats[skill].p = v else stats[skill].a = v end
        elseif n == "POTION_INFO_DURATION" and type(v) == "number" then duration = v
        elseif n == "POTION_INFO_CUSTOM_TEXT" and type(v) == "string" then custom = cut(v)
        elseif SAY[n] ~= nil and v ~= nil and v ~= 0 and v ~= false then effects[#effects + 1] = string.format(SAY[n], tostring(v))
        else
            for key, label in pairs(PAIRS) do
                if n == "POTION_INFO_" .. key .. "_ABS" or n == "POTION_INFO_" .. key .. "_PCENT" then pairsSeen[key] = label end
            end
        end
    end
    local parts = {}
    for _, skill in ipairs(order) do
        local s = both(stats[skill].a, stats[skill].p)
        if s ~= "" then parts[#parts + 1] = titleCase(skill) .. " " .. s end
    end
    for key, label in pairs(pairsSeen) do
        local a, p = nil, nil
        for _, e in ipairs(fieldList(info, "POTION_INFO_" .. key .. "_")) do
            if e.name == "POTION_INFO_" .. key .. "_ABS" then a = e.value elseif e.name == "POTION_INFO_" .. key .. "_PCENT" then p = e.value end
        end
        local s = both(a, p)
        if s ~= "" then parts[#parts + 1] = label .. " " .. s end
    end
    for _, e in ipairs(effects) do parts[#parts + 1] = e end
    local lines = {}
    if #parts > 0 then lines[#lines + 1] = "Effect: " .. table.concat(parts, ", ") end
    if custom ~= nil then lines[#lines + 1] = "Effect: " .. custom end
    if duration ~= nil and duration > 0 then
        local secs = math.floor(duration) -- (in seconds: Overload's 360 is its 6 minutes - 3.2.07 took it for ticks)
        lines[#lines + 1] = "Lasts: " .. ((secs >= 60) and (math.floor(secs / 60) .. " min" .. ((secs % 60 > 0) and (" " .. secs % 60 .. " s") or ""))
            or (secs .. " s"))
    end
    return lines
end

local function nameOf(itemId)
    local slot = itemId and Items.slotOf[itemId]
    return slot and Items.names[slot] or nil
end

-- The extra lines for one item (plain text, wrapped by the Info box), or an empty list.
function Extras.lines(itemId, item)
    if Extras.cache[itemId] ~= nil then return Extras.cache[itemId] end
    local lines = {}
    local ready = Recipes ~= nil and Recipes.rowsState ~= nil and Recipes.rowsState.ready
    if ready then settle() end
    -- potions: the item's dose bundle, or its own POTION_INFO
    local info = nil
    for _, e in ipairs(fieldList(item, "POTION_")) do
        if e.name == "POTION_INFO" and field(e.value, "typeName") ~= nil then info = e.value
        elseif e.name == "POTION_STRUCT" and info == nil then info = Extras.potionInfo[field(e.value, "id")] end
    end
    if info ~= nil then for _, l in ipairs(potionLines(info)) do lines[#lines + 1] = l end end
    -- familiars
    local f = Extras.familiars[itemId]
    if f ~= nil then
        if itemId == f.pouch then
            if f.familiar then lines[#lines + 1] = "Familiar: " .. f.familiar .. (f.does and (" - " .. f.does) or "") end
            local scroll = nameOf(f.scroll)
            if scroll then lines[#lines + 1] = "Its scroll: " .. scroll .. (f.scrollDoes and (" - " .. f.scrollDoes) or "") end
        else
            lines[#lines + 1] = "Scroll of: " .. (f.familiar or nameOf(f.pouch) or "a familiar") .. (f.scrollDoes and (" - " .. f.scrollDoes) or "")
            local pouch = nameOf(f.pouch)
            if pouch then lines[#lines + 1] = "Made from: " .. pouch end
        end
    end
    -- teleport jewellery
    local places = Extras.teleports and Extras.teleports[itemId]
    if places ~= nil then lines[#lines + 1] = "Teleports to: " .. table.concat(places, ", ") end
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
    if ready then Extras.cache[itemId] = lines end -- (before the tables are read, ask again next time)
    return lines
end

end }
