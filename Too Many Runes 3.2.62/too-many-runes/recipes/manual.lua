-- Too Many Runes - Recipes: hand-written 'made from' entries
-- Items the game records no recipe for (masterwork armour steps, custom-fit armour). The facts live in recipes/exceptions.lua.
-- (Moved over from the old plugin almost unchanged; recipes/compat.lua explains how it fits the new one.)
return { run = function(T)
local _ENV = T


-- The facts used in this file (custom-fit armour ...) are written in recipes/exceptions.lua, because the game does not
-- record them as a recipe. The masterwork armour steps come from the game's own links (see links.lua).

-- A copy of a list of text lines (so the copy can be added to without changing the original).
local function copyList(list)
    local copy = {}
    for i, v in ipairs(list) do copy[i] = v end
    return copy
end

-- The first item with exactly this name (lowercase): its item number and its name. Nil if none.
-- (A lookup table is built the first time, and again if the item list has grown since.)
function findByName(lowerName)
    if Recipes.nameIndexCount ~= #Items.lower then
        Recipes.nameIndex = {}
        for idx = 1, #Items.lower do
            local lower = Items.lower[idx]
            if Recipes.nameIndex[lower] == nil then Recipes.nameIndex[lower] = idx end
        end
        Recipes.nameIndexCount = #Items.lower
    end
    local idx = Recipes.nameIndex[lowerName]
    if idx ~= nil then return Items.ids[idx], Items.names[idx] end
    return nil
end

-- Masterwork magic and ranged armour is made in steps: a draft, then an unfinished piece, then the finished piece. The game links the
-- finished piece to both of the others, and Recipes.deriveDrafts (links.lua) reads those links the other way round once all items have
-- been checked. This adds what the plain links do not say: a draft lists the pieces it is for, and an unfinished piece says which piece it
-- becomes. (The finished piece needs nothing extra: its links already read "Upgraded from: <unfinished piece>" and "Drafted from: <draft>".)
-- The wording is in recipes/exceptions.lua (Exceptions.tailoring). Returns a list of "made from" entries, or nil if the item is neither.
function Recipes.tailoringSources(itemId)
    local T = Exceptions.tailoring
    local function pieceEntries(out, ids)
        for _, pieceId in ipairs(ids) do
            local name = Recipes.usedName(pieceId)
            if name ~= nil then out[#out + 1] = { id = pieceId, name = name } end
        end
        return out
    end
    local pieces = Recipes.draftPieces and Recipes.draftPieces[itemId]
    if pieces ~= nil then return pieceEntries({ { lines = copyList(T.draftText) } }, pieces) end
    local becomes = Recipes.finishedOf and Recipes.finishedOf[itemId]
    if becomes ~= nil then return pieceEntries({ { lines = copyList(T.unfinishedThen) } }, becomes) end
    return nil
end

-- The "made from" entries that are found by an item's name alone (given in lowercase), or nil.
-- (haveSources: the game already links this item to the one it was made from, so a guess from its name is not needed.)
function Recipes.madeFromByName(lower, haveSources)
    -- Items whose name says what they are made from (Exceptions.nameRules): custom-fit armour, riveted melee armour.
    for _, rule in ipairs(Exceptions.nameRules) do
        if string.sub(lower, 1, #rule.prefix) == rule.prefix and not (rule.onlyIfNothingElse and haveSources) then
            local fromId, fromName = findByName(rule.fromPrefix .. string.sub(lower, #rule.prefix + 1))
            if fromId == nil then return nil end
            return { { id = fromId, name = fromName, label = rule.label, note = rule.note } }
        end
    end
    return nil
end

-- Hand-written "made from" entries for an item, or nil.
function manualSource(itemObj, haveSources, itemId)
    local name = field(itemObj, "name")
    local byName = nil
    if type(name) == "string" then byName = Recipes.madeFromByName(string.lower(name), haveSources) end
    return byName or Recipes.tailoringSources(itemId)
end

end }
