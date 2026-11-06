-- Too Many Runes - The Source tab
-- Where an item is gathered: mined, cut, caught, grown, hunted, collected, dug up (Archaeology) or dropped by a boss. One line for each
-- source, with the skill's picture (the rows come from Gather.rowsOf in recipes/gather.lua). The Recipe tab shows only recipes, the
-- Uses tab only uses, and this tab only sources.
return { run = function(T)
local _ENV = T

local function sourceRows(itemId)
    local list = nil
    if Gather ~= nil and Gather.rowsOf ~= nil then
        local ok, found = pcall(Gather.rowsOf, itemId)
        if ok then list = found end
    end
    local rows = Recipes.toDetailRows(list)
    local ready = Gather ~= nil and Gather.ready == true
    if #rows == 0 then rows[1] = ready and "No available source(s) in the plugin's data." or "No source found yet." end
    if not ready then rows[#rows + 1] = "" ; rows[#rows + 1] = "(Still reading the game's data, so this can change.)" end
    return rows
end
Details.setTab("source", "Source", sourceRows)

end }
