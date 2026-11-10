-- Too Many Runes - Recipes: where gathered items come from
-- The Source tab: an item that is mined, cut, caught, grown, hunted, collected or dug up shows where. Nothing is typed in from the wiki:
-- the game keeps a table for each kind of gathering (found by the surveys "gather" and "gather2"; the columns are in DATA-SOURCES.md):
--   Mining         the rock table (data rows 1423 to 1481, named ..._ROCK; also WILD_ESSENCE_MINE_ and the Croesus mining rows): column 2
--                  the rock's name,
--                  column 4 = the ore, the level, and a third number (not used)
--   Woodcutting    rows WOODCUTTING_SITE_: column 2 a place (sometimes), column 3 a record with the log (SKILLGUIDE_ITEM), the level and
--                  the tree's name
--   Fishing        rows FISHING_SITE_: column 2 the way of fishing, column 4 records FISHINGSPOT_ with each fish (FISH_k), its level
--                  (REQUIREDLEVEL_k) and bait (BAIT_k)
--   Divination     rows DIVINATION_SITE_: column 3 a record with the memory and the level
--   Farming        rows FARMING_SITE_: column 2 the patch's name, column 3 a list of what grows there (records with the crop and the level)
--   Archaeology    rows ARCH_SITE_ (column 3 the dig site's name, column 15 a list of its materials) and ARCH_EXCAVATION_ (column 5 the
--                  level, column 16 the
--                  material): a material's level is the lowest level of the excavations that give it
--   Hunter         the game has no table that links a creature to what it gives: only the Hunter guide's level and name are used
-- Boss drops (the game's boss records) add a plain row "Dropped by <boss>" to the Source tab; see "boss drops" below.
-- The skill guides' gathered lists (MINING "resources", WOODCUTTING "trees", FISHING "catches" ...) are read as a last resort for items no
-- table gave: the guide's level and name (marked guide = true). The items that have ONLY a guide are listed in the console once, so the
-- gaps can be seen.
-- The results are used by: the Source tab (Gather.rowsOf, recipes/source_tab.lua) and the filter "Gathered" (core/filters.lua). The search by
-- skill (Gather.levelIn) comes with the @ search words.
-- (Moved over from the old plugin's ii_recipes/gather.lua. Changed: the Source tab of its own, longer rows (the new box wraps and
-- scrolls), up to 60 sources, whole lists read from the data rows (3.0.50) and a search word for every place (3.0.47).)
-- (How the files fit together is explained at the top of main.lua.)
return { run = function(T)
local _ENV = T

Gather = {
    src = {},        -- item number -> list of { skill = "MINING", level = n, name = "Coal rock", bait = true, guide = true }
    levels = {},     -- item number -> { MINING = lowest level ... } (the search by skill reads it)
    count = 0,       -- how many items have a source
    perSkill = {},   -- skill -> how many table sources were read
    sites = {},      -- the Archaeology dig sites: { name =, key =, list = (the list of materials), restore = (the list of artefacts) }
    noDig = {},      -- names of the damaged artefacts that no dig spot or dig site was found for (printed once)
    sitesOf = {},    -- item number -> the dig sites (search words, "daemonheim") where it is found: materials and damaged artefacts
    siteWords = {},  -- the dig sites' search words: "@daemonheim" lists everything found there (Recipes.stationIndex holds the items)
    isCommon = {},   -- item number -> true for an item that is the common find of a dig spot (it can come from several dig sites)
    spots = {},      -- the dig spots (hotspots) with a name: { name, common = the item every dig gives }
    siteNames = {},  -- search word -> the dig site's name (shown while the mouse is over its picture)
    siteRank = {},   -- dig site name -> its place in the game's list of dig sites (the pictures are shown in that order)
    slugRank = {},   -- the same by search word
    digLevel = {},   -- Archaeology material item number -> the lowest level of an excavation that gives it
    patchSeen = {},  -- the farming lists already read (a list is shared by many rows)
    artefacts = {},  -- the hotspots' artefacts: { link = (the restoration row's number), level =, name = (the hotspot) }, resolved in Gather.finish
    ready = false,   -- the skill guides are read as well
}

local SKILLS = { "MINING", "WOODCUTTING", "FISHING", "FARMING", "HUNTER", "DIVINATION", "ARCHAEOLOGY" }
local LABEL = { MINING = "Mining", WOODCUTTING = "Woodcutting", FISHING = "Fishing", FARMING = "Farming", HUNTER = "Hunter",
                DIVINATION = "Divination", ARCHAEOLOGY = "Archaeology" }
local ORDER = {}
for i, s in ipairs(SKILLS) do ORDER[s] = i end
Gather.skills, Gather.label = SKILLS, LABEL

-- The guide filters (their names, lower case) that hold gathered items; the other filters of those guides are tools, outfits, upgrades ...
local GATHERED = {
    MINING = { resources = true },
    WOODCUTTING = { trees = true },
    FISHING = { catches = true, barbarian = true, multiple = true, ["fish farm"] = true },
    DIVINATION = { gathering = true },
    ARCHAEOLOGY = { materials = true },
    HUNTER = { tracking = true, ["big game hunter"] = true, ["butterflies, moths, and implings"] = true },
    FARMING = { allotments = true, hops = true, trees = true, ["fruit trees"] = true, bushes = true, flowers = true, herbs = true, special = true },
}

-- "Items" the tables hold that are no item: what a rock that gives nothing "gives"
local NOT_ITEMS = { ["no resource"] = true, ["approval rating"] = true }

local MAX_SOURCES = 60 -- the Source tab lists this many, then "(N more sources)"
local MAX_TEXT = 90   -- the longest row text (longer rows wrap onto the next line)

local function starts(text, prefix) return string.sub(text, 1, #prefix) == prefix end

-- "WOODCUTTING_SITE_OAK_TREE" -> "Oak tree"
local function pretty(configName, prefix)
    local s = configName
    if prefix ~= nil and starts(s, prefix) then s = string.sub(s, #prefix + 1) end
    s = string.lower((string.gsub(s, "_", " ")))
    return (string.gsub(s, "^%l", string.upper))
end

-- The values of one column of a data row, as a plain list (empty when there are none): list.n = how many, list.width = the size of one
-- entry. (The game's count is the size of ONE entry: a column that holds a list - a dig spot's artefacts, each with its chance - has its
-- entries one after another, that many values each. Found by the 3.0.49 survey: before, only the first entry was read, so a dig spot gave
-- one artefact and one material, and a fishing spot one of its fish lists.)
local function columnList(row, c)
    local values, count = Recipes.rowValues(row, c)
    local list = { n = 0 }
    if values ~= nil and type(count) == "number" then
        local last = count
        if type(values) == "table" then
            for k in pairs(values) do if type(k) == "number" and k > last then last = k end end
        end
        last = math.min(last, 400)
        for k = 1, last do list[k] = valueAt(values, k) end
        list.n, list.width = last, count
    end
    return list
end

local function textOf(v)
    if type(v) == "string" and v ~= "" then return v end
    return nil
end

-- An item value (Obj): its number and name, or nil when it is no real item.
local function itemOf(v)
    if field(v, "typeName") ~= "Obj" then return nil end
    local id, name = field(v, "id"), field(v, "name")
    if type(id) ~= "number" or type(name) ~= "string" or name == "" or NOT_ITEMS[string.lower(name)] then return nil end
    return id, name
end

-- Remember one source of an item.
-- spot = true: a single hotspot (an artefact's or a common item's), not one of the dig sites that a material comes from.
local function addSource(id, skill, level, name, bait, guide, spot, info)
    level = (type(level) == "number" and level > 0) and level or 0
    local list = Gather.src[id]
    if list == nil then
        list = {}
        Gather.src[id] = list
        Gather.count = Gather.count + 1
    end
    for _, s in ipairs(list) do
        if s.skill == skill and s.name == name then
            if s.level == 0 or (level > 0 and level < s.level) then s.level = level end
            if bait then s.bait = true end
            if info ~= nil and s.info == nil then s.info = info end
            return
        end
    end
    list[#list + 1] = { skill = skill, level = level, name = name, bait = bait or nil, guide = guide or nil, spot = spot or nil, info = info or nil }
    if not guide then Gather.perSkill[skill] = (Gather.perSkill[skill] or 0) + 1 end
    local t = Gather.levels[id]
    if t == nil then t = {}; Gather.levels[id] = t end
    local known = t[skill]
    if known == nil or (level > 0 and (known == 0 or level < known)) then t[skill] = level end
end

-- Does the item have a source in this skill that came from a table (not only from the guide)?
local function hasTableSource(id, skill)
    for _, s in ipairs(Gather.src[id] or {}) do
        if s.skill == skill and not s.guide then return true end
    end
    return false
end

Gather.guideStats = {} -- skill -> { entries = how many wanted guide entries, texts = how many have words about where, table = of those, how
                       -- many belong to an item with a table source }
-- A source that is no gathering skill ("Monster drop"): shown as plain words with no picture and no click. (The hand-written facts,
-- playerFacts.gathered.drops.)
local function addPlain(id, text)
    local list = Gather.src[id]
    if list == nil then
        list = {}
        Gather.src[id] = list
        Gather.count = Gather.count + 1
    end
    for _, s in ipairs(list) do
        if s.plain == text then return end
    end
    list[#list + 1] = { skill = "DROP", level = 0, plain = text }
end

-- What the developer said about items that only the skill guides know (playerFacts.gathered in ii_exceptions.lua), by lower case name:
-- ignore = no source wanted; places = { { skill, place }, ... } as sources; drops = a plain "Monster drop" row.
local function gatheredFacts()
    local ignore, places, drops = {}, {}, {}
    local F = nil
    pcall(function() F = Recipes.playerFacts().gathered end)
    if type(F) == "table" then
        for _, n in ipairs(F.ignore or {}) do ignore[string.lower(n)] = true end
        for n, list in pairs(F.places or {}) do places[string.lower(n)] = list end
        for _, n in ipairs(F.drops or {}) do drops[string.lower(n)] = F.dropText or "Monster drop" end
    end
    return ignore, places, drops
end

-- What the developer said about WHERE an item is found (playerFacts.gathered.where = { ["Petrified roots"] = { "Fenmoor on Havenhythe" } }): the
-- places are shown under the item's sources, in the same way as the guide's own words (an item that has no words of its own from the guide).
local function applyWhere()
    local F = nil
    pcall(function() F = Recipes.playerFacts().gathered end)
    if type(F) ~= "table" or type(F.where) ~= "table" then return end
    for name, places in pairs(F.where) do
        local text = "Locations:<br>- " .. table.concat(places, "<br>- ")
        local slots = nil
        pcall(function() slots = Recipes.slotsOf(string.lower(name)) end)
        for _, slot in ipairs(slots or {}) do
            for _, s in ipairs(Gather.src[itemIds[slot]] or {}) do
                if s.plain == nil and s.info == nil then s.info = text end
            end
        end
    end
end

-- A record (struct) of a skill guide: the item, the level and the name.
local function guideRecord(struct)
    local f = fieldList(struct, "SKILLGUIDE_")
    local id, itemName = itemOf(getField(f, "SKILLGUIDE_ITEM"))
    local level, name, filter = getField(f, "SKILLGUIDE_LEVEL"), getField(f, "SKILLGUIDE_NAME"), getField(f, "SKILLGUIDE_FILTER")
    return id, itemName, (type(level) == "number") and level or nil, textOf(name), filter, textOf(getField(f, "SKILLGUIDE_INFO"))
end

----- reading the data rows (called by Recipes.rowsStep for every row whose name is wanted) -----

-- Which kind of gathering table does this data row (name, number) belong to? nil: none.
function Gather.kindOf(name, n)
    if starts(name, "WOODCUTTING_SITE_") then return "wood" end
    if starts(name, "FISHING_SITE_") then return "fish" end
    if starts(name, "DIVINATION_SITE_") then return "div" end
    if starts(name, "FARMING_SITE_") then return "farm" end
    if starts(name, "ARCH_EXCAVATION_") then return "dig" end
    if starts(name, "ARCH_SITE_") then return "site" end
    if string.sub(name, -5) == "_ROCK" or starts(name, "WILD_ESSENCE_MINE_") or starts(name, "EGWD_BIK_BOSS_SKILLING_MINING_")
       or (type(n) == "number" and n >= 1400 and n <= 1500) then
        return "rock"
    end
    return nil
end

local readers = {}

-- Mining: column 2 the rock, column 4 the ore, the level and a third number (the rows between 1400 and 1500 are the rock table; a row of another
-- shape is no rock and is skipped)
function readers.rock(name, row)
    local rock = textOf(valueAt(columnList(row, 2), 1))
    if rock == nil then return end
    local c4 = columnList(row, 4)
    local width = (type(c4.width) == "number" and c4.width > 0) and c4.width or 3
    for k = 1, c4.n, width do -- (each entry: the ore, the level, a third number; a gem rock has one entry for each gem)
        local id, level = itemOf(c4[k]), c4[k + 1]
        if id ~= nil and type(level) == "number" then addSource(id, "MINING", level, rock) end
    end
end

function readers.wood(name, row)
    local place = textOf(columnList(row, 2)[1])
    local c3 = columnList(row, 3)
    for k = 1, c3.n do
        local struct = c3[k]
        if field(struct, "typeName") == "Struct" then
            local id, _, level, treeName = guideRecord(struct)
            if id ~= nil then addSource(id, "WOODCUTTING", level, treeName or place or pretty(name, "WOODCUTTING_SITE_")) end -- (ivy: no item)
        end
    end
end

function readers.div(name, row)
    local place = textOf(columnList(row, 2)[1])
    local c3 = columnList(row, 3)
    for k = 1, c3.n do
        local struct = c3[k]
        if field(struct, "typeName") == "Struct" then
            local id, itemName, level, wispName = guideRecord(struct)
            if id ~= nil then addSource(id, "DIVINATION", level, wispName or place or (string.gsub(itemName, " memory$", " wisp"))) end
        end
    end
end

function readers.fish(name, row)
    local method = textOf(columnList(row, 2)[1]) or pretty(name, "FISHING_SITE_")
    method = string.gsub(method, " Fishing$", "")
    -- (the game's lists end in words that only tell its lists apart: "Big Net/Harpoon Member", "Big Cage/Harpoon Rare")
    local cut = true
    while cut do
        cut = false
        for _, w in ipairs({ " Members", " Member", " Rare", " F2P", " P2P", " Free" }) do
            if #method > #w and string.lower(string.sub(method, -#w)) == string.lower(w) then method = string.sub(method, 1, -#w - 1); cut = true end
        end
    end
    local c4 = columnList(row, 4)
    for i = 1, c4.n do
        local v = c4[i]
        if field(v, "typeName") == "Struct" then
            local f = fieldList(v, "FISHINGSPOT_")
            for k = 1, 12 do
                local fishId = itemOf(getField(f, "FISHINGSPOT_FISH_" .. k))
                if fishId ~= nil then
                    local bait = getField(f, "FISHINGSPOT_BAIT_" .. k) ~= nil
                    addSource(fishId, "FISHING", getField(f, "FISHINGSPOT_REQUIREDLEVEL_" .. k), method, bait)
                end
            end
        end
    end
end

-- What each seed grows. The game links no seed to its crop (the 3.0.57 survey: a patch's list gives the crop and its guide name -
-- "Potato" -> Raw potato, in the Allotment Patch - and the seed itself only its Farming level), so a seed is matched by its name: "Potato
-- seed" -> "Potato", "Oak sapling" -> "Oak", "Apple tree seed" -> "Apple tree" (or "Apple"). Gather.grows: guide name (lower case) ->
-- { { id = crop, level =, patch = }, ... }.
Gather.grows = {}
local SEED_ENDS = { " seeds", " seed", " seedling", " sapling", " spores", " spore" }
function Gather.growsFrom(seedName)
    local lower = string.lower(seedName or "")
    for _, ending in ipairs(SEED_ENDS) do
        if #lower > #ending and string.sub(lower, -#ending) == ending then
            local base = string.sub(lower, 1, -#ending - 1)
            return Gather.grows[base] or Gather.grows[(string.gsub(base, " tree$", ""))] or Gather.grows[base .. " tree"]
        end
    end
    return nil
end

-- A herb patch gives the grimy herb, but the game's patch list names the clean one ("Clean torstol"): the crop is the item "Grimy <herb>"
-- when there is one (3.0.87, the developer).
local function patchCrop(id)
    local slot = Items.slotOf[id]
    local lower = slot and itemLower[slot]
    if lower ~= nil and string.sub(lower, 1, 6) == "clean " then
        local grimy = findByName("grimy " .. string.sub(lower, 7))
        if grimy ~= nil then return grimy end
    end
    return id
end
Gather.patchCrops = {} -- (the items the game's farming patch lists grow - @patch; 3.0.87: not the skill guide's other Farming items, like honeycombs)

function readers.farm(name, row)
    local list = columnList(row, 3)[1]
    if field(list, "typeName") ~= "Enum" then return end
    local listName = field(list, "configName")
    if listName ~= nil and Gather.patchSeen[listName] then return end
    Gather.patchSeen[listName or name] = true
    local patch = textOf(columnList(row, 2)[1]) or pretty(name, "FARMING_SITE_")
    local entries, count = field(list, "values"), field(list, "valueCount")
    if entries == nil or type(count) ~= "number" then return end
    for e = 1, Recipes.listCount(count, 200, tostring(listName)) do
        local struct = valueAt(valueAt(entries, e), 2)
        if field(struct, "typeName") == "Struct" then
            local id, _, level, guideName = guideRecord(struct)
            if id ~= nil then
                id = patchCrop(id)
                Gather.patchCrops[id] = true
                addSource(id, "FARMING", level, patch)
                if type(guideName) == "string" and guideName ~= "" then -- (what a seed grows: Gather.growsFrom)
                    local key = string.lower(guideName)
                    Gather.grows[key] = Gather.grows[key] or {}
                    table.insert(Gather.grows[key], { id = id, level = level, patch = patch })
                end
            end
        end
    end
end

-- Archaeology excavations: column 5 the level, column 16 the material (and a weight). A material's level is the lowest of its excavations. The row of
-- a hotspot (it has a name in column 3) also gives a common item in column 15. Column 18 links the artefacts the hotspot gives: rows named
-- ARCH_RESTORATION_
-- (read from the game: column 5 the level, 6 the DAMAGED item, 7 the restored item); the damaged item is dug up at this hotspot.
function readers.dig(name, row)
    local level = columnList(row, 5)[1]
    if type(level) ~= "number" then return end
    local hotspot = textOf(columnList(row, 3)[1])
    local common = itemOf(columnList(row, 15)[1])
    if hotspot ~= nil and common ~= nil then
        addSource(common, "ARCHAEOLOGY", level, hotspot, nil, nil, true)
        Gather.spots[#Gather.spots + 1] = { name = hotspot, common = common }
        Gather.isCommon[common] = true
    end
    -- column 16: the materials the spot gives, column 17: its other finds (log pages ...), each with its chance (3.0.49 survey: Castra
    -- debris gives four materials and four other finds)
    for _, c in ipairs({ 16, 17 }) do
        local list = columnList(row, c)
        for k = 1, list.n do
            local item = itemOf(list[k])
            if item ~= nil then
                if c == 16 and (Gather.digLevel[item] == nil or level < Gather.digLevel[item]) then Gather.digLevel[item] = level end
                if hotspot ~= nil then addSource(item, "ARCHAEOLOGY", level, hotspot, nil, nil, true) end
            end
        end
    end
    local links = columnList(row, 18) -- (each artefact with its chance: the 3.0.49 survey found the Exsanguinate scroll second at Orcus altar)
    for k = 1, links.n do
        local link = links[k]
        if field(link, "typeName") == "DBRow" and type(field(link, "id")) == "number" then
            Gather.artefacts[#Gather.artefacts + 1] = { link = field(link, "id"), level = level, name = hotspot or pretty(name, "ARCH_EXCAVATION_") }
        end
    end
end

-- Archaeology dig sites: column 3 the name, column 15 the list of the site's materials, column 16 the list of its artefacts (rows ARCH_RESTORATION_;
-- a site whose row has none is tried under the list's usual name ARCH_<SITE>_RESTORATION_LIST). Read in Gather.finish, when every
-- excavation is known.

-- A value as short text, for the console.
local function brief(v)
    local t = field(v, "typeName")
    if t ~= nil then return tostring(t) .. ":" .. tostring(field(v, "name") or field(v, "configName") or field(v, "id")) end
    return tostring(v)
end

-- The picture in a record's settings: a whole number whose setting is called ...SPRITE... (then IMAGE, GRAPHIC, ICON); failing that the
-- only whole number of four digits or more. Returns the number, or nil.
local function pickSprite(fields)
    -- (a setting that ENDS with the word first: RS3TLI_BUTTON_GRAPHIC, not ..._GRAPHIC_HEIGHT)
    for _, word in ipairs({ "SPRITE", "IMAGE", "GRAPHIC", "ICON" }) do
        for _, e in ipairs(fields) do
            local upper = string.upper(e.name)
            if type(e.value) == "number" and e.value >= 0 and string.sub(upper, -#word) == word then return e.value end
        end
    end
    for _, word in ipairs({ "SPRITE", "IMAGE", "GRAPHIC", "ICON" }) do
        for _, e in ipairs(fields) do
            if type(e.value) == "number" and e.value >= 0 and string.find(string.upper(e.name), word, 1, true) then return e.value end
        end
    end
    local only, n = nil, 0
    for _, e in ipairs(fields) do
        if type(e.value) == "number" and e.value >= 1000 and e.value == math.floor(e.value) then only, n = e.value, n + 1 end
    end
    if n == 1 then return only end
    return nil
end

-- A record's settings as short text, for the console.
local function describe(fields)
    local parts = {}
    for _, e in ipairs(fields) do
        local v = e.value
        if type(v) == "string" then v = "\"" .. string.sub(v, 1, 30) .. "\"" elseif type(v) ~= "number" then v = brief(v) end
        parts[#parts + 1] = e.name .. "=" .. tostring(v)
    end
    return table.concat(parts, ", ")
end

-- The dig site's own picture. Column 10 is a record ARCH_SITE_ICON_<SITE> whose settings are the game's button for the dig site in three states:
-- RS3TLI_BUTTON_STRUCT_ON (the picture shown, the "second" one in @icons), _OVER (the mouse is over it, the "third") and sometimes
-- _DISABLED, each a record of its
-- own whose RS3TLI_BUTTON_GRAPHIC is the picture (40 x 40). The picture used is the _ON one (chosen by the developer in the picture viewer)
-- and the picture shown
-- while the mouse is over it is the _OVER one. Column 9 (the bigger scene picture, 10294 ...) is only the fallback when a record cannot be read.
-- What was found and what the records hold are printed once at start-up (Gather.finish). Returns the picture, the "over" picture, the text, the three
-- states and the column 9 picture.
local function siteIcon(row)
    local struct = columnList(row, 10)[1]
    local c9 = columnList(row, 9)[1]
    if type(c9) ~= "number" or c9 < 1000 or c9 ~= math.floor(c9) then c9 = nil end
    if field(struct, "typeName") ~= "Struct" then return c9, nil, "no record in column 10; column 9 = " .. tostring(c9), {}, c9 end
    local fields = fieldList(struct)
    local diag = tostring(field(struct, "configName")) .. " {" .. describe(fields) .. "}; column 9 = " .. tostring(c9)
    local states = {}
    for _, state in ipairs({ "ON", "OVER", "DISABLED" }) do
        local record = getField(fields, "RS3TLI_BUTTON_STRUCT_" .. state)
        if field(record, "typeName") == "Struct" then
            local f = fieldList(record)
            states[state] = pickSprite(f) or false
            diag = diag .. "; " .. state .. " {" .. describe(f) .. "}"
        end
    end
    local icon, over = nil, nil
    if type(states.ON) == "number" then
        icon = states.ON
        if type(states.OVER) == "number" and states.OVER ~= icon then over = states.OVER end
    else
        icon = pickSprite(fields)
        if icon == nil and c9 ~= nil then icon, diag = c9, diag .. " [column 9 used]" end
    end
    return icon, over, diag, states, c9
end

function readers.site(name, row)
    local siteName = textOf(columnList(row, 3)[1])
    if siteName == nil then return end
    local list, restore = columnList(row, 15)[1], columnList(row, 16)[1]
    if field(list, "typeName") ~= "Enum" then list = nil end
    if field(restore, "typeName") ~= "Enum" then restore = nil end
    local icon, over, diag, states, icon9 = siteIcon(row)
    Gather.sites[#Gather.sites + 1] = { name = siteName, key = string.match(name, "^ARCH_SITE_(.+)$"), list = list, restore = restore, icon = icon, over = over, diag = diag,
                                        states = states, icon9 = icon9 }
end

function Gather.read(kind, name, row)
    local reader = readers[kind]
    if reader ~= nil then reader(name, row) end
end

-- THE DIG SITES AND DIG SPOTS (Archaeology). Gather.finish runs once, after the data rows have all been read (it is called by the guide pass
-- below). It gives the dig sites their materials and the hotspots' damaged artefacts their sources and dig sites, in the small steps below;
-- the steps run in the order they are written.

-- Remembers that an item is found at a dig site: the site's search word ("@daemonheim") lists the item (Recipes.stationIndex[word] holds what
-- is found there), and the item keeps the list of its sites (Gather.sitesOf).
local function markSite(id, slug)
    local list = Gather.sitesOf[id]
    if list == nil then list = {}; Gather.sitesOf[id] = list end
    for _, v in ipairs(list) do
        if v == slug then return end
    end
    list[#list + 1] = slug
    local set = Recipes.stationIndex[slug]
    if set == nil then set = {}; Recipes.stationIndex[slug] = set end
    set[id] = true
end

-- True when a dig spot (a hotspot) already gives this damaged artefact.
local function hasSpot(id)
    for _, src in ipairs(Gather.src[id] or {}) do
        if src.skill == "ARCHAEOLOGY" and src.spot then return true end
    end
    return false
end

-- Step 1: every dig site gets its search word, its place in the game's list of sites and its pictures. The console gets one short line (the
-- records of each site are only printed while LOG_DETAILS is true).
local function nameDigSites()
    for rank, site in ipairs(Gather.sites) do
        site.slug = Recipes.materialSlug(site.name)
        Gather.siteWords[site.slug] = true
        Gather.siteRank[site.name] = rank
        Gather.slugRank[site.slug] = rank
        Gather.siteNames[site.slug] = site.name
        if site.icon ~= nil then Recipes.stationSprites["site_" .. site.slug] = site.icon end
        if site.over ~= nil then Recipes.stationSprites["site_" .. site.slug .. "_over"] = site.over end
        detail((string.gsub("Too Many Runes: dig site " .. site.name .. " (@" .. site.slug .. "): picture " .. tostring(site.icon) .. ", mouse over "
            .. tostring(site.over) .. "; " .. tostring(site.diag), "<", "(")))
    end
    local names = {}
    for _, site in ipairs(Gather.sites) do names[#names + 1] = site.name .. ((site.icon == nil) and " (NO PICTURE)" or "") end
    detail((string.gsub("Too Many Runes: dig sites: " .. #Gather.sites .. " (" .. table.concat(names, ", ") .. ")", "<", "(")))
end

-- Step 2: the materials in each dig site's list are found at that site.
local function addSiteMaterials()
    for _, site in ipairs(Gather.sites) do
        local entries, count = nil, nil
        if site.list ~= nil then entries, count = field(site.list, "values"), field(site.list, "valueCount") end
        if entries ~= nil and type(count) == "number" then
            for k = 1, Recipes.listCount(count, 100, tostring(field(site.list, "configName"))) do
                local id = itemOf(valueAt(valueAt(entries, k), 2))
                if id ~= nil then
                    addSource(id, "ARCHAEOLOGY", Gather.digLevel[id], site.name)
                    markSite(id, site.slug)
                end
            end
        end
    end
end

-- Step 3: the damaged artefacts of the hotspots get the hotspot as their source.
local function addHotspotArtefacts()
    local artefactCount = 0
    for _, art in ipairs(Gather.artefacts) do
        local row = nil
        pcall(function() row = config.DBRow.FromID(art.link) end)
        local damaged = itemOf(columnList(row, 6)[1])
        if damaged ~= nil then
            art.id = damaged
            addSource(damaged, "ARCHAEOLOGY", art.level, art.name, nil, nil, true)
            artefactCount = artefactCount + 1
        end
    end
    detail("Too Many Runes: damaged artefacts with a dig spot: " .. artefactCount .. " (of " .. #Gather.artefacts .. " links)")
end

-- Step 4: an artefact no hotspot gives is found at the dig site whose list of artefacts holds it.
local function addArtefactsFromSiteLists()
    local siteCount = 0
    for _, site in ipairs(Gather.sites) do
        local restore = site.restore
        if restore == nil and site.key ~= nil then pcall(function() restore = config.Enum["ARCH_" .. site.key .. "_RESTORATION_LIST"] end) end
        local entries, count = field(restore, "values"), field(restore, "valueCount")
        if entries ~= nil and type(count) == "number" then
            for k = 1, Recipes.listCount(count, 400, tostring(field(restore, "configName"))) do
                local v = valueAt(valueAt(entries, k), 2)
                local damaged, level = nil, nil
                if field(v, "typeName") == "DBRow" then
                    local full = nil
                    pcall(function() full = config.DBRow.FromID(field(v, "id")) end)
                    damaged, level = itemOf(columnList(full, 6)[1]), columnList(full, 5)[1]
                else
                    damaged = itemOf(v)
                end
                if damaged ~= nil then
                    markSite(damaged, site.slug)
                    if not hasSpot(damaged) then
                        addSource(damaged, "ARCHAEOLOGY", level, site.name)
                        siteCount = siteCount + 1
                    end
                end
            end
        end
    end
    detail("Too Many Runes: damaged artefacts given a dig site from the sites' lists: " .. siteCount)
end

-- Step 5: an artefact whose restoration row is named after a dig site (ARCH_RESTORATION_KHARIDET_ACCESS_SEAL,
-- ARCH_RESTORATION_STORMGUARD_WINGSUIT_V1) belongs to that site, even when no list holds it (the game's own name for the row; rows named
-- after no site, or after a quest, are left alone).
local function addArtefactsFromRowNames()
    local nameCount = 0
    for _, info in pairs(Recipes.rowsState.restoredOf or {}) do
        if info.from ~= nil and type(info.rowName) == "string" then
            for _, site in ipairs(Gather.sites) do
                if site.key ~= nil and string.sub(info.rowName, 1, 17 + #site.key + 1) == "ARCH_RESTORATION_" .. site.key .. "_" then
                    markSite(info.from, site.slug)
                    if not hasSpot(info.from) then
                        addSource(info.from, "ARCHAEOLOGY", info.level, site.name)
                        nameCount = nameCount + 1
                    end
                end
            end
        end
    end
    detail("Too Many Runes: damaged artefacts given a dig site from the name of their restoration row: " .. nameCount)
end

-- Step 6: the dig spots and what each gives (the item every dig gives, the damaged artefacts). Returns spotItems (spot name -> list of item
-- numbers) and spotOrder (the spot names, in the order they were found).
local function collectSpotItems()
    local spotItems, spotOrder = {}, {}
    local function spotAdd(name, id)
        local l = spotItems[name]
        if l == nil then l = {}; spotItems[name] = l; spotOrder[#spotOrder + 1] = name end
        for _, v in ipairs(l) do
            if v == id then return end
        end
        l[#l + 1] = id
    end
    for _, spot in ipairs(Gather.spots) do spotAdd(spot.name, spot.common) end
    for _, art in ipairs(Gather.artefacts) do
        if art.id ~= nil then spotAdd(art.name, art.id) end
    end
    return spotItems, spotOrder
end

-- Step 7: what the developer said (playerFacts.digSites.links in ii_exceptions.lua): the dig site of a dig spot (by its name) or of a damaged
-- artefact (by its name). Returns how many links were used.
local function applyDeveloperLinks(spotItems)
    local links = {}
    pcall(function() links = (Recipes.playerFacts().digSites or {}).links or {} end)
    local lowered = {}
    for key, value in pairs(links) do
        if type(key) == "string" then lowered[string.lower(key)] = value end
    end
    local bySite = {}
    for _, site in ipairs(Gather.sites) do
        bySite[site.slug] = site
        if site.key ~= nil then bySite[string.lower(site.key)] = site end
    end
    local function linkSites(value)
        local list = {}
        for _, v in ipairs(type(value) == "table" and value or { value }) do
            local site = (type(v) == "string") and (bySite[Recipes.materialSlug(v)] or bySite[string.lower(v)]) or nil
            if site ~= nil then list[#list + 1] = site else print((string.gsub("Too Many Runes: playerFacts.digSites.links names a dig site that does not exist: " .. tostring(v), "<", "("))) end
        end
        return list
    end
    local linkCount = 0
    for name, ids in pairs(spotItems) do
        local value = lowered[string.lower(name)]
        if value ~= nil then
            for _, site in ipairs(linkSites(value)) do
                for _, id in ipairs(ids) do markSite(id, site.slug) end
                linkCount = linkCount + 1
            end
        end
    end
    for _, info in pairs(Recipes.rowsState.restoredOf or {}) do
        local value = (info.from ~= nil and type(info.fromName) == "string") and lowered[string.lower(info.fromName)] or nil
        if value ~= nil then
            for _, site in ipairs(linkSites(value)) do
                markSite(info.from, site.slug)
                if not hasSpot(info.from) then addSource(info.from, "ARCHAEOLOGY", info.level, site.name) end
                linkCount = linkCount + 1
            end
        end
    end
    return linkCount
end

-- Step 8: a dig spot belongs to one dig site: what is not told for one of its items is the site of the others (the artefacts' sites; the item
-- every dig gives only when it has a single site, since it can come from several).
local function shareSitesInSpot(spotItems, spotOrder)
    for _, name in ipairs(spotOrder) do
        local ids, union, seen = spotItems[name], {}, {}
        for _, id in ipairs(ids) do
            local slugs = Gather.sitesOf[id]
            if slugs ~= nil and (#slugs == 1 or not Gather.isCommon[id]) then
                for _, slug in ipairs(slugs) do
                    if not seen[slug] then seen[slug] = true; union[#union + 1] = slug end
                end
            end
        end
        if #union > 0 then
            for _, id in ipairs(ids) do
                if Gather.sitesOf[id] == nil then
                    for _, slug in ipairs(union) do markSite(id, slug) end
                end
            end
        end
    end
end

-- Step 9: what the developer said is a quest item (playerFacts.digSites.quest: dig spots and damaged artefacts by name) has no dig site and is
-- not listed as missing. Returns the names, in lower case, as a set.
local function readQuestItems()
    local quest = {}
    pcall(function()
        for _, q in ipairs((Recipes.playerFacts().digSites or {}).quest or {}) do quest[string.lower(tostring(q))] = true end
    end)
    return quest
end

-- Step 10: the dig spots whose items still have no dig site go to Gather.missingSpots (listed at start-up, so the developer can say where they
-- are: playerFacts.digSites.links). Returns how many spots were left out as quest items.
local function listSpotsWithoutSite(spotItems, spotOrder, quest)
    local questSkipped = 0
    Gather.missingSpots = {}
    for _, name in ipairs(spotOrder) do
        local missing = {}
        for _, id in ipairs(spotItems[name]) do
            if Gather.sitesOf[id] == nil then missing[#missing + 1] = id end
        end
        if #missing > 0 then
            if quest[string.lower(name)] then questSkipped = questSkipped + 1
            else Gather.missingSpots[#Gather.missingSpots + 1] = { name = name, ids = missing } end
        end
    end
    table.sort(Gather.missingSpots, function(a, b) return a.name < b.name end)
    return questSkipped
end

-- Step 11 (console only): the item or items found at the most dig sites.
local function logMostSites()
    local best, ids = 0, {}
    for id, list in pairs(Gather.sitesOf) do
        if #list > best then best, ids = #list, { id }
        elseif #list == best then ids[#ids + 1] = id end
    end
    table.sort(ids)
    local shown = {}
    for i = 1, math.min(#ids, 8) do
        local n = nil
        pcall(function() n = field(config.Obj.FromID(ids[i]), "name") end)
        shown[i] = tostring(n or "?") .. " (" .. tostring(ids[i]) .. ")"
    end
    if best > 0 then
        detail((string.gsub("Too Many Runes: the most dig sites for one item: " .. best .. " (" .. table.concat(shown, ", ") .. ((#ids > 8) and (", ... " .. #ids .. " items") or "") .. ")", "<", "(")))
    end
end

-- Step 12: the damaged artefacts (the restoration rows the plugin read) that still have no place go to Gather.noDig, sorted by name.
local function listArtefactsWithoutPlace(quest)
    local seen = {}
    for _, info in pairs(Recipes.rowsState.restoredOf or {}) do
        if info.from ~= nil and not seen[info.from] then
            seen[info.from] = true
            if Gather.src[info.from] == nil and not quest[string.lower(tostring(info.fromName))] then Gather.noDig[#Gather.noDig + 1] = tostring(info.fromName) end
        end
    end
    table.sort(Gather.noDig)
end

-- Step 13 (console only): how many sources each gathering skill read from the game's tables.
local function logSourceCounts()
    local parts = {}
    for _, skill in ipairs(SKILLS) do parts[#parts + 1] = LABEL[skill] .. " " .. (Gather.perSkill[skill] or 0) end
    detail("Too Many Runes: gathering sources read from the game's tables: " .. table.concat(parts, ", ") .. " (" .. Gather.count .. " items so far)")
end

-- The data rows have all been read (called by the guide pass below): the dig sites' materials and the hotspots' damaged artefacts get their
-- sources and their dig sites. The steps are above, in the order they run.
function Gather.finish()
    nameDigSites()
    addSiteMaterials()
    addHotspotArtefacts()
    addArtefactsFromSiteLists()
    addArtefactsFromRowNames()
    local spotItems, spotOrder = collectSpotItems()
    local linkCount = applyDeveloperLinks(spotItems)
    shareSitesInSpot(spotItems, spotOrder)
    local quest = readQuestItems()
    local questSkipped = listSpotsWithoutSite(spotItems, spotOrder, quest)
    logMostSites()
    detail("Too Many Runes: dig sites given by the developer's links: " .. linkCount .. "; dig spots still without a dig site: " .. #Gather.missingSpots .. " (quest items left out: " .. questSkipped .. ")")
    listArtefactsWithoutPlace(quest)
    logSourceCounts()
end

----- the skill guides: a last resort for gathered items no table gave -----
-- (the Mining guide's geode entries - "Higher chance at finding geodes when mining copper and tin rocks" - are kept as the pass meets them,
-- for addGeodes below: { words = { "copper", "tin" }, members = true / false })
Gather.geodeRocks = {}
local function noteGeodeRocks(name, struct)
    local X = Exceptions.geodes
    local list = X and string.match(string.lower(name), X.guideName)
    if list == nil then return end
    local words = {}
    for part in string.gmatch(list .. " and ", "(.-) and ") do words[#words + 1] = part end
    local lastPart = words[#words] or ""
    local shared = string.find(lastPart, " ", 1, true) and string.match(lastPart, "(%S+)$") or nil -- ("light and dark animica")
    for k = 1, #words - 1 do if shared ~= nil and not string.find(words[k], " ", 1, true) then words[k] = words[k] .. " " .. shared end end
    local members = getField(fieldList(struct, "SKILLGUIDE_MEMBERS"), "SKILLGUIDE_MEMBERS")
    Gather.geodeRocks[#Gather.geodeRocks + 1] = { words = words, members = isTrue(members) }
end
Gather.noteGeodeRocks = noteGeodeRocks -- (dev/mock_test.lua)
Gather.guideState = { skillPos = 1, entryPos = 0 }
Gather.guideOnly = {} -- skill -> names of the items that have only the guide as a source

----- boss drops -----
-- The game numbers its bosses (BSLAY_ID, carried by each boss's creatures). The list BSLAY_INT_TO_STRUCT holds one record per boss; the
-- record has the
-- boss's name (BSLAY_NAME) and BSLAY_BOSS_SPEC_DROPS, a list of the items the boss is known for. The data has no drop chances and nothing
-- for ordinary
-- monsters. Each of those items gets a plain row "Dropped by <boss>" on its Source tab (no picture, no click), one row for each boss that drops it.
-- They do not count for the "Gathered" filter (Gather.has) or for the search by skill: only the Source tab shows them.
Gather.bossStats = { bosses = 0, items = 0 }

-- "Dropped by The Barrows: Rise of the Six" is too long for a row: the name loses its "The ", then what follows a comma, then its end.
local function bossText(name)
    local text = "Dropped by " .. name
    if #text > MAX_TEXT and string.sub(name, 1, 4) == "The " then text = "Dropped by " .. string.sub(name, 5) end
    if #text > MAX_TEXT then
        local first = string.match(name, "^([^,]+),")
        if first ~= nil then text = "Dropped by " .. first end
    end
    if #text > MAX_TEXT then text = string.sub(text, 1, MAX_TEXT - 2) .. ".." end
    return text
end

local function addBossSource(id, bossName)
    local list = Gather.src[id]
    if list == nil then
        list = {}
        Gather.src[id] = list -- (not counted in Gather.count: that counts the gathered items)
    end
    local text = bossText(bossName)
    local first = true
    for _, s in ipairs(list) do
        if s.plain == text then return end
        if s.boss then first = false end
    end
    list[#list + 1] = { skill = "DROP", level = 0, plain = text, name = bossName, boss = true }
    if first then Gather.bossStats.items = Gather.bossStats.items + 1 end
end

local function addBossDrops()
    local index = nil
    pcall(function() index = config.Enum["BSLAY_INT_TO_STRUCT"] end)
    local entries, count = field(index, "values"), field(index, "valueCount")
    if entries == nil or type(count) ~= "number" then return end
    for e = 1, Recipes.listCount(count, 200, "BSLAY_INT_TO_STRUCT") do
        local struct = valueAt(valueAt(entries, e), 2)
        if field(struct, "typeName") == "Struct" then
            local f = fieldList(struct, "BSLAY_")
            local name = textOf(getField(f, "BSLAY_NAME"))
            local list = getField(f, "BSLAY_BOSS_SPEC_DROPS")
            local items, itemCount = field(list, "values"), field(list, "valueCount")
            if name ~= nil and items ~= nil and type(itemCount) == "number" then
                Gather.bossStats.bosses = Gather.bossStats.bosses + 1
                for k = 1, Recipes.listCount(itemCount, 200, "the drops of " .. name) do
                    local id = itemOf(valueAt(valueAt(items, k), 2))
                    if id ~= nil then addBossSource(id, name) end
                end
            end
        end
    end
end

-- 3.0.97: the game's collection logs (the drops check of 3.0.96): the table COLLECTION_LOG has a row per log, whose column 8 lists the
-- log's own rows; each of those has its name in column 5 and its items in column 14. Read: the Boss log (an item no boss record above
-- names gets "Dropped by <boss>"), the Slayer log ("Dropped by Slayer monsters in <region>") and the Treasure Trail log ("Treasure Trail
-- reward (<tier>)"). (The other logs - Archaeology collections, animal breeding - are not about where an item comes from.)
-- Each gives: the row's words, or the boss's name; and (3.0.98) its search word and the word of its group: "@slayer-morytania",
-- "@medium-clue" and "@clue" (every Treasure Trail reward).
local COLLECTION_LOGS = {
    COLLECTION_LOG_BOSSES = function(name) return nil, name end,
    COLLECTION_LOG_SLAYER = function(name)
        return (name == "General") and "Dropped by Slayer monsters" or ("Dropped by Slayer monsters in " .. name), nil,
            "slayer-" .. Recipes.materialSlug(name)
    end,
    COLLECTION_LOG_CLUESCROLLS = function(name)
        if name == "General" then return "Treasure Trail reward", nil, "clue" end
        return "Treasure Trail reward (" .. name .. ")", nil, Recipes.materialSlug(name) .. "-clue", "clue"
    end,
}
Gather.logStats = { logs = 0, rows = 0 }
local function addCollectionLogs()
    for logName, textFor in pairs(COLLECTION_LOGS) do
        local log = nil
        pcall(function() log = config.DBRow[logName] end)
        local parts = log ~= nil and Recipes.rowValues(log, 8) or nil
        if parts ~= nil then
            Gather.logStats.logs = Gather.logStats.logs + 1
            for k = 1, 200 do
                local row = valueAt(parts, k)
                if row == nil then break end
                local name = textOf(valueAt(Recipes.rowValues(row, 5) or {}, 1))
                local items = Recipes.rowValues(row, 14)
                if name ~= nil and items ~= nil then
                    Gather.logStats.rows = Gather.logStats.rows + 1
                    local text, boss, word, group = textFor(name)
                    for n = 1, 400 do
                        local v = valueAt(items, n)
                        if v == nil then break end
                        local id = itemOf(v)
                        if id ~= nil then
                            if boss ~= nil then
                                local known = false -- (a boss record already names a boss for it: that one is kept)
                                for _, s in ipairs(Gather.src[id] or {}) do if s.boss then known = true end end
                                if not known then addBossSource(id, boss) end
                            elseif #text <= MAX_TEXT then
                                local list = Gather.src[id]
                                if list == nil then list = {}; Gather.src[id] = list end
                                local dupe = false
                                for _, s in ipairs(list) do if s.plain == text then dupe = true end end
                                if not dupe then
                                    list[#list + 1] = { skill = "DROP", level = 0, plain = text, name = name, log = true, word = word, group = group }
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

-- 3.0.47: every named place an item is gathered from ("Castra debris", "Copper rock", a fishing spot, a boss) gets a search word:
-- "@castra-debris" lists everything found there (Recipes.stationIndex holds the items, the same way as a dig site's). The picture on that
-- Source row types it. (A dig site already has its own word and pictures; of the skill guides' words about where, only short ones are
-- place names: "Shark pools at fish farms", not a sentence.)
Gather.nodeWords = {}
-- The search word of a drop: the boss's ("araxxi", its name without "The ") or the log's ("slayer-morytania"); nil if it has none.
function Gather.dropWord(s)
    local word = nil
    if s.boss and type(s.name) == "string" then word = Recipes.materialSlug((string.gsub(s.name, "^The ", "")))
    elseif s.log then word = s.word end
    if type(word) == "string" and word ~= "" and Gather.nodeWords[word] and Recipes.stationIndex[word] ~= nil then return word end
    return nil
end
function Gather.wordOf(s)
    if s.plain ~= nil or s.foundAt ~= nil or type(s.name) ~= "string" then return nil end
    local slug = Recipes.materialSlug((string.gsub(s.name, " Woodcutting$", "")))
    if Gather.nodeWords[slug] or Gather.siteWords[slug] then return slug end
    return nil
end
local function indexPlaces()
    local taken = {} -- (a word that already means something else keeps that meaning)
    for k in pairs(Recipes.stationIndex) do taken[k] = true end
    for _, name in pairs(skillNames or {}) do if type(name) == "string" then taken[string.lower(name)] = true end end
    local count = 0
    for id, list in pairs(Gather.src) do
        for _, s in ipairs(list) do
            local short = type(s.name) == "string" and #s.name <= 40 and select(2, string.gsub(s.name, "%S+", "")) <= 6
            if s.plain == nil and (not s.guide or short) and type(s.name) == "string" and not (s.skill == "ARCHAEOLOGY" and not s.spot) then
                local slug = Recipes.materialSlug((string.gsub(s.name, " Woodcutting$", "")))
                if slug ~= "" and (Gather.nodeWords[slug] or not taken[slug]) then
                    if not Gather.nodeWords[slug] then Gather.nodeWords[slug] = true; count = count + 1 end
                    local set = Recipes.stationIndex[slug]
                    if set == nil then set = {}; Recipes.stationIndex[slug] = set end
                    set[id] = true
                end
            end
        end
    end
    -- (3.0.98: the drops - "@araxxi" (a boss: its name without "The "), "@boss" (every boss drop), "@slayer-morytania", "@medium-clue",
    -- "@clue" (every Treasure Trail reward); a word that already means something else keeps that meaning)
    local function addWord(word, id)
        if word == nil or word == "" or (taken[word] and not Gather.nodeWords[word]) then return end
        Gather.nodeWords[word] = true
        local set = Recipes.stationIndex[word]
        if set == nil then set = {}; Recipes.stationIndex[word] = set end
        set[id] = true
    end
    for id, list in pairs(Gather.src) do
        for _, s in ipairs(list) do
            if s.boss and type(s.name) == "string" then
                addWord(Recipes.materialSlug((string.gsub(s.name, "^The ", ""))), id)
                addWord("boss", id)
            elseif s.skill == "MINING" and s.plain == nil and not s.guide then
                addWord("rock", id) -- ("@rock": everything mined from a rock - the game's rock table, not the guide)
            elseif s.skill == "WOODCUTTING" and s.plain == nil and not s.guide then
                addWord("tree", id) -- ("@tree": everything cut from a tree - the game's tree table, not the guide - as @rock)
            elseif s.skill == "DIVINATION" and s.plain == nil and not s.guide then
                addWord("wisp", id) -- ("@wisp": everything harvested from a wisp - the game's wisp table, not the guide)
            elseif s.log then
                addWord(s.word, id)
                addWord(s.group, id)
                -- (@slayer, the skill's own word: the Slayer log's drops are Slayer items too - the developer, 3.0.99. The skill search
                -- counts what the stations index holds under the skill's name: core/query.lua)
                if type(s.word) == "string" and string.sub(s.word, 1, 7) == "slayer-" then
                    local set = Recipes.stationIndex["slayer"]
                    if set == nil then set = {}; Recipes.stationIndex["slayer"] = set end
                    set[id] = true
                end
            end
        end
    end
    -- (3.0.86: @patch - everything grown in a farming patch: the game's patch lists, not the other Farming sources - a beehive's honeycombs)
    local patch = Recipes.stationIndex["patch"] or {}
    for id in pairs(Gather.patchCrops) do patch[id] = true end
    if next(patch) ~= nil then Recipes.stationIndex["patch"] = patch; Gather.nodeWords["patch"] = true end
    detail("Too Many Runes: places to gather from, each with its own search word: " .. count)
end
Gather.indexPlaces = indexPlaces -- (dev/mock_test.lua)

-- STONE AND WOOD SPIRITS (3.1.33, the developer: "mining copper ore can drop other items ... what items all drop from each rock and
-- tree"). An ore carries its stone spirit in the setting STONE_SPIRIT_LIST, a kind of log its wood spirit in WOOD_SPIRIT_LIST (the node
-- check of 3.1.30 - 3.1.32). A spirit comes from the same rocks and trees as its ore or logs, so it is given their sources: its Source tab
-- shows them ("Mining level: 1 - Copper rock") and the rock's or tree's search word finds it with the ore. (The other extras the check
-- looked for - gems from ordinary rocks, bird's nests, geodes, chronicle fragments - are not tied to a rock, tree or wisp in the game's
-- data.)
local function addSpirits()
    local params = {}
    pcall(function() params.MINING = config.Param.STONE_SPIRIT_LIST end)
    pcall(function() params.WOODCUTTING = config.Param.WOOD_SPIRIT_LIST end)
    local todo = {}
    for id, list in pairs(Gather.src) do
        for _, s in ipairs(list) do
            if params[s.skill] ~= nil and not s.guide and s.name ~= nil then todo[#todo + 1] = { id = id, s = s } end
        end
    end
    local spiritsOf, added = {}, 0
    for _, t in ipairs(todo) do
        local spirits = spiritsOf[t.id]
        if spirits == nil then
            spirits = {}
            spiritsOf[t.id] = spirits
            local p = params[t.s.skill]
            local obj = try(function() return config.Obj.FromID(t.id) end)
            local okH, has = pcall(function() return obj:HasParam(p) end)
            local en = nil
            if okH and has == true then pcall(function() en = obj:GetParamValue(p) end) end
            local entries, n = field(en, "values"), field(en, "valueCount")
            if entries ~= nil and type(n) == "number" then
                for k = 1, math.min(n, 10) do
                    local spirit = valueAt(valueAt(entries, k), 2)
                    local sid = field(spirit, "id")
                    if field(spirit, "typeName") == "Obj" and type(sid) == "number" and sid ~= t.id then spirits[#spirits + 1] = sid end
                end
            end
        end
        for _, sid in ipairs(spirits) do
            addSource(sid, t.s.skill, t.s.level, t.s.name, nil, nil, t.s.spot, nil)
            added = added + 1
        end
    end
    detail("Too Many Runes: stone and wood spirits given their rocks and trees: " .. added)
end
Gather.addSpirits = addSpirits -- (dev/mock_test.lua)

-- GEODES: given the rocks the Mining guide names as their sources (Gather.geodeRocks, above) - a free-to-play rock its sedimentary geode, a
-- members rock its igneous and metamorphic ones (recipes/exceptions.lua, geodes) - so a geode's Source tab lists the rocks it is found in,
-- and @rock and each rock's own word find it. (What a geode gives when opened is not in the game's data.)
local function addGeodes()
    local X = Exceptions.geodes
    if X == nil or #Gather.geodeRocks == 0 then return 0 end
    local rocks = {} -- "copper rock" -> the rock's source (its level and name, from the rock table)
    for _, list in pairs(Gather.src) do
        for _, s in ipairs(list) do
            if s.skill == "MINING" and not s.guide and s.plain == nil and type(s.name) == "string" then
                local lower = string.lower(s.name)
                if rocks[lower] == nil or s.level < rocks[lower].level then rocks[lower] = s end
            end
        end
    end
    local function geodeIds(names) -- (by their debug names: the game's own table of names, so no going through every item)
        local ids = {}
        for _, n in ipairs(names) do
            local gid = try(function() return id.Obj[n] end)
            if type(gid) == "number" and Items.slotOf[gid] ~= nil then ids[#ids + 1] = gid end
        end
        if #ids < #names then -- (the table did not answer: every item's debug name, once)
            local wanted = {}
            for _, n in ipairs(names) do wanted[string.lower(n)] = true end
            ids = {}
            for slot = 1, #Items.ids do if wanted[Items.debug[slot] or ""] then ids[#ids + 1] = Items.ids[slot] end end
        end
        return ids
    end
    local f2p, members = geodeIds(X.f2p), geodeIds(X.members)
    local added, missing = 0, {}
    for _, entry in ipairs(Gather.geodeRocks) do
        local words = {}
        for _, w in ipairs(entry.words) do
            if w == "primal" then for _, p in ipairs(X.primal or {}) do words[#words + 1] = p end else words[#words + 1] = w end
        end
        for _, w in ipairs(words) do
            local rock = rocks[w .. " rock"]
            if rock == nil then missing[#missing + 1] = w end
            for _, gid in ipairs((rock ~= nil) and (entry.members and members or f2p) or {}) do
                addSource(gid, "MINING", rock.level, rock.name, nil, nil, rock.spot, nil)
                added = added + 1
            end
        end
    end
    if #missing > 0 then detail("Too Many Runes: geode rocks not in the rock table: " .. table.concat(missing, ", ")) end
    return added
end
Gather.addGeodes = addGeodes -- (dev/mock_test.lua)

-- ENERGY (playerFacts.energy, recipes/player.lua): harvesting a wisp gives its energy as well as its memories, so an energy is given the
-- wisps its memories come from ("Pale memory" -> "Pale energy"; an enriched memory's wisp too).
local function addEnergies()
    if Recipes.energyOfMemory == nil then return 0 end
    local todo = {}
    for id, list in pairs(Gather.src) do
        for _, s in ipairs(list) do
            if s.skill == "DIVINATION" and not s.guide and s.plain == nil and s.name ~= nil then todo[#todo + 1] = { id = id, s = s } end
        end
    end
    local added = 0
    for _, t in ipairs(todo) do
        local slot = Items.slotOf[t.id]
        local energy = slot and Recipes.energyOfMemory(Items.lower[slot], t.id) or nil
        if energy ~= nil then
            addSource(energy, "DIVINATION", t.s.level, t.s.name, nil, nil, t.s.spot, nil)
            added = added + 1
            -- (and its search word, "@energy-rift": every energy made at a rift - put here as well as by the recipe check)
            local word = ((Recipes.playerFacts and Recipes.playerFacts().energy) or {}).station
            if word ~= nil then
                local set = Recipes.stationIndex[word]
                if set == nil then set = {}; Recipes.stationIndex[word] = set end
                set[energy] = true
            end
        end
    end
    return added
end
Gather.addEnergies = addEnergies -- (dev/mock_test.lua)

local function guideDone()
    pcall(applyWhere)
    local okS, errS = pcall(addSpirits)
    if not okS then trouble("reading the stone and wood spirits", errS) end
    local okG, errG = pcall(addGeodes)
    if not okG then trouble("giving the geodes their rocks", errG) end
    local okE, errE = pcall(addEnergies)
    if not okE then trouble("giving the energies their wisps", errE) end
    local okB, errB = pcall(addBossDrops)
    if not okB then print("Too Many Runes: could not read the boss drops: " .. tostring(errB)) end
    local okL, errL = pcall(addCollectionLogs)
    if not okL then print("Too Many Runes: could not read the collection logs: " .. tostring(errL)) end
    pcall(indexPlaces)
    Gather.ready = true
    local lines, counts = {}, {}
    for _, skill in ipairs(SKILLS) do
        local names = Gather.guideOnly[skill]
        if names ~= nil and #names > 0 then
            local shown = {}
            for i = 1, math.min(#names, 12) do shown[i] = names[i] end
            lines[#lines + 1] = LABEL[skill] .. " " .. #names .. " (" .. table.concat(shown, ", ") .. ((#names > 12) and ", ..." or "") .. ")"
            counts[#counts + 1] = LABEL[skill] .. " " .. #names
        end
    end
    local statParts = {}
    for _, skill in ipairs(SKILLS) do
        local st = Gather.guideStats[skill]
        if st ~= nil and st.entries > 0 then statParts[#statParts + 1] = LABEL[skill] .. " " .. st.texts .. "/" .. st.entries .. " (" .. st.table .. " of items with a table source)" end
    end
    detail("Too Many Runes: skill guide entries with words about where: " .. ((#statParts > 0) and table.concat(statParts, ", ") or "none"))
    detail("Too Many Runes: gathered items with a skill and a level but no place: " .. ((#counts > 0) and table.concat(counts, ", ") or "none"))
    detail("Too Many Runes: the same, with the names (the skill guide is their only source): " .. ((#lines > 0) and table.concat(lines, "; ") or "none"))
    if #Gather.noDig > 0 then
        local shown = {}
        for i = 1, math.min(#Gather.noDig, 15) do shown[i] = Gather.noDig[i] end
        detail("Too Many Runes: damaged artefacts with no dig spot or dig site: " .. #Gather.noDig .. " (" .. table.concat(shown, ", ") .. ((#Gather.noDig > 15) and ", ..." or "") .. ")")
    end
    -- the dig spots and the damaged artefacts that still have no dig site, ready to be copied into playerFacts.digSites.links (ii_exceptions.lua)
    local function nameOfItem(id)
        local n = nil
        pcall(function() n = field(config.Obj.FromID(id), "name") end)
        return tostring(n or id)
    end
    local missing = Gather.missingSpots or {}
    if #missing > 0 or #Gather.noDig > 0 then
        detail("Too Many Runes: DIG SITE MISSING for " .. #missing .. " dig spots and " .. #Gather.noDig .. " damaged artefacts. Write the dig site after each = in playerFacts.digSites.links (ii_exceptions.lua), or send these lines:")
        for i = 1, math.min(#missing, 200) do
            local names = {}
            for k = 1, math.min(#missing[i].ids, 4) do names[k] = nameOfItem(missing[i].ids[k]) end
            detail((string.gsub("Too Many Runes:   [\"" .. missing[i].name .. "\"] = \"\",  -- " .. table.concat(names, ", ") .. ((#missing[i].ids > 4) and ", ..." or ""), "<", "(")))
        end
        for i = 1, math.min(#Gather.noDig, 100) do
            detail((string.gsub("Too Many Runes:   [\"" .. Gather.noDig[i] .. "\"] = \"\",  -- (a damaged artefact with no dig spot)", "<", "(")))
        end
    end
    detail("Too Many Runes: " .. Gather.count .. " items have a source (mined, cut, caught, grown, hunted, collected or dug up).")
    detail("Too Many Runes: " .. Gather.bossStats.items .. " items are known boss drops (" .. Gather.bossStats.bosses .. " bosses).")
    if Recipes.onDataReady then pcall(Recipes.onDataReady) end
end

function Gather.guideStep()
    local S = Gather.guideState
    if Gather.ready or Recipes.rowsState == nil or not Recipes.rowsState.ready then return end -- (rowsState: recipes/guides.lua)
    if not Items.loaded then return end -- (the geodes, energies and spirits are found among the items: the whole list first)
    if not Gather.finished then
        Gather.finished = true -- (the data rows are all read: the dig sites' materials get their sources first)
        local ok, err = pcall(Gather.finish)
        if not ok then print("Too Many Runes: could not finish reading the gathering tables: " .. tostring(err)) end
        return
    end
    local skill = SKILLS[S.skillPos]
    if skill == nil then
        guideDone()
        return
    end
    if S.entryPos == 0 then
        S.en, S.wanted, S.count = nil, {}, 0
        pcall(function() S.en = config.Enum["SKILLGUIDE_" .. skill] end)
        local filters = nil
        pcall(function() filters = config.Enum["SKILLGUIDE_" .. skill .. "_FILTERS"] end)
        local fe, fc = field(filters, "values"), field(filters, "valueCount")
        if fe ~= nil and type(fc) == "number" then
            for e = 1, math.min(fc, 40) do
                local entry = valueAt(fe, e)
                local fname = valueAt(entry, 2)
                if type(fname) == "string" and GATHERED[skill][string.lower(fname)] then S.wanted[tostring(valueAt(entry, 1))] = true end
            end
        end
        local count = field(S.en, "valueCount")
        if type(count) ~= "number" or count < 1 or field(S.en, "values") == nil then
            S.skillPos = S.skillPos + 1
            return
        end
        S.count = Recipes.listCount(count, 1000, "SKILLGUIDE_" .. skill)
        S.entryPos = 1
        return
    end
    local entries = field(S.en, "values")
    local last = math.min(S.entryPos + Scan.of(40) - 1, S.count)
    for e = S.entryPos, last do
        local struct = valueAt(valueAt(entries, e), 2)
        if field(struct, "typeName") == "Struct" then
            local id, itemName, level, name, filter, info = guideRecord(struct)
            if id == nil and skill == "MINING" and type(name) == "string" then noteGeodeRocks(name, struct) end
            if id ~= nil and skill == "FARMING" then -- (the grimy herb, as from the patch lists: 3.0.87)
                local crop = patchCrop(id)
                if crop ~= id then id = crop; itemName = Items.names[Items.slotOf[crop]] or itemName end
            end
            local stats = Gather.guideStats[skill]
            if stats == nil then stats = { entries = 0, texts = 0, table = 0 }; Gather.guideStats[skill] = stats end
            if id ~= nil and S.wanted[tostring(filter)] then
                stats.entries = stats.entries + 1
                if info ~= nil then stats.texts = stats.texts + 1 end
            end
            if id ~= nil and S.wanted[tostring(filter)] and hasTableSource(id, skill) and info ~= nil then
                stats.table = stats.table + 1
            end
            if id ~= nil and S.wanted[tostring(filter)] and not hasTableSource(id, skill) then
                local lower = string.lower(itemName)
                if S.ignore == nil then S.ignore, S.places, S.drops = gatheredFacts() end
                if S.ignore[lower] then
                    -- (not wanted, e.g. a minigame item)
                elseif S.places[lower] ~= nil then
                    for _, p in ipairs(S.places[lower]) do addSource(id, p[1], (p[1] == skill) and level or 0, p[2]) end
                elseif S.drops[lower] ~= nil then
                    addPlain(id, S.drops[lower])
                else
                    local known = false
                    for _, s in ipairs(Gather.src[id] or {}) do
                        if s.skill == skill then known = true end
                    end
                    addSource(id, skill, level, name, nil, true, nil, info)
                    if not known then
                        local list = Gather.guideOnly[skill]
                        if list == nil then list = {}; Gather.guideOnly[skill] = list end
                        list[#list + 1] = itemName
                    end
                end
            end
        end
    end
    S.entryPos = last + 1
    if S.entryPos > S.count then
        S.skillPos = S.skillPos + 1
        S.entryPos = 0
    end
end
Passes.add("gathering guides", Gather.guideStep, function() return Gather.ready end, function()
    if not Gather.ready then pcall(indexPlaces) end
    Gather.ready = true -- (carry on without the guides rather than make the menu wait for ever)
    if Recipes.onDataReady then pcall(Recipes.onDataReady) end
end)

----- using the sources -----

-- An item's sources: a list, or nil. A grimy herb has the sources of its clean herb (the Farming guide lists the clean ones).
local aliasCache = {}
function Gather.sourcesOf(id)
    local list = Gather.src[id]
    if list ~= nil then return list end
    if not Gather.ready then return nil end -- (the grimy herbs wait until everything is read)
    local known = aliasCache[id]
    if known ~= nil then return known or nil end
    local result = false
    local slot = idToSlot ~= nil and idToSlot[id] or nil
    local lower = slot ~= nil and itemLower[slot] or nil
    local rest = lower ~= nil and string.match(lower, "^grimy (.+)$") or nil
    if rest ~= nil and Recipes.slotsOf ~= nil then
        for _, s in ipairs(Recipes.slotsOf("clean " .. rest) or {}) do
            local other = Gather.src[itemIds[s]]
            if other ~= nil then result = other; break end
        end
    end
    aliasCache[id] = result
    return result or nil
end

-- (An item that is only a boss drop is not "gathered": the filter ignores it.)
function Gather.has(id)
    for _, s in ipairs(Gather.sourcesOf(id) or {}) do
        if not s.boss then return true end
    end
    return false
end

-- The levels an item is gathered at: skill (upper case) -> the lowest level (0: no level known), or nil when it has no source.
local aliasLevels = {}
function Gather.levelsOf(id)
    local t = Gather.levels[id]
    if t ~= nil then return t end
    local known = aliasLevels[id]
    if known ~= nil then return known or nil end
    local list = Gather.sourcesOf(id) -- (a grimy herb: the levels of its clean herb)
    if list == nil then return nil end
    t = {}
    for _, s in ipairs(list) do
        if t[s.skill] == nil or (s.level > 0 and (t[s.skill] == 0 or s.level < t[s.skill])) then t[s.skill] = s.level end
    end
    aliasLevels[id] = t
    return t
end

-- The lowest level in a skill (its number) that an item is gathered at: a number (0: no level known), or nil when the item is no part of it.
function Gather.levelIn(id, skill)
    local name = skillNames[skill]
    if ORDER[name] == nil then return nil end -- (not a gathering skill: the common case, answered at once)
    local t = Gather.levelsOf(id)
    if t == nil then return nil end
    return t[name]
end

-- The lowest level over all skills that an item is gathered at (the search by level alone), or nil. Only levels from lo to hi count (either
-- may be nil).
function Gather.lowest(id, lo, hi)
    local t = Gather.levelsOf(id)
    if t == nil then return nil end
    local best = nil
    for _, level in pairs(t) do
        if level > 0 and (best == nil or level < best) and (lo == nil or level >= lo) and (hi == nil or level <= hi) then best = level end
    end
    return best
end

-- A small count as a word ("one", "two" ... "twelve"), a bigger one as digits: the dig site lines read "Found at two dig sites:" (the
-- developer's wording).
local NUMBER_WORDS = { "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "twelve" }
local function numberWord(n)
    return NUMBER_WORDS[n] or tostring(n)
end

-- One source as a line: "Mining 20 - Coal rock", "Fishing 5 - Small Net/Bait Saltwater (bait)"
local function lineOf(s)
    if s.plain ~= nil then return (string.gsub(s.plain, "<", "<lt>")) end
    local text = LABEL[s.skill] or s.skill
    if s.level > 0 then text = text .. " level: " .. s.level end -- ("Mining level: 50 - Runite rock")
    if s.name ~= nil then
        local name = string.gsub(s.name, " Woodcutting$", "")
        text = text .. " - " .. name
        if s.bait and #text + 7 <= MAX_TEXT then text = text .. " (bait)" end
    end
    if #text > MAX_TEXT then text = string.sub(text, 1, MAX_TEXT - 2) .. ".." end
    return (string.gsub(text, "<", "<lt>"))
end

-- the order of the sources on the Source tab: by skill, then level, then name
local function sourceBefore(a, b)
    if a.skill ~= b.skill then return (ORDER[a.skill] or 99) < (ORDER[b.skill] or 99) end
    if a.level ~= b.level then return a.level < b.level end
    return tostring(a.name) < tostring(b.name)
end

-- The rows for the Source tab, at most `room` of them (the last may be "(N more sources)"), or nil when the item has no source.
function Gather.rowsOf(id, room)
    local list = Gather.sourcesOf(id)
    if list == nil or #list == 0 then return nil end
    local sorted, dig = {}, {}
    for _, s in ipairs(list) do
        if s.skill == "ARCHAEOLOGY" and s.name ~= nil and not s.guide and not s.spot then dig[#dig + 1] = s else sorted[#sorted + 1] = s end
    end
    -- the row of dig site pictures (only when every site has its picture): after the last Archaeology line
    local sitesRow = nil
    local slugs = Gather.sitesOf[id]
    if slugs ~= nil and #slugs > 0 then
        local ordered, entries = {}, {}
        for _, slug in ipairs(slugs) do ordered[#ordered + 1] = slug end
        table.sort(ordered, function(a, b) return (Gather.slugRank[a] or 99) < (Gather.slugRank[b] or 99) end)
        for _, slug in ipairs(ordered) do
            if Recipes.stationSprite("site_" .. slug) == nil then entries = nil; break end
            entries[#entries + 1] = { sprite = "site_" .. slug, over = (Recipes.stationSprite("site_" .. slug .. "_over") ~= nil) and ("site_" .. slug .. "_over") or nil,
                                      query = "@" .. slug, name = Gather.siteNames[slug] }
        end
        if entries ~= nil and #entries > 0 then sitesRow = { text = "", sites = entries } end
    end
    if #dig > 0 then
        -- one line for all the dig sites that give it: "Archaeology 12 - 2 dig sites" (their pictures follow, below; the names, when there
        -- are no pictures)
        table.sort(dig, function(a, b) return (Gather.siteRank[a.name] or 99) < (Gather.siteRank[b.name] or 99) end)
        local level = 0
        local names = {}
        for _, s in ipairs(dig) do
            if s.level > 0 and (level == 0 or s.level < level) then level = s.level end
            names[#names + 1] = s.name
        end
        local name, siteList = table.concat(names, ", "), nil
        if sitesRow ~= nil or #dig > 1 then
            name = #dig .. ((#dig == 1) and " dig site" or " dig sites")
            if sitesRow == nil then siteList = names end -- (no pictures: the names follow on the next line)
        end
        sorted[#sorted + 1] = { skill = "ARCHAEOLOGY", level = level, name = name, foundAt = (sitesRow ~= nil) and #dig or nil, siteList = siteList }
    end
    table.sort(sorted, sourceBefore)
    -- a guide row that only says HOW (a perk: "Barehanded catching", "Possibility of catching") is left out when the item has a row with
    -- words about where
    local anyInfo = false
    for _, s in ipairs(sorted) do if s.info ~= nil then anyInfo = true end end
    if anyInfo then
        local kept = {}
        for _, s in ipairs(sorted) do
            if not (s.guide and s.info == nil and s.name ~= nil and string.find(string.lower(s.name), "catching", 1, true)) then kept[#kept + 1] = s end
        end
        sorted = kept
    end
    local rows = {}
    local cap = math.min(MAX_SOURCES, room or MAX_SOURCES)
    if sitesRow ~= nil then
        if cap >= 2 then cap = cap - 1 else sitesRow = nil end -- (the pictures take a place)
    end
    local shown, more = #sorted, false
    if #sorted > cap then
        if cap >= 2 then shown, more = cap - 1, true else shown = cap end -- (the "more" line takes a place)
    end
    for i = 1, shown do
        local s = sorted[i]
        -- the dig sites (with their pictures below): "Found at one dig site:", "Found at five dig sites:" (the developer's wording); the
        -- level is in the search ("@archaeology 12")
        local text = (s.foundAt ~= nil) and ("Found at " .. numberWord(s.foundAt) .. ((s.foundAt == 1) and " dig site" or " dig sites") .. ":") or lineOf(s)
        if s.plain ~= nil then
            local row = { text = text, skill = s.skill }
            -- (3.1.15: a drop has the developer's picture, Exceptions.stationSpriteNumbers.src_drop, which searches the boss or the log -
            -- "@araxxi", "@slayer-morytania"; 3.1.16: a Treasure Trail reward its own, src_clue, which searches its clue - "@medium-clue")
            if s.skill == "DROP" then
                row.sprite = (s.group == "clue") and "src_clue" or "src_drop"
                local word = Gather.dropWord(s)
                if word ~= nil then row.query = "@" .. word end
            end
            rows[#rows + 1] = row
        else -- (the picture searches the place, "@castra-debris"; or the skill, when the place has no word)
            rows[#rows + 1] = { text = text, sprite = "src_" .. string.lower(s.skill), query = "@" .. (Gather.wordOf(s) or string.lower(s.skill)), skill = s.skill }
        end
        if s.siteList ~= nil then rows[#rows + 1] = { text = (string.gsub(table.concat(s.siteList, ", "), "<", "<lt>")) } end
    end
    if sitesRow ~= nil then
        for i = #rows, 1, -1 do
            if rows[i].skill == "ARCHAEOLOGY" then table.insert(rows, i + 1, sitesRow); break end
        end
    end
    if more then rows[#rows + 1] = { text = "(" .. (#sorted - shown) .. " more sources)" } end
    -- (and how many sources: the Source tab's count - every dig site counts, though they share a line; 3.0.88)
    return rows, #sorted + ((#dig > 1) and (#dig - 1) or 0)
end

end }
