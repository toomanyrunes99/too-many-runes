-- Too Many Runes - The search language
-- What can be typed in the search box besides a name or an item number:
--   @smithing         every item whose recipe needs (or gives experience in) that skill, lowest level first
--   @smithing 60      ... at exactly level 60        @smithing <60  at or below 60        @smithing >60  at or above 60
--   @smithing 60-70   ... from level 60 to 70        (the skill word needs its @: "smithing >60" looks for the name "smithing" with a level)
--   @furnace          every item made at that station (a click on the station's picture in a recipe's "Made at" row types this):
--                     @furnace @forge @anvil @range @bonfire @altar @ritual @sawmill @woodworking
--                     @spinning @loom @pottery @oven @fletchbench @water (the two workbenches use the skill words: @invention finds what
--                     the Inventor's
--                     workbench makes and @archaeology what the Archaeologist's workbench restores, besides the items with a level in that skill)
--   @food @potion     categories (foods the game's cooking tables list; potions, flasks and salves with levels)
--   @armour @weapon @ammo   what can be worn or wielded (recipes/gear.lua), and one word per category of the game's own list: @feet @hands @cape
--                     @dagger @staff @bow ... (made from the category names ARMOUR_FEET, WEAPON_DAGGER ...; a word a skill or station
--                     already has is skipped)
--   dragon @smithing  words left over are searched for in the names, so the three kinds can be mixed.
--   sword >60         a level (<60 >60 60-70 =60) with a name, or on its own: items with a level in ANY skill that fits ("<60" alone: any item).
-- A bare number next to plain words is part of the name ("ring 4", "prayer potion 4"); on its own it is an item number (and "#100" searches item
-- numbers only).
-- Where the facts come from: the skills are the ones the plugin learns from the game's skill guides (skillNames); the levels from the recipes
-- (Recipes.skillIndex, filled by the recipe check, recipes/uses.lua) and the skill guides (Recipes.guideMap); the stations from the "Made at"
-- rows of the recipes (Recipes.stationIndex, same pass); foods from the game's cooking tables; potions from Filters.families; equipment from
-- the inventory menus and categories of the items (Recipes.gearIndex, recipes/gear.lua).
-- (Moved over from the old plugin's ii_browse/query.lua; core/search.lua asks it first. A click on a row that carries a search word -
-- "Made at: Furnace", an Invention material, a skill line on the Source tab - types the word into the search box: ui/details.lua.)
-- (How the files fit together is explained at the top of main.lua.)
return { run = function(T)
local _ENV = T

Query = { spec = nil } -- spec: the search being shown, when it is one of these (nil for a plain name search)

local STATIONS = { "furnace", "forge", "anvil", "range", "bonfire", "altar", "ritual", "sawmill", "woodworking",
                  "spinning", "loom", "pottery", "oven", "fletchbench", "water" }
-- (3.0.68: the benches read from the game's lists and rows, recipes/stations.lua: @furniture @obelisk @dunganvil @soulforge ...)
for _, key in ipairs(Recipes.BENCH_ORDER or {}) do
    local known = false
    for _, w in ipairs(STATIONS) do if w == key then known = true end end
    if not known then STATIONS[#STATIONS + 1] = key end
end
local CATEGORIES = { "food", "potion" }
local GEAR = { "armour", "weapon", "ammo" } -- (recipes/gear.lua; its slot words are added once the equipment pass has read the items)

-- Every word the search knows: { word, kind = "skill" | "station" | "category", value }.
local function allWords()
    local list = {}
    for n, name in pairs(skillNames) do
        if type(n) == "number" and type(name) == "string" then list[#list + 1] = { word = string.lower(name), kind = "skill", value = n } end
    end
    for _, w in ipairs(STATIONS) do list[#list + 1] = { word = w, kind = "station", value = w } end
    -- the kinds of Invention material ("clear-parts"): searched like a station, in the same index (a recipe row that names one)
    for w in pairs(Recipes.materialWords or {}) do
        if w ~= "" then list[#list + 1] = { word = w, kind = "station", value = w } end
    end
    -- the Archaeology dig sites ("daemonheim", "kharid-et"): everything found there (recipes/gather.lua; a click on a dig site's picture
    -- types the word)
    for w in pairs((Gather ~= nil and Gather.siteWords) or {}) do
        if w ~= "" then list[#list + 1] = { word = w, kind = "station", value = w } end
    end
    -- the places items are gathered from ("castra-debris", "copper-rock"): everything found there (recipes/gather.lua; a click on the
    -- picture on a Source row types the word)
    for w in pairs((Gather ~= nil and Gather.nodeWords) or {}) do
        if w ~= "" then list[#list + 1] = { word = w, kind = "station", value = w } end
    end
    -- the stations a hand-written fact names ("energy-rift": recipes/player.lua)
    for w in pairs(Recipes.factStations or {}) do
        if w ~= "" then list[#list + 1] = { word = w, kind = "station", value = w } end
    end
    for _, w in ipairs(CATEGORIES) do list[#list + 1] = { word = w, kind = "category", value = w } end
    local taken = {}
    for _, e in ipairs(list) do taken[e.word] = true end
    for _, w in ipairs(GEAR) do
        list[#list + 1] = { word = w, kind = "gear", value = w }
        taken[w] = true
    end
    for w in pairs(Recipes.gearSlots or {}) do
        if not taken[w] then list[#list + 1] = { word = w, kind = "gear", value = w } end
    end
    -- (always the same order, so a start that fits two words, or two skills with one name, is answered the same way every time)
    table.sort(list, function(a, b)
        if a.word ~= b.word then return a.word < b.word end
        return tostring(a.value) < tostring(b.value)
    end)
    return list
end

-- 3.0.48: the words that fit the start of an @ word being typed, best first: those that start with it ("cas" -> "castra-debris"), then
-- those with a later part that starts with it ("deb" -> "castra-debris"); shorter words first. At most `max`. Used by ui/suggest.lua.
function Query.suggest(typed, max)
    local part = Recipes.materialSlug(typed or "")
    if part == "" then return {} end
    local first, later, seen = {}, {}, {}
    for _, e in ipairs(allWords()) do
        local w = e.word
        if not seen[w] then
            seen[w] = true
            if string.sub(w, 1, #part) == part then first[#first + 1] = w
            elseif string.find("-" .. w, "-" .. part, 1, true) then later[#later + 1] = w end
        end
    end
    local function order(a, b) if #a ~= #b then return #a < #b end return a < b end
    table.sort(first, order)
    table.sort(later, order)
    local out = {}
    for _, w in ipairs(first) do if #out < max then out[#out + 1] = w end end
    for _, w in ipairs(later) do if #out < max then out[#out + 1] = w end end
    return out, #first + #later -- (and how many fit in all)
end

-- Another word for one the search knows (SEARCH_SYNONYMS in settings.lua: "chestpiece" -> "body"), and with formsToo its plural / singular
-- ("rings" -> "ring", "boot" -> "boots"). Returns the entry, or nil.
local function synonymOf(list, word, formsToo)
    local byWord = {}
    for _, e in ipairs(list) do if byWord[e.word] == nil then byWord[e.word] = e end end
    local function viaTable(w)
        local cands = (type(SEARCH_SYNONYMS) == "table") and SEARCH_SYNONYMS[w] or nil
        if type(cands) == "string" then cands = { cands } end
        for _, c in ipairs(cands or {}) do if byWord[c] ~= nil then return byWord[c] end end
        return nil
    end
    local found = viaTable(word)
    if found ~= nil or not formsToo then return found end
    local forms = {}
    if string.sub(word, -3) == "ies" then forms[#forms + 1] = string.sub(word, 1, -4) .. "y" end
    if string.sub(word, -2) == "es" then forms[#forms + 1] = string.sub(word, 1, -3) end
    if string.sub(word, -1) == "s" then forms[#forms + 1] = string.sub(word, 1, -2) end
    forms[#forms + 1] = word .. "s"
    for _, f in ipairs(forms) do
        if byWord[f] ~= nil then return byWord[f] end
        found = viaTable(f)
        if found ~= nil then return found end
    end
    return nil
end

-- The word typed, as an entry of the list: exactly; otherwise every word it can mean (3.0.55: nothing is assumed) - its word in the
-- synonym table ("chestpiece" -> body) and (not with exactOnly) all the words it is the start of ("@pot": @potion and @pottery); failing
-- those, its plural / singular ("rings" -> ring). Returns the entry; or nil, nil and the list of entries when it can mean several.
local function resolve(list, word, exactOnly)
    for _, e in ipairs(list) do
        if e.word == word then return e end
    end
    local found, seen = {}, {}
    local other = synonymOf(list, word, false)
    if other ~= nil then found[1] = other; seen[other] = true end
    if not exactOnly and #word >= 3 then
        for _, e in ipairs(list) do
            if string.sub(e.word, 1, #word) == word and not seen[e] then found[#found + 1] = e; seen[e] = true end
        end
    end
    if #found == 1 then return found[1] end
    if #found > 1 then return nil, nil, found end
    return synonymOf(list, word, true)
end

-- "<60" -> 1, 60   ">60" -> 60, nil   "60-70" -> 60, 70   "=60" -> 60, 60   (anything else: nil). "<" and ">" include the number itself.
local function condition(tok)
    local op, n = string.match(tok, "^([<>]=?)(%d+)$")
    if op ~= nil then
        n = tonumber(n)
        if string.sub(op, 1, 1) == "<" then return 1, n end
        return n, nil
    end
    local a, b = string.match(tok, "^(%d+)%-(%d+)$")
    if a ~= nil then
        a, b = tonumber(a), tonumber(b)
        if a > b then a, b = b, a end
        return a, b
    end
    local e = string.match(tok, "^=(%d+)$")
    if e ~= nil then return tonumber(e), tonumber(e) end
    return nil
end

-- Turn what was typed (lower case, trimmed, not starting with #) into a search: { skill, station, category, gear, lo, hi, hasLevel, text,
-- invalid, note }, or nil when it is an ordinary name search.
function Query.parse(q)
    local raw, tokens = {}, {}
    for tok in string.gmatch(q, "%S+") do raw[#raw + 1] = tok end
    local i = 1
    while i <= #raw do
        local t = raw[i]
        -- an operator typed apart from its number ("< 60") belongs with it
        if (string.match(t, "^[<>]=?$") or t == "=") and raw[i + 1] ~= nil and string.match(raw[i + 1], "^%d+$") then
            t = t .. raw[i + 1]
            i = i + 1
        end
        tokens[#tokens + 1] = t
        i = i + 1
    end
    if #tokens == 0 then return nil end

    local list = nil
    local function words()
        if list == nil then list = allWords() end
        return list
    end
    local spec = {}
    local explicit, bare, plain = false, {}, {}
    local k = 0
    while k < #tokens do
        k = k + 1
        local tok = tokens[k]
        if string.sub(tok, 1, 1) == "@" then
            explicit = true
            local w = string.sub(tok, 2)
            -- a place name typed with spaces ("@castra debris") is one word ("castra-debris"): the longest run of the next words that makes
            -- a word the search knows exactly
            if w ~= "" then
                local last = k
                while tokens[last + 1] ~= nil and string.sub(tokens[last + 1], 1, 1) ~= "@" and condition(tokens[last + 1]) == nil do last = last + 1 end
                for j = last, k + 1, -1 do
                    local joined = Recipes.materialSlug(w .. " " .. table.concat(tokens, " ", k + 1, j))
                    local hit = false
                    for _, e in ipairs(words()) do if e.word == joined then hit = true; break end end
                    if hit then w = joined; k = j; break end
                end
            end
            local e, why, many = nil, nil, nil
            if w ~= "" then e, why, many = resolve(words(), w, false) end
            if many ~= nil then
                spec.any = spec.any or {} -- (every word it starts: Query.collect finds what any of them finds)
                spec.any[#spec.any + 1] = many
            elseif e == nil then
                spec.invalid = true
                -- (a bare @ gives no note: the "Try @smithing, @furnace ..." line was redundant)
                spec.note = why or ((w ~= "") and ("Unknown " .. tok) or nil)
            else
                spec[e.kind] = e.value
            end
        else
            local lo, hi = condition(tok)
            if lo ~= nil then
                spec.lo, spec.hi, spec.hasLevel = lo, hi, true
            elseif string.match(tok, "^%d+$") then
                bare[#bare + 1] = tonumber(tok)
            else
                plain[#plain + 1] = tok
            end
        end
    end

    -- A skill, station or category word needs its "@": a plain word stays a word of the name, even "smithing" (before, a plain word that
    -- was exactly a skill was taken for one when a level came with it, so "smithing >60" = "@smithing >60", and "prayer potion 4" turned
    -- into a skill search).
    -- A level written like a level (>60, <60, 60-70, =60) still works with plain name words ("sword >60": swords that need level 60 or more
    -- in any skill).
    local rest = {}
    for _, tok in ipairs(plain) do rest[#rest + 1] = tok end

    if #bare > 0 then
        if spec.hasLevel then
            for _, n in ipairs(bare) do rest[#rest + 1] = tostring(n) end -- (a level is already given: the number is part of the name)
        elseif explicit then
            spec.lo, spec.hi, spec.hasLevel = bare[1], bare[1], true -- ("@smithing 85": a bare number is the level, but only next to an @ word)
            for k = 2, #bare do rest[#rest + 1] = tostring(bare[k]) end
        else
            return nil -- (numbers and words with no @ word in them: an ordinary name search, like "ring 4")
        end
    end

    if not (explicit or spec.hasLevel) then return nil end
    spec.text = table.concat(rest, " ")
    return spec
end

-- The level an item needs in a skill: a number; 0 when all that is known is that it gives experience in it (or the skill's guide lists it
-- without a level); nil when the skill is no part of it.
-- The game's stat number of a skill (the wear requirements count the skills their own way: matched by name, STAT_TO_STRING)
local skillToStat = nil
local function statOfSkill(skill)
    if skillToStat == nil then
        local byName, map, any = {}, {}, false
        for n, name in pairs(readEnum("STAT_TO_STRING", 60)) do
            if type(name) == "string" then byName[string.lower(name)] = n end
        end
        for k, name in pairs(skillNames) do
            if type(k) == "number" and type(name) == "string" and byName[string.lower(name)] ~= nil then map[k] = byName[string.lower(name)]; any = true end
        end
        if not any then return nil end -- (not read yet: try again next time)
        skillToStat = map
    end
    return skillToStat[skill]
end

local function levelIn(itemId, skill)
    local level = nil
    local t = Recipes.skillIndex[itemId]
    if t ~= nil then level = t[skill] end
    local g = Recipes.guideMap[itemId]
    if g ~= nil and g.stat == skill then
        if type(g.level) == "number" and (level == nil or level == 0) then level = g.level
        elseif level == nil then level = 0 end
    end
    if (level == nil or level == 0) and Gather ~= nil then
        -- (mined, cut, caught, grown, hunted, collected or dug up at this level: recipes/gather.lua)
        local gathered = Gather.levelIn(itemId, skill)
        if gathered ~= nil and (level == nil or gathered > 0) then level = gathered end
    end
    if level == nil then
        -- made at that skill's workbench (Invention: the Inventor's workbench, Archaeology: the Archaeologist's): a click on the
        -- workbench's picture types the skill word, and the stations index holds those items under the skill's name
        local name = skillNames[skill]
        local bench = type(name) == "string" and Recipes.stationIndex[string.lower(name)] or nil
        if bench ~= nil and bench[itemId] then level = 0 end
    end
    if level == nil and Recipes.wearIndex ~= nil then
        -- worn or wielded with that skill ("To wear: Attack 40": recipes/gear.lua)
        local w = Recipes.wearIndex[itemId]
        local stat = (w ~= nil) and statOfSkill(skill) or nil
        if stat ~= nil and w[stat] ~= nil then level = w[stat] end
    end
    return level
end

local function inRange(level, spec)
    if level == nil or level < 1 then return false end
    if spec.lo ~= nil and level < spec.lo then return false end
    if spec.hi ~= nil and level > spec.hi then return false end
    return true
end

-- The lowest level an item needs in any skill (counting only levels that fit the search when spec is given); nil if it has none.
local function lowestLevel(itemId, spec)
    local best = nil
    local t = Recipes.skillIndex[itemId]
    if t ~= nil then
        for _, level in pairs(t) do
            if level > 0 and (spec == nil or inRange(level, spec)) and (best == nil or level < best) then best = level end
        end
    end
    local g = Recipes.guideMap[itemId]
    if g ~= nil and type(g.level) == "number" and g.level > 0 and (spec == nil or inRange(g.level, spec)) and (best == nil or g.level < best) then
        best = g.level
    end
    if Gather ~= nil then
        local gl = Gather.lowest(itemId, spec ~= nil and spec.lo or nil, spec ~= nil and spec.hi or nil)
        if gl ~= nil and (best == nil or gl < best) then best = gl end
    end
    local w = Recipes.wearIndex and Recipes.wearIndex[itemId] or nil -- (the level needed to wear or wield it: "sword >60")
    for _, level in pairs(w or {}) do
        if level > 0 and (spec == nil or inRange(level, spec)) and (best == nil or level < best) then best = level end
    end
    return best
end

-- How to tell whether an item is in the category (food, potion).
local function categoryTest(spec)
    if spec.category == "food" then
        local T = Recipes.cookingTables and Recipes.cookingTables() or nil
        return function(slot, id) return T ~= nil and (T.oven[id] or T.fire[id]) and true or false end
    elseif spec.category == "potion" then
        -- (1) the game's own category POTION (read by the equipment pass, recipes/gear.lua); (2) a dose family (levels (1) to (3) exist,
        -- one is made) whose recipe needs Herblore: that keeps flasks, salves and renewals, and drops the charged things (Watering can (8),
        -- Waterskin (4), Castle wars brace (3)) that only look like doses.
        local families = Filters.families
        local own = Recipes.gearIndex and Recipes.gearIndex.potion or nil
        local herb = nil
        for n, name in pairs(skillNames) do
            if type(n) == "number" and type(name) == "string" and string.lower(name) == "herblore" then herb = n end
        end
        local cache = {}
        local function familyUsesHerblore(base)
            for k = 1, 8 do
                local slots = Recipes.slotsOf and Recipes.slotsOf(base .. " (" .. k .. ")") or nil
                if slots == nil then break end
                for _, s in ipairs(slots) do
                    local t = Recipes.skillIndex[itemIds[s]]
                    if t ~= nil and t[herb] ~= nil then return true end
                end
            end
            return false
        end
        return function(slot, id)
            if own ~= nil and own[id] then return true end
            if families == nil or herb == nil then return false end
            local base = string.match(itemLower[slot], "^(.+) %(%d%)$")
            if base == nil or families[base] ~= true then return false end
            local known = cache[base]
            if known == nil then
                known = familyUsesHerblore(base)
                -- (the recipes are still being read: do not remember a "no" yet)
                if known or (Recipes.craftState ~= nil and Recipes.craftState.ready) then cache[base] = known end
            end
            return known
        end
    end
    return nil
end

-- Does the item fit the search? Returns the number the results are sorted by (its level), or nil if it does not fit.
local function check(spec, slot, inCategory)
    if spec.text ~= "" and not string.find(itemLower[slot], spec.text, 1, true) then
        local debugName = (SHOW_DEBUG_NAMES == true) and Items.debug[slot] or nil -- (the debug name, when they are shown)
        if debugName == nil or not string.find(debugName, (string.gsub(spec.text, " ", "_")), 1, true) then return nil end
    end
    local id = itemIds[slot]
    if spec.station ~= nil then
        local set = Recipes.stationIndex[spec.station]
        if set == nil or not set[id] then return nil end
    end
    if inCategory ~= nil and not inCategory(slot, id) then return nil end
    if spec.gear ~= nil then
        local set = Recipes.gearIndex and Recipes.gearIndex[spec.gear] or nil
        if set == nil or not set[id] then return nil end
    end
    if spec.skill ~= nil then
        local level = levelIn(id, spec.skill)
        if level == nil then return nil end
        if spec.hasLevel and not inRange(level, spec) then return nil end
        return (level > 0) and level or 5000
    elseif spec.hasLevel then
        return lowestLevel(id, spec) -- (nil when no skill has a level that fits)
    end
    return lowestLevel(id, nil) or 5000
end

-- Call add(slot) for every item that fits, lowest level first (then by name).
function Query.collect(spec, add)
    if spec.invalid then return end
    -- an @ word that is the start of several words ("@pot": @potion and @pottery) finds what ANY of them finds: one search for each
    -- choice (at most 64 of them), and an item is in when one of them has it, with its lowest key
    local specs = { spec }
    for _, group in ipairs(spec.any or {}) do
        local nextSpecs = {}
        for _, s in ipairs(specs) do
            for _, e in ipairs(group) do
                if #nextSpecs < 64 then
                    local sub = {}
                    for k, v in pairs(s) do sub[k] = v end
                    sub.any = nil
                    sub[e.kind] = e.value
                    nextSpecs[#nextSpecs + 1] = sub
                end
            end
        end
        specs = nextSpecs
    end
    local tests = {}
    for k, s in ipairs(specs) do tests[k] = categoryTest(s) end
    local hits = {}
    for slot = 1, #itemIds do
        local best = nil
        for k, s in ipairs(specs) do
            local key = check(s, slot, tests[k])
            if key ~= nil and (best == nil or key < best) then best = key end
        end
        if best ~= nil then hits[#hits + 1] = { slot = slot, key = best } end
    end
    table.sort(hits, function(a, b)
        if a.key ~= b.key then return a.key < b.key end
        local x, y = itemLower[a.slot], itemLower[b.slot]
        if x ~= y then return x < y end
        return a.slot < b.slot
    end)
    for _, h in ipairs(hits) do add(h.slot) end
end

end }
