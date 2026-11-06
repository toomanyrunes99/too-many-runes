-- Too Many Runes - The window
-- One PrettyUI window:
--   title bar      "Too Many Runes", with the loading / item count at its left
--   tab row        one tab per page (pages/ folder), the minimize button at the right end
--   page area      the open tab's page
--   bottom bar     filter, view, page arrows and the search box - shared by every tab
-- The window can be dragged bigger or smaller by its corner; everything is placed again to fit, and the size and place are remembered.
--
-- A PAGE (one tab) is a table:  { key =, label =, build = function(layer), layout = function(w, h), refresh = function(newSearch),
--   pageInfo = function() return page, pages end (optional), goTo = function(n) (optional), tick = function() (optional) }
-- and is added with Window.addPage(page). refresh is called whenever the search, the filter or the view changes.
return { run = function(T)
local _ENV = T

Window = { pages = {}, order = {}, active = nil, collapsed = false, closed = false }

local FRAME_W, FRAME_H = 16, 40  -- PrettyUI's frame round the inside of a window (32 of the 40 are the title bar)
local PAD, TAB_H, BAR_H = 6, 28, 36
local TOP = TAB_H + 10           -- where the page area starts (under the tabs and their line)
local SEARCH_W = 250
local COLLAPSED_IN = math.max(60, COLLAPSED_W or 100) - FRAME_W -- the inside width while minimized (COLLAPSED_W in settings.lua)

-- THE VIEWS of an item list (the second dropdown)
VIEWS = { { id = "rows", label = "Rows" }, { id = "icons:64", label = "Icons: 64" }, { id = "icons:48", label = "Icons: 48" },
          { id = "icons:32", label = "Icons: 32" }, { id = "icons:16", label = "Icons: 16" } }
View = { current = VIEW_DEFAULT }
do
    local saved = Saved.get("view")
    for _, v in ipairs(VIEWS) do if v.id == saved then View.current = saved end end
end

----------------------------------------------------------------
-- THE WINDOW ITSELF
----------------------------------------------------------------
local cw = math.max(WINDOW_MIN_W, Saved.num("win_w") or WINDOW_W) -- the size of the inside (without the side panel)
local ch = math.max(WINDOW_MIN_H, Saved.num("win_h") or WINDOW_H)
-- (the Recently viewed column, if it was open last time: the window is made that wide from the start - pages/recent.lua)
local startSide = (Saved.get("recent_open") == "yes" and Saved.get("collapsed") ~= "yes") and (RECENT_W or 250) or 0
do
    local sw, sh = screenSize()
    local x, y = Saved.num("win_x"), Saved.num("win_y")
    if x == nil then x = (sw > 0) and math.floor((sw - cw - FRAME_W) / 2) or 80 end
    if y == nil then y = (sh > 0) and math.floor(sh * 0.06) or 40 end
    if sw > 0 then x = math.max(0, math.min(x, sw - 120)) end
    if sh > 0 then y = math.max(0, math.min(y, sh - 60)) end
    Window.win = prettyui.Window.new(gameArea(), {
        title = "Too Many Runes",
        x = x, y = y, width = cw + startSide + FRAME_W, height = ch + FRAME_H,
        minWidth = COLLAPSED_IN + FRAME_W, minHeight = TOP + FRAME_H, -- (so it may shrink to the minimized width; our corner keeps WINDOW_MIN_W)
        resizable = false, scrollable = false, destroyOnClose = false, -- (resizing is done by our own handles: see RESIZING)
        onClose = function() Window.closed = true end,
    })
    Window.lastX, Window.lastY = x, y
end
-- The whole window stays hidden while the files load (one a frame) and is shown once it is laid out (start.lua): before, the parts
-- showed in the top left corner for a moment at start-up.
Window.starting = true
pcall(function() Window.win.root.hidden = true end)
local content = Window.win.content
Window.content = content

-- THE SIDE PANEL'S ROOM: pages/recent.lua's Recently viewed panel takes a column this wide on the window's left (Window.setSide); the
-- window is that much wider and everything else moves over by it. Not while minimized.
Window.sideW = startSide
local function side() return Window.collapsed and 0 or (Window.sideW or 0) end
Window.side = side

-- The status at the left of the title bar ("Reading items... 42%", "Found 58,328 items"). If it cannot go there, it goes in the title.
pcall(function() Window.status = Kit.text(Window.win.root, 12, 5, 240, 22, "left") end)
-- choices: the words to show, longest first ({ "Found 58,328 items (11,878 items hidden)", "Found 58,328 items" }); the first that fits
-- between the left edge and the window's centred title is shown (the last one shortened with ".." when even that does not fit).
local TITLE_HALF = 72 -- (about half the width of the title "TOO MANY RUNES")
function Window.setStatus(choices)
    if type(choices) ~= "table" then choices = { tostring(choices) } end
    local winW = (Window.collapsed and COLLAPSED_IN or (cw + side())) + FRAME_W
    local maxW = math.max(60, math.floor(winW / 2 - TITLE_HALF - 12 - 10))
    local text = nil
    for _, c in ipairs(choices) do
        if text == nil and textWidth(c) <= maxW then text = c end
    end
    text = text or fitText(choices[#choices], maxW)
    if Window.status ~= nil and Window.statusW ~= maxW then
        Window.statusW = maxW
        pcall(function() Window.status:SetSize(maxW, 22) end)
    end
    if Window.statusWords == text then return end
    Window.statusWords = text
    if Window.status ~= nil then
        pcall(function() Window.status.content = text; Window.status:MoveToFront() end)
    else
        pcall(function() Window.win:SetTitle("Too Many Runes - " .. text) end)
    end
end
function Window.refreshStatus()
    local text
    if not Items.loaded then
        text = "Reading items... " .. math.min(99, math.floor(Items.progress() * 100)) .. "%"
    elseif Search.active and Search.spec ~= nil and Search.spec.note ~= nil then
        text = tostring(Search.spec.note) -- (an @word the search does not know, or a start that fits two: core/query.lua)
    elseif Search.active then
        local n = #Search.results
        text = withCommas(n) .. ((n == 1) and " match" or " matches")
    elseif Filters.key ~= "all" then
        text = Filters.byKey[Filters.key].label .. ": " .. withCommas(#Filters.current())
    else
        text = "Found " .. withCommas(Items.count()) .. " items"
    end
    -- while the recipes and uses are still being read: how far that has got ("Found 58,328 items - recipes 40%")
    local note = nil
    if Items.loaded and Window.loadingNote ~= nil then
        local ok, n = pcall(Window.loadingNote)
        if ok and type(n) == "string" then note = n end
    end
    -- (the longest words first: Window.setStatus shows the first that fits beside the title)
    if note ~= nil then
        Window.setStatus({ text .. " - " .. note, "Reading " .. note, text })
    elseif Items.loaded and not Search.active and Filters.key == "all" and Window.active == "search" then
        -- once everything is read: how many the hide switches leave out (noted, broken, unfinished, junk - the Settings page)
        local hidden = Items.count() - #Filters.current()
        if hidden > 0 then Window.setStatus({ text .. " (" .. withCommas(hidden) .. " items hidden)", text }) else Window.setStatus({ text }) end
    else
        Window.setStatus({ text })
    end
end

----------------------------------------------------------------
-- THE TAB ROW
----------------------------------------------------------------
Window.tabs = Kit.tabStrip(content, TAB_H, function(key) Window.show(key) end)
Window.tabLine = Kit.rect(content, PAD, TAB_H + 4, 10, 1, FRAME_LINE)

-- Minimize: a dash; while the window is minimized, a little square ("make it big again").
-- (It sits in the tab row, not the title bar: the title bar is the window's drag handle and swallows clicks.)
Window.minButton = Kit.button(content, "", 22, 22, function() Window.setCollapsed(not Window.collapsed) end)
Window.dash = Kit.rect(content, 0, 0, 12, 2, Vector4.new(0.91, 0.84, 0.69, 1.0))
Window.square = {}
for k = 1, 4 do
    Window.square[k] = Kit.rect(content, 0, 0, 1, 1, Vector4.new(0.91, 0.84, 0.69, 1.0))
    Window.square[k].hidden = true
end
-- Settings and Help: two buttons left of the minimize button. Each opens its page (pages/settings.lua, pages/help.lua) in place of the
-- tabs' pages; the same button goes back to the tab you were on.
local function togglePage(key)
    if Window.pages[key] == nil then return end
    if Window.collapsed then Window.setCollapsed(false) end
    if Window.active == key then
        Window.show(Window.backTo or Window.order[1])
    else
        local cur = Window.pages[Window.active]
        if cur ~= nil and not cur.noTab then Window.backTo = Window.active end
        Window.show(key)
    end
end
-- Open the window (if closed or minimized) on one of its pages, e.g. the Settings page from the Plugins window (ui/ribbon.lua).
function Window.openPage(key)
    if Window.closed then Window.reopen() end
    if Window.collapsed then Window.setCollapsed(false) end
    if Window.active ~= key then togglePage(key) end
end
Window.helpButton = Kit.button(content, "?", 22, 22, function() togglePage("help") end)
local SETTINGS_W = math.ceil(textWidth("Settings") + 20)
Window.settingsButton = Kit.button(content, "Settings", SETTINGS_W, 22, function() togglePage("settings") end)
local function placeMinButton()
    local x, y = (Window.collapsed and COLLAPSED_IN or (cw + side())) - PAD - 22, 3
    Window.helpButton:place(x - 4 - 22, y)
    Window.settingsButton:place(x - 8 - 22 - SETTINGS_W, y)
    Window.minButton:place(x, y)
    Window.dash:SetPos(x + 5, y + 14)
    local s = Window.square
    s[1]:SetPos(x + 5, y + 5);  s[1]:SetSize(12, 2)
    s[2]:SetPos(x + 5, y + 15); s[2]:SetSize(12, 2)
    s[3]:SetPos(x + 5, y + 5);  s[3]:SetSize(2, 12)
    s[4]:SetPos(x + 15, y + 5); s[4]:SetSize(2, 12)
end

----------------------------------------------------------------
-- THE BOTTOM BAR (shared by every tab)
----------------------------------------------------------------
local function numbered(list, labelOf, idOf)
    local entries = {}
    for k, e in ipairs(list) do entries[k] = { label = labelOf(e), id = idOf(e) } end
    return entries
end
-- (the filters in this order: All items, Favorites, Gathered, Craftable, Uncraftable, then any others)
local FILTER_ORDER = { all = 1, fav = 2, gathered = 3, craftable = 4, non = 5 }
local filterList = {}
for _, f in ipairs(Filters.list) do filterList[#filterList + 1] = f end
table.sort(filterList, function(a, b) return (FILTER_ORDER[a.key] or 99) < (FILTER_ORDER[b.key] or 99) end)
Window.filter = Kit.dropdown(content, numbered(filterList, function(f) return f.label end, function(f) return f.key end),
    Filters.key, function(key) Filters.setKey(key) end, true)
Window.view = Kit.dropdown(content, numbered(VIEWS, function(v) return v.label end, function(v) return v.id end),
    View.current, function(v) Window.setView(v) end)

Window.prev = Kit.picture(content, PAGER_ICONS.prev, function() Window.turn(-1) end)
Window.next = Kit.picture(content, PAGER_ICONS.next, function() Window.turn(1) end)
Window.pageText = Kit.text(content, 0, 0, 120, 22)

Window.search = Kit.input(content, SEARCH_W, 28, "")
Window.search:show(false) -- (until the first Window.layout puts it in place: before that it sat in the top left corner at start-up)
-- The hint in the empty search box: "Search: name or #number", then an example that changes every few seconds, fading out and in
-- (Window.tickHint, called by the clock in start.lua). It is words laid over the box, on its left and centred top to bottom: hidden as
-- soon as the box holds text. The examples are SEARCH_HINTS in settings.lua.
local HINTS = (type(SEARCH_HINTS) == "table" and #SEARCH_HINTS > 0) and SEARCH_HINTS or { "name or #number" }
local HINT_LABEL = "Search: "                                  -- (stays put; only the example after it fades)
local HINT_LABEL_W = math.ceil(textWidth(HINT_LABEL))
Window.hintLabel = Kit.text(content, 0, 0, HINT_LABEL_W + 4, 28, "left")
Window.hintLabel.content = HINT_LABEL
pcall(function() Window.hintLabel.rgba = 0xA09070FF end)
Window.hint = Kit.text(content, 0, 0, SEARCH_W - 44 - HINT_LABEL_W, 28, "left")
Window.hint.hidden, Window.hintLabel.hidden = true, true -- (Window.tickHint shows them once the window is laid out)
pcall(function() Window.hint.rgba = 0xA09070FF end)
Window.hint.content = HINTS[1]
local hintAt, hintTick = 1, 0
function Window.tickHint()
    local show = Search.text == "" and not Window.collapsed
    Window.hint.hidden = not show
    Window.hintLabel.hidden = not show
    if not show then return end
    hintTick = hintTick + 1
    local HOLD, FADE = 140, 20 -- (in game ticks, 50 a second: shown for about 3 seconds, then 0.4 s out and 0.4 s in)
    local t = hintTick % (HOLD + 2 * FADE)
    local alpha = 1
    local function ease(x) return x * x * (3 - 2 * x) end -- (starts and ends gently: a smoother fade than a straight line)
    if t >= HOLD and t < HOLD + FADE then alpha = 1 - ease((t - HOLD) / FADE)
    elseif t >= HOLD + FADE then
        if t == HOLD + FADE then hintAt = hintAt % #HINTS + 1; Window.hint.content = HINTS[hintAt] end
        alpha = ease((t - HOLD - FADE) / FADE)
    end
    pcall(function() Window.hint.alpha = alpha end)
end
Window.search.onChange = function(text)
    if text == Search.text then return end -- (the box also reports when it loses focus, with the same text)
    Search.run(text)
end
Window.clear = Kit.button(content, "X", 24, 24, function()
    Window.search:setText("")
    Search.run("")
end)
Window.clear:show(false)
Window.redButtons = {} -- (other buttons with red words: the Settings page's reset button)
function Window.keepClearRed()
    if Search.text ~= "" and not Window.clear:isHovered() then Window.clear:setTextColour(0xE05050FF) end
    for _, b in ipairs(Window.redButtons) do if not b:isHovered() then b:setTextColour(0xE05050FF) end end
end

local barParts = { Window.filter, Window.view, Window.prev, Window.next, Window.search, Window.helpButton, Window.settingsButton }

-- The page arrows and "Page 1 / 501", centred in the room between the dropdowns and the search box.
function Window.refreshPager()
    local page = Window.pages[Window.active]
    local cur, total = nil, nil
    if page ~= nil and page.pageInfo ~= nil then cur, total = page.pageInfo() end
    local shown = cur ~= nil and not Window.collapsed
    Window.prev:show(shown); Window.next:show(shown); Window.pageText.hidden = not shown
    if not shown then return end
    local y = ch - BAR_H + 4
    local left = side() + PAD + Window.view.w
    local right = side() + cw - PAD - SEARCH_W - 4 - Window.filter.w
    local mid = math.floor((left + right) / 2)
    -- (a narrow window: "1 / 646" instead of "Page 1 / 646", and only the arrows when even that does not fit, so they never squash)
    local room = right - left - 8 - 2 * (15 + 4)
    local text = "Page " .. cur .. " / " .. total
    if textWidth(text) + 8 > room then text = cur .. " / " .. total end
    if textWidth(text) + 8 > room then text = "" end
    Window.pageText.content = text
    local tw = (text ~= "") and (math.ceil(textWidth(text)) + 8) or 4
    Window.pageText:SetSize(tw, 22); Window.pageText:SetPos(mid - tw // 2, y + 3)
    Window.prev:place(mid - tw // 2 - 4 - 15, y + 5)
    Window.next:place(mid + tw // 2 + 4, y + 5)
end

-- The arrows go round: back from page 1 is the last page, on from the last page is page 1.
function Window.turn(step)
    local page = Window.pages[Window.active]
    if page == nil or page.pageInfo == nil then return end
    local cur, total = page.pageInfo()
    local n = cur + step
    if n < 1 then n = total elseif n > total then n = 1 end
    local ok, err = pcall(page.goTo, n)
    if not ok then trouble("turning the page", err) end
    Window.refreshPager()
end

----------------------------------------------------------------
-- PAGES (the tabs)
----------------------------------------------------------------
local function area() return side() + PAD, TOP, cw - 2 * PAD, ch - TOP - BAR_H - 2 end
function Window.areaOrigin() return side() + PAD, TOP end -- (where a page's (0, 0) is inside the window)

function Window.addPage(page)
    page.layer = ui.Layer.new(content)
    page.layer.hidden = true
    page.stale = true
    page.build(page.layer)
    Window.pages[page.key] = page
    if not page.noTab then -- (Settings and Help have a button of their own instead of a tab)
        Window.order[#Window.order + 1] = page.key
        Window.tabs:add(page.key, page.label)
    end
    Kit.raiseDropdowns() -- (the page was made after the dropdowns: keep their open lists on top of it)
end

local function layoutPage(page)
    local x, y, w, h = area()
    page.layer:SetPos(x, y)
    page.layer:SetSize(w, h)
    local ok, err = pcall(page.layout, w, h)
    if not ok then trouble("laying out the " .. page.label .. " tab", err) end
    page.stale = false
end

local function refreshPage(page, newSearch)
    local ok, err = pcall(page.refresh, newSearch)
    if not ok then trouble("showing the " .. page.label .. " tab", err) end
end

function Window.show(key)
    local page = Window.pages[key]
    if page == nil then return end
    Window.active = key
    for k, p in pairs(Window.pages) do p.layer.hidden = (k ~= key) or Window.collapsed end
    if page.noTab then
        Window.tabs.active = nil
        Window.tabs.underline.hidden = true
        for _, b in pairs(Window.tabs.buttons) do b:setActive(false) end
    else
        Saved.set("tab", key)
        Window.tabs:select(key)
    end
    Window.refreshStatus()
    Window.helpButton:setActive(key == "help")
    Window.settingsButton:setActive(key == "settings")
    if page.stale then layoutPage(page) end
    if page.searchStale then page.searchStale = false; refreshPage(page, true) else refreshPage(page, false) end
    Window.refreshPager()
end

-- The search (or the filter) changed: the open tab shows it now, the others when they are opened.
-- Put words in the search box and search for them (a click on "Made at: Furnace" types "@furnace": ui/details.lua).
function Window.runSearch(text)
    Window.search:setText(text)
    Search.run(text)
end

-- Where the search box is: x, y (inside the window) and its width. (ui/suggest.lua puts its list just above it.)
function Window.searchBox() return side() + cw - PAD - SEARCH_W, ch - BAR_H + 4, SEARCH_W end

function Window.searchChanged()
    Window.clear:show(Search.text ~= "" and not Window.collapsed)
    Window.keepClearRed()
    for k, p in pairs(Window.pages) do
        if k == Window.active then refreshPage(p, true) else p.searchStale = true end
    end
    Window.refreshStatus()
    Window.refreshPager()
end

-- The view dropdown changed (rows or icons).
function Window.setView(v)
    if v == View.current then return end
    View.current = v
    Saved.set("view", v)
    for _, p in pairs(Window.pages) do p.stale = true end
    Window.show(Window.active)
end

----------------------------------------------------------------
-- PLACING EVERYTHING
----------------------------------------------------------------
function Window.layout()
    local sx = side() -- (the side panel's column, when it is open)
    Window.tabs:place(sx + PAD + (Window.tabsInset or 0), 2) -- (tabsInset: room for the Recently viewed arrow, pages/recent.lua)
    Window.tabLine:SetPos(PAD, TAB_H + 4) -- (the gold line runs across the side column too)
    Window.tabLine:SetSize(sx + cw - 2 * PAD, 1)
    placeMinButton()
    local y = ch - BAR_H + 4
    Window.view:place(sx + PAD, y)
    Window.filter:place(sx + cw - PAD - SEARCH_W - 4 - Window.filter.w, y) -- (the filter sits just left of the search box)
    Window.search:place(sx + cw - PAD - SEARCH_W, y)
    Window.search:show(not Window.collapsed)
    Window.hintLabel:SetPos(sx + cw - PAD - SEARCH_W + 10, y)
    Window.hint:SetPos(sx + cw - PAD - SEARCH_W + 10 + HINT_LABEL_W, y)
    Window.clear:place(sx + cw - PAD - 26, y + 2)
    for _, p in pairs(Window.pages) do p.stale = true end
    if Window.active ~= nil and not Window.collapsed then
        local page = Window.pages[Window.active]
        layoutPage(page)
        refreshPage(page, false)
    end
    Window.refreshPager()
    Window.refreshStatus() -- (the room beside the title changes with the window's width)
end

-- Minimize: a small bar (COLLAPSED_W wide) with the title bar and the "make it big again" button. (Remembered for next time.)
function Window.setCollapsed(flag)
    Window.collapsed = flag
    Saved.set("collapsed", flag and "yes" or "no")
    for _, part in ipairs(barParts) do part:show(not flag) end
    for _, b in pairs(Window.tabs.buttons) do b:show(not flag) end -- (the tabs and the status do not fit in the small bar)
    Window.tabs.underline.hidden = flag or Window.active == nil or (Window.pages[Window.active] or {}).noTab == true
    if Window.status ~= nil then Window.status.hidden = flag end
    local narrow = flag and COLLAPSED_IN + FRAME_W < 200 -- (under 200 pixels the full title does not fit next to the X)
    pcall(function() Window.win:SetTitle(narrow and "TMR" or "Too Many Runes") end)
    Window.tabLine.hidden = flag
    Window.dash.hidden = flag
    for _, r in ipairs(Window.square) do r.hidden = not flag end
    pcall(function() Window.win:SetSize((flag and COLLAPSED_IN or (cw + side())) + FRAME_W, (flag and TOP or ch) + FRAME_H) end)
    placeMinButton()
    if flag then
        Window.clear:show(false)
        for _, p in pairs(Window.pages) do p.layer.hidden = true end
        Window.refreshPager()
    else
        Window.layout()
        Window.show(Window.active)
        Window.clear:show(Search.text ~= "")
    end
end

-- Once in a while (the clock, start.lua): notice the window being resized or moved.
-- (Only the place: the size is only ever changed by the plugin itself - its own resize handles, the side column, minimizing - so it is
-- known. Reading root.width here made the whole window jump for a moment now and then with the side column open: it sometimes read
-- 250 short, and the window was laid out again at that size - the corner dots flickering over the search box, 3.0.60 to 3.0.62.)
function Window.watch()
    local root = Window.win.root
    local okPos, x, y = pcall(function() return root.x, root.y end)
    if okPos and type(x) == "number" and type(y) == "number" and (x ~= Window.lastX or y ~= Window.lastY) then
        Window.lastX, Window.lastY = x, y
        Saved.set("win_x", math.floor(x)); Saved.set("win_y", math.floor(y))
    end
end

----------------------------------------------------------------
-- THE HOVER LABEL: one label for the whole window (the name of the picture under the mouse), shown just above that picture.
-- (One PrettyUI tooltip per picture cost about ten parts each, and a plugin may only have about 4,000.)
----------------------------------------------------------------
function Window.showHover(text, x, y, size)
    local h = Window.hover
    if h == nil then
        h = { bg = Kit.rect(content, 0, 0, 1, 1, Vector4.new(0.05, 0.04, 0.03, 0.92)), text = Kit.text(content, 0, 0, 10, LINE_H) }
        h.line = Kit.rect(content, 0, 0, 1, 1, FRAME_LINE)
        Window.hover = h
    end
    local w = math.ceil(textWidth(text)) + 14
    local lx = math.max(2, math.min(math.floor(x + size / 2 - w / 2), side() + cw - w - 2))
    local ly = y - LINE_H - 6
    if ly < 0 then ly = y + size + 4 end
    h.line:SetPos(lx - 1, ly - 1); h.line:SetSize(w + 2, LINE_H + 4)
    h.bg:SetPos(lx, ly); h.bg:SetSize(w, LINE_H + 2)
    h.text:SetPos(lx, ly + 1); h.text:SetSize(w, LINE_H)
    h.text.content = plain(text)
    for _, part in ipairs({ h.line, h.bg, h.text }) do part.hidden = false; pcall(function() part:MoveToFront() end) end
end
function Window.hideHover()
    local h = Window.hover
    if h ~= nil then h.line.hidden, h.bg.hidden, h.text.hidden = true, true, true end
end

----------------------------------------------------------------
-- RESIZING: drag any side or corner of the window to make it bigger or smaller (the bottom-right corner is marked with dots).
-- (PrettyUI's own edge resizing did not respond in the game, so the window does its own, the way PrettyUI drags things: pressing a
-- handle starts it; while the button is held, that handle covers the whole screen so it keeps getting the mouse, and the size follows the
-- mouse until the button is let go.) The left and top handles also move the window: the window's own dragging does not notice a move made
-- this way (3.0.34: the window could not be dragged after a reset), so when one of those is let go the window is folded and opened again,
-- which puts it right.
----------------------------------------------------------------
local GRIP, EDGE, SMALL = 18, 6, 8 -- (corner, side and top-corner sizes: the top corners stay small to keep clear of the X)
-- { name, dx, dy }: dx = 1 drags the right side, -1 the left side; dy = 1 the bottom, -1 the top
local HANDLES = { { "br", 1, 1 }, { "bl", -1, 1 }, { "tr", 1, -1 }, { "tl", -1, -1 }, { "r", 1, 0 }, { "l", -1, 0 }, { "b", 0, 1 }, { "t", 0, -1 } }
Window.grips = {}
for _, hd in ipairs(HANDLES) do
    local g = ui.Layer.new(gameArea())
    pcall(function() g.clickthrough = false end)
    Window.grips[#Window.grips + 1] = { layer = g, name = hd[1], dx = hd[2], dy = hd[3] }
end
Window.grip = Window.grips[1].layer
-- The dots in the bottom-right corner: on a small layer of their own on the game screen (like the handles), kept on the window's
-- corner every frame. (As parts of the window itself they jumped about 250 to the left now and then while the side column was open,
-- 3.0.60 to 3.0.63, even when nothing moved them.)
local DOTS = 20
Window.gripDots = {}
pcall(function()
    Window.dotLayer = ui.Layer.new(gameArea())
    Window.dotLayer:SetSize(DOTS, DOTS)
    pcall(function() Window.dotLayer.clickthrough = true end)
    for k, d in ipairs({ { 6, 6 }, { 10, 6 }, { 6, 10 }, { 14, 6 }, { 10, 10 }, { 6, 14 } }) do
        Window.gripDots[k] = { dx = d[1], dy = d[2], rect = Kit.rect(Window.dotLayer, DOTS - d[1] - 2, DOTS - d[2] - 2, 2, 2, Vector4.new(0.91, 0.84, 0.69, 0.9)) }
    end
end)

local drag = nil
local function mouse() -- (the mouse in interface units: the screen position divided by the interface scale)
    local m = try(Mouse.GetPosition)
    if m == nil then return nil end
    local percent = try(function() return tonumber(game.options.InterfaceScale.setting) end)
    local scale = (type(percent) == "number" and percent > 0) and percent / 100 or 1
    return m.x / scale, m.y / scale
end

-- Where each handle goes on the window's border: x, y, w, h.
local function handleRect(name, x, y, w, h)
    if name == "br" then return x + w - GRIP, y + h - GRIP, GRIP, GRIP end
    if name == "bl" then return x, y + h - GRIP, GRIP, GRIP end
    if name == "tr" then return x + w - SMALL, y, SMALL, SMALL end
    if name == "tl" then return x, y, SMALL, SMALL end
    if name == "r" then return x + w - EDGE, y + SMALL, EDGE, h - SMALL - GRIP end
    if name == "l" then return x, y + SMALL, EDGE, h - SMALL - GRIP end
    if name == "b" then return x + GRIP, y + h - EDGE, w - 2 * GRIP, EDGE end
    return x + SMALL, y, w - 2 * SMALL, EDGE -- "t"
end

function Window.innerSize() return cw, ch end -- (the inside of the window, frame left out)

function Window.placeGrip()
    if drag ~= nil then return end
    local root = Window.win.root
    local hide = Window.collapsed or Window.closed or Window.starting
    for _, g in ipairs(Window.grips) do g.layer.hidden = hide end
    if Window.dotLayer ~= nil then Window.dotLayer.hidden = hide end
    if hide then return end
    local okSize, x, y = pcall(function() return root.x, root.y end)
    if not okSize or type(x) == "nil" or type(y) ~= "number" or type(x) ~= "number" then return end
    -- (the size is the one the window was given, not root.width: with the side column, root.width now and then read 250 short, and the
    -- corner dots flickered over to the search box - 3.0.60)
    local w, h = cw + side() + FRAME_W, ch + FRAME_H
    for _, g in ipairs(Window.grips) do
        local gx, gy, gw, gh = handleRect(g.name, x, y, w, h)
        pcall(function() g.layer:SetPos(gx, gy); g.layer:SetSize(math.max(1, gw), math.max(1, gh)); g.layer:MoveToFront() end)
    end
    Window.placeDots(x, y, w, h)
    pcall(function() Window.dotLayer:MoveToFront() end) -- (above the window, which comes to the front when it is clicked)
end
-- Put the corner dots on the window's bottom-right corner (x, y: the window's place; w, h: its size). Only moved when that changed.
function Window.placeDots(x, y, w, h)
    if Window.dotLayer == nil then return end
    local key = x .. "," .. y .. "," .. w .. "," .. h
    if Window.dotsAt == key then return end
    Window.dotsAt = key
    pcall(function() Window.dotLayer:SetPos(x + w - DOTS, y + h - DOTS) end)
end
-- Every frame: keep the dots on the corner while the window is dragged about.
function Window.followDots()
    if Window.dotLayer == nil or Window.dotLayer.hidden then return end
    local ok, x, y = pcall(function() return Window.win.root.x, Window.win.root.y end)
    if ok and type(x) == "number" and type(y) == "number" then Window.placeDots(x, y, cw + side() + FRAME_W, ch + FRAME_H) end
end

local function dragMove()
    local mx, my = mouse()
    if drag == nil or mx == nil then return end
    local sw, sh = screenSize()
    local w, h, x, y = cw, ch, drag.x, drag.y
    if drag.dx == 1 then w = drag.w + (mx - drag.mx) elseif drag.dx == -1 then w = drag.w - (mx - drag.mx) end
    if drag.dy == 1 then h = drag.h + (my - drag.my) elseif drag.dy == -1 then h = drag.h - (my - drag.my) end
    w, h = math.max(WINDOW_MIN_W, math.floor(w)), math.max(WINDOW_MIN_H, math.floor(h))
    if drag.dx == -1 then w = math.min(w, drag.w + drag.x); x = drag.x + drag.w - w end -- (the right side stays put; not past the screen's left)
    if drag.dy == -1 then h = math.min(h, drag.h + drag.y); y = drag.y + drag.h - h end
    if drag.dx == 1 and sw > 0 then w = math.min(w, math.max(WINDOW_MIN_W, sw - x - FRAME_W - side())) end
    if drag.dy == 1 and sh > 0 then h = math.min(h, math.max(WINDOW_MIN_H, sh - y - FRAME_H)) end
    if w ~= cw or h ~= ch then
        cw, ch = w, h
        pcall(function() Window.win:SetSize(cw + side() + FRAME_W, ch + FRAME_H) end)
        Window.placeDots(x, y, cw + side() + FRAME_W, ch + FRAME_H) -- (the corner dots follow while dragging)
        if drag.dx == -1 or drag.dy == -1 then
            pcall(function() Window.win.root:SetPos(x, y) end)
            drag.movedWindow = true
        end
        drag.moved = true
    end
    if drag.moved and tickCount - (drag.laidOut or 0) >= 4 then -- (the contents follow about 12 times a second while dragging)
        drag.laidOut, drag.moved = tickCount, false
        Window.layout()
    end
end
local function dragEnd()
    if drag == nil then return true end
    local movedWindow = drag.movedWindow
    drag = nil
    Saved.set("win_w", cw); Saved.set("win_h", ch)
    if movedWindow then
        -- (fold and open again: the window's own dragging then knows where it is - see above)
        Window.setCollapsed(true)
        Window.setCollapsed(false)
    else
        Window.layout()
    end
    Window.placeGrip()
    return false
end
for _, g in ipairs(Window.grips) do
    pcall(function()
        g.layer:Subscribe(ui.Hook.ONCLICK, function()
            local mx, my = mouse()
            if mx == nil or Window.collapsed or drag ~= nil then return true end
            local x, y = nil, nil
            pcall(function() x, y = Window.win.root.x, Window.win.root.y end)
            if type(x) ~= "number" then x = Window.lastX or 0 end
            if type(y) ~= "number" then y = Window.lastY or 0 end
            drag = { mx = mx, my = my, w = cw, h = ch, x = x, y = y, dx = g.dx, dy = g.dy, handle = g }
            return false
        end)
        g.layer:Subscribe(ui.Hook.ONHOLD, function()
            if drag == nil or drag.handle ~= g then return true end
            if not drag.expanded then -- (cover the whole screen while the button is held)
                drag.expanded = true
                pcall(function() g.layer:SetPos(0, 0); g.layer:SetSize(0, 0, 1.0, 1.0); g.layer:MoveToFront() end)
            end
            dragMove()
            return false
        end)
        g.layer:Subscribe(ui.Hook.ONRELEASE, dragEnd)
        g.layer:Subscribe(ui.Hook.ONDRAGCOMPLETE, dragEnd)
    end)
end
-- The game sends "held" less often than it draws, so while dragging the window's size also follows the mouse every frame.
pcall(function()
    Event.Draw.Subscribe("tmr3_resize", function()
        if Window == nil then return end -- (the plugin was switched off)
        if drag == nil then pcall(Window.followDots) return end
        pcall(dragMove)
    end)
end)

-- Open or close the side panel's column (px wide; 0 = closed). The window grows (or shrinks) on its LEFT side, so what is in it stays
-- where it was on the screen; moving the window like that needs the fold-and-open-again of dragEnd (see above) for its dragging.
-- keepPlace = true (at start-up: the saved place already has the column in it): the window only gets wider.
function Window.setSide(px, keepPlace)
    px = math.max(0, math.floor(px or 0))
    local before = Window.sideW or 0
    if px == before then return end
    Window.sideW = px
    if Window.collapsed then return end -- (it is put right when the window is opened again)
    local ok, x, y = pcall(function() return Window.win.root.x, Window.win.root.y end)
    pcall(function() Window.win:SetSize(cw + px + FRAME_W, ch + FRAME_H) end)
    if ok and type(x) == "number" and type(y) == "number" and not keepPlace then
        local nx = math.max(0, x - (px - before))
        if nx ~= x then
            pcall(function() Window.win.root:SetPos(nx, y) end)
            Window.setCollapsed(true)
            Window.setCollapsed(false)
            return
        end
    end
    Window.layout()
    Window.placeGrip()
end

-- Back to the starting size (WINDOW_W x WINDOW_H in settings.lua), opened and not minimized: the button on the Plugins window page.
function Window.resetSize()
    if Window.collapsed then Window.setCollapsed(false) end
    cw, ch = WINDOW_W, WINDOW_H
    Saved.set("win_w", cw); Saved.set("win_h", ch)
    pcall(function() Window.win:SetSize(cw + side() + FRAME_W, ch + FRAME_H) end)
    Window.layout()
    Window.reopen()
    Window.placeGrip()
end

function Window.reopen()
    pcall(function() Window.win:Show() end)
    Window.closed = false
end

function Window.shutdown()
    pcall(function() if Ribbon ~= nil then Ribbon.shutdown() end end)
    for _, g in ipairs(Window.grips or {}) do pcall(function() g.layer:Destroy() end) end
    pcall(function() Window.dotLayer:Destroy() end)
    pcall(function() Window.win:Destroy() end)
    Window.win = nil
end

end }
