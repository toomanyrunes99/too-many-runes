-- Too Many Runes - Recently viewed: a column on the left side of the window
-- The items you opened last, newest first (at most RECENT_MAX in settings.lua). The arrow at the top left of the window (left of the
-- tabs) opens and closes the column, and turns round with it. The window grows on its left side to make room (Window.setSide in
-- ui/window.lua), so the column is part of the window: under its title bar, moved, resized and minimized with it. The items show as
-- pictures or rows, the same as the item list (the Icons / Rows dropdown); the mouse wheel scrolls them a line at a time, with
-- "(scroll down: 12 more)" at the bottom - the same as a long Uses tab. A click opens the item in the Item search tab. Every item opened
-- in the window counts (a click in the list, a material, the game's right-click menu) except the ones opened from the column itself, so
-- the list does not jump about while you look through it. The list is saved like the favourites; the Settings page's reset keeps it (and
-- closes the column).
-- (3.0.58 and before: a tab of its own, "Recently viewed". 3.0.59: a panel of its own beside the window.)
return { run = function(T)
local _ENV = T

local MAX = RECENT_MAX or 128
local W = RECENT_W or 250
local ARROW = RECENT_ARROW or { sprite = 17040, w = 21, h = 21, flipWhenOpen = true }
local PAD, TAB_H, BAR_H, TOP = 6, 28, 36, 38 -- (the same as ui/window.lua)
local GAP = { [64] = 4, [48] = 3, [32] = 2, [16] = 2 }
local ROW_H, ICON = 34, 32
local BUTTON_PAD = 26 -- (a button keeps this much of its width free around its words: ui/details.lua)

Recent = { ids = {}, open = (Saved.get("recent_open") == "yes"), scroll = 0 }
for n in string.gmatch(Saved.get("recent") or "", "%d+") do
    if #Recent.ids < MAX then Recent.ids[#Recent.ids + 1] = tonumber(n) end
end

----------------------------------------------------------------
-- THE COLUMN (inside the window, on its left)
----------------------------------------------------------------
local content = Window.content
local col = ui.Layer.new(content)
col.hidden = true
local title = Kit.text(col, 0, 0, 10, TAB_H, "center")
title.content = "Recently Viewed"
local frame = Kit.frame(col)
local more = Kit.text(frame.inner, 0, 0, 10, LINE_H, "center")
local count = Kit.text(col, 0, 0, 10, 22, "center")
local cells = {} -- k -> { pic =, button = } (made when first needed; reused for whatever item is k-th on screen)
local shown = {} -- k -> the item number in cell k now
local lay = { mode = "icons", size = 32, cols = 1, rows = 1, maxScroll = 0 }

local function scrollBy(dir)
    if Recent.wheelTick == tickCount then return end -- (one notch reaches every part under the mouse: once a tick)
    Recent.wheelTick = tickCount
    local s = math.max(0, math.min((Recent.scroll or 0) + dir, lay.maxScroll or 0))
    if s ~= Recent.scroll then Recent.scroll = s; Recent.draw() end
end
Kit.wheel(frame.inner, scrollBy)

local function cell(k)
    local c = cells[k]
    if c ~= nil then return c end
    c = {}
    c.pic = Kit.itemIcon(frame.inner, ICON, ICON)
    Kit.wheel(c.pic, scrollBy)
    c.pic:Subscribe(ui.Hook.ONMOUSEOVER, function()
        pcall(function() c.pic.colour = HOVER_TINT end)
        local id = shown[k]
        if id ~= nil and lay.mode == "icons" and c.x ~= nil then
            local slot = Items.slotOf[id]
            if slot ~= nil then pcall(Window.showHover, Items.names[slot] .. " (" .. id .. ")", lay.ox + c.x, lay.oy + c.y, lay.size) end
        end
        return true
    end)
    c.pic:Subscribe(ui.Hook.ONMOUSELEAVE, function() pcall(function() c.pic.colour = WHITE end); pcall(Window.hideHover); return true end)
    c.pic:Subscribe(ui.Hook.ONCLICK, function() if shown[k] ~= nil then Recent.openItem(shown[k]) end return false end)
    cells[k] = c
    return c
end
local function cellButton(c, k, w)
    if c.button == nil then
        c.button = Kit.button(frame.inner, "", w, ICON, function() if shown[k] ~= nil then Recent.openItem(shown[k]) end end)
        Kit.wheel(c.button:root(), scrollBy)
        c.buttonW = w
    elseif c.buttonW ~= w then
        c.buttonW = w
        pcall(function() c.button.sb.root:SetSize(w, ICON) end)
    end
    return c.button
end

-- Draw the items from the scroll position (and the "more" line under them).
function Recent.draw()
    local ids = {}
    for _, n in ipairs(Recent.ids) do if Items.slotOf[n] ~= nil then ids[#ids + 1] = n end end
    local n = #ids
    local per = lay.cols
    lay.maxScroll = math.max(0, math.ceil(n / per) - lay.rows)
    Recent.scroll = math.max(0, math.min(Recent.scroll or 0, lay.maxScroll))
    local k = 0
    for r = 0, lay.rows - 1 do
        for c = 0, per - 1 do
            local id = ids[(Recent.scroll + r) * per + c + 1]
            if id == nil then break end
            k = k + 1
            local cl = cell(k)
            shown[k] = id
            if lay.mode == "icons" then
                cl.x, cl.y = lay.left + c * lay.step, lay.top + r * lay.step
                cl.pic:SetSize(lay.size, lay.size)
                cl.pic:SetPos(cl.x, cl.y)
                if cl.button then cl.button:show(false) end
            else
                cl.x, cl.y = lay.left, lay.top + r * ROW_H
                cl.pic:SetSize(ICON, ICON)
                cl.pic:SetPos(cl.x, cl.y)
                local bw = lay.innerW - ICON - 12
                local b = cellButton(cl, k, bw)
                b:place(cl.x + ICON + 4, cl.y)
                b:setLabel(plain(fitText(Items.names[Items.slotOf[id]] .. " (" .. id .. ")", bw - BUTTON_PAD)))
                b:show(true)
            end
            cl.pic.colour = WHITE
            cl.pic.hidden = not Kit.setItem(cl.pic, id)
        end
    end
    for j, cl in pairs(cells) do
        if j > k then
            shown[j] = nil
            cl.pic.hidden = true
            if cl.button then cl.button:show(false) end
        end
    end
    local below = n - (Recent.scroll + lay.rows) * per
    if n == 0 then more.content = Items.loaded and "Nothing viewed yet." or ""
    elseif below > 0 then more.content = "(scroll down: " .. below .. " more)"
    elseif Recent.scroll > 0 then more.content = "(scroll up for the start)"
    else more.content = "" end
    count.content = (n == 1) and "1 item" or (n .. " items")
end

-- Lay the column out (the window's layout calls this).
function Recent.layout()
    local _, ch = Window.innerSize()
    local open = Recent.open and not Window.collapsed
    col.hidden = not open
    if not open then return end
    local w = W - PAD - 4 -- (the column, and a small gap before the item list)
    col:SetPos(PAD, 0); col:SetSize(w, ch)
    title:SetPos(0, 2); title:SetSize(w, TAB_H)
    frame:place(0, TOP, w, ch - TOP - BAR_H - 2)
    count:SetPos(0, ch - BAR_H + 7); count:SetSize(w, 22)
    local innerW, innerH = frame.w, frame.h
    lay.innerW = innerW
    lay.ox, lay.oy = PAD + 1, TOP + 1 -- (the column's inside, from the window's top left: for the hover label)
    local avail = innerH - LINE_H - 4 -- (the bottom line is for "(scroll down: ...)")
    local size = tonumber(string.match(View.current, "^icons:(%d+)$"))
    if size ~= nil and GAP[size] ~= nil then
        lay.mode, lay.size = "icons", size
        lay.step = size + GAP[size]
        lay.cols = math.max(1, (innerW - 8 + GAP[size]) // lay.step)
        lay.rows = math.max(1, (avail - 4 + GAP[size]) // lay.step)
        lay.left = (innerW - ((lay.cols - 1) * lay.step + size)) // 2
        lay.top = 4
    else
        lay.mode, lay.size = "rows", ICON
        lay.cols = 1
        lay.rows = math.max(1, (avail - 4) // ROW_H)
        lay.left, lay.top = 4, 4
    end
    lay.rows = math.min(lay.rows, math.ceil(MAX / lay.cols)) -- (never more pictures than the list can hold)
    more:SetPos(0, innerH - LINE_H - 2); more:SetSize(innerW, LINE_H)
    Recent.draw()
end

-- The item under the mouse in the column (for the right-click menu inside the window: ui/game_menu.lua).
function Recent.hovered()
    if col.hidden then return nil end
    for k, cl in pairs(cells) do
        if shown[k] ~= nil then
            if not cl.pic.hidden and cl.pic.isMouseOver == true then return shown[k] end
            if cl.button ~= nil then
                local ok, over = pcall(function() return cl.button:isHovered() end)
                if ok and over then return shown[k] end
            end
        end
    end
    return nil
end

function Recent.add(itemId)
    if type(itemId) ~= "number" or Recent.pause then return end
    for k, n in ipairs(Recent.ids) do if n == itemId then table.remove(Recent.ids, k) break end end
    table.insert(Recent.ids, 1, itemId)
    while #Recent.ids > MAX do table.remove(Recent.ids) end
    Saved.set("recent", table.concat(Recent.ids, ","))
    if Recent.open and not col.hidden then Recent.scroll = 0; Recent.draw() end
end

-- A click in the column: open the item on the Item search tab (without moving it to the front of the list).
function Recent.openItem(itemId)
    if Window.active ~= "search" then Window.show("search") end
    local page = Window.pages.search
    if page == nil or page.details == nil then return end
    Recent.pause = true
    pcall(function() page.details:open(itemId) end)
    Recent.pause = false
end

----------------------------------------------------------------
-- THE ARROW (top left of the window, before the tabs)
----------------------------------------------------------------
Window.tabsInset = ARROW.w + 8
local arrow = Kit.picture(content, { normal = ARROW.sprite, w = ARROW.w, h = ARROW.h }, function() Recent.toggle() end)
local function paintArrow()
    local flip = (Recent.open == (ARROW.flipWhenOpen == true))
    local done = false
    pcall(function() arrow.sprite.isFlippedHorizontally = flip; done = (arrow.sprite.isFlippedHorizontally == flip) end)
    if not done then pcall(function() arrow.sprite.rotationDegrees = flip and 180 or 0 end) end
end
paintArrow()

function Recent.toggle() Recent.setOpen(not Recent.open) end
-- atStart = true: the saved window place already has the column in it (the window only gets wider).
function Recent.setOpen(flag, atStart)
    Recent.open = (flag == true)
    Saved.set("recent_open", Recent.open and "yes" or "no")
    paintArrow()
    Recent.scroll = 0
    Window.setSide(Recent.open and W or 0, atStart)
    Window.layout()
end

-- The window's layout places the arrow and the column; a new view (Icons / Rows) draws the column again; minimizing hides both.
local layout = Window.layout
Window.layout = function(...)
    layout(...)
    pcall(function()
        arrow:place(Window.side() + PAD, 2 + math.max(0, (TAB_H - ARROW.h) // 2))
        arrow:show(not Window.collapsed)
    end)
    pcall(Recent.layout)
end
local setCollapsed = Window.setCollapsed
Window.setCollapsed = function(...) -- (minimizing does not lay the window out: hide the column and the arrow here - 3.0.61 showed them)
    setCollapsed(...)
    pcall(function() arrow:show(not Window.collapsed) end)
    pcall(Recent.layout)
end
local setView = Window.setView
Window.setView = function(...)
    setView(...)
    pcall(Recent.layout)
end
-- (once the items have loaded, their pictures can be drawn)
local loadedSeen = false
Event.Draw.Subscribe("tmr3_recent", function()
    if Recent == nil or Window == nil then return end
    if not loadedSeen and Items.loaded then loadedSeen = true; if Recent.open then pcall(Recent.layout) end end
end)

-- Open at start-up if it was open last time.
if Recent.open then pcall(Recent.setOpen, true, true) end

end }
