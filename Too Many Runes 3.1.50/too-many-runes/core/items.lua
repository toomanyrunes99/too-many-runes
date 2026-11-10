-- Too Many Runes - The item list
-- Asks the game "is there an item with number 0? 1? 2? ..." up to MAX_ITEM_ID, a few hundred per tick, and writes down every item that
-- exists. Each item gets a "slot" (its place in these lists); slots are in item-number order.
return { run = function(T)
local _ENV = T

Items = {
    ids = {},      -- slot -> item number
    names = {},    -- slot -> name
    lower = {},    -- slot -> name in lower case (for searching)
    idText = {},   -- slot -> item number as text (for searching by number)
    slotOf = {},   -- item number -> slot
    flags = {},    -- slot -> what kind of clutter it is (only for items that are any)
    debug = {},    -- slot -> the game's own name (debug name) in lower case (searched when SHOW_DEBUG_NAMES is on)
    nextId = 0, loaded = false, highest = 0,
}

-- The kinds of clutter the hide switches can hide (one bit each).
Items.NOTED, Items.BROKEN, Items.JUNK, Items.DUNG, Items.DISC = 1, 2, 8, 16, 32 -- (4 is not used)

-- Is a game category one of JUNK_CATEGORIES? (asked once per category)
local junkWanted, junkAnswer = nil, {}
local function junkCategory(category)
    if type(category) ~= "number" or category < 0 then return false end
    if junkAnswer[category] ~= nil then return junkAnswer[category] end
    if junkWanted == nil then
        junkWanted = {}
        for _, name in ipairs(JUNK_CATEGORIES or {}) do junkWanted[string.upper(name)] = true end
    end
    local name = try(function() return id.Category.FromID(category) end)
    junkAnswer[category] = type(name) == "string" and junkWanted[string.upper(name)] == true
    return junkAnswer[category]
end

-- What kind of clutter an item is: a noted copy (its game name starts CERT_), "(broken)", or junk.
local junkWords = nil -- (JUNK_NAME_WORDS as "_WORD_", made the first time)
local function classify(lower, configName, category)
    local f = 0
    if type(configName) == "string" and string.sub(configName, 1, 5) == "CERT_" then f = f | Items.NOTED end
    if string.find(lower, "%(broken%)%s*$") then f = f | Items.BROKEN end
    local junk = junkCategory(category)
    if not junk and type(configName) == "string" then
        local upper = string.upper(configName)
        local padded = "_" .. upper .. "_"
        if junkWords == nil then
            junkWords = {}
            for _, word in ipairs(JUNK_NAME_WORDS or {}) do junkWords[#junkWords + 1] = "_" .. string.upper(word) .. "_" end
        end
        for _, word in ipairs(junkWords) do
            if string.find(padded, word, 1, true) then junk = true break end
        end
        if not junk then
            for _, pattern in ipairs(JUNK_DEBUG_PATTERNS or {}) do
                if string.find(upper, pattern) then junk = true break end
            end
        end
        if not junk and string.find(upper, "TOKEN", 1, true) then
            for _, word in ipairs(JUNK_TOKEN_WITH or {}) do
                if string.find(upper, word, 1, true) then junk = true break end
            end
        end
    end
    if not junk then
        for _, pattern in ipairs(JUNK_NAME_PATTERNS or {}) do
            if string.find(lower, pattern) then junk = true break end
        end
    end
    if junk then f = f | Items.JUNK end
    return f
end

Items.classify = classify -- (dev/mock_test.lua)

-- The game's setting that ties an item to its MTX store (looked up once).
local mtxLooked, mtxParamValue = false, nil
local function mtxParam()
    if not mtxLooked then
        mtxLooked = true
        pcall(function() mtxParamValue = config.Param.MTXMGT_ITEM_STRUCT end)
    end
    return mtxParamValue ~= nil
end
function Items.add(n)
    local cfg = try(config.Obj.FromID, n)
    if cfg == nil then return end
    local name = field(cfg, "name")
    if type(name) ~= "string" or name == "" or name == "null" then return end
    local slot = #Items.ids + 1
    Items.ids[slot], Items.names[slot], Items.lower[slot], Items.idText[slot] = n, name, string.lower(name), tostring(n)
    Items.slotOf[n] = slot
    if n > Items.highest then Items.highest = n end
    local configName = field(cfg, "configName")
    if type(configName) == "string" then Items.debug[slot] = string.lower(configName) end
    local f = classify(Items.lower[slot], configName, field(cfg, "category"))
    -- (what the game's data cannot say - removed from the game, bought with real money, Dungeoneering only, no longer obtainable -
    -- comes from the RuneScape Wiki's lists: data/wiki_lists.lua)
    for _, r in ipairs(JUNK_ID_RANGES or {}) do -- (settings.lua: items marked by their numbers)
        if n >= r[1] and n <= r[2] then f = f | Items.JUNK break end
    end
    local wiki = WikiLists and WikiLists.is
    if wiki ~= nil then
        if wiki.removed[n] or wiki.microtransaction[n] then f = f | Items.JUNK end
        if wiki.dungeoneering[n] then f = f | Items.DUNG end
        if wiki.discontinued[n] then f = f | Items.DISC end
    end
    -- (3.1.00, the developer: an item the game ties to its MTX store - the setting MTXMGT_ITEM_STRUCT, e.g. the cosmetic "Crest of Seren"
    -- from Solomon's store, found by the crest check - is an MTX item too, whatever its debug name)
    if (f & Items.JUNK) == 0 and mtxParam() then
        local ok, has = pcall(function() return cfg:HasParam(mtxParamValue) end)
        if ok and has == true then f = f | Items.JUNK end
    end
    if f ~= 0 then Items.flags[slot] = f end
end

function Items.count() return #Items.ids end
function Items.progress() return math.min(1, Items.nextId / MAX_ITEM_ID) end
function Items.is(slot, flag) return ((Items.flags[slot] or 0) & flag) ~= 0 end

Passes.add("item list", function()
    local perTick = math.max(20, math.floor(ITEMS_PER_TICK * Scan.paced() + 0.5)) -- (fewer while the game struggles: core/passes.lua)
    local last = math.min(Items.nextId + perTick - 1, MAX_ITEM_ID)
    for n = Items.nextId, last do Items.add(n) end
    Items.nextId = last + 1
    if Items.nextId > MAX_ITEM_ID then
        Items.loaded = true
        say("ready (" .. withCommas(#Items.ids) .. " items).")
        if Items.highest > MAX_ITEM_ID - 2000 then
            say("WARNING - the highest item number found (" .. Items.highest .. ") is close to MAX_ITEM_ID (" .. MAX_ITEM_ID
                .. "): raise MAX_ITEM_ID in settings.lua or the newest items will be missing.")
        end
    end
end, function() return Items.loaded end)

end }
