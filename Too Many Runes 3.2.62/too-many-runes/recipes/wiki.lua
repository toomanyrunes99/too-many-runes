-- Too Many Runes - Recipes and uses from the RuneScape Wiki (3.2.10)
-- Credit: the RuneScape Wiki (runescape.wiki), CC BY-NC-SA 3.0 (the data: data/wiki_recipes.lua).
-- The game's data comes first. A wiki recipe is shown only on an item the game gives no recipe for, under "From the RuneScape Wiki:";
-- its materials list it on their Uses tab, after their uses from the game. The wiki data is read once the game's own recipes are known
-- (Recipes.craftState: which items the game makes), so a wiki recipe can never stand in for one of the game's.
-- 3.2.14: a wiki recipe is used only when its wiki page has the game's name for the item (the wiki's numbers for some new items are other
-- items in the game: the "Mollusc totem (small)" recipe landed on "Extreme antisanguine flask (4)").
return { run = function(T)
local _ENV = T

Wiki = { ready = false, recipes = {}, uses = {}, affected = {}, made = 0, materials = 0 }

local function nameOf(id)
    local slot = Items.slotOf[id]
    return slot and Items.names[slot] or nil
end

-- (3.2.14) a recipe counts only when its wiki page has the game's name for the item: "Extreme antisanguine flask (4)" got
-- "Mollusc totem (small)"'s recipe in 3.2.10, because the wiki's item number for the new totem is the flask's number in the game.
-- Endings in brackets are left out of both ("4-poster (historical)" = "4-poster", "Super antisanguine flask (4)" = its page).
local function plain(s)
    s = string.lower(tostring(s or ""))
    s = string.gsub(s, "#.*$", "")
    for _ = 1, 3 do
        local before = s
        s = string.gsub(s, "%s*%b()%s*$", "")
        if s == before then break end
    end
    return (string.gsub(s, "%s+", " "))
end

-- (3.2.54) The reading, a part each tick (it was all in one tick - a stutter about 20 seconds after start-up): the file is loaded in one
-- tick, then its recipes are gone through a few hundred a tick (Scan.full, like the other passes), then the things with no item number.
-- (3.2.56: the file is in parts now, a part a tick - readPart below.)
local R = { stage = nil }
WIKI_WORK_PER_TICK = 250 -- (3.2.58: how much of the wiki reading is done a tick - see step below)
local function addUse(mat, use, key)
    if type(mat) ~= "number" or Items.slotOf[mat] == nil then return end
    local seen = R.seen
    seen[mat] = seen[mat] or {}
    if seen[mat][key] then return end
    seen[mat][key] = true
    local u = Wiki.uses[mat]
    if u == nil then u = {}; Wiki.uses[mat] = u; Wiki.materials = Wiki.materials + 1 end
    u[#u + 1] = use
    Wiki.affected[mat] = true
end
-- (3.2.57) A name used more than once is written once in the file (S, in data/wiki_recipes.lua): a number in f, t, qu or u is S[number],
-- and a negative number where a skill or material name goes is S[-number]. Put back as the names, once, when a recipe is taken.
local function expand(r)
    local S = R.S or {}
    local function one(v)
        if type(v) == "number" then return S[v] end
        if type(v) == "table" then for i, e in ipairs(v) do if type(e) == "number" then v[i] = S[e] end end end
        return v
    end
    r.f, r.qu, r.u, r.t = one(r.f), one(r.qu), one(r.u), one(r.t)
    local sk, m = r.s, r.m
    if sk ~= nil then for i = 1, #sk, 3 do if type(sk[i]) == "number" and sk[i] < 0 then sk[i] = S[-sk[i]] end end end
    if m ~= nil then for i = 1, #m, 2 do if type(m[i]) == "number" and m[i] < 0 then m[i] = S[-m[i]] end end end
end
local function addRecipes(made, all)
    local slot = Items.slotOf[made]
    local list = {}
    if slot ~= nil then
        local name = plain(Items.names[slot])
        for _, r in ipairs(all) do
            if r.p == nil or plain(r.p) == name then list[#list + 1] = r else R.skipped = R.skipped + 1 end
        end
    end
    if slot ~= nil and #list > 0 and Filters.craftable(slot) ~= true then -- (the game makes it: its own recipe is shown, not the wiki's)
        Wiki.recipes[made] = list
        Wiki.affected[made] = true
        Wiki.made = Wiki.made + 1
        for _, r in ipairs(list) do
            expand(r)
            local m = r.m or {}
            for i = 1, #m, 2 do addUse(m[i], { made = made, r = r }, made) end
        end
    end
end
-- (3.2.56) One part of the wiki's recipes: data/wiki_recipes.lua is part 1 (it says how many parts there are), then _2.lua, _3.lua ...
-- Each is about 60 KB, read in its own tick - one 617 KB file read in one tick was the stutter just before "wiki recipes ready". The
-- part's recipes go into R.data, and the part itself is let go (package.loaded), so its table can be freed.
local function readPart(k)
    local name = (k == 1) and "data/wiki_recipes" or ("data/wiki_recipes_" .. k)
    local ok, part = pcall(require, name)
    for _ = 1, 3 do
        if ok and type(part) == "table" then break end
        ok, part = pcall(require, name)
    end
    pcall(function() package.loaded[name] = nil end)
    if not ok or type(part) ~= "table" then
        say("could not load " .. name .. ".lua (" .. tostring(part) .. ")" .. ((k == 1) and "; no wiki recipes." or "; its recipes are left out."))
        return nil
    end
    local data = R.data
    if type(part.S) == "table" then R.S = part.S end -- (3.2.57: the names written once - see expand below)
    for made, list in pairs(part.r or {}) do data.r[made] = list end
    for _, x in ipairs(part.x or {}) do data.x[#data.x + 1] = x end
    return part
end

-- One step of the reading; true once it is finished.
local function step()
    if R.stage == nil then
        R.data, R.key, R.xi, R.skipped, R.seen = { r = {}, x = {} }, nil, 1, 0, {}
        local first = readPart(1)
        if first == nil then R.data, R.seen = nil, nil return true end
        R.parts, R.part, R.stage = tonumber(first.parts) or 1, 2, "load"
        return false
    end
    if R.stage == "load" then -- (a part a tick)
        if R.part <= R.parts then readPart(R.part); R.part = R.part + 1 return false end
        R.stage = "r"
        return false
    end
    -- (3.2.58) A fixed amount of work a tick - a recipe and each of its materials count one - never sped up past it, only slowed when the
    -- game struggles: the work was Scan.full(600) items a tick, up to 3 times that once the game coped, so a few ticks each took about
    -- 1,800 items - and the last one all 1,134 things with no item number - the stutter just before "wiki recipes ready". About 21,000 in
    -- all: some 2 seconds.
    local data = R.data
    local budget = math.max(40, math.floor(WIKI_WORK_PER_TICK * math.min(1, Scan.paced())))
    local function cost(list) local c = 0 for _, r in ipairs(list or {}) do c = c + 1 + #(r.m or {}) // 2 end return c end
    if R.stage == "r" then
        local recipes = data.r or {}
        while budget > 0 do
            local made, all = next(recipes, R.key)
            if made == nil then R.stage = "x" break end
            R.key = made
            addRecipes(made, all)
            budget = budget - cost(all)
        end
        return false
    end
    local xs = data.x or {} -- (things with no item number - only their materials' uses)
    while budget > 0 and R.xi <= #xs do
        local x = xs[R.xi]
        for _, r in ipairs(x.r or {}) do
            expand(r)
            local m = r.m or {}
            for i = 1, #m, 2 do addUse(m[i], { name = x.n, r = r }, "x:" .. tostring(x.n)) end
        end
        budget = budget - cost(x.r)
        R.xi = R.xi + 1
    end
    if R.xi <= #xs then return false end
    -- (3.2.57: the recipes whose wiki item number is another item in the game are left out when the file is built, so R.skipped is 0 now
    -- unless an old file is read)
    local left = (R.skipped > 0) and ("; " .. withCommas(R.skipped) .. " wiki recipes left out: the wiki's item number is another item in the game") or ""
    say("wiki recipes ready (" .. withCommas(Wiki.made) .. " items get a recipe from the RuneScape Wiki, " .. withCommas(Wiki.materials)
        .. " items get wiki uses" .. left .. ").")
    R.data, R.seen, R.S = nil, nil, nil
    return true
end

-- A heading row with the RuneScape Wiki's button in front of it (its size: WIKI_ICON in settings.lua - the picture is not square).
local function wikiHeading(text)
    local ic = WIKI_ICON
    if type(ic) ~= "table" or type(ic.sprite) ~= "number" then return { text = text } end
    return { text = text, pic = ic.sprite, picW = tonumber(ic.w) or 24, picH = tonumber(ic.h) or 24 }
end

-- The Recipe tab's rows for an item the wiki has a recipe for (the game has none), or nil.
function Wiki.recipeRows(itemId)
    local list = Wiki.recipes[itemId]
    if list == nil then return nil end
    local rows = {}
    for k, r in ipairs(list) do
        if k > 1 then rows[#rows + 1] = { text = "" } end
        -- (3.2.49: with the wiki's button in front - WIKI_ICON, settings.lua)
        -- (3.2.52: just "Info:" - the button says it is the wiki's)
        rows[#rows + 1] = wikiHeading((#list > 1) and ("Recipe " .. k .. " info:") or "Info:")
        local s = r.s or {}
        for i = 1, #s, 3 do
            local xp = tonumber(s[i + 2]) or 0
            rows[#rows + 1] = { text = "Needs: " .. tostring(s[i]) .. " level " .. tostring(s[i + 1]) .. ((xp > 0) and ("  (" .. withCommas(xp) .. " XP)") or "") }
        end
        if r.qu then rows[#rows + 1] = { text = "Quest: " .. r.qu } end
        for _, u in ipairs(r.u or {}) do rows[#rows + 1] = { text = "Needs: " .. u } end
        if r.f then rows[#rows + 1] = { text = "Made at: " .. r.f } end
        if r.t and #r.t > 0 then rows[#rows + 1] = { text = "Tools: " .. table.concat(r.t, ", ") } end
        if r.q and r.q > 1 then rows[#rows + 1] = { text = "Makes: " .. withCommas(r.q) } end
        local m = r.m or {}
        if #m > 0 then rows[#rows + 1] = { text = "Materials:" } end
        for i = 1, #m, 2 do
            local mat, n = m[i], tonumber(m[i + 1]) or 1
            if type(mat) == "number" then
                local name = nameOf(mat)
                rows[#rows + 1] = { text = withCommas(n) .. " x " .. (name or ("item " .. mat)), icon = name and mat or nil }
            else
                rows[#rows + 1] = { text = withCommas(n) .. " x " .. tostring(mat) }
            end
        end
    end
    return rows
end

-- The Uses tab's rows for a material of wiki recipes ("Used to make (from the RuneScape Wiki):" and each thing), and how many; or nil.
function Wiki.useRows(itemId)
    local list = Wiki.uses[itemId]
    if list == nil then return nil, 0 end
    local entries = {}
    for _, u in ipairs(list) do
        local name = u.made and nameOf(u.made) or u.name
        local s = u.r and u.r.s
        local need = (s and s[1]) and ("  (" .. tostring(s[1]) .. " level " .. tostring(s[2]) .. ")") or ""
        entries[#entries + 1] = { sort = string.lower(tostring(name)), text = tostring(name) .. need, icon = u.made }
    end
    table.sort(entries, function(a, b) return a.sort < b.sort end)
    -- (3.2.53: the wiki's button and "Info:" on a line of their own, as on the Recipe tab, then what it makes)
    local rows = { wikiHeading("Info:"), { text = (#entries == 1) and "Used to make 1 thing:"
                     or ("Used to make " .. withCommas(#entries) .. " things:") } }
    for _, e in ipairs(entries) do rows[#rows + 1] = { text = e.text, icon = e.icon } end
    return rows, #entries
end

-- Read once the game's recipes are known; then the open item and the list are shown again.
Passes.add("wiki recipes", function()
    local C, U = Recipes.craftState, Recipes.usedState
    if not (C ~= nil and C.ready and U ~= nil and U.ready) then return end
    local okStep, done = pcall(step)
    if okStep and not done then return end -- (more next tick)
    if not okStep then say("the wiki recipes stopped because of an error: " .. tostring(done)) end
    Wiki.ready = true
    pcall(Recipes.onDataReady)
end, function() return Wiki.ready end, function() Wiki.ready = true end)

end }
