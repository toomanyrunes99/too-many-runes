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
TEXT_RGBA  = 0xE7D7B0FF                        -- PrettyUI's cream text colour
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
function Button:root() return self.sb.root end
function Button:destroy() pcall(function() self.sb:Destroy() end) end

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
function Kit.input(parent, w, h, placeholder)
    local f = prettyui.TextField.new(parent, { width = w, height = h, maxLength = 40, placeholder = placeholder or "" })
    local box = { field = f }
    -- (the second value is why it changed - typing, Enter, Esc, a click elsewhere: ui.InputFieldActionResult - for ui/suggest.lua)
    f.onChange = function(_, why, text) if box.onChange ~= nil then box.onChange(text or field(f.root, "content") or "", why) end end
    function box:place(x, y) f.root:SetPos(x, y) end
    function box:setSize(w2, h2) pcall(function() f.root:SetSize(w2, h2) end) end
    function box:setText(text) pcall(function() f:SetText(text, false) end) end
    function box:show(flag) f.root.hidden = not flag end
    return box
end

-- A dropdown. entries = { { label =, id = } ... }; onPick(id) when another choice is made.
-- (The game sorts a dropdown's choices by their words, so they are put in that same (alphabetical) order here first: then the place the
-- game picks an entry by - counted from 0 - is its place in our list too. Until 3.0.35 each label started with a number to set the order.)
-- keepOrder = true: the choices stay in the order given. Each label then starts with an empty colour tag, "<col=000001></col>", that
-- shows nothing but sorts them (3.0.57: All items, Favorites, Gathered, Craftable, Uncraftable).
function Kit.dropdown(parent, entries, selectedId, onPick, keepOrder)
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
    local box = { list = dd, w = 100 }
    for _, e in ipairs(entries) do box.w = math.max(box.w, math.ceil(textWidth(e.words or e.label) + 40)) end
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

-- A row of tabs: buttons side by side, the open one pressed in with a gold line under it. Adding a tab is one call:
--   strip:add(key, label [, width])     strip:select(key)     strip:setLabel(key, text)     strip:place(x, y)
function Kit.tabStrip(parent, h, onPick)
    local strip = { parent = parent, h = h, keys = {}, buttons = {}, x = 0, y = 0, gap = 4 }
    strip.underline = Kit.rect(parent, 0, 0, 1, 2, GOLD)
    strip.underline.hidden = true -- (until a tab is opened)
    function strip:add(key, label, width)
        local w = width or math.ceil(textWidth(label) + 28)
        local b = Kit.button(parent, label, w, self.h, function() onPick(key) end)
        self.keys[#self.keys + 1] = key
        self.buttons[key] = b
        self:place(self.x, self.y)
    end
    function strip:select(key)
        self.active = key
        self.underline.hidden = false
        for k, b in pairs(self.buttons) do b:setActive(k == key) end
        self:place(self.x, self.y)
    end
    function strip:setLabel(key, text) if self.buttons[key] then self.buttons[key]:setLabel(text) end end
    function strip:show(key, flag) if self.buttons[key] then self.buttons[key]:show(flag); self.buttons[key].hidden = not flag; self:place(self.x, self.y) end end
    function strip:place(x, y)
        self.x, self.y = x, y
        local cx = x
        for _, key in ipairs(self.keys) do
            local b = self.buttons[key]
            if not b.hidden then
                b:place(cx, y)
                if key == self.active then self.underline:SetPos(cx + 2, y + self.h); self.underline:SetSize(b.w - 4, 2) end
                cx = cx + b.w + self.gap
            end
        end
        self.right = cx
    end
    return strip
end

end }
