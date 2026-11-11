-- Too Many Runes - The game's right-click menu
-- Adds "Recipe: <item>", "Uses: <item>" and "Source: <item>" to the menu that opens when you right-click an item in the game (backpack,
-- bank, ground...) - only the ones whose tab has something for that item. Picking one opens the window on that item, on that tab.
-- The same entries come up when you right-click an item inside this plugin: a picture or a row of the item list, or an item in the
-- details column (a material, a use, the open item's own picture); picking one opens it in that tab's details column.
-- (Moved over from the old plugin's ii_browse/game_menu.lua: the same way of adding and placing the entries, tested in game.)
-- How it works (from the game's own plugin documentation, game/minimenu):
--   * Event.MiniMenuReady is sent each time the game has worked out the menu (about 50 times a second while it is closed). The only
--     things a plugin may do then are add an entry (miniMenu:Add) and swap two entries (miniMenu:Swap). The menu is rebuilt from
--     scratch each time, so nothing we add piles up.
--   * miniMenu.entries lists the entries from the bottom of the menu to the top: the LAST one is the one a plain left-click does.
--     Our entries must never end up last, so after adding them we swap them down to just above the item's "Examine" entry.
-- If anything here fails it switches itself off (the game's menu is then left alone) and says so in the console.
-- (How the files fit together is explained at the top of main.lua.)
return { run = function(T)
local _ENV = T

GameMenu = { off = false, decided = {} }

local MAX_ITEMS = 3 -- at most this many different items get entries in one menu (a pile on the ground can hold many)
local LABEL = { recipe = "Recipe: ", uses = "Uses: ", source = "Source: ", tmr = "Info: " } -- ("Info": none of the three has anything)
local RANK = { tmr = 0, source = 1, uses = 2, recipe = 3 } -- (entries are listed bottom to top: Recipe ends up on top)
-- Our entries' words are green so they stand out (MENU_COLOUR in settings.lua: "" = the game's own colour).
local function coloured(text)
    local c = (type(MENU_COLOUR) == "string") and MENU_COLOUR or "00aa00"
    if c == "" then return text end
    return "<col=" .. c .. ">" .. text .. "</col>"
end
-- The entries for an item: the tabs that have something, or "Info" (opens the item) when none has.
local function tabsFor(d)
    local list = {}
    for _, tab in ipairs({ "recipe", "uses", "source" }) do if d[tab] then list[#list + 1] = tab end end
    if #list == 0 and d.ready then list[1] = "tmr" end -- (only once the game's data is all read: until then "nothing" may be "not yet")
    return list
end

local TEXT_FIELDS = { "fullText", "overrideText", "verbText", "subjectText", "extraText" }

local function stripTags(text) return (string.gsub(text, "<[^>]*>", "")) end

-- Does this entry's text contain the given words?
local function hasText(entry, needle)
    needle = stripTags(needle) -- (our entries are coloured: the colour tags are not part of the words compared)
    for _, name in ipairs(TEXT_FIELDS) do
        local t = field(entry, name)
        if type(t) == "string" and string.find(stripTags(t), needle, 1, true) ~= nil then return true end
    end
    return false
end

-- Is this entry the one we added with this label ("Recipe: Vial of water")? The game may keep the whole label in one text, or split it
-- into a verb and a subject; an entry that the game marks as made by a plugin (type 10) is also accepted if its texts hold both parts.
local function isOurs(entry, label)
    if entry == nil then return false end
    if hasText(entry, label) then return true end
    local kind = tostring(field(entry, "actionEntryType"))
    if kind ~= "10" and string.upper(kind) ~= "PLUGIN" then return false end
    local prefix, name = string.match(stripTags(label), "^(%a+): (.*)$")
    if prefix == nil then return false end
    local all = {}
    for _, f in ipairs(TEXT_FIELDS) do
        local t = field(entry, f)
        if type(t) == "string" then all[#all + 1] = t end
    end
    local text = stripTags(table.concat(all, " "))
    return string.find(text, prefix, 1, true) ~= nil and string.find(text, name, 1, true) ~= nil
end

-- How many entries the menu holds.
local function countOf(menu, entries)
    local n = field(menu, "entryCount")
    if type(n) ~= "number" and entries ~= nil then pcall(function() n = #entries end) end
    if type(n) ~= "number" then return nil end
    return n
end

-- The item number a menu entry is about (nil if it is not about an item this plugin knows).
local function itemOfEntry(entry)
    local id = nil
    local data = field(entry, "componentData")      -- an item in the backpack, the bank, an interface...
    if data ~= nil then
        local cfg = field(data, "objConfig")
        if cfg ~= nil then id = field(cfg, "id") end
    end
    if id == nil then
        data = field(entry, "objData")              -- an item on the ground
        if data ~= nil then
            local cfg = field(data, "config")
            if cfg ~= nil then id = field(cfg, "id") end
        end
    end
    if type(id) == "number" and Items.slotOf[id] ~= nil then return id end
    return nil
end

local function isExamine(entry)
    local verb = field(entry, "verbText")
    if type(verb) == "string" and string.lower(stripTags(verb)) == "examine" then return true end
    local kind = tostring(field(entry, "actionVerbType"))
    return kind == "1" or string.upper(kind) == "EXAMINE"
end

-- Which tabs have something for this item: { recipe, uses, source }. Worked out once the game's data is all read (until then only what
-- is known so far is offered, and nothing is remembered).
local function allReady()
    return Recipes.allRead ~= nil and Recipes.allRead() and Recipes.usedState.ready == true and (Gather == nil or Gather.ready == true)
end
local function wanted(id)
    local known = GameMenu.decided[id]
    if known ~= nil then return known end
    local d = { recipe = false, uses = false, source = false }
    local obj = try(config.Obj.FromID, id)
    if obj ~= nil then
        local okR, recipe = pcall(Recipes.get, id, obj)
        d.recipe = okR and recipe ~= nil and recipe.rows ~= nil and #recipe.rows > 0 and not recipe.sameNameOnly
        if Recipes.usedState.ready then
            local okU, used = pcall(Recipes.usedFor, id, obj)
            d.uses = okU and used ~= nil
        end
        if Gather ~= nil and Gather.rowsOf ~= nil then
            local okS, rows = pcall(Gather.rowsOf, id)
            d.source = okS and rows ~= nil and #rows > 0
        end
    end
    d.ready = allReady()
    if d.ready then GameMenu.decided[id] = d end
    return d
end

-- What the game calls when one of our entries is picked: the extra values given to Add arrive in order.
function GameMenu.open(...)
    local id, tab, pageKey = nil, nil, nil
    for _, v in ipairs({ ... }) do
        if type(v) == "number" and id == nil then id = v end
        if LABEL[v] ~= nil and tab == nil then tab = (v == "tmr") and "recipe" or v
        elseif type(v) == "string" and Window.pages[v] ~= nil and Window.pages[v].details ~= nil then pageKey = v end
    end
    if id == nil then return end
    pageKey = pageKey or "search" -- (an item in the game opens on Item search; one inside the plugin on the tab it was on)
    local ok, err = pcall(function()
        if Window.closed then Window.reopen() end              -- (the window may have been closed with its X)
        if Window.collapsed then Window.setCollapsed(false) end -- (or folded up)
        if Window.active ~= pageKey then Window.show(pageKey) end
        local page = Window.pages[pageKey]
        page.details:open(id)                                   -- (a fresh trail for the Back arrow)
        page.details:showTab(tab or "recipe")
    end)
    if not ok then say("could not open the item from the game's menu: " .. tostring(err)) end
end

local function switchOff(why)
    GameMenu.off = true
    say("the game's right-click menu entries are switched off (" .. why .. "). Everything else works as before.")
end

-- Move our entries (the ones whose texts are in ours: label -> item number) to just above each item's Examine entry.
-- The entries are first sorted out on paper, then put in place with swaps of neighbours (which keeps the others in their order).
local function arrange(menu, ours)
    local entries = field(menu, "entries")
    local n = countOf(menu, entries)
    if n == nil or n < 2 then return false end
    local mine, others, found = {}, {}, 0 -- by current position
    local examineOf = {}                    -- item -> position among the others
    for i = 1, n do
        local e = valueAt(entries, i)
        local info = nil
        for label, o in pairs(ours) do
            if isOurs(e, label) then info = o end
        end
        if info ~= nil then
            mine[i] = info
            found = found + 1
        else
            others[#others + 1] = i
            local id = itemOfEntry(e)
            if id ~= nil and examineOf[id] == nil and isExamine(e) then examineOf[id] = #others end
        end
    end
    if found == 0 then return false end

    -- the order we want: the others as they are, our entries (in the order they are now) right after their item's Examine
    -- (never after the last of the others: that one is what a left-click does)
    local after = {}
    for i = 1, n do
        local info = mine[i]
        if info ~= nil then
            local a = examineOf[info.id] or (#others - 1)
            if a > #others - 1 then a = #others - 1 end
            if a < 0 then a = 0 end
            after[a] = after[a] or {}
            after[a][#after[a] + 1] = i
        end
    end
    -- (whatever order the game put them in, they read Recipe, Uses, Source from the top, and each item's entries stay together)
    for _, list in pairs(after) do
        table.sort(list, function(x, y)
            local a, b = mine[x], mine[y]
            if a.order ~= b.order then return a.order < b.order end
            return a.rank < b.rank
        end)
    end
    local want, rank = {}, {} -- want = positions in the order wanted; rank[position] = where it should end up
    for _, i in ipairs(after[0] or {}) do want[#want + 1] = i end
    for p, i in ipairs(others) do
        want[#want + 1] = i
        for _, j in ipairs(after[p] or {}) do want[#want + 1] = j end
    end
    for place, i in ipairs(want) do rank[i] = place end

    -- bubble sort by rank with swaps of neighbours
    local current = {}
    for i = 1, n do current[i] = rank[i] end
    local moved = true
    while moved do
        moved = false
        for i = 1, n - 1 do
            if current[i] > current[i + 1] then
                menu:Swap(i, i + 1)
                current[i], current[i + 1] = current[i + 1], current[i]
                moved = true
            end
        end
    end
    return true
end

----- right-click over this plugin's own items -----
local function over(component)
    if component == nil then return false end
    local ok, v = pcall(function() return component.isMouseOver == true and component.hidden ~= true end)
    return ok and v == true
end
local function overButton(b)
    if b == nil then return false end
    local ok, v = pcall(function() return b.sb.root.hidden ~= true and (b.sb.hovered == true or b.sb.root.isMouseOver == true) end)
    return ok and v == true
end

-- The item under the mouse in the open tab - a picture or a row of its item list, or an item in its details column - and that tab's key;
-- nil if none.
function GameMenu.hovered()
    if Window.closed or Window.collapsed then return nil end
    if Recent ~= nil and Recent.hovered ~= nil then -- (the Recently viewed column: opened on the Item search tab)
        local ok, id = pcall(Recent.hovered)
        if ok and id ~= nil then return id, "search" end
    end
    local page = Window.pages[Window.active]
    if page == nil then return nil end
    local box = page.box
    if box ~= nil then
        for n, s in pairs(box.pics) do
            if over(s) then
                local slot = box:at(n)
                if slot ~= nil then return Items.ids[slot], page.key end
            end
        end
        for n, b in pairs(box.buttons) do
            if overButton(b) then
                local slot = box:at(n)
                if slot ~= nil then return Items.ids[slot], page.key end
            end
        end
    end
    local d = page.details
    if d ~= nil then
        for _, s in ipairs(d.slots) do
            if s.itemId ~= nil and (over(s.icon) or overButton(s.button)) then return s.itemId, page.key end
        end
        if d.itemId ~= nil and over(d.icon) then return d.itemId, page.key end
    end
    return nil
end

-- Put our entries (in the order given) BEFORE all the game's own entries, so the game's last entry ("Cancel") stays what a left-click does.
local function arrangeFirst(menu, labels)
    local entries = field(menu, "entries")
    local n = countOf(menu, entries)
    if n == nil then return false end
    local others, mine = {}, {}
    for i = 1, n do
        local e = valueAt(entries, i)
        local which = nil
        for k, label in ipairs(labels) do
            if isOurs(e, label) then which = k end
        end
        if which ~= nil then mine[#mine + 1] = { pos = i, k = which } else others[#others + 1] = i end
    end
    if #mine ~= #labels then return false end
    table.sort(mine, function(a, b) return a.k < b.k end)
    local rank, place = {}, 0
    for _, m in ipairs(mine) do place = place + 1; rank[m.pos] = place end
    for _, i in ipairs(others) do place = place + 1; rank[i] = place end
    local current = {}
    for i = 1, n do current[i] = rank[i] end
    local moved = true
    while moved do
        moved = false
        for i = 1, n - 1 do
            if current[i] > current[i + 1] then
                menu:Swap(i, i + 1)
                current[i], current[i + 1] = current[i + 1], current[i]
                moved = true
            end
        end
    end
    return true
end

-- The menu is about no item of the game (the mouse is over this plugin): add Recipe / Uses / Source for the item under the mouse, below the
-- game's own "Cancel" (which stays the left-click action, so a left-click on the item works exactly as it always did).
local function pluginMenu(menu, entries, n)
    if n < 1 then return end -- (no game entry to keep as the left-click action: leave the menu alone)
    local id, pageKey = GameMenu.hovered()
    if id == nil or Items.slotOf[id] == nil then return end
    local name = Items.names[Items.slotOf[id]]
    local d = wanted(id)
    local labels = {}
    local tabs = tabsFor(d)
    for k = #tabs, 1, -1 do -- (the list goes bottom to top: Recipe ends up on top)
        labels[#labels + 1] = { text = coloured(LABEL[tabs[k]] .. name), tab = tabs[k] }
    end
    if #labels == 0 then return end
    for i = 1, n do
        if isOurs(valueAt(entries, i), labels[1].text) then return end -- (already there)
    end
    local texts = {}
    for _, w in ipairs(labels) do
        menu:Add(w.text, GameMenu.open, id, w.tab, pageKey)
        texts[#texts + 1] = w.text
    end
    if arrangeFirst(menu, texts) ~= true then error("the entries just added could not be found in the menu") end
    -- a check that never relies on the above having worked: the entry a left-click does must not be one of ours
    local finalEntries = field(menu, "entries")
    local last = valueAt(finalEntries, countOf(menu, finalEntries))
    for _, t in ipairs(texts) do
        if isOurs(last, t) then error("one of our entries ended up as the left-click action") end
    end
end

-- The items the menu is about (at most MAX_ITEMS), in the order the menu lists them.
local function itemsOfMenu(entries, n)
    local items, seen, orderOf = {}, {}, {}
    for i = 1, n do
        local id = itemOfEntry(valueAt(entries, i))
        if id ~= nil and not seen[id] then
            seen[id] = true
            items[#items + 1] = id
            orderOf[id] = #items
            if #items >= MAX_ITEMS then break end
        end
    end
    return items, orderOf
end

-- The entries to add for these items: { text, tab, id }, leaving out any that are already in the menu.
local function entriesToAdd(items, entries, n)
    local labels = {}
    for _, id in ipairs(items) do
        local name = Items.names[Items.slotOf[id]]
        local d = wanted(id)
        for _, tab in ipairs(tabsFor(d)) do
            do
                local text = coloured(LABEL[tab] .. name)
                local present = false
                for i = 1, n do
                    if isOurs(valueAt(entries, i), text) then present = true; break end
                end
                if not present then labels[#labels + 1] = { text = text, tab = tab, id = id } end
            end
        end
    end
    return labels
end

-- THE LEFT-CLICK CHECK. Whatever happened before: if the entry a left-click does (the last) is one of ours, the nearest entry of the game's
-- is moved into its place, one swap of neighbours at a time (as arrange does). Returns "ok" (it was not ours), "fixed", or false (no entry
-- of the game's).
local function keepLeftClick(menu, ours)
    local entries = field(menu, "entries")
    local n = countOf(menu, entries)
    if n == nil or n < 1 then return "ok" end
    local function mine(e) for label in pairs(ours) do if isOurs(e, label) then return true end end return false end
    if not mine(valueAt(entries, n)) then return "ok" end
    for k = n - 1, 1, -1 do
        if not mine(valueAt(entries, k)) then
            for i = k, n - 1 do menu:Swap(i, i + 1) end
            return "fixed"
        end
    end
    return false
end

local function onMenuReady(event)
    if GameMenu.off or GAME_MENU == false or not Items.loaded then return end -- (GAME_MENU: the Settings page switch)
    local menu = field(event, "miniMenu")
    if menu == nil then return end
    local entries = field(menu, "entries")
    local n = countOf(menu, entries) or 0
    if n < 1 or entries == nil then return end

    local items, orderOf = itemsOfMenu(entries, n)
    if #items == 0 then
        if not GameMenu.pluginOff then
            local ok, err = pcall(pluginMenu, menu, entries, n)
            if not ok then
                GameMenu.pluginOff = true
                say("the right-click menu over this plugin's items is switched off (" .. tostring(err) .. "). The menu for items in the game still works.")
            end
        end
        return
    end
    local labels = entriesToAdd(items, entries, n)
    if #labels == 0 then return end
    local ours, added = {}, false
    for _, w in ipairs(labels) do
        local okAdd, errAdd = pcall(function() menu:Add(w.text, GameMenu.open, w.id, w.tab) end)
        if not okAdd then
            switchOff("adding an entry failed: " .. tostring(errAdd))
            if added then pcall(keepLeftClick, menu, ours) end -- (the ones already added must not be the left-click either)
            return
        end
        added = true
        ours[w.text] = { id = w.id, rank = RANK[w.tab], order = orderOf[w.id] }
    end

    local okMove, placed = pcall(arrange, menu, ours)
    if not okMove then
        switchOff("moving the entries failed: " .. tostring(placed))
        pcall(keepLeftClick, menu, ours)
        return
    end
    if placed ~= true then
        -- (the entries we just added are not in the list, so we cannot see where they went or make sure that they are not the left-click action)
        switchOff("the entries just added could not be found in the menu")
        pcall(keepLeftClick, menu, ours)
        return
    end

    -- a check that never relies on the above having worked: the entry a left-click does must not be one of ours (and if it is, it is moved
    -- back up for this menu too)
    local okKeep, kept = pcall(keepLeftClick, menu, ours)
    if not okKeep or kept ~= "ok" then switchOff("one of our entries ended up as the left-click action") end
end

local ok, err = pcall(function() Event.MiniMenuReady.Subscribe("toomanyrunes_menu", function(event)
    if GameMenu == nil then return end -- (the plugin was switched off)
    local okRun, errRun = pcall(onMenuReady, event) -- (an error of ours never reaches the game's menu)
    if not okRun then switchOff("an error: " .. tostring(errRun)) end
end) end)
if not ok then say("the right-click menu entries could not be set up: " .. tostring(err)) end

end }
