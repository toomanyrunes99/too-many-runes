-- Too Many Runes - Recipes: quests, achievements and unlocks
-- Quests needed to wear an item, and the achievements that unlock a recipe (Kili's Knowledge and so on).
-- (Moved over from the old plugin almost unchanged; recipes/compat.lua explains how it fits the new one.)
return { run = function(II)
local _ENV = II


-- Making the Necromancy equipment (the Deathwarden robes and the rest) is unlocked by a "Kili's Knowledge"
-- achievement, which the recipe stores only as a plain number. The achievement is found through the tier the item
-- belongs to; how is explained in recipes/exceptions.lua (Exceptions.kiliAchievement). The other achievement numbers
-- (requirement type 62) are not explained by any list the game hands to a plugin, so they are not shown.

-- An achievement looked up by its internal name (or nil). Tries the name first; if the game does not allow
-- that, looks through the block of numbers the Necromancy achievements live in (once).
function Recipes.achievementByConfig(configName)
    local found = nil
    if Recipes.achievementByName ~= false then
        pcall(function() found = config.Achievement[configName] end)
        if found ~= nil and field(found, "configName") == configName then return found end
        if found == nil then Recipes.achievementByName = false end -- (the game does not look achievements up by name)
    end
    if Recipes.achievementWindow == nil then
        Recipes.achievementWindow = {}
        for id = 3300, 3500 do
            local a = nil
            pcall(function() a = config.Achievement.FromID(id) end)
            local c = field(a, "configName")
            if type(c) == "string" then Recipes.achievementWindow[c] = a end
        end
    end
    return Recipes.achievementWindow[configName]
end

-- Item number -> the name of the achievement that unlocks making it (built once).
function Recipes.kiliOf(itemId)
    if Recipes.kiliMap == nil then
        Recipes.kiliMap = {}
        local summary = {}
        local ok, err = pcall(function()
            local lists = nil
            pcall(function() lists = config.Enum["NECRO_MAKEX_EQUIPMENT_UPGRADES"] end)
            local entries, count = field(lists, "values"), field(lists, "valueCount")
            if entries == nil or type(count) ~= "number" then return end
            for e = 1, Recipes.listCount(count, 60, "NECRO_MAKEX_EQUIPMENT_UPGRADES") do
                local entry = valueAt(entries, e)
                local tier = nil
                if entry ~= nil then tier = valueAt(entry, 2) end
                local tierName = field(tier, "configName") or field(tier, "name")
                local suffix = nil
                if type(tierName) == "string" then suffix = string.match(tierName, "UPGRADES_(.+)$") end
                local achievement = nil
                if suffix ~= nil then achievement = Recipes.achievementByConfig(Exceptions.kiliAchievement .. suffix) end
                local achievementName = field(achievement, "name")
                local items, itemCount = field(tier, "values"), field(tier, "valueCount")
                if items == nil and type(field(tier, "id")) == "number" then
                    local full = nil
                    pcall(function() full = config.Enum.FromID(field(tier, "id")) end)
                    items, itemCount = field(full, "values"), field(full, "valueCount")
                end
                if type(achievementName) == "string" and achievementName ~= "" and items ~= nil and type(itemCount) == "number" then
                    local used = 0
                    for k = 1, Recipes.listCount(itemCount, 100, tostring(tierName)) do
                        local itemEntry = valueAt(items, k)
                        local obj = nil
                        if itemEntry ~= nil then obj = valueAt(itemEntry, 2) end
                        local id = field(obj, "id")
                        if type(id) == "number" then
                            Recipes.kiliMap[id] = achievementName
                            used = used + 1
                        end
                    end
                    summary[#summary + 1] = suffix .. " = " .. achievementName .. " (" .. used .. " items)"
                end
            end
        end)
        if not ok then print("Too Many Runes: could not read the Necromancy equipment lists: " .. tostring(err)) end
        if #summary > 0 then
            detail("Too Many Runes: Necromancy equipment is unlocked by achievements (read from the game): " .. table.concat(summary, "; "))
        else
            print("Too Many Runes: could not match the Necromancy equipment to its achievements, so those are not shown.")
        end
    end
    return Recipes.kiliMap[itemId]
end

-- The type-62 numbers of a recipe, each as { number = achievement name }, for those we can name.
function Recipes.unlocksOf(itemId, fields)
    local found, numbers = {}, {}
    for n = 1, 6 do
        local t = getField(fields, "RECIPE_REQUIREMENT_TYPE_" .. n)
        local v = getField(fields, "RECIPE_REQUIREMENT_VALUE_" .. n)
        if t == Exceptions.requirementTypes.achievement and type(v) == "number" then numbers[#numbers + 1] = v end
    end
    if #numbers == 0 then return found end
    local kili = Recipes.kiliOf(itemId)
    if kili ~= nil and #numbers == 1 then found[numbers[1]] = kili end
    return found
end

end }
