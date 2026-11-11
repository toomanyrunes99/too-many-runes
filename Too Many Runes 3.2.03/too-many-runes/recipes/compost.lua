-- Too Many Runes - What goes in a compost bin
-- The three composts come from the game's own list FARMING_COMPOST_TYPES (1 Compost, 2 Supercompost, 3 Ultracompost). What to put in the
-- bin for each is not in the game's data, so it comes from the RuneScape Wiki's compost bin recipes (data/wiki_lists.lua:
-- WikiLists.compost, .supercompost, .ultracompost).
-- Shown: on the Uses tab of an item that goes in ("In a compost bin, makes:" and the compost - recipes/uses_tab.lua), on the Recipe tab of
-- each compost ("From: 111 compostable items" - recipes/stations.lua), and the search words @compostable, @supercompostable and
-- @ultracompostable (everything that makes that compost).
return { run = function(T)
local _ENV = T

Compost = {
    ready = false,
    words = { "compostable", "supercompostable", "ultracompostable" }, -- (the wiki's own words for the three lists)
    lists = { "compost", "supercompost", "ultracompost" },
    made = {},   -- tier -> { id =, name = } the compost it makes
    tierOf = {}, -- item number -> tier (1 - 3)
    count = {},  -- tier -> how many items make it
}
local FALLBACK = { 6032, 6034, 43966 } -- (the composts' numbers, if the game's list cannot be read)

local function build()
    if Compost.ready or not Items.loaded or Gather == nil or Gather.nodeWords == nil then return end
    local ids = {}
    pcall(function()
        local en = config.Enum.FARMING_COMPOST_TYPES
        local values, count = field(en, "values"), field(en, "valueCount")
        for i = 1, (type(count) == "number" and math.min(count, 10) or 0) do
            local pair = valueAt(values, i)
            local tier, obj = valueAt(pair, 1), valueAt(pair, 2)
            local id = field(obj, "id")
            if type(tier) == "number" and type(id) == "number" then ids[tier] = id end
        end
    end)
    for tier, list in ipairs(Compost.lists) do
        local id = ids[tier] or FALLBACK[tier]
        local slot = Items.slotOf[id]
        Compost.made[tier] = { id = id, name = slot and Items.names[slot] or list }
        local set, n = {}, 0
        for _, item in ipairs(WikiLists ~= nil and WikiLists[list] or {}) do
            if Items.slotOf[item] ~= nil then set[item] = true; Compost.tierOf[item] = tier; n = n + 1 end
        end
        Compost.count[tier] = n
        Recipes.stationIndex[Compost.words[tier]] = set
        Gather.nodeWords[Compost.words[tier]] = true
    end
    Compost.ready = true
end
Passes.add("compost", build, function() return Compost.ready end)

-- The tier a compost item is (1 - 3), or nil.
function Compost.tierMade(itemId)
    for tier, m in pairs(Compost.made) do if m.id == itemId then return tier end end
    return nil
end

-- The Uses tab's rows for an item that goes in a compost bin, or nil.
function Compost.useRows(itemId)
    local tier = Compost.tierOf[itemId]
    if tier == nil then return nil end
    local made = Compost.made[tier]
    return {
        { text = "In a compost bin, makes:", picItem = Recipes.stationItemPicture("compost"), query = "@" .. Compost.words[tier] },
        { text = made.name, icon = made.id },
    }
end

end }
