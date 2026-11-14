-- Too Many Runes - The building blocks of the window
-- Text, buttons, item pictures, picture buttons, frames, dropdowns, a search box and a row of tabs. Everything on screen is made from
-- these, so the look of the whole plugin can be changed here in one place.
return { run = function(T)
local _ENV = T

if type(prettyui) ~= "table" then error("PrettyUI is not loaded (is the PrettyUI plugin switched on?)", 0) end

Kit = { dropdowns = {} }

-- COLOURS
WHITE      = Vector4.new(1.0, 1.0, 1.0, 1.0)  -- (a picture drawn white = no tint)
GOLD       = Vector4.new(0.72, 0.60, 0.28, 1.0)
FRAME_LINE = Vector4.new(0.45, 0.37, 0.20, 1.0)
FRAME_BG   = Vector4.new(0.0, 0.0, 0.0, 0.28)
HOVER_TINT = Vector4.new(0.55, 1.0, 0.55, 1.0) -- a picture under the mouse turns green (the Settings page can change it)
MARK_RGB  = { 0.95, 0.78, 0.40 } -- (3.2.11) the item list's marks - the open item, an open group's tray - in gold
HOVER_RGB = { 0.55, 1.0, 0.55 } -- (the same colour as numbers: the outline round the item under the mouse)
TEXT_RGBA  = 0xE7D7B0FF                        -- PrettyUI's cream text colour
GOLD_RGBA  = 0xE3C27AFF                        -- (3.2.17) the words of an open tab (plain buttons)
DIM_RGBA   = 0x9A8B6EFF                        -- (3.2.11) dim words: the facts line, the Info box's ID / value / right-click lines
EMPTY_TAB_RGBA = 0x6D604BFF                    -- (3.2.11) a details tab with nothing in it (plain-button tabs; the game's tabs fade instead)
LINE_H     = 20                                -- the height of one line of text

-- A line of text. align: "left" or "centre" (the default).
function Kit.text(parent, x, y, w, h, align)
    local t = ui.Text.new(parent)
    t:SetSize(w, h or LINE_H)
    t:SetPos(x, y)
    t.font = id.Font.MUSEO_SANS_15PT_REGULAR
    if align == "left" then
        pcall(function() t.alignHorizontal = ui.AlignMode.TOPLEFT; t.alignVertical = ui.AlignMode.CENTRE end)
    else
        t:AlignTo(ui.AlignMode.CENTRE)
    end
    t.content = ""
    pcall(function() t.isShadowed = true; t.shadowColour = Vector4.new(0.0, 0.0, 0.0, 1.0) end)
    pcall(function() t.rgba = TEXT_RGBA end)
    return t
end

-- A filled rectangle (lines, frames, backgrounds). Clicks go through it.
function Kit.rect(parent, x, y, w, h, colour)
    local r = ui.Rectangle.new(parent)
    r.fill = true
    r.colour = colour
    r:SetPos(x, y)
    r:SetSize(w, h)
    pcall(function() r.clickthrough = true end)
    return r
end

-- A framed box: a dark background, a thin gold-brown line round it, and an inner layer (cut off at the edges) to put things in.
-- Place it with box:place(x, y, w, h); box.inner is where its contents go; box.w / box.h are its inner size.
function Kit.frame(parent)
    local box = { bg = Kit.rect(parent, 0, 0, 1, 1, FRAME_BG), lines = {} }
    for k = 1, 4 do box.lines[k] = Kit.rect(parent, 0, 0, 1, 1, FRAME_LINE) end
    box.inner = ui.Layer.new(parent)
    function box:place(x, y, w, h)
        self.bg:SetPos(x, y); self.bg:SetSize(w, h)
        local L = self.lines
        L[1]:SetPos(x, y); L[1]:SetSize(w, 1)
        L[2]:SetPos(x, y + h - 1); L[2]:SetSize(w, 1)
        L[3]:SetPos(x, y); L[3]:SetSize(1, h)
        L[4]:SetPos(x + w - 1, y); L[4]:SetSize(1, h)
        self.inner:SetPos(x + 1, y + 1); self.inner:SetSize(w - 2, h - 2)
        self.w, self.h = w - 2, h - 2
    end
    function box:show(flag) -- (3.2.11: the Info box hides when it has nothing to show)
        local hide = not flag
        self.bg.hidden, self.inner.hidden = hide, hide
        for _, l in ipairs(self.lines) do l.hidden = hide end
    end
    return box
end

-- A PrettyUI button. b:place(x, y), b:setLabel(text), b:show(flag), b:setActive(flag) (looks pressed in), b.onPress = function.
local Button = {}
Button.__index = Button
function Kit.button(parent, label, w, h, onPress)
    local b = setmetatable({ onPress = onPress, w = w, h = h }, Button)
    b.sb = prettyui.SimpleButton.new(parent, label, function() if b.onPress ~= nil then b.onPress() end end, { width = w, height = h })
    return b
end
function Button:place(x, y) self.sb.root:SetPos(x, y) end
function Button:setLabel(text) if self.sb.content.content ~= text then self.sb.content.content = text end end
function Button:show(flag) self.sb.root.hidden = not flag end
function Button:setActive(flag) pcall(function() self.sb:SetActive(flag) end) end
function Button:isHovered() return self.sb.hovered == true or self.sb.root.isMouseOver == true end
function Button:setTextColour(rgba) pcall(function() self.sb.content.rgba = rgba end) end
function Button:setEmpty(flag) -- (3.2.11: a details tab with nothing in it for this item is drawn dim)
    if self.empty == (flag == true) then return end
    self.empty = (flag == true)
    self:setTextColour(self.empty and EMPTY_TAB_RGBA or TEXT_RGBA)
end
function Button:root() return self.sb.root end

-- The game's own outline round the item's shape (a picture's outlineWidth), on the picture under the mouse: HOVER_OUTLINE in settings.lua
-- (0 = none). Kit.itemOutline(sprite, true / false).
function Kit.itemOutline(sprite, on)
    pcall(function() sprite.outlineWidth = on and (tonumber(HOVER_OUTLINE) or 0) or 0 end)
end

-- THE MOUSE OVER A PICTURE: Kit.hoverIn(sprite) gives it the hover colour and the outline at once; Kit.hoverOut(sprite) takes both off
-- again.
function Kit.hoverIn(sprite)
    pcall(function() sprite.colour = HOVER_TINT end)
    Kit.itemOutline(sprite, true)
end
function Kit.hoverOut(sprite)
    Kit.itemOutline(sprite, false)
    pcall(function() sprite.colour = WHITE end)
end

-- A square box round the picture under the mouse: HOVER_BOX pixels thick (settings.lua; 0 = none, the default - the game's own outline is
-- used instead), in the hover colour, just outside the picture (in the gap between pictures, so nothing covers it). o:show(x, y, w, h)
-- round that picture, o:hide(). Its four lines are made in parent the first time it is shown; clicks go through.
function Kit.outline(parent)
    local o = { parent = parent }
    function o:show(x, y, w, h)
        local t = tonumber(HOVER_BOX) or 0
        if t <= 0 or x == nil or y == nil then return end
        if self.lines == nil then
            self.lines = {}
            for k = 1, 4 do self.lines[k] = Kit.rect(self.parent, 0, 0, 1, 1, HOVER_TINT) end
        end
        local L = self.lines
        for k = 1, 4 do pcall(function() L[k].colour = HOVER_TINT; L[k].hidden = false end) end
        L[1]:SetPos(x - t, y - t); L[1]:SetSize(w + 2 * t, t)
        L[2]:SetPos(x - t, y + h); L[2]:SetSize(w + 2 * t, t)
        L[3]:SetPos(x - t, y); L[3]:SetSize(t, h)
        L[4]:SetPos(x + w, y); L[4]:SetSize(t, h)
    end
    function o:hide()
        if self.lines ~= nil then for k = 1, 4 do pcall(function() self.lines[k].hidden = true end) end end
    end
    return o
end

-- A sprite that shows an item's picture (no "1" on it).
function Kit.itemIcon(parent, w, h)
    local s = ui.Sprite.new(parent)
    s:SetSize(w, h)
    s.colour = WHITE
    pcall(function() s.associatedObjectQuantityMode = ui.ObjectQuantityDisplayMode.NEVER end)
    s.hidden = true
    return s
end
-- Draw item number n on it. Returns true if that worked.
function Kit.setItem(sprite, n)
    local ok, err = pcall(function() sprite:SetAssociatedObject(n) end)
    if not ok then trouble("drawing an item picture", err) end
    return ok
end

-- A picture that works as a button: pics = { normal =, hover =, disabled =, w =, h =, flip =, rotate = } (the game's picture numbers).
-- p:place(x, y), p:show(flag), p:setUsable(flag) (grey and dead while false), p:setPics(pics), p.onPress = function.
local Picture = {}
Picture.__index = Picture
function Kit.picture(parent, pics, onPress)
    local s = ui.Sprite.new(parent)
    local p = setmetatable({ sprite = s, pics = pics, onPress = onPress, usable = true, hovered = false }, Picture)
    s:SetSize(pics.w or 24, pics.h or 24)
    s.colour = WHITE
    if pics.rotate then pcall(function() s.rotationDegrees = pics.rotate end) end
    if pics.flip then -- (mirror left to right; if the game cannot, turn it round instead: a triangle looks the same)
        local flipped = false
        pcall(function() s.isFlippedHorizontally = true; flipped = (s.isFlippedHorizontally == true) end)
        if not flipped then pcall(function() s.rotationDegrees = 180 end) end
    end
    s:Subscribe(ui.Hook.ONMOUSEOVER, function() p.hovered = p.usable; p:paint(); return true end)
    s:Subscribe(ui.Hook.ONMOUSELEAVE, function() p.hovered = false; p:paint(); return true end)
    s:Subscribe(ui.Hook.ONCLICK, function()
        if p.usable and p.onPress ~= nil then pcall(p.onPress) end
        return false
    end)
    p:paint()
    return p
end
function Picture:paint()
    local pics = self.pics
    local sid = (not self.usable and pics.disabled) or (self.hovered and pics.hover) or pics.normal
    pcall(function() self.sprite.spriteID = sid end)
    if pics.hover == nil then pcall(function() self.sprite.alpha = self.hovered and 1.0 or 0.85 end) end
end
function Picture:place(x, y) self.sprite:SetPos(x, y) end
function Picture:show(flag) self.sprite.hidden = not flag end
function Picture:setUsable(flag) self.usable = (flag == true); if not self.usable then self.hovered = false end; self:paint() end
function Picture:setPics(pics) self.pics = pics; self:paint() end

-- The mouse wheel over a part of the window: fn(1) for down, fn(-1) for up. (The game sends the wheel to the part under the mouse, so
-- every part that can be under it is bound.)
function Kit.wheel(component, fn)
    pcall(function()
        component:Subscribe(ui.Hook.ONSCROLLWHEEL, "tmr3_wheel", function(_, delta)
            if type(delta) ~= "number" or delta == 0 then return true end
            fn(delta > 0 and 1 or -1)
            return false
        end)
    end)
end

-- A one-line box to type in. Returns PrettyUI's field (field.onChange = function(text), field:SetText(text)).
function Kit.input(parent, w, h, placeholder, maxLength)
    local f = prettyui.TextField.new(parent, { width = w, height = h, maxLength = maxLength or 40, placeholder = placeholder or "" })
    local box = { field = f }
    -- (the second value is why it changed - typing, Enter, Esc, a click elsewhere: ui.InputFieldActionResult - for ui/suggest.lua)
    f.onChange = function(_, why, text) if box.onChange ~= nil then box.onChange(text or field(f.root, "content") or "", why) end end
    function box:place(x, y) f.root:SetPos(x, y) end
    function box:setText(text) pcall(function() f:SetText(text, false) end) end
    function box:show(flag) f.root.hidden = not flag end
    return box
end

-- A dropdown. entries = { { label =, id = } ... }; onPick(id) when another choice is made.
-- (The game sorts a dropdown's choices by their words, so they are put in that same (alphabetical) order here first: then the place the
-- game picks an entry by - counted from 0 - is its place in our list too.)
-- keepOrder = true: the choices stay in the order given. Each label then starts with an empty colour tag, "<col=000001></col>", that shows
-- nothing but sorts them (All items, Favorites, Gathered, Craftable, Uncraftable).
-- (pad, minW: the room beside the words - the arrow and the edges - and the narrowest it may be; 40 and 100 unless given.)
function Kit.dropdown(parent, entries, selectedId, onPick, keepOrder, pad, minW)
    local sorted = {}
    for k, e in ipairs(entries) do
        sorted[k] = keepOrder and { label = string.format("<col=%06x></col>", k) .. e.label, id = e.id, words = e.label } or e
    end
    if not keepOrder then table.sort(sorted, function(a, b) return a.label < b.label end) end
    entries = sorted
    local dd = ui.List.new(parent)
    dd.stylesheetID = id.StyleSheet.DROPDOWN_DEFAULT
    dd.dropdownMaxVisibleEntries = #entries
    local placeOf, entryAt = {}, {}
    for k, e in ipairs(entries) do
        placeOf[e.id], entryAt[k - 1] = k - 1, e
        dd:Add(e.label, k - 1)
    end
    dd:SetEntrySelected(placeOf[selectedId] or 0, true)
    -- What the list says is selected now: its answer has come back as a number, an entry with an id, or a flag (all are accepted).
    local function selected()
        local number = nil
        pcall(function()
            for key, entry in pairs(dd.selectedEntries) do
                local n = nil
                if type(entry) == "number" then n = entry
                elseif entry == true then n = key
                elseif type(entry) ~= "boolean" and type(entry) ~= "string" then n = field(entry, "id") end
                if type(n) == "number" then number = n end
            end
        end)
        return number
    end
    dd:Subscribe(ui.Hook.ONSELECTIONCHANGED, function(_, entryId, picked)
        if picked == 0 or picked == false then return end -- (the entry that was un-picked is reported too)
        local n = selected()
        if n == nil or entryAt[n] == nil then n = entryId end
        local e = entryAt[n]
        if e ~= nil then onPick(e.id) else say("could not tell what the dropdown chose (" .. tostring(entryId) .. ")") end
    end)
    local box = { list = dd, w = minW or 100 }
    for _, e in ipairs(entries) do box.w = math.max(box.w, math.ceil(textWidth(e.words or e.label) + (pad or 40))) end
    function box:place(x, y) dd:SetSize(self.w, 28); dd:SetPos(x, y) end
    function box:show(flag) dd.hidden = not flag end
    function box:select(id2) if placeOf[id2] ~= nil then pcall(function() dd:SetEntrySelected(placeOf[id2], true) end) end end
    Kit.dropdowns[#Kit.dropdowns + 1] = dd
    return box
end
-- Keep the dropdowns above everything made after them, so their open lists draw on top.
function Kit.raiseDropdowns()
    for _, dd in ipairs(Kit.dropdowns) do pcall(function() dd:MoveToFront() end) end
end

-- A TAB DRAWN WITH THE GAME'S OWN TAB PICTURES (like the game's Summary / Skills / Loadout / Achievements tabs). The pictures are the ones PrettyUI's own tabs use (RS3_PARENT_TAB_UNSELECTED_ / _CURRENT_
-- LEFT, TILE, RIGHT): each is 60 high, its tab part the top 42; the left end 60 wide, the right end 30, the tile between them from 30 in.
-- big = true: drawn at that size (as PrettyUI draws them); otherwise all of it scaled down so the tab part is h high. The same calls as
-- Kit.button: t:place(x, y), t:setLabel(text), t:show(flag), t:setActive(flag) ...
local TAB_PICS = nil
local function tabPics()
    if TAB_PICS == nil then
        TAB_PICS = {}
        pcall(function()
            local S = id.Sprite
            TAB_PICS.inactive = { S.RS3_PARENT_TAB_UNSELECTED_LEFT, S.RS3_PARENT_TAB_UNSELECTED_TILE, S.RS3_PARENT_TAB_UNSELECTED_RIGHT }
            TAB_PICS.active = { S.RS3_PARENT_TAB_CURRENT_LEFT, S.RS3_PARENT_TAB_CURRENT_TILE, S.RS3_PARENT_TAB_CURRENT_RIGHT }
        end)
    end
    return TAB_PICS
end
function Kit.gameTabsReady()
    local p = tabPics()
    return p.active ~= nil and type(p.active[1]) == "number" and type(p.inactive[1]) == "number"
end
local TAB_TEXT = 0xF2E2BCFF -- (the tab words' colour, as the game's)
local GameTab = {}
GameTab.__index = GameTab
-- cut: where the line under the tabs is, from the row's top. A layer shows only what lies inside it (PrettyUI's scrolling works that way), so the tab's layer is made to end there: the
-- pictures' bottom - made for the game's own thicker line - is cut off. A closed tab ends on the line; the open one one pixel past it, so it
-- covers the line and joins the box below.
function Kit.gameTab(parent, label, w, h, onPress, big, cut)
    local k = big and 1 or (h / 42)
    local t = setmetatable({ onPress = onPress, w = w, h = h, active = false, hovered = false, big = big, cut = cut }, GameTab)
    local vh = math.floor(60 * k + 0.5)
    -- (the open tab's picture reaches 39 of its 60, a closed one's only 37 - so a closed tab is drawn that much lower, and all of them
    -- stand on the same line, as the game's do)
    t.drop = math.floor(vh * 2 / 60 + 0.5)
    t.x, t.y = 0, 0
    local L = ui.Layer.new(parent)
    L:SetSize(w, vh)
    L.clickthrough = true
    t.layer = L
    local function pic()
        local s = ui.Sprite.new(L)
        s.colour = WHITE
        pcall(function() s.clickthrough = true end)
        return s
    end
    t.left, t.mid, t.right = pic(), pic(), pic()
    local ends = math.floor(30 * k + 0.5)
    t.left:SetSize(2 * ends, vh)
    t.mid:SetPos(ends, 0); t.mid:SetSize(-2 * ends, vh, 1.0)
    pcall(function() t.mid.isTiling = (big == true) end) -- (scaled down: stretched, as a tiled picture would keep its own size)
    t.right:SetPos(-ends, 0, 1.0); t.right:SetSize(ends, vh)
    t.label = Kit.text(L, 0, 0, 10, 10)
    t.label:SetPos(math.floor(8 * k + 0.5), math.floor(7 * k + 0.5))
    t.label:SetSize(-math.floor(16 * k + 0.5), math.max(LINE_H - 2, math.floor(32 * k + 0.5)), 1.0)
    pcall(function() t.label.rgba = TAB_TEXT; t.label.maxLines = 1; t.label.clickthrough = true end)
    pcall(function() t.label.alignHorizontal = ui.AlignMode.CENTRE; t.label.alignVertical = ui.AlignMode.CENTRE end)
    t.label.content = label
    local H = ui.Layer.new(parent)
    H:SetSize(w, h)
    H.clickthrough = false
    H:Subscribe(ui.Hook.ONMOUSEOVER, function() t.hovered = true; t:paint(); return true end)
    H:Subscribe(ui.Hook.ONMOUSELEAVE, function() t.hovered = false; t:paint(); return true end)
    H:Subscribe(ui.Hook.ONCLICK, function() if t.onPress ~= nil then pcall(t.onPress) end return false end)
    t.hit = H
    t:paint()
    return t
end
function GameTab:paint()
    -- (an open cut tab stands one pixel higher than the closed ones, so it covers the line; an open tab that is not cut is not raised)
    local top = (not self.active) and self.drop or ((self.cut ~= nil) and math.max(0, self.drop - 1) or 0)
    pcall(function() self.layer:SetPos(self.x, self.y + top) end)
    if self.cut ~= nil then pcall(function() self.layer:SetSize(self.w, math.max(1, self.cut + (self.active and 1 or 0) - top)) end) end
    local pics = tabPics()[self.active and "active" or "inactive"]
    pcall(function() self.left.spriteID, self.mid.spriteID, self.right.spriteID = pics[1], pics[2], pics[3] end)
    -- (3.2.11: a tab with nothing in it for this item is dimmer than the other closed tabs)
    local alpha = (self.active or self.hovered) and 1.0 or 0.65
    if self.empty and not self.active then alpha = self.hovered and 0.6 or 0.3 end
    pcall(function() self.label.alpha = alpha end)
end
function GameTab:place(x, y)
    self.x, self.y = x, y
    self.hit:SetPos(x, y)
    self:paint()
end
function GameTab:setLabel(text) if self.label.content ~= text then self.label.content = text end end
function GameTab:show(flag) self.layer.hidden = not flag; self.hit.hidden = not flag end
function GameTab:setActive(flag)
    self.active = (flag == true)
    self:paint()
    if self.active then pcall(function() self.layer:MoveToFront(); self.hit:MoveToFront() end) end -- (its ends over its neighbours')
end
function GameTab:setEmpty(flag) if self.empty ~= (flag == true) then self.empty = (flag == true); self:paint() end end
function GameTab:isHovered() return self.hovered == true end
function GameTab:setTextColour(rgba) pcall(function() self.label.rgba = rgba end) end
function GameTab:root() return self.layer end

-- A row of tabs: buttons side by side, the open one pressed in with a gold line under it. Adding a tab is one call:
--   strip:add(key, label [, width])     strip:select(key)     strip:setLabel(key, text)     strip:place(x, y)
Kit.stripsToFit = {} -- (the tab rows whose widths are worked out at the next frame: strip:fit)
Event.Draw.Subscribe("tmr3_tab_fit", function()
    if Kit == nil or next(Kit.stripsToFit) == nil then return end -- (Kit == nil: the plugin was switched off)
    local list = Kit.stripsToFit
    Kit.stripsToFit = {}
    for strip in pairs(list) do pcall(strip.fitNow, strip) end
end)
-- style: nil - PrettyUI buttons; "big" or "small" - the game's tab pictures (Kit.gameTab), PrettyUI's size or scaled to
-- h. The game's tabs have no gold line under them: the open one is drawn in front, lit.
function Kit.tabStrip(parent, h, onPick, style)
    if style ~= nil and not Kit.gameTabsReady() then style = nil end -- (the game did not hand the pictures over: plain buttons)
    local strip = { parent = parent, h = h, keys = {}, buttons = {}, labels = {}, x = 0, y = 0, gap = (style ~= nil) and 2 or 4, style = style }
    strip.underline = Kit.rect(parent, 0, 0, 1, 2, GOLD)
    strip.underline.hidden = true -- (until a tab is opened)
    -- (3.2.17) plain buttons: the open one gets a gold border and gold words, instead of the line under it
    strip.ring = {}
    if style == nil then
        for k = 1, 4 do strip.ring[k] = Kit.rect(parent, 0, 0, 1, 1, GOLD); strip.ring[k].hidden = true end
    end
    -- (3.2.22) strip:setIcon(key, picture): a picture in front of a tab's words (the words are given room for it by the caller)
    strip.icons, strip.iconH, strip.iconX = {}, {}, {}
    -- (3.2.26) strip:setWords(key, text, x): the tab's words drawn by the plugin (the button itself has none), x from the tab's left - so
    -- the tab is just as wide as its picture and words, without the room the game's buttons keep round their own words
    strip.wordsOf, strip.wordsX = {}, {}
    function strip:setWords(key, t, x)
        self.wordsOf[key], self.wordsX[key] = t, x or 6
        pcall(function() t.clickthrough = true end)
        pcall(function() t.rgba = (key == self.active) and GOLD_RGBA or TEXT_RGBA end)
        self:place(self.x, self.y)
    end
    function strip:setIcon(key, pic, h, x)
        self.icons[key], self.iconH[key], self.iconX[key] = pic, h or 20, x or 5
        pcall(function() pic.clickthrough = true end)
        self:place(self.x, self.y)
    end
    function strip:paintRing(b, x, y)
        local R = self.ring
        if #R == 0 then return end
        local show = (b ~= nil) and not self.hiddenStrip
        for k = 1, 4 do R[k].hidden = not show end
        if not show then return end
        R[1]:SetPos(x, y); R[1]:SetSize(b.w, 1)
        R[2]:SetPos(x, y + self.h - 1); R[2]:SetSize(b.w, 1)
        R[3]:SetPos(x, y); R[3]:SetSize(1, self.h)
        R[4]:SetPos(x + b.w - 1, y); R[4]:SetSize(1, self.h)
    end
    function strip:make(label, w, onPress)
        if self.style ~= nil then return Kit.gameTab(self.parent, label, w, self.h, onPress, self.style == "big", self.cut) end
        return Kit.button(self.parent, label, w, self.h, onPress)
    end
    -- how wide a tab is for these words (the game's tabs: PrettyUI's room round the words, and its smallest tab, 90 wide at the big size)
    function strip:widthFor(text, asked)
        if self.style == "big" then return math.max(90, asked or 0, 4 * math.ceil((textWidth(text) + 24) / 4)) end
        if self.style == "small" then return math.max(math.floor(90 * self.h / 42), asked or 0, 4 * math.ceil((textWidth(text) + 20) / 4)) end
        return asked or (4 * math.ceil((textWidth(text) + 20) / 4))
    end
    function strip:add(key, label, width)
        local w = (self.style ~= nil) and self:widthFor(label, width) or (width or math.ceil(textWidth(label) + 28))
        local b = self:make(label, w, function() onPick(key) end)
        self.keys[#self.keys + 1] = key
        self.buttons[key] = b
        self.labels[key] = label
        self:place(self.x, self.y)
    end
    function strip:select(key)
        self.active = key
        self.underline.hidden = true -- (3.2.17: plain buttons show the open one by a gold border - strip.ring - not a line)
        for k, b in pairs(self.buttons) do
            b:setActive(k == key)
            if self.style == nil and b.setTextColour ~= nil then b:setTextColour((k == key) and GOLD_RGBA or TEXT_RGBA) end
            local t = self.wordsOf and self.wordsOf[k]
            if t ~= nil then pcall(function() t.rgba = (k == key) and GOLD_RGBA or TEXT_RGBA end) end
        end
        self:place(self.x, self.y)
    end
    -- (3.2.11) a tab with nothing in it for this item: drawn dim (kept through fitNow's change of button, by place)
    strip.empty = {}
    function strip:setEmpty(key, flag)
        self.empty[key] = (flag == true)
        local b = self.buttons[key]
        if b ~= nil and b.setEmpty ~= nil then b:setEmpty(self.empty[key]) end
    end
    function strip:setLabel(key, text)
        if self.buttons[key] then self.labels[key] = text; self.buttons[key]:setLabel(text) end
    end
    -- strip.maxW set: the buttons are made as wide as their words need, all of them inside maxW ("Recipe (12)", "Uses (99+)", "Source
    -- (3)"). The width is worked out at the next frame (a button of a new width is made then, not while a click is running).
    function strip:fit() if self.maxW ~= nil then Kit.stripsToFit[self] = true end end
    function strip:fitNow()
        -- the ways to write the words, tried in turn until they fit (PrettyUI cuts words that do not fit with "...", so every button keeps
        -- 20 pixels round its words - what "Uses (99+)" needed): as they are; "Recipe(3)"; then only the open tab keeps its count
        local function words(key, way)
            local text = self.labels[key] or ""
            if way >= 2 then text = (string.gsub(text, " %(", "(")) end
            if way >= 3 and key ~= self.active then text = (string.gsub(text, "%s*%(.*%)$", "")) end
            return text
        end
        local best = nil
        for way = 1, 3 do
            local list, total = {}, -self.gap
            for _, key in ipairs(self.keys) do
                local text = words(key, way)
                local w = self:widthFor(text) -- (whole steps of 4: fewer widths to keep)
                list[key] = { text = text, w = w }
                if not self.buttons[key].hidden then total = total + w + self.gap end
            end
            best = list
            if total <= self.maxW then break end
        end
        -- (a button of another width is never destroyed and remade - that kept crashing the game; each width a tab has needed is kept,
        -- hidden, and shown again when it is needed again)
        self.pool = self.pool or {}
        for _, key in ipairs(self.keys) do
            local old, e = self.buttons[key], best[key]
            if old.w ~= e.w then
                local pool = self.pool[key]
                if pool == nil then pool = {}; self.pool[key] = pool end
                pool[old.w] = old
                local b = pool[e.w]
                if b == nil then b = self:make(e.text, e.w, old.onPress); pool[e.w] = b end
                b.hidden = old.hidden
                old:show(false)
                b:show(not old.hidden)
                b:setLabel(e.text)
                b:setActive(key == self.active)
                self.buttons[key] = b
            else
                old:setLabel(e.text)
            end
        end
        self:place(self.x, self.y)
    end
    -- (3.2.16) strip.wrapW set: tabs that would pass that width go on to a new line below (self.lines = how many lines, self.height = how
    -- tall); strip:show(false) hides every tab of the strip.
    function strip:show(flag)
        self.hiddenStrip = not flag
        for _, b in pairs(self.buttons) do b:show(flag) end
        if not flag then self.underline.hidden = true end
        if not flag then self:paintRing(nil) end
        self:place(self.x, self.y)
    end
    function strip:place(x, y)
        self.x, self.y = x, y
        local cx, cy, lines, ringed = x, y, 1, false
        for _, key in ipairs(self.keys) do
            local b = self.buttons[key]
            if self.wrapW ~= nil and not b.hidden and cx > x and cx + b.w > x + self.wrapW then
                cx, cy, lines = x, cy + self.h + self.gap, lines + 1
            end
            if b.setEmpty ~= nil then b:setEmpty(self.empty[key]) end
            local ic = self.icons and self.icons[key]
            if ic ~= nil then
                ic.hidden = b.hidden or self.hiddenStrip == true
                local ih = self.iconH[key] or 20
                local ix = self.iconX[key] or 5
                pcall(function() ic:SetPos(cx + ix, cy + (self.h - ih) // 2); ic:MoveToFront() end)
            end
            local tw = self.wordsOf and self.wordsOf[key]
            if tw ~= nil then
                tw.hidden = b.hidden or self.hiddenStrip == true
                local tx = self.wordsX[key] or 6
                pcall(function() tw:SetPos(cx + tx, cy + (self.h - LINE_H) // 2); tw:SetSize(math.max(4, b.w - tx - 2), LINE_H); tw:MoveToFront() end)
            end
            if not b.hidden then
                b:place(cx, cy)
                if key == self.active and self.style == nil then self:paintRing(b, cx, cy); ringed = true end
                cx = cx + b.w + self.gap
            end
        end
        if not ringed then self:paintRing(nil) end
        self.right, self.lines, self.height = cx, lines, lines * self.h + (lines - 1) * self.gap
    end
    return strip
end

end }
