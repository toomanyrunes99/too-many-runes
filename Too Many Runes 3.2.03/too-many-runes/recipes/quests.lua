-- Too Many Runes - Quest items (from the game's own data only - no wiki data for this yet)
-- Every item's settings carry a "quests" list ("all quests related to this config": core/items.lua reads it with the item). About 1,900
-- items have one, across about 175 quests, mostly newer ones; older quest items have none in the game's data, so they are not here.
-- Search words: "@quest" (every item with a quest) and one for each quest, "quest-" and the quest's name ("@quest ode of the devourer" -
-- typed with spaces, it is one word: core/query.lua). The Info box has a "Quest item from: ..." line whose quest picture (QUEST_PIC, 30103)
-- types that search (data/info.lua). Built once, when the item list is read.
return { run = function(T)
local _ENV = T

Quests = { ready = false, count = 0, quests = 0 }

local function step()
    if Quests.ready or not Items.loaded or Gather == nil or Gather.nodeWords == nil then return end
    local all = Recipes.stationIndex["quest"] or {}
    for slot, list in pairs(Items.quests) do
        local id = Items.ids[slot]
        if id ~= nil then
            all[id] = true
            Quests.count = Quests.count + 1
            for _, q in ipairs(list) do
                local word = "quest-" .. Recipes.materialSlug(q.name)
                local set = Recipes.stationIndex[word]
                if set == nil then set = {}; Recipes.stationIndex[word] = set; Quests.quests = Quests.quests + 1 end
                set[id] = true
                Gather.nodeWords[word] = true
            end
        end
    end
    Recipes.stationIndex["quest"] = all
    Gather.nodeWords["quest"] = true
    Quests.ready = true
    detail("Too Many Runes: " .. Quests.count .. " quest items, from " .. Quests.quests .. " quests")
end
Passes.add("quest items", step, function() return Quests.ready end, function() Quests.ready = true end)

end }
