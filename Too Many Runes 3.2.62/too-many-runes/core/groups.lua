-- Too Many Runes - Grouping the forms of an item
-- In the item list, the forms of one item share one picture: the doses or charges ("Attack potion (1)" ... "(4)", "Ring of dueling (8)"),
-- charged / uncharged / degraded, "Augmented X" with X, and items with exactly the same name. The picture carries a number (how many
-- forms), drawn by the game like a stack in the backpack. Clicking it opens the item and unfolds the other forms right after it; clicking
-- it again folds them away. One group is open at a time (opening one, or selecting any item that is not one of its forms, folds the one
-- before), and a new search folds it.
-- Only the forms in the list being shown are grouped (one match = a normal picture). Not grouped: the Favorites list (you picked those one
-- by one), a search by item number, and everything when the Settings switch "Group the forms of an item" is off (GROUP_FORMS).
return { run = function(T)
local _ENV = T

Groups = { keys = {}, rank = {}, top = {}, kind = {}, step = {}, open = {} }

local FORM_WORDS = { charged = 900, uncharged = 800, degraded = 700, -- (the words in brackets that are forms; the number: see rank)
                     unstrung = 650, martial = 600, broken = 100,     -- ("Eternal magic shortbow (unstrung)", "(martial)", "X (broken)")
                     -- (3.2.38: the stages of an urn - "Fragile smithing urn (unfired)", "(no rune)", "(empty)", "(full)": the urn itself is
                     -- the picture, they unfold after it in the order they come)
                     unfired = 400, norune = 390, empty = 380, full = 370 }
local SALVAGE_SIZES = { tiny = 1, small = 2, medium = 3, large = 4, huge = 5 }
local FORM_STEP = { martial = 99, unfired = 1, norune = 2, empty = 3, full = 4 } -- (martial: unfolded after the Mk. 1 - 5 it is made from)
-- Stages in brackets, in the order they are made ("Eternal magic orb (inert)" -> (meagre) -> ... -> (ascended): the wiki's recipes)
local TIERS = { inert = 1, meagre = 2, weak = 3, lesser = 4, moderate = 5, greater = 6, saturated = 7, ascended = 8 }

-- Also grouped: the upgrades "X + 1" ... "X + 5" and "X Mk. 1" ... "Mk. 5", stages in brackets ("(inert)" ... "(ascended)"), "(unstrung)",
-- "(martial)", and the broken copies ("Broken X + 2", "X (broken)").
-- The other forms the game links to an item (worn and broken states, charged / uncharged, PvP "(kp)" and male / female versions:
-- Exceptions.formRules, recipes/links.lua) join its group too, even when their names don't follow the patterns above.
-- A DYED version ("Elite dracolich chaps (blood)") joins the group of the item it is dyed from, and so does its augmented version: the game
-- links them (its DYE_RESULT_ and AUGMENTED_VERSION settings, recipes/links.lua - read a few seconds after start-up, when the groups are
-- made again: Groups.regroup). Unfolded, the forms come in this order (Groups.kind): the item, its augmented version, the dyed versions,
-- the augmented dyed versions.
-- WHICH FORM IS THE GROUP'S PICTURE: the one most likely to be the item you want, in this order:
--   1. no hide-switch mark (noted, junk ...), not one of the game's "dummy" copies, not augmented, not dyed, sold on the Grand Exchange
--   (Groups.top; the odd copies - "Prayer potion (5)" and (6), quest versions - are not sold there, so the highest dose is (4))
--   2. has a recipe or a gathering place (the plugin knows something about it; asked each time the list is grouped, since the recipes are
--   read after the items)
--   3. tradeable, then the plain name, the highest dose or charge, charged, uncharged, degraded (Groups.rank)
--   4. the lowest item number (usually the original)
-- The group's name for an item (its name without the form) is worked out once, with its top and rank.
function Groups.keyOf(slot)
    local k = Groups.keys[slot]
    if k ~= nil then return k end
    local name = Items.lower[slot] or ""
    local base, rank, step, broken = name, nil, 0, false
    local rest = string.match(base, "^augmented (.+)$")
    if rest ~= nil then base = rest end
    local unbroken = string.match(base, "^broken (.+)$") -- ("Broken elder rune platebody + 3" is a form of the platebody)
    base = string.gsub(base, " %(no rune%)$", " (norune)") -- (3.2.38: the urn stage in two words, as one)
    if unbroken ~= nil then base, broken = unbroken, true end
    -- (3.2.41) The sizes of a salvage - "Tiny bladed bronze salvage" ... "Huge" - are one item: unfolded tiny to huge, tiny the picture
    local size, salvage = string.match(base, "^(%a+) (.+ salvage)$")
    local front, num = string.match(base, "^(.-) %((%d+)%)$")
    if size ~= nil and SALVAGE_SIZES[size] ~= nil then
        base, step = salvage, SALVAGE_SIZES[size]
        rank = 1e6 - step
    elseif front ~= nil and front ~= "" then
        base, rank = front, 1e6 + math.min(tonumber(num) or 0, 999999)
    else
        local front2, word = string.match(base, "^(.-) %((%a+)%)$")
        if front2 ~= nil and front2 ~= "" and FORM_WORDS[word] ~= nil then
            base, rank, step = front2, FORM_WORDS[word], FORM_STEP[word] or 0
            if word == "broken" then broken = true end
        elseif front2 ~= nil and front2 ~= "" and TIERS[word] ~= nil then
            base, rank, step = front2, 1000 - TIERS[word], TIERS[word] -- (the first stage is the picture)
        end
    end
    -- The upgrades: "Rune platebody + 1" ... "+ 5", "Starbloom robe top + 3", "Eternal magic shortbow Mk. 2" - unfolded in order, after the
    -- item itself (without it, the lowest is the picture)
    local front3, up = string.match(base, "^(.-) %+ (%d+)$")
    if front3 == nil then front3, up = string.match(base, "^(.-) mk%. (%d+)$") end
    if front3 ~= nil and front3 ~= "" then
        step = math.min(tonumber(up) or 0, 98)
        base = front3
        if rank == nil then rank = 1e6 - step end
    end
    rank = rank or 2e6
    if Items.trade[slot] then rank = rank + 1e7 end
    -- Dyed: the game links it (or, augmented, the item it is the augmented version of) to the item it was dyed from
    local dyed = false
    local id = Items.ids[slot]
    if Recipes ~= nil and Recipes.dyedFrom ~= nil and id ~= nil then
        local plain = (rest ~= nil) and Recipes.augmentedFrom(id) or id
        local from = plain and Recipes.dyedFrom(plain)
        local fromSlot = from and Items.slotOf[from]
        if fromSlot ~= nil and fromSlot ~= slot then
            Groups.keys[slot] = base -- (in case the links ever go round in a circle)
            base, dyed = Groups.keyOf(fromSlot), true
        end
    end
    -- Another form the game links to its item (worn, broken, charged, PvP, male / female: recipes/links.lua, Recipes.formRootOf) joins
    -- that item's group, after it
    local linked = false
    if not dyed and Recipes ~= nil and Recipes.formRootOf ~= nil and id ~= nil then
        local main = Recipes.formRootOf(id)
        local mainSlot = nil
        if main ~= nil and main ~= id then mainSlot = Items.slotOf[main] end -- (3.2.06: "main and main ~= id and ..." gave false, not nil, for a
        -- stack's own main item, so every main item got the group name of "no item" and all of them shared one group - Ahrim's, Torva ...)
        if mainSlot ~= nil and mainSlot ~= slot then
            Groups.keys[slot] = base -- (in case the links ever go round in a circle)
            base, linked = Groups.keyOf(mainSlot), true
        end
    end
    local top = ((Items.flags[slot] or 0) == 0) and 16 or 0
    if not string.find(Items.debug[slot] or "", "dummy", 1, true) then top = top + 8 end
    if rest == nil and not broken then top = top + 4 end
    if not dyed and not linked then top = top + 2 end
    if Items.ge[slot] then top = top + 1 end -- (not augmented: an augmented item has a recipe - augmenting it - that X itself may not have)
    -- (3.2.43) Every armour set the Grand Exchange clerk swaps (the game's category EXCHANGE_SET: "Bronze armour set (lg)", "Infinity robes
    -- set" ...) is one big group: they sit together on Misc > Exchange sets (3.2.44), folded into one picture
    local cat = (Recipes ~= nil and Recipes.catIndex ~= nil and id ~= nil) and Recipes.catIndex[id] or nil
    local catName = (cat ~= nil and Recipes.categoryName ~= nil) and Recipes.categoryName(cat) or nil
    if catName == "EXCHANGE_SET" then base = "\1armour sets" end
    -- (3.2.45) Urns fold over every skill, (3.2.46) by tier AND stage: "Cracked cooking urn (no rune)" with "Cracked fishing urn (no rune)",
    -- not with the Decorated ones or the Cracked ones of another stage (Impious, Accursed, Infernal: the prayer urns' tiers)
    if catName == "URN" then
        base = "\1urns " .. (string.match(name, "^(%a+)") or "") .. " " .. (string.match(name, "%((.-)%)$") or "")
    end
    Groups.keys[slot], Groups.rank[slot], Groups.top[slot] = base, rank, top
    -- (the order unfolded: 0 the item, 1 augmented, 2 dyed, 3 both, then broken ones; within each, by step: + 1 ... + 5, Mk. 1 ... 5, stages)
    Groups.kind[slot] = ((rest ~= nil) and 1 or 0) + (dyed and 2 or 0) + (broken and 4 or 0)
    Groups.step[slot] = step
    return base
end

function Groups.enabled()
    if GROUP_FORMS == false or Filters.key == "fav" then return false end
    if Search.idOnly or string.match(Search.query or "", "^%d+$") then return false end
    return true
end

-- THE GROUPED LIST. state = the list being shown (src), grouped: reps = one slot per group in the order the groups first appear (the
-- group's picture), byKey[name] = the group (a number - its place in reps - while it has one member; a table of its members, with
-- key, pos and rep, from the second), opens = the open groups in list order, each with ex (its other forms). The list grows while the
-- items load, so only the new part is added each time. The box is given a view: view[i] and #view read through the open groups.
local state = nil

local function known(st, slot) -- (2. above: worked out once per grouping)
    local k = st.known[slot]
    if k == nil then
        k = (Filters.craftable(slot) == true) or (Gather ~= nil and Gather.has ~= nil and Gather.has(Items.ids[slot]) == true)
        st.known[slot] = k
    end
    return k
end
local function better(st, a, b) -- (is form a a better picture than form b?)
    if Groups.top[a] == nil then Groups.keyOf(a) end -- (a mark changed since - recipes/tidy_copies.lua - is worked out again)
    if Groups.top[b] == nil then Groups.keyOf(b) end
    local top = Groups.top
    if top[a] ~= top[b] then return top[a] > top[b] end
    local ka, kb = known(st, a), known(st, b)
    if ka ~= kb then return ka end
    local rank = Groups.rank
    if rank[a] ~= rank[b] then return rank[a] > rank[b] end
    return Items.ids[a] < Items.ids[b]
end

local function locate(st, i) -- (place i of the view: its place in reps, or nil and the unfolded form there)
    local off = 0
    for _, o in ipairs(st.opens) do
        local p = o.g.pos + off
        if i <= p then return i - off end
        local m = #o.ex
        if i <= p + m then return nil, o.ex[i - p] end
        off = off + m
    end
    return i - off
end

local function refreshOpens(st)
    local opens, rank = {}, Groups.rank
    for k in pairs(Groups.open) do
        local g = st.byKey[k]
        if type(g) == "table" then
            local ex, at = {}, {}
            for n, s in ipairs(g) do if s ~= g.rep then ex[#ex + 1] = s; at[s] = n end end
            local kind = Groups.kind
            table.sort(ex, function(a, b) -- (the item, augmented, dyed, augmented dyed; then the order the picture is chosen in)
                if Items.ids[a] == Items.ids[b] then return at[a] < at[b] end
                local ka, kb = kind[a] or 0, kind[b] or 0
                if ka ~= kb then return ka < kb end
                local sa, sb = Groups.step[a] or 0, Groups.step[b] or 0
                if sa ~= sb then return sa < sb end
                return better(st, a, b)
            end)
            opens[#opens + 1] = { g = g, ex = ex }
        end
    end
    table.sort(opens, function(a, b) return a.g.pos < b.g.pos end)
    st.opens = opens
end

-- The list to show for src (a list of slots): grouped, or src itself when grouping is off. fresh = a new search: fold every group.
-- WARNING: the grouped list is a stand-in (st.view): #list, list[i] and ipairs(list) work, but pairs(list) and next(list) see nothing.
function Groups.of(src, fresh)
    if fresh then Groups.open = {} end
    if not Groups.enabled() then state = nil return src end
    local st = state
    if st == nil or st.src ~= src or st.done > #src then
        st = { src = src, done = 0, byKey = {}, reps = {}, opens = {}, known = {} }
        st.view = setmetatable({}, {
            __len = function() local n = #st.reps; for _, o in ipairs(st.opens) do n = n + #o.ex end return n end,
            __index = function(_, i)
                if type(i) ~= "number" then return nil end
                local j, form = locate(st, i)
                if j ~= nil then return st.reps[j] end
                return form
            end })
        state = st
        if next(Groups.open) ~= nil then st.reopen = true end
    end
    local n = #src
    if st.done < n then
        local byKey, reps, keyOf = st.byKey, st.reps, Groups.keyOf
        for i = st.done + 1, n do
            local slot = src[i]
            local k = keyOf(slot)
            local g = byKey[k]
            if g == nil then
                reps[#reps + 1] = slot
                byKey[k] = #reps
            else
                if type(g) == "number" then -- (its second member: a group now)
                    g = { key = k, pos = g, rep = reps[g], reps[g] }
                    byKey[k] = g
                end
                g[#g + 1] = slot
                if better(st, slot, g.rep) then g.rep = slot; reps[g.pos] = slot end
                st.changedAt = math.min(st.changedAt or g.pos, g.pos) -- (for Groups.changedUpTo: the picture or its number changed)
                if Groups.open[k] then st.reopen = true end
            end
        end
        st.done = n
    end
    if fresh and #st.opens > 0 then st.reopen = true end -- (a new search of the same list folds what it showed unfolded too)
    if st.reopen then st.reopen = nil; refreshOpens(st) end
    return st.view
end

-- What is at place i of the shown list: the slot, and its group when it is a group's picture.
local function groupAt(i)
    local st = state
    if st == nil or i == nil then return nil end
    local j = locate(st, i)
    if j == nil then return nil end
    local slot = st.reps[j]
    local g = slot and st.byKey[Groups.keys[slot]]
    if type(g) == "table" and g.pos == j then return g end
    return nil
end

-- (3.2.12) The form that put a group's picture where it is - the group's first form in the list - or nil when place i is not a group's
-- picture. The shelves go by it (pages/item_search.lua): the picture shown can be another form, on another shelf, which split the shelves.
function Groups.firstAt(i)
    local g = groupAt(i)
    return g and g[1] or nil
end

-- The number on the picture at place i (how many forms), or nil.
function Groups.countAt(i)
    local g = groupAt(i)
    return g and #g or nil
end

-- Words added to the name under the mouse at place i.
function Groups.noteAt(i)
    local g = groupAt(i)
    if g == nil then return "" end
    return " - " .. #g .. " forms: click to " .. (Groups.open[g.key] and "fold them" or "show them")
end

-- Is place i part of an open group (its picture or one of its forms)? Its group's name, or nil. (The item box marks those; the name tells
-- two open groups side by side apart.)
function Groups.openAt(i)
    local st = state
    if st == nil or i == nil or i < 1 or next(Groups.open) == nil then return nil end
    local j, form = locate(st, i)
    if j == nil then return form and Groups.keys[form] or nil end
    local slot = st.reps[j]
    local g = slot and st.byKey[Groups.keys[slot]]
    if type(g) == "table" and g.pos == j and Groups.open[g.key] then return g.key end
    return nil
end

-- A click at place i: a group's picture unfolds its forms, folding any other open group, or folds them when they are open. Returns true
-- when the list changed, and the group picture's new place (folding a group before it moves it back).
function Groups.click(i)
    local g = groupAt(i)
    if g == nil then return false end
    local wasOpen = Groups.open[g.key]
    Groups.open = {}
    if not wasOpen then Groups.open[g.key] = true end
    refreshOpens(state)
    return true, g.pos
end

-- Selecting an item that is not one of the open group's forms folds the group. itemId: the item now open; place (optional): its place in
-- the list. Returns true when it folded, and the item's new place (folding a group before it moves it back).
function Groups.foldUnless(itemId, place)
    local st = state
    if st == nil or next(Groups.open) == nil then return false end
    local shift = 0
    for _, o in ipairs(st.opens) do
        for _, s in ipairs(o.g) do if Items.ids[s] == itemId then return false end end
        if place ~= nil and place > o.g.pos + #o.ex then shift = shift + #o.ex end
    end
    Groups.open = {}
    refreshOpens(st)
    return true, place and (place - shift) or nil
end

-- Make every group again from the start (the item links are read: the dyed versions join their items). Folds any open group.
function Groups.regroup()
    Groups.keys, Groups.rank, Groups.top, Groups.kind, Groups.step = {}, {}, {}, {}, {}
    Groups.open = {}
    state = nil
    if Search ~= nil and Search.refresh ~= nil then pcall(Search.refresh) end
end

-- The plugin shutting down forgets every open group and the grouped list, without drawing anything (main.lua, PluginShutdown: otherwise
-- reloading with a group unfolded freezes the game for 10 - 14 seconds).
-- (3.2.43) Work every group's name out again, quietly (no new search): the item groups (core/shelves.lua) call it after each sort, since the
-- armour sets' group needs the game's categories, read by the equipment pass
function Groups.rekey()
    Groups.keys, Groups.rank, Groups.top, Groups.kind, Groups.step = {}, {}, {}, {}, {}
    state = nil
end
function Groups.forget()
    Groups.open = {}
    if state ~= nil then state.opens = {} end
    state = nil
end

-- While the items load: did a group change at or before place i (a new form joined it, so its picture or number changed)? Asked once.
function Groups.changedUpTo(i)
    local st = state
    if st == nil or st.changedAt == nil then return false end
    local hit = st.changedAt <= i
    st.changedAt = nil
    return hit
end

end }
