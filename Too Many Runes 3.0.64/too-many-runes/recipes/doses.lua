-- Too Many Runes - Recipes: doses (potions, flasks, salves)
-- Potions, flasks and salves come in levels named by the doses left: "Prayer potion (3)", "Prayer flask (6)", "Overload salve (6)".
-- Only ONE level of such a family is made; the others are got by drinking, pouring or sharing doses. So a level with no recipe of its own
-- points at the level of the same family that has one (the developer's words: potions are made at (3), flasks and salves at (6)).
-- (Moved over from the old plugin almost unchanged; recipes/compat.lua explains how it fits the new one.)
return { run = function(II)
local _ENV = II

-- Nothing here is typed in from the wiki: which level is made is read from the game (the level that has a recipe). The words and the
-- levels the developer named are in recipes/exceptions.lua (playerFacts.doses). An item counts when ALL of these are true:
--   * its name ends in a number in brackets, "<name> (1)", and the items "<name> (1)" ... "<name> (N)" all exist (N is at least 3);
--   * it has no recipe, and no other item of that name is a plain copy that could give one (the same-name rule goes first);
--   * exactly ONE level of the family has a recipe of its own (a skill guide's text counts) - or several do and the player's level
--     (3 for a potion, 6 for a flask or a salve) is one of them. If it is unclear which level is made, nothing is shown.
-- A flask with NO made level at all gets what the developer said: it is made by using a potion on a Potion flask (the potion is the item
-- with the flask's name and "potion" in place of "flask", or the same name without the word). Such a recipe carries fromPlayer = "doses".

local function facts() return Recipes.playerFacts().doses end

local function endsWith(text, tail) return string.sub(text, -#tail) == tail end

-- Does this item have a recipe (or a skill guide's text) of its own? Returns the answer, or nil.
local function madeAnswer(slot, ownAnswer)
    local id = itemIds[slot]
    local obj = nil
    pcall(function() obj = config.Obj.FromID(id) end)
    if obj == nil then return nil end
    local r = ownAnswer(id, obj)
    if r and (r.recipe == true or r.guide ~= nil) then return r end
    return nil
end

local signature = Recipes.signature -- (a recipe as one line of text, from recipes/copies.lua)

local function heightOf(rows)
    local height = 0
    for _, row in ipairs(rows) do height = height + ((row.icon ~= nil or row.query ~= nil or row.pic ~= nil) and ROW_HEIGHT or LINE_HEIGHT) end
    return height
end

-- the label row of a pointer: "Made as: <name>" (a button only fits about 38 letters)
local function pointerRow(prefix, name, id)
    local label = prefix .. name
    if #label > 38 then label = string.sub(label, 1, 36) .. ".." end
    return { text = (label:gsub("<", "<lt>")), icon = id }
end

-- The recipe a flask gets when the game gives none for any level of it: a potion used on a Potion flask (the developer's words).
-- flaskBase is the flask's name without the level, in lower case ("extreme prayer flask").
local function flaskRecipe(F, flaskBase)
    local stem = string.sub(flaskBase, 1, -#F.flaskWord - 1)
    local potions = nil
    for _, candidate in ipairs({ stem .. " potion", stem }) do
        local found = {}
        for level = 4, 1, -1 do
            local id, name = findByName(candidate .. " (" .. level .. ")")
            if id ~= nil then found[#found + 1] = { id = id, name = name } end
        end
        if #found > 0 then potions = found; break end
    end
    if potions == nil then return nil end
    local flaskId = findByName(string.lower(F.flaskItem))
    local rows = {}
    for _, line in ipairs(F.useLines) do rows[#rows + 1] = { text = line } end
    rows[#rows + 1] = { text = "1 x " .. F.flaskItem, icon = flaskId }
    rows[#rows + 1] = { text = F.potionLabel }
    for _, p in ipairs(potions) do rows[#rows + 1] = { text = p.name, icon = p.id } end
    for _, row in ipairs(rows) do
        if row.icon ~= nil and #row.text > 38 then row.text = string.sub(row.text, 1, 36) .. ".." end
        row.text = (row.text:gsub("<", "<lt>"))
    end
    return { rows = rows, height = heightOf(rows), materials = 1 + #potions, ingredients = 1 + #potions, wear = 0, recipe = true, fromPlayer = "doses" }
end

-- The recipe an item shows because it is one level of a potion / flask / salve family (nil if it is not one, or if the game says
-- nothing about the family). ownAnswer(id, obj) gives an item's own answer without this rule (so the rule never calls itself).
function Recipes.doseFamily(itemId, itemObj, ownAnswer)
    if DOSE_RULE ~= true then return nil end
    local F = facts()
    if F == nil then return nil end
    local name = field(itemObj, "name")
    if type(name) ~= "string" then return nil end
    local base, level = string.match(name, "^(.+) %((%d)%)$")
    if base == nil then return nil end
    local lowerBase = string.lower(base)

    -- the family: every level from 1 up must exist (a run of at least 3)
    local top = 0
    local levels = {}
    for k = 1, 9 do
        local slots = Recipes.slotsOf(lowerBase .. " (" .. k .. ")")
        if slots == nil then break end
        levels[k] = slots
        top = k
    end
    if top < 3 or tonumber(level) > top then return nil end

    -- the levels that have an answer of their own (if several items share a name and differ, nothing is guessed)
    local madeLevels, count = {}, 0
    for k = 1, top do
        local first = nil
        for _, slot in ipairs(levels[k]) do
            local r = madeAnswer(slot, ownAnswer)
            if r ~= nil then
                local entry = { id = itemIds[slot], name = itemNames[slot], result = r, sig = signature(r) }
                if first == nil then first = entry elseif first.sig ~= entry.sig then first = false; break end
            end
        end
        if first == false then return nil end
        if first ~= nil then madeLevels[k] = first; count = count + 1 end
    end

    local isFlask = endsWith(lowerBase, F.flaskWord)
    local isSalve = endsWith(lowerBase, F.salveWord)
    if count == 0 then
        if isFlask then return flaskRecipe(F, lowerBase) end
        return nil
    end
    local target = nil
    if count == 1 then
        for k = 1, top do if madeLevels[k] then target = madeLevels[k] end end
    else
        local preferred = (isFlask and F.flaskLevel) or (isSalve and F.salveLevel) or F.potionLevel
        target = madeLevels[preferred]
    end
    if target == nil or target.id == itemId then return nil end

    local rows = { pointerRow(F.pointer, target.name, target.id) }
    for _, r in ipairs(target.result.rows) do
        local copy = {}
        for key, v in pairs(r) do copy[key] = v end
        rows[#rows + 1] = copy
    end
    if #rows > RECIPE_MAX_LINES then
        local hidden = #rows - RECIPE_MAX_LINES + 1
        for i = #rows, RECIPE_MAX_LINES, -1 do rows[i] = nil end
        rows[RECIPE_MAX_LINES] = { text = "(" .. hidden .. " more rows not shown)" }
    end
    local result = {}
    for key, v in pairs(target.result) do result[key] = v end
    result.rows, result.height, result.doseOf = rows, heightOf(rows), target.id
    return result
end

end }
