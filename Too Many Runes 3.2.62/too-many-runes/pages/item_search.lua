-- Too Many Runes - The item search page
-- The item box on the left (every item the search and filter let through, the forms of an item grouped: core/groups.lua) and the item
-- details on the right.
-- (3.2.18) Above the item box: one row of group tabs (core/shelves.lua) - All, Gear, Food ... - and, for a picked group, a heading line
-- whose dropdown picks its smaller group: "Gear > [Melee] (2,075)". With nothing typed in the search, the list is sorted shelf by shelf;
-- gold headings in the list part the shelves when more than one is shown.
return { run = function(T)
local _ENV = T

local page = { key = "search", label = "Item search" }

-- THE GROUP TABS (3.2.18). One row of plain buttons with short words (the open one with a gold border); a row too long for a narrow
-- window goes on to a second line. A picked group adds a heading line under the row: its name, a dropdown of its smaller groups ("All
-- gear", Melee, Ranged ...) and how many items are shown. On All there is no heading line.
local TAB_H, ROW_GAP, HEAD_H = 24, 4, 28
local SHORT = { consumables = "Food", questclue = "Quests" } -- (the tab words; the headings keep the full names)
-- (3.2.22) the picture in front of each tab's words: an item everyone knows (its number), or a picture of the game's (sprite) - All tries
-- the game's infinity picture under a few names; with none of them found it has no picture
-- (3.2.47: All has the game's picture 1434 (a sprite); Favorites, the tab after it, the gold star of the item details' favourite button)
local TAB_PICS = { all = { sprite = 1434 }, fav = { names = { "RAND_SPEEDRUN_STAR_GOLD_0" } },
                   gear = { item = 1163 }, consumables = { item = 379 }, gathering = { item = 1511 }, artisan = { item = 2347 },
                   support = { item = 526 }, questclue = { sprite = QUEST_PIC }, misc = { item = 1925 } }
local PIC_W, PIC_H = 20, 18 -- (the picture's size)
ShelfTabs = {}
-- (3.2.20: the smaller groups are picked with a plain button and a little list that opens under it - the game's own dropdown, made here,
-- was not drawn, or drawn in the wrong place)
local function subWords(g, sub)
    if sub == nil or sub == "all" then return "All " .. string.lower(g.tab) end
    for _, sb in ipairs(g.subs) do if sb.key == sub then return sb.tab end end
    return sub
end
local function closePicker()
    if page.openPicker ~= nil then page.openPicker.layer.hidden = true; page.openPicker = nil end
end
function ShelfTabs.paint()
    if page.tabs == nil then return end
    page.tabs:select(Shelves.tab)
    for key, b in pairs(page.subButtons) do
        local open = (key == Shelves.tab)
        b:show(open)
        if open then b:setLabel(subWords(Shelves.groupByKey[key], Shelves.sub)) end
    end
end

function page.build(layer)
    page.box = ItemBox.new(layer, function(itemId, place)
        local changed, at = Groups.click(place) -- (a group's picture: its other forms unfold, or fold away; another open group folds)
        if not changed then changed, at = Groups.foldUnless(itemId, place) end -- (another item: the open group folds)
        if changed then
            page.refresh(false)
            local want = at and page.box:pageOfPlace(at) -- (folding a group before it moved it: keep it on screen)
            if want ~= nil and want ~= page.box.page then page.box:goTo(want) end
            Window.refreshPager()
        end
        page.details:open(itemId)
    end)
    page.box.countOf, page.box.hoverNote, page.box.inGroup = Groups.countAt, Groups.noteAt, Groups.openAt
    page.box.selectedOf = function() return page.details.itemId end -- (the item open on the right is marked in the list)
    page.details = Details.new(layer)
    -- (a click opens the tab, shows its group's row of sub-tabs and makes room for it: page.relayout)
    local function picked(key, sub)
        closePicker()
        if key == Shelves.tab and sub == Shelves.sub then return end
        Shelves.setTab(key, sub)
        ShelfTabs.paint()
        page.box.page = 1 -- (a new tab starts on its first page)
        page.relayout()
        Window.refreshPager()
        Window.refreshStatus()
    end
    page.tabs = Kit.tabStrip(layer, TAB_H, function(key) picked(key, nil) end)
    local function tabPic(key)
        local def, pic = TAB_PICS[key], nil
        if def ~= nil and def.item ~= nil then
            pic = Kit.itemIcon(layer, PIC_W, PIC_H)
            if not Kit.setItem(pic, def.item) then pic.hidden = true; pic = nil end
        else
            local spriteId = def and def.sprite
            if spriteId == nil and def ~= nil and def.names ~= nil then
                for _, n in ipairs(def.names) do
                    local ok, v = pcall(function() return id.Sprite[n] end)
                    if ok and type(v) == "number" then spriteId = v break end
                end
            end
            if type(spriteId) == "number" then
                pic = ui.Sprite.new(layer)
                pcall(function() pic.spriteID = spriteId; pic.colour = WHITE; pic:SetSize(PIC_H, PIC_H) end)
            end
        end
        return pic -- (3.2.23: nothing of the plugin's own is written onto the game's picture - the game refuses that, and the page failed)
    end
    -- (3.2.26) each tab: a blank button with the picture and the words drawn on it - a small edge, the picture, the word, a small edge
    local EDGE, GAP = 7, 4
    local function addTab(key, word)
        local pic = tabPic(key)
        local x = EDGE + (pic and (PIC_W + GAP) or 0)
        page.tabs:add(key, "", x + math.ceil(textWidth(word)) + EDGE)
        page.tabs.labels[key] = word
        if pic ~= nil then page.tabs:setIcon(key, pic, PIC_H, EDGE) end
        page.tabs:setWords(key, Kit.text(layer, 0, 0, 10, LINE_H, "left"), x)
        page.tabs.wordsOf[key].content = word
    end
    addTab("all", "All")
    addTab("fav", "Favorites") -- (3.2.47: in place of the dropdown beside the search box - core/shelves.lua)
    for _, g in ipairs(Shelves.GROUPS) do addTab(g.key, SHORT[g.key] or g.tab) end
    -- the heading line: "Gear >", the dropdown of the group's smaller groups, the count, a thin line to the right edge
    page.headName = Kit.text(layer, 0, 0, 10, HEAD_H, "left")
    page.headCount = Kit.text(layer, 0, 0, 10, HEAD_H, "left")
    pcall(function() page.headName.rgba = 0xD9B25FFF; page.headCount.rgba = DIM_RGBA end)
    page.headLine = Kit.rect(layer, 0, 0, 1, 1, FRAME_LINE)
    -- the button of each group (the one of the open group is shown) and its list, made the first time it is opened
    page.subButtons, page.pickers = {}, {}
    local function openPicker(g)
        local pp = page.pickers[g.key]
        if pp == nil then
            pp = { layer = ui.Layer.new(layer), rows = {} }
            pp.frame = Kit.frame(pp.layer)
            -- (3.2.40) A layer over the whole list, under its buttons, that takes the mouse: the frame's back lets clicks through, so a
            -- click in the gap between two choices opened the item under it, and its name showed on hover (the way ui/suggest.lua's list
            -- does it)
            pp.block = ui.Layer.new(pp.layer)
            pcall(function() pp.block.clickthrough = false end)
            pp.block:Subscribe(ui.Hook.ONMOUSEOVER, function() pcall(Window.hideHover); return true end)
            pp.block:Subscribe(ui.Hook.ONCLICK, function() return false end)
            local list = { { key = "all", words = subWords(g, nil) } }
            for _, sb in ipairs(g.subs) do list[#list + 1] = { key = sb.key, words = sb.tab } end
            local w = 0
            for _, e in ipairs(list) do w = math.max(w, math.ceil(textWidth(e.words) + 28)) end
            pp.w, pp.h = w + 10, #list * (TAB_H + 2) + 8
            for _, e in ipairs(list) do
                local key = e.key
                pp.rows[#pp.rows + 1] = { key = key, b = Kit.button(pp.layer, e.words, w, TAB_H, function()
                    picked(g.key, (key ~= "all") and key or nil)
                end) }
            end
            page.pickers[g.key] = pp
        end
        local at = page.subAt or { x = 0, y = 0 }
        pp.layer:SetPos(at.x, at.y + TAB_H + 2); pp.layer:SetSize(pp.w, pp.h)
        pp.frame:place(0, 0, pp.w, pp.h)
        pp.block:SetPos(0, 0); pp.block:SetSize(pp.w, pp.h)
        for k, r in ipairs(pp.rows) do
            r.b:place(5, 4 + (k - 1) * (TAB_H + 2))
            r.b:setActive(r.key == (Shelves.sub or "all"))
        end
        pp.layer.hidden = false
        pcall(function() pp.layer:MoveToFront() end) -- (over the item pictures)
        page.openPicker = pp
    end
    for _, g in ipairs(Shelves.GROUPS) do
        local w = math.ceil(textWidth(subWords(g, nil)) + 28)
        for _, sb in ipairs(g.subs) do w = math.max(w, math.ceil(textWidth(sb.tab) + 28)) end
        local b = Kit.button(layer, subWords(g, nil), w, TAB_H, function()
            if page.openPicker ~= nil then closePicker() else openPicker(g) end
        end)
        b.w = w
        b:show(false)
        page.subButtons[g.key] = b
    end
    ShelfTabs.paint()
    local open = page.details.open
    page.details.open = function(self, ...) -- (any other way an item is opened - a material, the back arrow - moves the mark too)
        local result = open(self, ...)
        if Groups.foldUnless(self.itemId) then page.refresh(false); Window.refreshPager() end -- (not one of the open group's forms)
        pcall(page.box.paintMarks, page.box)
        return result
    end
end

function page.layout(w, h, keepPicker)
    page.w, page.h = w, h
    -- (its place may have moved - but not when only the count on the heading line changed: 3.2.34, the list growing while the plugin loads
    -- closed it again and again)
    if not keepPicker then closePicker() end
    local dw = math.min(DETAILS_W, w - 240)
    local bw = w - dw - 6
    -- the row of group tabs across the whole page (as many lines as it needs - one, unless the window is very narrow), the heading line
    -- of a picked group, then the item box under them; the details column starts under the tabs
    page.tabs.wrapW = w - 4
    page.tabs:place(2, 2)
    local top = 2 + page.tabs.height + ROW_GAP
    local y = top
    local g = Shelves.groupByKey[Shelves.tab]
    page.headName.hidden, page.headCount.hidden, page.headLine.hidden = (g == nil), (g == nil), (g == nil)
    if g ~= nil then
        local name = g.tab .. "  >"
        local nw = math.ceil(textWidth(name)) + 6
        page.headName.content = plain(name)
        page.headName:SetPos(6, y); page.headName:SetSize(nw, HEAD_H)
        local b = page.subButtons[g.key]
        page.subAt = { x = 6 + nw + 4, y = y + (HEAD_H - TAB_H) // 2 }
        b:place(page.subAt.x, page.subAt.y)
        local cx = page.subAt.x + b.w + 8
        local count = "(" .. withCommas(Shelves.shown or #page.box.list) .. ")"
        local cw = math.ceil(textWidth(count)) + 6
        page.headCount.content = count
        page.headCount:SetPos(cx, y); page.headCount:SetSize(cw, HEAD_H)
        page.headLine:SetPos(cx + cw + 4, y + HEAD_H // 2); page.headLine:SetSize(math.max(1, bw - (cx + cw + 4) - 4), 1)
        y = y + HEAD_H + ROW_GAP
    end
    page.box:place(0, y, bw, h - y)
    page.details:place(w - dw, top, dw, h - top)
end
function page.relayout(keepPicker)
    if page.w ~= nil then page.layout(page.w, page.h, keepPicker); page.box:render() end
    local pp = page.openPicker
    if pp ~= nil then pcall(function() pp.layer:MoveToFront() end) end -- (still over the item pictures drawn again)
end

-- The shelves for the item box (ui/item_box.lua): the shelf at a place in the list (the forms of an open group stay on their group's
-- shelf, so its tray is not split by a heading) and each heading's words, with how many of the list are on that shelf.
-- (A group's picture goes by the group's first form, which is what put it there: Groups.firstAt.)
local function shelfInfo(list)
    local function of(p)
        local g = Groups.openAt(p)
        if g ~= nil and p > 1 and Groups.openAt(p - 1) == g then return of(p - 1) end
        return Shelves.ofSlot(Groups.firstAt(p) or list[p])
    end
    local counts = {}
    for i = 1, #list do local k = of(i); counts[k] = (counts[k] or 0) + 1 end
    return { of = of, label = function(key)
        local e = Shelves.byKey[key] or Shelves.byKey.misc
        return e.label .. " (" .. withCommas(counts[key] or 0) .. ")"
    end }
end

-- (the list sorted by shelf is kept while the list it came from is the same, so the groups - core/groups.lua - are not worked out again)
local sortedFrom, sortedN, sorted = nil, -1, nil
function page.refresh(newSearch)
    local base = Search.list()
    local shelved = Shelves.active()
    if shelved then
        if base ~= sortedFrom or #base ~= sortedN then sortedFrom, sortedN, sorted = base, #base, Shelves.sort(base) end
        base = sorted
    end
    local list = Groups.of(base, newSearch)
    -- (the gold headings in the list only when it holds more than one shelf: not with a smaller group picked - the heading line says it)
    page.box.shelves = (shelved and Shelves.sub == nil) and shelfInfo(list) or nil
    page.box:setList(list, newSearch)
    page.box:render()
    Shelves.shown = #Filters.current() -- (how many items the tabs let through: the title and the heading line say the same number)
    if page.headCount ~= nil and not page.headCount.hidden then -- (the heading line's count)
        local old = page.headCount.content
        local now = "(" .. withCommas(Shelves.shown) .. ")"
        if old ~= now then page.relayout(true) end
    end
end

-- The item list grew while loading: draw the page again only if it was not full (new items are added at the end of the list).
function page.grow()
    local box, list = page.box, Groups.of(Search.list())
    if math.min(box.perPage, #list - (box.page - 1) * box.perPage) ~= box.shown or Groups.changedUpTo(box.page * box.perPage) then
        page.refresh(false)
    end
end

function page.pageInfo() return page.box.page, page.box:pageCount() end
function page.goTo(n) page.box:goTo(n) end

Window.addPage(page)

end }
