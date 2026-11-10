-- Too Many Runes - Recipes: plain copies of a made item
-- The game keeps a second item number for some items (a noted or otherwise changed version). Such a copy has no recipe of its own,
-- but it IS the same item, so it shows the recipe of the item it copies.
-- (Moved over from the old plugin almost unchanged; recipes/compat.lua explains how it fits the new one.)
return { run = function(II)
local _ENV = II

-- Nothing here is typed in from the wiki: the rule is read from how the game describes the items. An item counts as a plain copy
-- of a made item only if ALL of these are true (the real game's data, survey round 26: 3,854 of the 5,241 look-alikes passed;
-- a survey of the gaps left 1,867 copies without a recipe, 1,191 of them because made items of that name differ):
--   * it has no recipe of its own, and no settings of any kind (an empty settings list);
--   * another item with exactly the same name does have a recipe, and its value and its "tradeable" flag are the same as the copy's;
--   * if SEVERAL made items of that name have the same value and tradeable flag as the copy, they are all made the same way (if they
--     are made differently, nothing is guessed). Made items of that name that differ in value or tradeable flag do not count: a made
--     item that is made differently but is a different kind of item (another value, not tradeable...) no longer blocks the copy.
-- The first row of its recipe says which item it copies (a click on it opens that item).

-- the item slots that have each name (lower case), rebuilt whenever the item list has grown
local slotsByName, slotsCount = {}, -1
local function slotsOf(lower)
    if slotsCount ~= #itemLower then
        slotsByName = {}
        for idx = 1, #itemLower do
            local name = itemLower[idx]
            local list = slotsByName[name]
            if list == nil then slotsByName[name] = { idx } else list[#list + 1] = idx end
        end
        slotsCount = #itemLower
    end
    return slotsByName[lower]
end

Recipes.slotsOf = slotsOf -- (recipes/doses.lua uses it too)

-- Does the item have no settings at all?
local function hasNoSettings(obj)
    local params = field(obj, "params")
    return params == nil or valueAt(params, 1) == nil
end

-- A recipe as one line of text (so two items with the same recipe can be told from two with different ones).
local function signature(result)
    local parts = {}
    for _, r in ipairs(result.rows or {}) do parts[#parts + 1] = tostring(r.text) .. "/" .. tostring(r.icon) end
    return table.concat(parts, "|")
end
Recipes.signature = signature -- (recipes/doses.lua uses it too)

-- The recipe an item shows because it is a plain copy of a made item (nil if it is not one).
-- ownAnswer(id, obj) gives an item's own answer without this rule (so the rule never calls itself).
function Recipes.copyOfTwin(itemId, itemObj, ownAnswer)
    if SAME_NAME_RULE ~= true then return nil end
    local name = field(itemObj, "name")
    if type(name) ~= "string" or name == "" then return nil end
    if #fieldList(itemObj, "RECIPE_") > 0 or not hasNoSettings(itemObj) then return nil end
    local slots = slotsOf(string.lower(name))
    if slots == nil or #slots < 2 then return nil end

    -- every other item of this name that has a recipe, kept only if it matches the copy in value and tradeable flag
    local cost, tradeable = field(itemObj, "cost"), isTrue(field(itemObj, "isTradeable"))
    local twin = nil
    for _, slot in ipairs(slots) do
        local id = itemIds[slot]
        if id ~= itemId then
            local obj = nil
            pcall(function() obj = config.Obj.FromID(id) end)
            if obj ~= nil and field(obj, "cost") == cost and isTrue(field(obj, "isTradeable")) == tradeable then
                local r = ownAnswer(id, obj)
                if r and r.recipe == true then
                    local s = signature(r)
                    if twin == nil then
                        twin = { id = id, name = itemNames[slot], result = r, sig = s }
                    elseif s ~= twin.sig then
                        return nil -- two look-alike made items are made differently: do not guess
                    end
                end
            end
        end
    end
    if twin == nil then return nil end
    local twinId, twinName, twinResult = twin.id, twin.name, twin.result

    -- the copy's recipe: one row saying what it copies, then the rows of that item's recipe
    local label = "Same as: " .. twinName
    if #label > 38 then label = string.sub(label, 1, 36) .. ".." end -- (a button only fits about 38 letters)
    local rows = { { text = (label:gsub("<", "<lt>")), icon = twinId } }
    for _, r in ipairs(twinResult.rows) do
        local copy = {}
        for k, v in pairs(r) do copy[k] = v end
        rows[#rows + 1] = copy
    end
    if #rows > RECIPE_MAX_LINES then
        local hidden = #rows - RECIPE_MAX_LINES + 1
        for i = #rows, RECIPE_MAX_LINES, -1 do rows[i] = nil end
        rows[RECIPE_MAX_LINES] = { text = "(" .. hidden .. " more rows not shown)" }
    end
    local height = 0
    for _, row in ipairs(rows) do height = height + ((row.icon ~= nil or row.query ~= nil or row.pic ~= nil) and ROW_HEIGHT or LINE_HEIGHT) end

    local result = {}
    for k, v in pairs(twinResult) do result[k] = v end
    result.rows, result.height = rows, height
    return result
end

end }
