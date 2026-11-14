-- Too Many Runes - More search words, all from the game's own data. They narrow any search, and mix with each other and with the other @
-- words ("@f2p @smithing", "@ore @members", "@teleport @ge"):
return { run = function(T)
local _ENV = T

Tags = { sets = {}, ready = false }
local KINDS = { "ore", "bar", "log", "fish", "herb", "seed", "gem", "rune" }
local FILTERS = {
    f2p = function(slot) return Items.members[slot] ~= true end,
    members = function(slot) return Items.members[slot] == true end,
    ge = function(slot) return Items.ge[slot] == true end,
    untradeable = function(slot) return Items.trade[slot] ~= true end,
}

-- Every tag word (for the search's word list: core/query.lua).
function Tags.words()
    local out = {}
    for _, w in ipairs(KINDS) do out[#out + 1] = w end
    for w in pairs(FILTERS) do out[#out + 1] = w end
    for _, w in ipairs(RIGHT_CLICK_WORDS or {}) do out[#out + 1] = w end
    return out
end

-- Does the item (slot, id) have the tag?
function Tags.has(word, slot, id)
    local f = FILTERS[word]
    if f ~= nil then return f(slot) end
    local ops = Items.ops[word]
    if ops ~= nil then return ops[slot] == true end
    local set = Tags.sets[word]
    return set ~= nil and set[id] == true
end

-- The kinds, worked out once everything they need has been read.
local function add(word, id)
    local set = Tags.sets[word]
    if set == nil then set = {}; Tags.sets[word] = set end
    set[id] = true
end
local function build()
    local index, U = Recipes.stationIndex, Recipes.usedState
    local furnace = index["furnace"] or {}
    local function lowerOf(id) local slot = Items.slotOf[id]; return slot and Items.lower[slot] end
    -- @ore: mined from a rock, and something smelted at a furnace is made from it. (Not the stone spirits - the rocks drop them too, and
    -- they go into the furnace with the ore - "Mithril stone spirit")
    for id in pairs(index["rock"] or {}) do
        local lower = lowerOf(id)
        if lower ~= nil and string.find(lower, "stone spirit", 1, true) then lower = nil end
        local by = lower and U.by[lower]
        if by ~= nil then
            for _, e in pairs(by) do if e.id ~= nil and furnace[e.id] then add("ore", id) break end end
        end
    end
    -- @bar: a bar smelted at a furnace
    for id in pairs(furnace) do
        local lower = lowerOf(id)
        if lower ~= nil and string.find(lower, " bar$") then add("bar", id) end
    end
    -- @log and @fish: from the gathering places (the game's tree and fishing tables, not the skill guides)
    for id, list in pairs(Gather.src or {}) do
        local lower = lowerOf(id)
        if lower ~= nil then
            for _, s in ipairs(list) do
                if not s.guide and s.skill == "WOODCUTTING" and string.find(lower, "logs?$") then add("log", id) end
                if not s.guide and s.skill == "FISHING" and string.find(lower, "^raw ") then add("fish", id) end
            end
        end
    end
    -- @herb, @seed, @rune and @gem: by the game's names ("Grimy guam", "Potato seed", "Air rune", "Uncut ruby" and "Ruby")
    local cut = {}
    for slot = 1, #Items.ids do
        local lower, id = Items.lower[slot], Items.ids[slot]
        if string.find(lower, "^grimy ") or string.find(lower, "^clean ") then add("herb", id) end
        if string.find(lower, " seeds?$") or string.find(lower, " sapling$") then add("seed", id) end
        if string.find(lower, "%a rune$") then add("rune", id) end
        local gem = string.match(lower, "^uncut (.+)$")
        if gem ~= nil then add("gem", id); cut[gem] = true end
    end
    for slot = 1, #Items.ids do
        if cut[Items.lower[slot]] then add("gem", Items.ids[slot]) end
    end
end
Passes.add("search words", function()
    -- (also waits for the recipe check: it is what fills the furnace's list, so without it @ore and @bar are empty)
    if Tags.ready or not Items.loaded or Gather == nil or not Gather.ready or not Recipes.usedState.ready
       or not (Recipes.craftState ~= nil and Recipes.craftState.ready) then return end
    local ok, err = pcall(build)
    if not ok then trouble("the new search words", err) end
    Tags.ready = true
end, function() return Tags.ready end, function() Tags.ready = true end)

end }
