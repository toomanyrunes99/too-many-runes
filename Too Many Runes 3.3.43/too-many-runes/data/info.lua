-- Too Many Runes - The facts about one item (the Info box)
-- Everything here is read from the item's "card" in the game: its number, members or tradeable, Grand Exchange limit, value,
-- what it takes to wear it and its right-click options. Facts from the game's tables come from recipes/extras.lua.
return { run = function(T)
local _ENV = T

Info = {}
QUEST_PIC = 30103 -- the plugin's quest picture; the game's own right-click menu uses 26112

-- Skill names (0 = Attack, 1 = Defence and so on, from the game's list STAT_TO_STRING) and quest names (the game's list
-- QL4_QUESTS), read once.
local stats, quests = nil, nil
function Info.statName(n)
    stats = stats or readEnum("STAT_TO_STRING", 60)
    local name = stats[n]
    if type(name) == "string" and name ~= "" then return name end
    return "skill #" .. tostring(n)
end
function Info.questName(n)
    if quests == nil then
        quests = {}
        for key, quest in pairs(readEnum("QL4_QUESTS", 1000)) do
            local name = (type(quest) ~= "number" and type(quest) ~= "string") and field(quest, "name") or nil
            if type(name) == "string" and name ~= "" then quests[key] = name end
        end
    end
    return quests[n]
end

-- What an item needs before it can be worn or wielded: { "Attack 40", "Quest: ..." } (the item's WEAR_REQUIRES_ settings).
function Info.wearRequirements(item)
    local out = {}
    local fields = fieldList(item, "WEAR_REQUIRES_")
    if #fields == 0 then return out end
    for n = 1, 5 do
        local stat, level = getField(fields, "WEAR_REQUIRES_STAT" .. n), getField(fields, "WEAR_REQUIRES_STAT_LEVEL" .. n)
        if type(stat) == "number" and type(level) == "number" and level > 0 then out[#out + 1] = Info.statName(stat) .. " " .. level end
    end
    for n = 1, 4 do
        local quest = getField(fields, "WEAR_REQUIRES_QUEST" .. n)
        local name = type(quest) == "number" and Info.questName(quest) or nil
        if name ~= nil then out[#out + 1] = "Quest: " .. name end
    end
    return out
end

-- The item's quests from the game's data (its own "quests" list): { { name, query } }. Shown on the Source tab
-- (recipes/source_tab.lua), not in the Info box.
function Info.questsOf(itemId, item)
    item = item or try(config.Obj.FromID, itemId)
    local out = {}
    pcall(function()
        for _, q in pairs(item.quests or {}) do
            local name = field(q, "name")
            if type(name) == "string" and name ~= "" then out[#out + 1] = { name = name, query = "@quest " .. string.lower(name) } end
        end
    end)
    -- and the quests the RuneScape Wiki says it is found during (the older quests, data/wiki_lists.lua), each once
    local wiki = WikiLists ~= nil and WikiLists.questsOf ~= nil and WikiLists.questsOf[itemId] or nil
    if wiki ~= nil then
        local have = {}
        for _, q in ipairs(out) do have[string.lower(q.name)] = true end
        for _, name in ipairs(wiki) do
            if not have[string.lower(name)] then
                have[string.lower(name)] = true
                out[#out + 1] = { name = name, query = "@quest " .. string.lower(name) }
            end
        end
    end
    return out
end

-- The lines of the Info box for an item (plain text; the box wraps long ones). Returns nil if the game has no such item.
-- Also returns the short facts line for the top of the details column ("Free-to-play · Not tradeable · Quest item"), and the
-- number of the first line drawn dim. The ID, value and right-click lines matter less, so they come last and are drawn dim.
function Info.lines(itemId)
    local item = try(config.Obj.FromID, itemId)
    if item == nil then return nil end
    local lines = {}
    local function add(text) lines[#lines + 1] = text end

    local facts = (isTrue(field(item, "isMembers")) and "Members" or "Free-to-play") .. "  |  "
        .. (isTrue(field(item, "isTradeable")) and "Tradeable" or "Not tradeable")
    if #Info.questsOf(itemId, item) > 0 then facts = facts .. "  |  Quest item" end

    -- The Info box holds only the item's number and game name, its value and Grand Exchange limit, and its right-click options.
    -- What it needs to be worn, and the familiar, relic, currency, Archaeology mystery and farm animal lines, are in its hover box
    -- (ui/details.lua, Details.hoverFor).

    -- the dim lines: number (and the game's own name), value and Grand Exchange, right-click options
    local dimFrom = #lines + 1
    local idLine = "Item ID: " .. itemId
    if SHOW_DEBUG_NAMES == true then
        local debugName = field(item, "configName")
        if type(debugName) == "string" and debugName ~= "" then idLine = idLine .. "  |  " .. debugName end
    end
    add(idLine)
    local cost, value = field(item, "cost"), {}
    if type(cost) == "number" then value[#value + 1] = "Value " .. withCommas(cost) end
    if isTrue(field(item, "isStockmarket")) then
        local limit = field(item, "stockmarketBuyLimit")
        value[#value + 1] = (type(limit) == "number") and ("GE limit " .. withCommas(limit) .. " / 4h") or "On the GE"
    else
        value[#value + 1] = "Not on the GE"
    end
    add(table.concat(value, "  |  "))

    local ops = {}
    pcall(function()
        for _, op in pairs(item.interfaceOpNames) do
            if type(op) == "string" and op ~= "" then ops[#ops + 1] = op end
        end
    end)
    add("Right-click: " .. ((#ops > 0) and table.concat(ops, ", ") or "nothing special"))
    return lines, item, facts, dimFrom
end

end }
