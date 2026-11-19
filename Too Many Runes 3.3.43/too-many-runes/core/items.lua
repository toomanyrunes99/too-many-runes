-- Too Many Runes - The item list
-- Asks the game about item numbers 0, 1, 2 and up, a few hundred per tick, and records every item that exists.
-- It stops after ITEM_ID_GAP numbers in a row have no item. MAX_ITEM_ID is only a safety stop.
-- Each item gets a "slot", its place in these lists. Slots are in item-number order.
return { run = function(T)
local _ENV = T

Items = {
    ids = {},      -- item number, by slot
    names = {},    -- name, by slot
    lower = {},    -- name in lower case, by slot (for searching)
    idText = {},   -- item number as text, by slot (for searching by number)
    slotOf = {},   -- slot, by item number
    flags = {},    -- kind of clutter, by slot (only for items that are clutter)
    debug = {},    -- the game's own name (debug name) in lower case, by slot. Searched when SHOW_DEBUG_NAMES is on
    trade = {},    -- true when the item can be traded. The item groups show a tradeable form first
    quests = {},   -- quests the game ties to the item, as { { id =, name = } ... } (recipes/quests.lua; only items that have any)
    members = {},  -- true for a members item (@members and @f2p in recipes/tags.lua)
    ops = {},      -- for each word in RIGHT_CLICK_WORDS, the slots whose right-click menu has it (@teleport, @bury in recipes/tags.lua)
    ge = {},       -- true when the item is sold on the Grand Exchange. The groups show such a form first
    nextId = 0, loaded = false, highest = 0,
}

-- The kinds of clutter the hide switches can hide (one bit each).
Items.NOTED, Items.BROKEN, Items.JUNK, Items.DUNG, Items.DISC = 1, 2, 8, 16, 32 -- 4 is not used

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
local junkWords = nil -- JUNK_NAME_WORDS written as "_WORD_", built on first use
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

Items.classify = classify -- shared so the offline test can check it

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
    local tradeable = field(cfg, "isTradeable")
    if tradeable == true or tradeable == 1 then Items.trade[slot] = true end
    local ge = field(cfg, "isStockmarket")
    if ge == true or ge == 1 then Items.ge[slot] = true end
    -- Members, and the right-click options that are search words. An option counts when it is the word or starts with it
    -- ("Teleport", "Teleport to house").
    local members = field(cfg, "isMembers")
    if members == true or members == 1 then Items.members[slot] = true end
    if RIGHT_CLICK_WORDS ~= nil then
        pcall(function()
            for _, op in pairs(cfg.interfaceOpNames or {}) do
                if type(op) == "string" and op ~= "" then
                    local lower = string.lower(op)
                    for _, w in ipairs(RIGHT_CLICK_WORDS) do
                        if lower == w or string.sub(lower, 1, #w + 1) == w .. " " then
                            local set = Items.ops[w]
                            if set == nil then set = {}; Items.ops[w] = set end
                            set[slot] = true
                        end
                    end
                end
            end
        end)
    end
    -- The item's "quests" list, which the game describes as all quests related to this config. It is what puts the little
    -- quest mark in the item's right-click menu. About 1,900 items have one, mostly from newer quests. Older quest items have
    -- none in the game's data.
    pcall(function()
        local list = cfg.quests
        if list == nil then return end
        for _, q in pairs(list) do
            local name = field(q, "name")
            if type(name) == "string" and name ~= "" then
                local mine = Items.quests[slot]
                if mine == nil then mine = {}; Items.quests[slot] = mine end
                mine[#mine + 1] = { id = field(q, "id"), name = name }
            end
        end
    end)
    local f = classify(Items.lower[slot], configName, field(cfg, "category"))
    -- What the game's data cannot say comes from the RuneScape Wiki's lists in data/wiki_lists.lua: items removed from the
    -- game, bought with real money, Dungeoneering only, or no longer obtainable.
    for _, r in ipairs(JUNK_ID_RANGES or {}) do -- items marked by their numbers in settings.lua
        if n >= r[1] and n <= r[2] then f = f | Items.JUNK break end
    end
    local wiki = WikiLists and WikiLists.is
    if wiki ~= nil then
        if wiki.removed[n] or wiki.microtransaction[n] then f = f | Items.JUNK end
        if wiki.dungeoneering[n] then f = f | Items.DUNG end
        if wiki.discontinued[n] then f = f | Items.DISC end
    end
    -- An item the game ties to its MTX store is an MTX item too, whatever its debug name. The setting is MTXMGT_ITEM_STRUCT,
    -- for example on the cosmetic "Crest of Seren" from Solomon's store.
    if (f & Items.JUNK) == 0 and mtxParam() then
        local ok, has = pcall(function() return cfg:HasParam(mtxParamValue) end)
        if ok and has == true then f = f | Items.JUNK end
    end
    if f ~= 0 then Items.flags[slot] = f end
end

function Items.count() return #Items.ids end
local GAP = ITEM_ID_GAP or 5000
local function stopAt() return math.min(MAX_ITEM_ID, Items.highest + GAP) end -- the last number to ask about, as far as is known so far
function Items.progress() return math.min(1, Items.nextId / math.max(ITEM_ID_GUESS or 70000, Items.highest + GAP)) end
function Items.is(slot, flag) return ((Items.flags[slot] or 0) & flag) ~= 0 end

Passes.add("item list", function()
    local perTick = math.max(20, math.floor(ITEMS_PER_TICK * Scan.paced() + 0.5)) -- fewer while the game is struggling (core/passes.lua)
    local last = math.min(Items.nextId + perTick - 1, stopAt())
    for n = Items.nextId, last do Items.add(n) end
    Items.nextId = last + 1
    if Items.nextId > stopAt() then
        Items.loaded = true
        say("ready (" .. withCommas(#Items.ids) .. " items).")
        if Items.highest > MAX_ITEM_ID - GAP then
            say("WARNING - the highest item number found (" .. Items.highest .. ") is close to MAX_ITEM_ID (" .. MAX_ITEM_ID
                .. "): raise MAX_ITEM_ID in settings.lua or the newest items will be missing.")
        end
    end
end, function() return Items.loaded end)

end }
