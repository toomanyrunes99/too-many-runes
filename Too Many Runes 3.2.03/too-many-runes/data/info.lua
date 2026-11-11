-- Too Many Runes - The facts about one item (the Info box)
-- Everything here is read from the item's "card" in the game: its number, members / tradeable, Grand Exchange limit, value, what it takes
-- to wear it and its right-click options.
return { run = function(T)
local _ENV = T

Info = {}
QUEST_PIC = 30103 -- (the plugin's quest picture - the game's own right-click menu uses 26112)

-- Skill names (0 = Attack, 1 = Defence ...: the game's list STAT_TO_STRING) and quest names (the game's list QL4_QUESTS), read once.
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

-- The lines of the Info box for an item (plain text; the box wraps long ones - a line can also be { text, pic, query }: a picture in
-- front of it that types a search). Returns nil if the game has no such item.
function Info.lines(itemId)
    local item = try(config.Obj.FromID, itemId)
    if item == nil then return nil end
    local lines = {}
    local function add(text) lines[#lines + 1] = text end

    -- "Quest item from: ..." (first in the box) - one line for each quest in the item's own "quests" list (the game's data only, no wiki
    -- data yet). Such a line is a table: its quest picture types that quest's search (recipes/quests.lua; ui/details.lua draws it).
    pcall(function()
        for _, q in pairs(item.quests or {}) do
            local name = field(q, "name")
            if type(name) == "string" and name ~= "" then
                lines[#lines + 1] = { text = "Quest item from: " .. name, pic = QUEST_PIC, query = "@quest " .. string.lower(name) }
            end
        end
    end)

    add("Item ID: " .. itemId)
    if SHOW_DEBUG_NAMES == true then
        local debugName = field(item, "configName")
        if type(debugName) == "string" and debugName ~= "" then add("Debug name: " .. debugName) end
    end
    add((isTrue(field(item, "isMembers")) and "Members" or "Free-to-play") .. "  |  "
        .. (isTrue(field(item, "isTradeable")) and "Tradeable" or "Not tradeable"))
    if isTrue(field(item, "isStockmarket")) then
        local limit = field(item, "stockmarketBuyLimit")
        add("Grand Exchange: yes" .. (type(limit) == "number" and (" (limit " .. withCommas(limit) .. " / 4h)") or ""))
    else
        add("Grand Exchange: no")
    end
    local cost = field(item, "cost")
    if type(cost) == "number" then add("Base value: " .. withCommas(cost)) end

    local wear = Info.wearRequirements(item)
    if #wear > 0 then add("To wear: " .. table.concat(wear, ", ")) end

    local ops = {}
    pcall(function()
        for _, op in pairs(item.interfaceOpNames) do
            if type(op) == "string" and op ~= "" then ops[#ops + 1] = op end
        end
    end)
    add("Right-click: " .. ((#ops > 0) and table.concat(ops, ", ") or "nothing special"))
    return lines, item
end

end }
