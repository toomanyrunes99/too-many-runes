-- Too Many Runes - The window
-- One PrettyUI window:
--   title bar      "Too Many Runes", with the loading / item count at its left
--   tab row        one tab per page (pages/ folder), Settings and Help at the right end (the minimize button is on the title bar)
--   page area      the open tab's page
--   bottom bar     view, page arrows and the search box - shared by every tab
-- The window can be dragged bigger or smaller by its corner; everything is placed again to fit, and the size and place are remembered.
--
-- A PAGE (one tab) is a table:  { key =, label =, build = function(layer), layout = function(w, h), refresh = function(newSearch),
--   pageInfo = function() return page, pages end (optional), goTo = function(n) (optional), tick = function() (optional) }
-- and is added with Window.addPage(page). refresh is called whenever the search, the filter or the view changes.
return { run = function(T)
local _ENV = T

Window = { pages = {}, order = {}, active = nil, collapsed = false, closed = false }

local FRAME_W, FRAME_H = 16, 40  -- PrettyUI's frame round the inside of a window (32 of the 40 are the title bar)
-- (the tab row is 42 high with the game's tab pictures at PrettyUI's size - MAIN_TAB_STYLE "big", settings.lua)
local MAIN_STYLE = (MAIN_TAB_STYLE ~= nil and Kit.gameTabsReady()) and MAIN_TAB_STYLE or nil
local PAD, TAB_H, BAR_H = 6, (MAIN_STYLE == "big") and 42 or 28, 36
local TOP = TAB_H + 10           -- where the page area starts (under the tabs and their line; 3.2.17: lower when the top row wraps)
local BASE_TOP = TOP
Window.TAB_H, Window.TOP = TAB_H, TOP -- (pages/recent.lua lines up with them)
-- (3.2.47: as wide as the item details column above it - DETAILS_W, which it is at every window size the plugin allows; it was 250)
local SEARCH_W = DETAILS_W or 310
local COLLAPSED_IN = math.max(60, COLLAPSED_W or 100) - FRAME_W -- the inside width while minimized (COLLAPSED_W in settings.lua)

-- THE VIEWS of an item list (the second dropdown)
-- (the icon sizes only, by name: a rows view did not fit the look. A saved "rows" starts on VIEW_DEFAULT.)
VIEWS = { { id = "icons:16", label = "Icons: Tiny" }, { id = "icons:32", label = "Icons: Small" },
          { id = "icons:48", label = "Icons: Medium" }, { id = "icons:64", label = "Icons: Large" } }
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
local startSide = (Saved.get("recent_open") == "yes" and START_MINIMIZED == false and Saved.get("collapsed") ~= "yes") and (RECENT_W or 250) or 0
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
        useNativeTransparency = false, -- (the plugin follows the game's transparency itself - Window.applySeeThrough)
    })
    Window.lastX, Window.lastY = x, y
end

-- THE WINDOW'S SEE-THROUGH BACKGROUND (only the game's own transparency, without PrettyUI's). The game keeps the player's interface
-- transparency in TOPLEVEL_V2_TRANSPARENCY (0 - 255: how see-through) and tells plugins when it changes (Event.VarTransmit), so the
-- window's background follows it at once. Window.seeThrough: on or off (the Settings page; saved as "see_through").
local TRANSPARENCY_VAR = "TOPLEVEL_V2_TRANSPARENCY"
Window.seeThrough = (Saved.get("see_through") or ((WINDOW_SEE_THROUGH ~= false) and "on" or "off")) == "on"
function Window.gameAlpha()
    local v = nil
    pcall(function() v = var.VarPlayer[TRANSPARENCY_VAR].value end)
    if type(v) ~= "number" then return nil end
    return math.max(0.1, math.min(1, 1 - v / 255))
end
function Window.applySeeThrough(flag)
    if flag ~= nil then Window.seeThrough = (flag == true) end
    local alpha = Window.seeThrough and (Window.gameAlpha() or 1) or 1
    pcall(function() Window.win.background.alpha = alpha end)
    return true
end
pcall(Window.applySeeThrough)
pcall(function()
    Event.VarTransmit.Subscribe("tmr3_see_through", function(ev)
        if Window == nil then return end -- (the plugin was switched off)
        if Window.win ~= nil and field(ev.var, "configName") == TRANSPARENCY_VAR then pcall(Window.applySeeThrough) end
    end)
end)
-- The whole window stays hidden while the files load (one a frame) and is shown once it is laid out (start.lua): otherwise the parts show
-- in the top left corner for a moment at start-up.
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
    elseif Shelves ~= nil and Shelves.ready and Shelves.where() ~= nil then
        text = Shelves.where() .. " (" .. withCommas(#Filters.current()) .. ")" -- (3.2.17: the open tab, "Artisan > Smithing (1,001)")
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
    elseif Items.loaded and not Search.active and Filters.key == "all" and Window.active == "search"
           and not (Shelves ~= nil and Shelves.ready and Shelves.where() ~= nil) then
        -- once everything is read: how many the hide switches leave out (noted, broken, junk ... - the Settings page)
        local hidden = Items.count() - #Filters.current()
        if hidden > 0 then Window.setStatus({ text .. " (" .. withCommas(hidden) .. " items hidden)", text }) else Window.setStatus({ text }) end
    else
        Window.setStatus({ text })
    end
end

----------------------------------------------------------------
-- THE TAB ROW
----------------------------------------------------------------
-- The same as the details tabs (ui/details.lua): a thin line under the tabs, with the tab pictures cut off at it (ui/kit.lua,
-- Kit.gameTab) - the line at 39 of the pictures' 60.
local LINE_AT = (MAIN_STYLE ~= nil) and (2 + math.floor(math.floor(60 * TAB_H / 42 + 0.5) * 39 / 60 + 0.5)) or (TAB_H + 4) -- (2: the row's top)
Window.tabs = Kit.tabStrip(content, TAB_H, function(key) Window.show(key) end, MAIN_STYLE)
if MAIN_STYLE ~= nil then Window.tabs.cut = LINE_AT - 2 end
Window.tabLine = Kit.rect(content, PAD, LINE_AT, 10, 1, FRAME_LINE)
local BASE_LINE = LINE_AT
-- (3.2.17) Window.topRow: a page's own row of tabs in the top row, in place of the pages' tabs - the item list's groups, pages/item_search.lua.
-- topRow.place(x, y, w) puts it there and says how many lines it took; a second line moves the line under the row and the pages down.
Window.TOP_ROW_LINE = 28 -- (one line of the row: a 24-high button and the gap under it)

-- Minimize: the developer's icon (MIN_SPRITE, settings.lua), on the title bar left of the X. It is inside the window, placed like
-- PrettyUI's own X - measured from the window's right edge - so it moves and resizes with the window by itself.
-- Why a click on it could drag the window (from PrettyUI's source, which its developer lets AI read, not change): the title bar is dragged
-- by a see-through layer of its own in front of the window (window.titleDrag, 32 high), from the left edge to 34 short of the right edge -
-- up to the X, which is why the X can be clicked. Window.fitTitleDrag cuts that layer short of this button too. PrettyUI puts the layer
-- back to its own length after every drag and every size change, and right after that it has the parts registered with the window (its
-- "overlays": its own scrollbar is one) put themselves right; this button is registered, so it cuts the layer again at once. (That is
-- PrettyUI's internal _RegisterOverlay: if a later PrettyUI has none, the layer's length is checked every frame instead, Window.followDots'
-- frame handler.) If the window cannot hold the button, it goes to the right end of the tab row.
-- (PrettyUI's X is 20 wide, 8 from the right edge and 7 down. The minimize button is the same size - 20 by 20 - level with the X, 6 left of
-- it.)
local MIN_SIZE = 20
local MIN_X, MIN_Y = -54, 7 -- (from the right edge: 8 + 20 (the X) + 6 + 20; the X's top)
local TITLE_H = 32          -- (PrettyUI's title bar)
local DRAG_CUT = 60         -- (the drag layer stops this far from the right edge: 6 short of this button, as PrettyUI's stops 6 short of the X)
local MIN_PICS = { normal = MIN_SPRITE or 24420, w = MIN_SIZE, h = MIN_SIZE }
local minInTitle = false
local function toggleCollapsed() Window.setCollapsed(not Window.collapsed) end
minInTitle = pcall(function()
    Window.minButton = Kit.picture(Window.win.root, MIN_PICS, toggleCollapsed)
    Window.minButton.sprite:SetPos(MIN_X, MIN_Y, 1.0)
end)
if not minInTitle then
    if Window.minButton ~= nil then pcall(function() Window.minButton.sprite:Destroy() end) end
    Window.minButton = Kit.picture(content, MIN_PICS, toggleCollapsed)
end
pcall(function() Window.minButton.sprite.clickthrough = false end)
-- Cut PrettyUI's title-bar drag layer short of the minimize button (not while the window is being dragged: the layer then covers the whole
-- screen, so the mouse is not lost).
local function dragSizes(win, t) return win.root.width, t.height end
local function dragWidth(t) return t.width end
function Window.fitTitleDrag()
    local win = Window.win
    local t = (win ~= nil and minInTitle) and win.titleDrag or nil
    if t == nil or win.dragFeedback ~= nil then return end
    local okW, w, h = pcall(dragSizes, win, t) -- (no new function each frame)
    if type(h) == "number" and h > TITLE_H + 1 then return end
    if not (okW and type(w) == "number" and w > 0) then w = (Window.collapsed and COLLAPSED_IN or (cw + side())) + FRAME_W end
    local want = math.max(1, math.floor(w - DRAG_CUT))
    local okN, now = pcall(dragWidth, t)
    if okN and now == want then return end
    pcall(function() t:SetSize(want, TITLE_H) end)
end
Window.dragFitBySync = minInTitle and pcall(function()
    Window.win:_RegisterOverlay(Window.minButton.sprite, nil, Window.fitTitleDrag)
end)
pcall(Window.fitTitleDrag)
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
-- The Help and Settings buttons at the right end of the tab row (the minimize button too, when it is not on the title bar).
local function placeTopButtons()
    local inner = Window.collapsed and COLLAPSED_IN or (cw + side())
    local x, y = inner - PAD - 22, (TAB_H > 28) and (2 + (TAB_H - 22) // 2) or 3 -- (in the middle of a taller tab row)
    if minInTitle then
        Window.helpButton:place(x, y)
        Window.settingsButton:place(x - 4 - SETTINGS_W, y)
    else
        Window.minButton:place(x, y)
        Window.helpButton:place(x - 4 - 22, y)
        Window.settingsButton:place(x - 8 - 22 - SETTINGS_W, y)
    end
end

----------------------------------------------------------------
-- THE BOTTOM BAR (shared by every tab)
----------------------------------------------------------------
local function numbered(list, labelOf, idOf)
    local entries = {}
    for k, e in ipairs(list) do entries[k] = { label = labelOf(e), id = idOf(e) } end
    return entries
end
-- (3.2.47: the filter dropdown beside the search box is gone - All and Favorites are tabs above the list, pages/item_search.lua)
Window.view = Kit.dropdown(content, numbered(VIEWS, function(v) return v.label end, function(v) return v.id end),
    View.current, function(v) Window.setView(v) end, true, 22, 60) -- (as narrow as its words allow)

Window.prev = Kit.picture(content, PAGER_ICONS.prev, function() Window.turn(-1) end)
Window.next = Kit.picture(content, PAGER_ICONS.next, function() Window.turn(1) end)
Window.pageText = Kit.text(content, 0, 0, 120, 22)

Window.search = Kit.input(content, SEARCH_W, 28, "")
Window.search:show(false) -- (until the first Window.layout puts it in place: otherwise it sits in the top left corner at start-up)
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
local HINT_HOLD, HINT_FADE = 140, 20 -- (in game ticks, 50 a second: shown for about 3 seconds, then 0.4 s out and 0.4 s in)
local function hintEase(x) return x * x * (3 - 2 * x) end -- (starts and ends gently: a smoother fade than a straight line)
local hintShown, hintAlpha = false, nil -- (what the hint's parts were last set to: only a change is passed on to the game)
function Window.tickHint()
    local show = Search.text == "" and not Window.collapsed
    if show ~= hintShown then
        hintShown = show
        Window.hint.hidden = not show
        Window.hintLabel.hidden = not show
    end
    if not show then return end
    hintTick = hintTick + 1
    local t = hintTick % (HINT_HOLD + 2 * HINT_FADE)
    local alpha = 1
    if t >= HINT_HOLD and t < HINT_HOLD + HINT_FADE then alpha = 1 - hintEase((t - HINT_HOLD) / HINT_FADE)
    elseif t >= HINT_HOLD + HINT_FADE then
        if t == HINT_HOLD + HINT_FADE then hintAt = hintAt % #HINTS + 1; Window.hint.content = HINTS[hintAt] end
        alpha = hintEase((t - HINT_HOLD - HINT_FADE) / HINT_FADE)
    end
    if alpha ~= hintAlpha then
        hintAlpha = alpha
        pcall(function() Window.hint.alpha = alpha end)
    end
end
Window.search.onChange = function(text)
    if text == (Search.pending or Search.text) then return end -- (the box also reports when it loses focus, with the same text)
    Search.runSoon(text) -- (once the typing stops: core/search.lua)
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

local barParts = { Window.view, Window.prev, Window.next, Window.search, Window.helpButton, Window.settingsButton }

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
    local right = side() + cw - PAD - SEARCH_W - 4
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
    elseif page.inOrder then -- (3.2.17: Item search has no tab - its groups' tabs are the top row - but is still the page to go back to)
        Window.order[#Window.order + 1] = page.key
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

-- The view dropdown changed (the icon size).
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
    local rowX = sx + PAD + (Window.tabsInset or 0) -- (tabsInset: room for the Recently viewed arrow, pages/recent.lua)
    Window.tabs:place(rowX, 2)
    -- (3.2.17) a page's own row of tabs (Window.topRow), from the arrow to the Settings button; more lines push the pages down
    local extra = 0
    if Window.topRow ~= nil then
        local right = (cw + sx) - PAD - 22 - (minInTitle and (4 + SETTINGS_W) or (8 + 22 + SETTINGS_W)) - 8
        local y = 2 + math.max(0, (BASE_LINE - 2 - 24) // 2)
        local ok, lines = pcall(Window.topRow.place, rowX, y, math.max(60, right - rowX))
        if ok and type(lines) == "number" and lines > 1 then extra = (lines - 1) * Window.TOP_ROW_LINE end
    end
    TOP, LINE_AT = BASE_TOP + extra, BASE_LINE + extra
    Window.TOP = TOP
    Window.tabLine:SetPos(PAD, LINE_AT) -- (the gold line runs across the side column too)
    Window.tabLine:SetSize(sx + cw - 2 * PAD, 1)
    placeTopButtons()
    local y = ch - BAR_H + 4
    Window.view:place(sx + PAD, y)
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

-- THE RUNE ICON. Minimized, the window is put away and a rune icon is left where its minimize button was; a click on it opens the window
-- again. It goes through the runes of ICON_RUNES (settings.lua) in a random order, each one melting into the next, and holds still while
-- the mouse is over it (with the item pictures' outline round it and "Too Many Runes" under it). It can be dragged about (pressed and
-- moved), and where it was put is remembered. The gold close button at its top right (picture 10805 turned 45 degrees) closes the plugin
-- as the window's X does. The first rune is put on as soon as the icon shows (no flicker of the minimize button's picture on a reload).
-- (On the game screen, like the resize handles: one layer holds the pictures, a see-through one in front of it takes the clicks.)
local ICON = 48       -- the icon's size
local ICON_CLOSE = 25 -- the close button's size
pcall(function() math.randomseed(os.time()) end) -- (a different order every start)
-- A random place in a list of n, not the one at 'not' (in turn, if the game has no random numbers).
local function randomRune(n, notAt)
    local ok, r = pcall(function()
        if notAt == nil or n < 2 then return math.random(n) end
        local k = math.random(n - 1)
        return (k >= notAt) and k + 1 or k
    end)
    if ok and type(r) == "number" then return r end
    return (notAt or 0) % n + 1
end
local ICON_CLOSE_AT = { 40, 5 } -- (where the close button's middle is, from the icon's top left: on the rune's top right edge)
local ICON_CLOSE_COLOUR = Vector4.new(1, 0.8, 0.25, 1) -- (gold: the game tints the picture with it)
local ICON_HOLD, ICON_FADE = 100, 25 -- (clock ticks, 50 a second: each rune 2 seconds, then half a second melting into the next)
pcall(function()
    local L = ui.Layer.new(gameArea())
    L:SetSize(ICON, ICON)
    L.clickthrough = true
    local ic = { layer = L, a = Kit.itemIcon(L, ICON, ICON), b = Kit.itemIcon(L, ICON, ICON), fallback = Kit.itemIcon(L, ICON, ICON), t = 0 }
    for _, s in ipairs({ ic.a, ic.b, ic.fallback }) do pcall(function() s.clickthrough = true end) end
    pcall(function() ic.fallback.spriteID = MIN_SPRITE or 24420 end)
    ic.cur, ic.nxt = ic.a, ic.b
    local H = ui.Layer.new(gameArea())
    H:SetSize(ICON, ICON)
    H.clickthrough = false
    H:Subscribe(ui.Hook.ONCLICK, function() return Window.iconPress() end) -- (these four: below, with the resize handles' dragging)
    H:Subscribe(ui.Hook.ONHOLD, function() return Window.iconHold() end)
    H:Subscribe(ui.Hook.ONRELEASE, function() return Window.iconRelease() end)
    H:Subscribe(ui.Hook.ONDRAGCOMPLETE, function() return Window.iconRelease() end)
    H:Subscribe(ui.Hook.ONMOUSEOVER, function() Window.iconHover = true; Window.iconLabel(true); Window.iconOutline(true); return true end)
    H:Subscribe(ui.Hook.ONMOUSELEAVE, function() Window.iconHover = false; Window.iconLabel(false); Window.iconOutline(false); return true end)
    ic.hit = H
    L.hidden, H.hidden = true, true
    Window.icon = ic
end)
-- the close button (the window's X does the same: Window.closed, and the plugin's ribbon button opens it again, big)
pcall(function()
    local ic = Window.icon
    ic.close = Kit.picture(gameArea(), { normal = 10805, w = ICON_CLOSE, h = ICON_CLOSE, rotate = 45 }, function()
        Window.showIcon(false)
        Window.closed = true
        pcall(function() Window.win:Close() end)
    end)
    pcall(function() ic.close.sprite.colour = ICON_CLOSE_COLOUR; ic.close.sprite.clickthrough = false end)
    ic.close:show(false)
end)
-- the name under it
pcall(function()
    local ic = Window.icon
    local label = "Too Many Runes"
    ic.label = { line = Kit.rect(gameArea(), 0, 0, 1, 1, FRAME_LINE), bg = Kit.rect(gameArea(), 0, 0, 1, 1, Vector4.new(0.05, 0.04, 0.03, 0.92)),
                 text = Kit.text(gameArea(), 0, 0, 10, LINE_H), w = math.ceil(textWidth(label)) + 14 }
    ic.label.text.content = label
    for _, part in ipairs({ ic.label.line, ic.label.bg, ic.label.text }) do part.hidden = true end
end)
-- The name under the icon, while the mouse is over it (above it when there is no room below).
function Window.iconLabel(flag)
    local ic = Window.icon
    if ic == nil or ic.label == nil then return end
    local lb = ic.label
    pcall(function()
        if flag and ic.x ~= nil then
            local sw, sh = screenSize()
            local lx = math.floor(ic.x + ICON / 2 - lb.w / 2)
            if sw > 0 then lx = math.max(0, math.min(lx, sw - lb.w)) end
            local ly = ic.y + ICON + 4
            if sh > 0 and ly + LINE_H + 4 > sh then ly = ic.y - LINE_H - 6 end
            lb.line:SetPos(lx - 1, ly - 1); lb.line:SetSize(lb.w + 2, LINE_H + 4)
            lb.bg:SetPos(lx, ly); lb.bg:SetSize(lb.w, LINE_H + 2)
            lb.text:SetPos(lx, ly + 1); lb.text:SetSize(lb.w, LINE_H)
        end
        for _, part in ipairs({ lb.line, lb.bg, lb.text }) do
            part.hidden = not flag
            if flag then part:MoveToFront() end
        end
    end)
end
-- Put the icon at x, y (kept on the screen, with room for the close button), its close button with it. While it is being dragged the click
-- layer stays where it is (it covers the whole screen then).
function Window.placeIcon(x, y, dragging)
    local ic = Window.icon
    if ic == nil then return end
    local sw, sh = screenSize()
    local overRight = math.max(0, math.ceil(ICON_CLOSE_AT[1] + ICON_CLOSE / 2 - ICON)) -- (how far the close button reaches past the icon)
    local overTop = math.max(0, math.ceil(ICON_CLOSE / 2 - ICON_CLOSE_AT[2]))
    if sw > 0 then x = math.max(0, math.min(x, sw - ICON - overRight)) end
    if sh > 0 then y = math.max(overTop, math.min(y, sh - ICON)) end
    x, y = math.floor(x), math.floor(y)
    ic.x, ic.y = x, y
    pcall(function()
        ic.layer:SetPos(x, y)
        local cx, cy = math.floor(x + ICON_CLOSE_AT[1] - ICON_CLOSE / 2), math.floor(y + ICON_CLOSE_AT[2] - ICON_CLOSE / 2)
        ic.close:place(cx, cy)
        if not dragging then ic.hit:SetPos(x, y); ic.hit:SetSize(ICON, ICON) end
    end)
end
-- Show or put away the icon: shown where it was last put, or else with its middle where the minimize button's middle is.
function Window.showIcon(flag)
    local ic = Window.icon
    if ic == nil then return end
    pcall(function() ic.layer.hidden = not flag; ic.hit.hidden = not flag end)
    pcall(function() ic.close:show(flag) end)
    if not flag then Window.iconHover = false; Window.iconLabel(false); Window.iconOutline(false); return end
    local ix, iy = Saved.num("icon_x"), Saved.num("icon_y")
    if ix == nil or iy == nil then
        local ok, x, y = pcall(function() return Window.win.root.x, Window.win.root.y end)
        if not (ok and type(x) == "number" and type(y) == "number") then x, y = Window.lastX or 0, Window.lastY or 0 end
        ix, iy = x + cw + side() + FRAME_W - 44 - ICON / 2, y + 17 - ICON / 2 -- (the minimize button's middle: 44 in from the right edge, 17 down)
    end
    Window.placeIcon(ix, iy)
    pcall(function()
        ic.layer:MoveToFront(); ic.hit:MoveToFront(); ic.close.sprite:MoveToFront()
    end)
    Window.firstRune()
    pcall(function() ic.fallback.hidden = ic.at ~= nil end)
end
-- The item pictures' outline on the rune while the mouse is over it (HOVER_OUTLINE, as in the item grid).
function Window.iconOutline(flag)
    local ic = Window.icon
    if ic == nil then return end
    Kit.itemOutline(ic.a, flag); Kit.itemOutline(ic.b, flag)
end
-- The first rune, at once (no list: the minimize button's picture stays).
function Window.firstRune()
    local ic, runes = Window.icon, ICON_RUNES
    if ic == nil or ic.at ~= nil or type(runes) ~= "table" or #runes == 0 then return end
    ic.at, ic.t = randomRune(#runes), 0
    Kit.setItem(ic.cur, runes[ic.at])
    pcall(function() ic.cur.alpha = 1; ic.cur.hidden = false; ic.fallback.hidden = true end)
end
-- Every clock tick while minimized: the next rune melts in.
local function ease(x) return x * x * (3 - 2 * x) end
function Window.tickIcon()
    local ic = Window.icon
    if ic == nil or not Window.collapsed or Window.closed then return end
    local runes = ICON_RUNES
    if type(runes) ~= "table" or #runes == 0 then return end -- (no list: the minimize button's picture stays)
    if ic.at == nil then Window.firstRune() return end
    if #runes < 2 or (Window.iconHover and ic.t < ICON_HOLD - 10) then return end -- (held still under the mouse)
    ic.t = ic.t + 1
    if ic.t == ICON_HOLD - 10 then -- (the next one, unseen, a moment early, so its picture is ready)
        ic.nextAt = randomRune(#runes, ic.at)
        Kit.setItem(ic.nxt, runes[ic.nextAt])
        pcall(function() ic.nxt.alpha = 0; ic.nxt.hidden = false end)
    elseif ic.t >= ICON_HOLD then
        local e = ease(math.min(1, (ic.t - ICON_HOLD) / ICON_FADE))
        pcall(function() ic.nxt.alpha = e; ic.cur.alpha = 1 - e end)
        if ic.t >= ICON_HOLD + ICON_FADE then
            pcall(function() ic.cur.hidden = true end)
            ic.cur, ic.nxt = ic.nxt, ic.cur
            ic.at, ic.t = ic.nextAt, 0
        end
    end
end

-- Minimize: the window is put away and the rune icon left in its place (above). (Remembered for next time.)
function Window.setCollapsed(flag)
    Window.collapsed = flag
    Saved.set("collapsed", flag and "yes" or "no")
    for _, part in ipairs(barParts) do part:show(not flag) end
    for _, b in pairs(Window.tabs.buttons) do b:show(not flag) end -- (the tabs and the status do not fit in the small bar)
    Window.tabs.underline.hidden = flag or Window.active == nil or (Window.pages[Window.active] or {}).noTab == true or Window.tabs.style ~= nil
    if Window.status ~= nil then Window.status.hidden = flag end
    local narrow = flag and COLLAPSED_IN + FRAME_W < 200 -- (under 200 pixels the full title does not fit next to the X)
    pcall(function() Window.win:SetTitle(narrow and "TMR" or "Too Many Runes") end)
    Window.tabLine.hidden = flag
    if flag then -- (put away, not made small; its title bar's drag layer too, which is beside it on the game screen)
        pcall(function() Window.win.root.hidden = true end)
        pcall(function() Window.win.titleDrag.hidden = true end)
    else
        pcall(function() Window.win:SetSize(cw + side() + FRAME_W, ch + FRAME_H) end)
        if not Window.closed and not Window.starting then
            pcall(function() Window.win.root.hidden = false end)
            pcall(function() Window.win:Show() end)
        end
    end
    Window.showIcon(flag)
    placeTopButtons()
    if flag then
        Window.clear:show(false)
        for _, p in pairs(Window.pages) do p.layer.hidden = true end
        Window.refreshPager()
    else
        Window.layout()
        Window.show(Window.active)
        Window.clear:show(Search.text ~= "")
    end
    pcall(Window.placeGrip) -- (the resize handles go with the window at once)
end

-- Once in a while (the clock, start.lua): notice the window being resized or moved.
-- (Only the place: the size is only ever changed by the plugin itself - its own resize handles, the side column, minimizing - so it is
-- known. Reading root.width here would make the whole window jump for a moment now and then with the side column open: it sometimes reads
-- 250 short, and the window would be laid out again at that size, the corner dots flickering over the search box.)
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

-- --------------------------------------------------------------
-- RESIZING: drag any side or corner of the window to make it bigger or smaller (the bottom-right corner is marked with dots).
-- (PrettyUI's own edge resizing does not respond in the game, so the window does its own, the way PrettyUI drags things: pressing a handle
-- starts it; while the button is held, that handle covers the whole screen so it keeps getting the mouse, and the size follows the mouse
-- until the button is let go.) The left and top handles also move the window: the window's own dragging does not notice a move made this
-- way (it could not be dragged afterwards), so when one of those is let go the window is folded and opened again, which puts it right.
-- --------------------------------------------------------------
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
-- The dots in the bottom-right corner: on a small layer of their own on the game screen (like the handles), kept on the window's corner
-- every frame. (As parts of the window itself they jumped about 250 to the left now and then while the side column was open, even when
-- nothing moved them.)
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
    local hide = (Window.collapsed or Window.closed or Window.starting) == true
    if hide ~= Window.gripsHidden then
        Window.gripsHidden = hide
        for _, g in ipairs(Window.grips) do g.layer.hidden = hide end
        if Window.dotLayer ~= nil then Window.dotLayer.hidden = hide end
    end
    if hide then return end
    local okSize, x, y = pcall(function() return root.x, root.y end)
    if not okSize or type(x) == "nil" or type(y) ~= "number" or type(x) ~= "number" then return end
    -- (the size is the one the window was given, not root.width: with the side column, root.width now and then reads 250 short, and the
    -- corner dots would flicker over to the search box)
    local w, h = cw + side() + FRAME_W, ch + FRAME_H
    local at = Window.gripsAt -- (where they were put last: nil after a drag, which spread one over the whole screen)
    local moved = at == nil or at.x ~= x or at.y ~= y or at.w ~= w or at.h ~= h
    if moved then Window.gripsAt = { x = x, y = y, w = w, h = h } end
    for _, g in ipairs(Window.grips) do
        if moved then
            local gx, gy, gw, gh = handleRect(g.name, x, y, w, h)
            pcall(function() g.layer:SetPos(gx, gy); g.layer:SetSize(math.max(1, gw), math.max(1, gh)) end)
        end
        pcall(function() g.layer:MoveToFront() end) -- (still every time: the window comes to the front when it is clicked)
    end
    Window.placeDots(x, y, w, h)
    pcall(function() Window.dotLayer:MoveToFront() end) -- (above the window, which comes to the front when it is clicked)
end
-- Put the corner dots on the window's bottom-right corner (x, y: the window's place; w, h: its size). Only moved when that changed.
function Window.placeDots(x, y, w, h)
    if Window.dotLayer == nil then return end
    local px, py = x + w - DOTS, y + h - DOTS
    if Window.dotsX == px and Window.dotsY == py then return end
    Window.dotsX, Window.dotsY = px, py
    pcall(function() Window.dotLayer:SetPos(px, py) end)
end
-- Every frame: keep the dots on the corner while the window is dragged about. (The window's place is read without making a new function
-- each frame - those small scraps every frame add up - see main.lua, MEMORY.)
local function rootPlace() return Window.win.root.x, Window.win.root.y end
function Window.followDots()
    if Window.dotLayer == nil or Window.gripsHidden ~= false then return end -- (hidden: Window.placeGrip)
    local ok, x, y = pcall(rootPlace)
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
    Window.gripsAt = nil -- (the handle that was dragged covers the whole screen: every handle is put back)
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
-- Dragging the rune icon: a press starts it; once the mouse has moved 5 pixels it is a drag - the click layer covers the whole
-- screen while the button is held, as the handles' does - and the icon follows the mouse; let go, its place is remembered. A press let go
-- before that opens the window.
local iconDrag = nil
local function iconDragMove()
    local mx, my = mouse()
    local ic = Window.icon
    if iconDrag == nil or mx == nil or ic == nil then return end
    local dx, dy = mx - iconDrag.mx, my - iconDrag.my
    if not iconDrag.moving then
        if math.abs(dx) + math.abs(dy) < 5 then return end
        iconDrag.moving = true
        Window.iconLabel(false)
        pcall(function() ic.hit:SetPos(0, 0); ic.hit:SetSize(0, 0, 1.0, 1.0); ic.hit:MoveToFront() end)
    end
    Window.placeIcon(iconDrag.x + dx, iconDrag.y + dy, true)
end
function Window.iconPress()
    local mx, my = mouse()
    local ic = Window.icon
    if mx == nil or ic == nil or ic.x == nil then Window.setCollapsed(false); return false end
    iconDrag = { mx = mx, my = my, x = ic.x, y = ic.y }
    return false
end
function Window.iconHold()
    if iconDrag == nil then return true end
    iconDragMove()
    return false
end
function Window.iconRelease()
    if iconDrag == nil then return true end
    local moving = iconDrag.moving
    iconDrag = nil
    local ic = Window.icon
    if moving then
        Window.placeIcon(ic.x, ic.y) -- (the click layer back to the icon's size)
        Saved.set("icon_x", ic.x); Saved.set("icon_y", ic.y)
        pcall(function() ic.close.sprite:MoveToFront() end)
        if Window.iconHover then Window.iconLabel(true) end
    else
        Window.setCollapsed(false)
    end
    return false
end
-- The game sends "held" less often than it draws, so while dragging the window's size also follows the mouse every frame.
pcall(function()
    Event.Draw.Subscribe("tmr3_resize", function()
        if Window == nil then return end -- (the plugin was switched off)
        if iconDrag ~= nil then pcall(iconDragMove) end -- (the rune icon, the same way)
        if drag == nil then
            pcall(Window.followDots)
            if not Window.dragFitBySync then pcall(Window.fitTitleDrag) end -- (only when PrettyUI cannot tell the button: see Minimize)
            return
        end
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
    Window.closed = false
    if Window.collapsed then Window.setCollapsed(false) return end -- (minimized: the rune icon goes, the window comes back)
    pcall(function() Window.win:Show() end)
end

function Window.shutdown()
    pcall(function() if Ribbon ~= nil then Ribbon.shutdown() end end)
    for _, g in ipairs(Window.grips or {}) do pcall(function() g.layer:Destroy() end) end
    pcall(function() Window.dotLayer:Destroy() end)
    pcall(function() Window.icon.layer:Destroy(); Window.icon.hit:Destroy() end) -- (the rune icon is on the game screen too)
    pcall(function() Window.icon.close.sprite:Destroy() end)
    pcall(function() for _, part in pairs({ Window.icon.label.line, Window.icon.label.bg, Window.icon.label.text }) do part:Destroy() end end)
    pcall(function() Window.win:Destroy() end)
    Window.win = nil
end

end }
