-- Too Many Runes - The Source tab
-- Where an item is gathered: mined, cut, caught, grown, hunted, collected, dug up (Archaeology) or dropped by a boss; and the reward shops
-- that sell it. One line for each source, with the skill's picture (the rows come from Gather.rowsOf in recipes/gather.lua). The Recipe tab
-- shows only recipes, the Uses tab only uses, and this tab only sources.
-- (Quest rewards are not listed: the game's quest data, the quests' QUEST_REWARDS_ITEM settings, names too few of the real rewards to be
-- useful.)
return { run = function(T)
local _ENV = T

-- The tab's words: "Source (N)", N = how many sources (each dig site counts), like the Uses tab's count; just "Source" while the game's
-- data is still being read, or when there are none.
local function sourcesOf(itemId)
    local found, count = nil, 0
    if Gather ~= nil and Gather.rowsOf ~= nil then
        local ok, f, c = pcall(Gather.rowsOf, itemId)
        if ok then found, count = f, (tonumber(c) or 0) end
    end
    -- (the reward shops that sell it - recipes/shops.lua)
    local okS, shopRows = pcall(function() return Shops ~= nil and Shops.rowsOf(itemId) or nil end)
    if okS and shopRows ~= nil and #shopRows > 0 then
        found = found or {}
        for _, r in ipairs(shopRows) do found[#found + 1] = r end
        count = count + #shopRows
    end
    return found, count
end
local function allReady() return Gather ~= nil and Gather.ready == true and (Shops == nil or Shops.ready == true) end
local function sourceRows(itemId)
    local list, count = sourcesOf(itemId)
    local rows = Recipes.toDetailRows(list)
    local ready = allReady()
    local label = ready and Recipes.countLabel("Source", count) or "Source"
    if #rows == 0 then rows[1] = ready and "No available source(s) in the plugin's data." or "No source found yet." end
    if not ready then rows[#rows + 1] = "" ; rows[#rows + 1] = "(Still reading the game's data, so this can change.)" end
    return rows, label
end
local function sourceLabel(itemId)
    if not allReady() then return "Source" end
    local _, count = sourcesOf(itemId)
    return Recipes.countLabel("Source", count)
end
Details.setTab("source", "Source", sourceRows, nil, sourceLabel)

end }
