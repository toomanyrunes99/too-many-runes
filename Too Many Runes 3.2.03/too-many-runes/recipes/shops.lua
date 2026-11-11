-- Too Many Runes - Reward shops ("Sold at: Archaeology Guild Shop (2,500 Chronotes)" on the Source tab)
-- All from the game's own data: a reward shop is a bundle (struct) with REWARDSHOP_ITEM_LIST - a list of the bundles of the things it sells
-- - and REWARDSHOP_NAME / REWARDSHOP_CURRENCY (REWARDSHOP_CURRENCY_SINGULAR for one). Each thing it sells is a bundle with REWARDSHOP_OBJ
-- (the item; experience and unlocks have none and are left out) and REWARDSHOP_COST.
-- (An unlock can have a REWARDSHOP_OBJ too - only its picture: otherwise the Artisans' Workshop shows "Sold at" on a Cannonball. So a shop
-- that marks the items it really gives (REWARDSHOP_IS_REWARD_OBJ) has only those counted; in a shop that marks none, a thing whose own name
-- (REWARDSHOP_ITEM_NAME) is not the item's name is left out.)
-- A background pass reads every bundle once (the game's own list of bundle names says which there are), a few hundred a tick.
-- Shops.of(itemId) -> { { shop, cost, currency, word } ... } or nil. Search words: "@shop" (everything a reward shop sells) and one per
-- shop ("@archaeology-guild-shop"), which the picture on the Source row types (recipes/source_tab.lua).
return { run = function(T)
local _ENV = T

Shops = { ready = false, byItem = {}, shops = 0, items = 0 }
local BUDGET = 300
local S = nil -- the pass: { names, k, params }

local function param(name)
    local p = nil
    pcall(function() p = config.Param[name] end)
    return p
end
local function value(st, p)
    if p == nil then return nil end
    local okH, has = pcall(function() return st:HasParam(p) end)
    if not okH or has ~= true then return nil end
    local ok, v = pcall(function() return st:GetParamValue(p) end)
    if ok then return v end
    return nil
end

-- The things one shop sells (its list may hold lists: a shop's tabs).
local function clean(text) return string.lower((string.gsub(tostring(text or ""), "<[^>]*>", ""))) end
local function readList(en, shop, depth, seen)
    local listId = field(en, "id")
    if en == nil or depth > 2 or (listId ~= nil and seen[listId]) then return end
    if listId ~= nil then seen[listId] = true end
    local entries, count = field(en, "values"), field(en, "valueCount")
    if entries == nil or type(count) ~= "number" or count < 1 or field(entries, 1) == nil then return end
    for e = 1, math.min(count, 500) do
        local v = valueAt(valueAt(entries, e), 2)
        local kind = field(v, "typeName")
        if kind == "Enum" then readList(v, shop, depth + 1, seen)
        elseif kind == "Struct" then
            local obj = value(v, S.p.obj)
            local itemId = field(obj, "id")
            if field(obj, "typeName") == "Obj" and type(itemId) == "number" then
                local flag = value(v, S.p.isItem)
                if isTrue(flag) then shop.marks = true end
                local ownName = value(v, S.p.itemName)
                shop.things[#shop.things + 1] = { id = itemId, cost = value(v, S.p.cost), flag = isTrue(flag),
                    named = type(ownName) == "string" and ownName ~= "" and clean(ownName) ~= clean(field(obj, "name")) }
            end
        end
    end
end

-- The things a shop really gives, once its whole list is read.
local function addThings(shop)
    for _, t in ipairs(shop.things) do
        local gives = (shop.marks and t.flag) or (not shop.marks and not t.named)
        if gives then
            local list = Shops.byItem[t.id]
            if list == nil then list = {}; Shops.byItem[t.id] = list; Shops.items = Shops.items + 1 end
            local cost = (type(t.cost) == "number") and t.cost or nil
            local dupe = false
            for _, e2 in ipairs(list) do if e2.shop == shop.name and e2.cost == cost then dupe = true end end
            if not dupe and #list < 12 then
                list[#list + 1] = { shop = shop.name, cost = cost, currency = shop.currency, singular = shop.singular, word = shop.word }
            end
        end
    end
end

local function readShop(st)
    local en = value(st, S.p.list)
    if field(en, "typeName") ~= "Enum" then return end
    local name = value(st, S.p.name)
    if type(name) ~= "string" or name == "" then return end
    name = (string.gsub(name, "<[^>]*>", "")) -- (the game's colour tags)
    local currency = value(st, S.p.currency)
    local singular = value(st, S.p.singular)
    local shop = { name = name, currency = (type(currency) == "string" and currency ~= "") and currency or nil,
                   singular = (type(singular) == "string" and singular ~= "") and singular or nil, word = Recipes.materialSlug(name),
                   things = {}, marks = false }
    Shops.shops = Shops.shops + 1
    readList(en, shop, 0, {})
    addThings(shop)
end

-- The search words, once every bundle has been read.
local function addWords()
    local all = Recipes.stationIndex["shop"] or {}
    for itemId, list in pairs(Shops.byItem) do
        all[itemId] = true
        for _, e in ipairs(list) do
            if e.word ~= nil and e.word ~= "" then
                local set = Recipes.stationIndex[e.word]
                if set == nil then set = {}; Recipes.stationIndex[e.word] = set end
                set[itemId] = true
                if Gather ~= nil and Gather.nodeWords ~= nil then Gather.nodeWords[e.word] = true end
            end
        end
    end
    Recipes.stationIndex["shop"] = all
    if Gather ~= nil and Gather.nodeWords ~= nil then Gather.nodeWords["shop"] = true end
end

local function step()
    if S == nil then
        S = { names = idNames("Struct"), k = 1,
              p = { list = param("REWARDSHOP_ITEM_LIST"), name = param("REWARDSHOP_NAME"), currency = param("REWARDSHOP_CURRENCY"),
                    singular = param("REWARDSHOP_CURRENCY_SINGULAR"), obj = param("REWARDSHOP_OBJ"), cost = param("REWARDSHOP_COST"),
                    isItem = param("REWARDSHOP_IS_REWARD_OBJ"), itemName = param("REWARDSHOP_ITEM_NAME") } }
        if S.p.list == nil or S.p.obj == nil then S.k = #S.names + 1 end -- (the game has no reward shops to hand over)
        return
    end
    for _ = 1, BUDGET do
        local e = S.names[S.k]
        if e == nil then
            addWords()
            Shops.ready = true
            detail("Too Many Runes: reward shops read (" .. Shops.shops .. " shops, " .. Shops.items .. " items)")
            if Recipes.onDataReady then pcall(Recipes.onDataReady) end
            return
        end
        S.k = S.k + 1
        local st = nil
        pcall(function() st = config.Struct.FromID(e.id) end)
        if st ~= nil and value(st, S.p.list) ~= nil then pcall(readShop, st) end
    end
end
Passes.add("reward shops", step, function() return Shops.ready end, function() Shops.ready = true end)

-- "2,500 Chronotes", "1 Ticket", "free"
local function price(e)
    if e.cost == nil then return nil end
    if e.cost == 0 then return "free" end
    local cur = (e.cost == 1 and e.singular) or e.currency
    return formatNumber(e.cost) .. ((cur ~= nil) and (" " .. cur) or "")
end

-- The Source tab's rows for an item a reward shop sells: { text, sprite, query } (the picture is the developer's choice: Exceptions.
-- stationSpriteNumbers.shop, when there is one).
function Shops.rowsOf(itemId)
    local list = Shops.byItem[itemId]
    if list == nil then return nil end
    local rows = {}
    for _, e in ipairs(list) do
        local p = price(e)
        rows[#rows + 1] = { text = "Sold at: " .. e.shop .. ((p ~= nil) and (" (" .. p .. ")") or ""), sprite = "shop", query = "@" .. e.word }
    end
    return rows
end

end }
