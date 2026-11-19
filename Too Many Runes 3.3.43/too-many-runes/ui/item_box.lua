-- Too Many Runes - The item box
-- A framed box that shows one page of a list of items, as a grid of pictures (the name shows when the mouse is over one) or as
-- rows (picture and name), in as many columns as fit. It fills whatever room it is given, so a bigger window shows more items
-- per page.
-- Any tab can use one:  box = ItemBox.new(layer, onPick)   box:place(x, y, w, h)   box:setList(slots)   box:render()
--
-- The game allows a plugin about 4,000 parts on screen in all ("invalid dynamic ID, expected a value between 0 and 4096"), so a
-- picture is just one part. Its name is shown by the window's one shared hover label, a page holds at most MAX_PICTURES pictures
-- (MAX_ROWS rows in the rows view), and the rows' buttons are a fixed width so they never have to be made again.
-- One set of parts serves every view: picture number n of the page is always the same part, whatever the view (16, 32, 48, 64
-- or rows) and however big the window is. It is just moved and resized. A separate picture for every line and column ever used
-- would keep adding parts as views are switched and the window resized, until the game refuses to make more. So the box never
-- holds more than MAX_PICTURES pictures and MAX_ROWS buttons. The parts sit in small layers of PER_LAYER each, to keep each
-- layer's list short.
-- Shelves: with box.shelves set (pages/item_search.lua: a group's tab, nothing typed in the search) the grid is split into
-- groups (core/shelves.lua). Each group starts on a new line under a gold heading, "Potions (1,214)", and every page starts with
-- its group's heading. Pages then hold different numbers of items, so the first item of every page is worked out in advance
-- (ItemBox:buildStarts).
return { run = function(T)
local _ENV = T

ItemBox = {}
ItemBox.__index = ItemBox

-- New pictures are made at most NEW_PER_TICK a game tick, since making a whole 16-pixel page (about 1,000) in one go freezes the
-- game for a moment on every reload. A page that is not finished is finished on the next ticks (ItemBox.tick, called by the
-- clock in start.lua). Pictures are kept once made, so turning pages costs nothing extra.
ItemBox.NEW_PER_TICK, ItemBox.made, ItemBox.waiting = 150, 0, {}
-- Drawing item pictures. The game draws an item's picture the first time it is shown (with its number, as a new picture), which
-- is slow: drawing a whole page at once freezes the game for 6 to 15 seconds after a start with the list open. So a picture is
-- only set again when its item or number changes (setting it again also takes off its hover look and outline). At most
-- ICONS_PER_TICK pictures never drawn before are drawn in one tick, fewer while the game struggles (Scan.paced), and the rest of
-- the page follows on the next ticks.
ItemBox.ICONS_PER_TICK, ItemBox.icons, ItemBox.seen = 36, 0, {} -- (the Settings page sets it for each speed)
function ItemBox.tick()
    ItemBox.made, ItemBox.icons = 0, 0
    for box in pairs(ItemBox.waiting) do
        ItemBox.waiting[box] = nil
        pcall(box.render, box)
    end
end
local function mayMake(cost)
    if ItemBox.made >= ItemBox.NEW_PER_TICK then return false end
    ItemBox.made = ItemBox.made + cost
    return true
end

local GAP = { [64] = 4, [48] = 3, [32] = 2, [16] = 2 } -- the space between pictures, for each picture size
local PER_LAYER = 100
local ROW_H, ROW_W, ICON_W, ICON_H = 34, 220, 36, 32 -- ROW_W is the width of one column of rows

function ItemBox.new(parent, onPick)
    local box = setmetatable({ frame = Kit.frame(parent), onPick = onPick, list = {}, page = 1, perPage = 1,
                               pics = {}, picLayers = {}, buttons = {}, buttonLayers = {}, rowW = 0 }, ItemBox)
    box.note = Kit.text(box.frame.inner, 0, 0, 10, 22) -- "No items match." when the list is empty
    box.markLayer, box.marks = ui.Layer.new(box.frame.inner), {} -- the marks behind the pictures (ItemBox:paintMarks), made first so they sit below them
    box.headLayer, box.heads = ui.Layer.new(box.frame.inner), {} -- the shelves' headings
    -- The wheel: with WHEEL_UP_NEXT = true, up is the next page and down the page before. false (the default) turns it round. One
    -- wheel notch reaches every part under the mouse (the picture, its layer and the box), so only the first one in a tick turns the
    -- page. Otherwise one notch would turn several pages.
    box.wheel = function(step)
        if box.wheelTick == tickCount then return end
        box.wheelTick = tickCount
        box:turn((WHEEL_UP_NEXT == false) and step or -step)
    end
    Kit.wheel(box.frame.inner, box.wheel)
    Kit.wheel(box.markLayer, box.wheel)
    Kit.wheel(box.headLayer, box.wheel)
    return box
end

-- Works out how many columns and rows fit (from the box's size and the view), keeping the first item of the page on screen.
-- anchorPlace gives the item to stay on while the window is made bigger or smaller: the one open on the right when it is on this
-- page, otherwise the page's first. It is remembered from the first size change on, because working it out again at every step
-- of a drag creeps back a little each time, many pages away. It is forgotten when the page is turned, the list changes or
-- another item is picked.
function ItemBox:anchorPlace()
    local sel = (self.selectedOf ~= nil) and self.selectedOf() or nil
    if sel ~= nil then
        for n = 1, (self.perPage or 0) do
            local slot = self:at(n)
            if slot == nil then break end
            if Items.ids[slot] == sel then return self:placeOf(n) end
        end
    end
    return self:placeOf(1)
end
function ItemBox:place(x, y, w, h)
    if self.keepPlace == nil then self.keepPlace = self:anchorPlace() end
    local first = self.keepPlace
    self.frame:place(x, y, w, h)
    w, h = self.frame.w, self.frame.h
    local size = tonumber(string.match(View.current, "^icons:(%d+)$"))
    if size ~= nil and GAP[size] ~= nil then
        local gap = GAP[size]
        local step, cap = size + gap, MAX_PICTURES or 1200
        self.mode, self.size = "icons", size
        local cols = math.max(1, (w - 8 + gap) // step)
        local rows = math.max(1, (h - 8 + gap) // step)
        self.stepX, self.stepY = step, step
        if cols * rows > cap then
            -- More would fit than a page may hold (MAX_PICTURES): use fewer columns and rows, spread out with extra space between them so the
            -- pictures still fill the box. The pictures stay their size; only the gaps grow.
            local even = math.sqrt((w - 8) * (h - 8) / cap)
            cols, rows = math.max(1, math.floor((w - 8) / even)), math.max(1, math.floor((h - 8) / even))
            while true do -- take any extra column or row that still keeps the page within the limit
                if (cols + 1) * rows <= cap and (cols + 1) * step <= w - 8 + gap then cols = cols + 1
                elseif cols * (rows + 1) <= cap and (rows + 1) * step <= h - 8 + gap then rows = rows + 1
                else break end
            end
            self.stepX = math.max(step, (w - 8 - size) // math.max(1, cols - 1))
            self.stepY = math.max(step, (h - 8 - size) // math.max(1, rows - 1))
        end
        self.cols, self.rows = cols, rows
        self.left = (w - ((cols - 1) * self.stepX + size)) // 2
        self.top = (h - ((rows - 1) * self.stepY + size)) // 2
    else
        self.mode = "rows"
        local cols = math.max(1, (w - 8) // ROW_W)
        local fit = math.max(1, (h - 8) // ROW_H)
        local rows = math.max(1, math.min(fit, (MAX_ROWS or 150) // cols))
        self.colW, self.colStep, self.rowStep = ROW_W, ROW_W, ROW_H
        local rowW = ROW_W - 4 -- the width a row really uses: picture, gap, button
        if rows < fit then
            -- More rows would fit than a page may hold (MAX_ROWS): spread the columns and rows out with extra space so they fill the box.
            self.colStep = math.max(ROW_W, (w - 8 - rowW) // math.max(1, cols - 1))
            self.rowStep = math.max(ROW_H, (h - 8 - ICON_H) // math.max(1, rows - 1))
        end
        self.cols, self.rows = cols, rows
        self.left = (w - ((cols - 1) * self.colStep + rowW)) // 2
        self.top = (h - ((rows - 1) * self.rowStep + ICON_H)) // 2
    end
    self.w, self.h = w, h
    self.ox, self.oy = x + 1, y + 1 -- the box's inside, from the page's top left, for the hover label
    self.perPage = self.cols * self.rows
    self:buildStarts()
    self.page = self:pageOfPlace(first)
    self.note:SetSize(w, 22)
    self.note:SetPos(0, h // 2 - 11)
end

function ItemBox:pageCount()
    if self.starts ~= nil then return math.max(1, #self.starts) end
    return math.max(1, math.ceil(#self.list / self.perPage))
end
-- The place in the list of item n of the page, and the page a place is on.
function ItemBox:placeOf(n)
    if self.starts ~= nil then return (self.starts[self.page] or 1) + n - 1 end
    return (self.page - 1) * (self.perPage or 1) + n
end
function ItemBox:pageOfPlace(p)
    if self.starts == nil then return math.max(1, (p - 1) // math.max(1, self.perPage or 1) + 1) end
    local lo, hi = 1, #self.starts
    while lo < hi do -- the last page that starts at or before p
        local mid = (lo + hi + 1) // 2
        if self.starts[mid] <= p then lo = mid else hi = mid - 1 end
    end
    return math.max(1, lo)
end
function ItemBox:at(i) return self.list[self:placeOf(i)] end
function ItemBox:setList(list, toFirstPage)
    if toFirstPage or list ~= self.list then self.keepPlace = nil end -- the same list again (a resize redraws it) keeps the item to stay on
    self.list = list
    if toFirstPage then self.page = 1 end
    self:buildStarts()
end

-- Shelf layout. One page from place p: where every item and heading goes. emit(kind, what, x, y) is told each one ("head" with
-- the shelf key, or "item" with the place). Returns the place after the page's last item.
local HEAD_H = 20
function ItemBox:shelfPage(p, emit, stopAt)
    local sh, list, size = self.shelves, self.list, self.size or 32
    local bottom, cap = (self.h or 100) - 4, self.perPage or 1
    local y, col, n, key = 4, 0, 0, nil
    while p <= #list and n < cap and (stopAt == nil or p < stopAt) do
        local k = sh.of(p)
        if k ~= key then
            if col > 0 then y = y + self.stepY; col = 0 end
            if n > 0 and y + HEAD_H + size > bottom then break end -- no room for the heading and one line under it
            if emit then emit("head", k, self.left, y) end
            y, key = y + HEAD_H, k
        end
        if col == self.cols then col = 0; y = y + self.stepY end
        if n > 0 and y + size > bottom then break end
        if emit then emit("item", p, self.left + col * self.stepX, y) end
        col, n, p = col + 1, n + 1, p + 1
    end
    return p
end
-- The first place of every page, only with shelves in the grid; otherwise every page holds perPage items.
-- An open group's forms are kept on one page: when they would be split, the page ends before the group, if the group fits on a
-- page.
function ItemBox:buildStarts()
    local shelves = self.shelves ~= nil and self.mode == "icons" and self.cols ~= nil
    local a, b, view = nil, nil, nil
    if Groups ~= nil and Groups.openRange ~= nil then a, b, view = Groups.openRange() end
    if view ~= self.list then a, b = nil, nil end
    if not shelves and a == nil then self.starts = nil return end
    local starts, p, n, per = {}, 1, #self.list, math.max(1, self.perPage or 1)
    repeat
        starts[#starts + 1] = p
        local nextP = shelves and self:shelfPage(p) or (p + per)
        if a ~= nil and a > p and a < nextP and b >= nextP and (b - a + 1) <= per then nextP = a end
        p = (nextP > p) and nextP or (p + 1)
    until p > n
    self.starts = starts
    if self.page > #starts then self.page = #starts end
end
function ItemBox:goTo(n) self.page = n; self.keepPlace = nil; self:render() end

-- The mouse wheel: one page on or back (it does not go round at the ends).
function ItemBox:turn(step)
    local n = self.page + step
    if n >= 1 and n <= self:pageCount() then
        self:goTo(n)
        Window.refreshPager()
    end
end

-- The layer that holds part n of a list (pictures or buttons), made the first time it is needed. Each covers the whole box.
local function layerFor(box, list, n)
    local k = (n - 1) // PER_LAYER + 1
    local layer = list[k]
    if layer == nil then
        layer = ui.Layer.new(box.frame.inner)
        list[k] = layer
        Kit.wheel(layer, box.wheel)
    end
    layer:SetPos(0, 0)
    layer:SetSize(box.w or 10, box.h or 10)
    return layer
end

-- Picture n of the page, the same part in every view. Its item is worked out when it is clicked or pointed at, so it is always
-- the one shown. nil when no more may be made this tick; the page is then finished on the next tick.
function ItemBox:pic(n)
    local s = self.pics[n]
    if s ~= nil then return s end
    if n > (MAX_PICTURES or 1200) or not mayMake(1) then return nil end
    s = Kit.itemIcon(layerFor(self, self.picLayers, n), 32, 32)
    self.pics[n] = s
    Kit.wheel(s, self.wheel)
    s:Subscribe(ui.Hook.ONMOUSEOVER, function()
        Kit.hoverIn(s)
        self.hoverN = n
        local slot = self:at(n)
        local at = self.picAt and self.picAt[n]
        if slot ~= nil and at ~= nil then -- an outline round it
            self.outline = self.outline or Kit.outline(self.frame.inner)
            pcall(function() self.outline:show(at[1], at[2], at[3], at[4]) end)
        end
        if slot ~= nil and at ~= nil and self.mode == "icons" then -- the rows show the name already
            local text = Items.names[slot] -- the name only, no number, and only if the game's box could not open
            if self.hoverNote ~= nil then text = text .. (self.hoverNote(self:placeOf(n)) or "") end -- a group
            local shown = false
            if Details ~= nil and Details.showItemTip ~= nil then -- the Recently viewed panel too
                -- The game's own hover box, as for the open item's picture. A stack's forms go in its last line: "4 forms - +3 options".
                local note = nil
                if self.hoverNote ~= nil then
                    local k = string.match(tostring(self.hoverNote(self:placeOf(n)) or ""), "(%d+) forms")
                    if k ~= nil then note = "+" .. k .. " forms" end
                end
                local ok, owner = pcall(Details.showItemTip, Items.ids[slot], s, note) -- the box finds the picture's place itself
                if ok and owner ~= nil then self.tipOwner, shown = owner, true end
            end
            if shown then
                -- the game's hover box is showing: nothing more to do
            elseif self.hover ~= nil then -- a box outside the window (the Recently viewed panel) has a label of its own
                pcall(self.hover, text, self.ox + at[1], self.oy + at[2], self.size)
            else
                local px, py = Window.areaOrigin()
                pcall(Window.showHover, text, px + self.ox + at[1], py + self.oy + at[2], self.size)
            end
        end
        return true
    end)
    s:Subscribe(ui.Hook.ONMOUSELEAVE, function()
        Kit.hoverOut(s)
        if self.hoverN == n then self.hoverN = nil end
        if self.outline ~= nil then pcall(function() self.outline:hide() end) end
        pcall(Window.hideHover)
        if self.tipOwner ~= nil then self.tipOwner.iconOver = false; pcall(Details.hideTipOf, self.tipOwner); self.tipOwner = nil end
        if self.hoverHide ~= nil then pcall(self.hoverHide) end
        return true
    end)
    s:Subscribe(ui.Hook.ONCLICK, function()
        local slot = self:at(n)
        if slot ~= nil then self.keepPlace = nil; self.onPick(Items.ids[slot], self:placeOf(n)) end
        return false
    end)
    return s
end

-- The button of row n (rows view): the item's name; a click opens it.
function ItemBox:button(n)
    local b = self.buttons[n]
    if b ~= nil then return b end
    if n > (MAX_ROWS or 150) or not mayMake(4) then return nil end
    b = Kit.button(layerFor(self, self.buttonLayers, n), "", ROW_W - ICON_W - 8, ICON_H, function()
        local slot = self:at(n)
        if slot ~= nil then self.keepPlace = nil; self.onPick(Items.ids[slot], self:placeOf(n)) end
    end)
    self.buttons[n] = b
    Kit.wheel(b:root(), self.wheel)
    return b
end

-- Shows the current page. A part that cannot be made is reported once in the console and left out; the rest of the page still
-- shows.
function ItemBox:render()
    pcall(Window.hideHover) -- the pictures are about to change under the mouse
    if self.tipOwner ~= nil then self.tipOwner.iconOver = false; pcall(Details.hideTipOf, self.tipOwner); self.tipOwner = nil end
    if self.outline ~= nil then pcall(function() self.outline:hide() end) end
    local pages = self:pageCount()
    if self.page > pages then self.page = pages end
    if self.page < 1 then self.page = 1 end
    local grid = (self.mode == "icons")
    for _, layer in pairs(self.picLayers) do layer:SetSize(self.w, self.h) end
    self.markLayer:SetPos(0, 0); self.markLayer:SetSize(self.w, self.h)
    for _, layer in pairs(self.buttonLayers) do layer:SetSize(self.w, self.h); layer.hidden = grid end
    self.picAt = {}
    local shown = 0
    -- With shelves: where this page's items and headings go.
    local spots, heads = nil, {}
    local stopAt = (self.starts ~= nil) and self.starts[self.page + 1] or nil -- a page may end early, so an open group goes on the next
    if grid and self.starts ~= nil and self.shelves ~= nil then
        spots = {}
        local first = self:placeOf(1)
        self:shelfPage(first, function(kind, what, x, y)
            if kind == "head" then heads[#heads + 1] = { key = what, x = x, y = y } else spots[what - first + 1] = { x, y } end
        end, stopAt)
    end
    for n = 1, self.perPage do
        local slot = self:at(n)
        if slot == nil or (spots ~= nil and spots[n] == nil) then break end
        if stopAt ~= nil and self:placeOf(n) >= stopAt then break end
        local x, y
        if spots ~= nil then
            x, y = spots[n][1], spots[n][2]
        elseif grid then
            local r, c = (n - 1) // self.cols + 1, (n - 1) % self.cols + 1
            x, y = self.left + (c - 1) * self.stepX, self.top + (r - 1) * self.stepY
        else
            local c, r = (n - 1) // self.rows + 1, (n - 1) % self.rows + 1 -- filled down the first column, then the next, like a newspaper
            x, y = self.left + (c - 1) * self.colStep, self.top + (r - 1) * self.rowStep
        end
        local ok, err = pcall(function()
            local s = self:pic(n)
            local b = (not grid) and self:button(n) or nil
            if s == nil or (not grid and b == nil) then ItemBox.waiting[self] = true return end -- finished on the next tick
            local w, h = grid and self.size or ICON_W, grid and self.size or ICON_H
            self.picAt[n] = { x, y, w, h }
            self.drawn = self.drawn or {}
            local d = self.drawn[n] -- what picture n shows now: item, number, size
            if d == nil then d = {}; self.drawn[n] = d end
            if d.w ~= w or d.h ~= h then s:SetSize(w, h); d.w, d.h = w, h end
            s:SetPos(x, y)
            if self.hoverN == n then Kit.hoverOut(s); self.hoverN = nil end -- the pictures are about to change under the mouse
            local itemId = Items.ids[slot]
            -- A group of forms shows no number, since the game's yellow number reads as "how many you have". The mouse over it says how many
            -- forms it holds (box.hoverNote).
            if d.id == itemId then
                s.hidden = false
            else
                local key = itemId
                local limit = math.max(3, math.floor(ItemBox.ICONS_PER_TICK * math.min(1, Scan.paced()) + 0.5)) -- not above 1
                if not ItemBox.seen[key] and ItemBox.icons >= limit then
                    s.hidden, d.id = true, nil -- drawn on a later tick
                    ItemBox.waiting[self] = true
                else
                    if not ItemBox.seen[key] then ItemBox.seen[key], ItemBox.icons = true, ItemBox.icons + 1 end
                    local drew = Kit.setItem(s, itemId)
                    pcall(function() s.associatedObjectQuantityMode = ui.ObjectQuantityDisplayMode.NEVER end)
                    d.id = drew and itemId or nil
                    s.hidden = not drew
                end
            end
            if b ~= nil then
                b:place(x + ICON_W + 4, y)
                b:setLabel(plain(fitText(Items.names[slot] .. " (" .. Items.ids[slot] .. ")", self.colW - ICON_W - 22)))
                b:show(true)
            end
            shown = n
        end)
        if not ok then trouble("making a picture in the item box", err) end
    end
    -- hide what this page does not use
    for n, s in pairs(self.pics) do if n > shown then s.hidden = true end end
    for n, b in pairs(self.buttons) do if grid or n > shown then b:show(false) end end
    self.shown = (spots ~= nil or self.starts ~= nil) and shown or math.max(0, math.min(self.perPage, #self.list - (self.page - 1) * self.perPage))
    local okH, errH = pcall(self.paintHeads, self, heads)
    if not okH then trouble("the shelves' headings", errH) end
    self.note.content = (#self.list == 0) and (Items.loaded and (self.emptyText or "No items match.") or "Loading items...") or ""
    local ok, err = pcall(self.paintMarks, self)
    if not ok then trouble("marking the item list", err) end
end

-- The shelves' headings: gold words ("Potions (1,214)") and a thin line to the box's right edge. Made once and reused.
local HEAD_RGBA = 0xD9B25FFF
function ItemBox:paintHeads(heads)
    for k, h in ipairs(heads) do
        local part = self.heads[k]
        if part == nil then
            part = { text = Kit.text(self.headLayer, 0, 0, 10, HEAD_H, "left"), line = Kit.rect(self.headLayer, 0, 0, 1, 1, FRAME_LINE) }
            pcall(function() part.text.rgba = HEAD_RGBA end)
            self.heads[k] = part
        end
        local words = self.shelves.label(h.key)
        local w = math.ceil(textWidth(words)) + 4
        part.text:SetSize(w, HEAD_H); part.text:SetPos(h.x, h.y - 2)
        part.text.content = plain(words)
        part.text.hidden = false
        local lx = h.x + w + 4
        part.line:SetPos(lx, h.y + HEAD_H // 2 - 2); part.line:SetSize(math.max(1, (self.w or 10) - lx - 6), 1)
        part.line.hidden = false
    end
    for k = #heads + 1, #self.heads do self.heads[k].text.hidden = true; self.heads[k].line.hidden = true end
    self.headLayer:SetPos(0, 0); self.headLayer:SetSize(self.w or 10, self.h or 10)
end

-- Marks behind the pictures. The item open on the right (box.selectedOf() gives its number) is marked strongly. The forms of
-- every open group (box.inGroup(place) gives the group's name) get a band, one for each run of them on a line. A band is open at
-- an end where the group goes on to the next line or comes from the last one, so the lines join up. In the rows view each row is
-- marked on its own.
-- How they look: the game's own resizable button frame in nine pieces (corners, edges, middle), tinted in the hover colour. A
-- band uses its hovered look and the item its pressed look. Should the game not have those pictures, see-through squares in the
-- hover colour are drawn instead. The parts come from pools (at most MAX_MARKS squares and MAX_PIECES pictures), made once and
-- reused, so a big open group cannot add many parts.
local MAX_MARKS, MAX_PIECES, SOFT, STRONG = 40, 160, 0.3, 0.65
MARK_NUDGE = MARK_NUDGE or 1
local markPics = nil
local function stylePics(style)
    if markPics == nil then
        markPics = {}
        pcall(function()
            local S = id.Sprite
            local function run(prefix, first, count) local t = {} for k = 0, count - 1 do t[k + 1] = S[prefix .. (first + k)] end return t end
            markPics.frame = { band = run("RS3_BTN_ICON_RESIZABLE_", 9, 9), sel = run("RS3_BTN_ICON_RESIZABLE_", 27, 9) }
        end)
        for name, set in pairs(markPics) do -- any picture missing: that style is drawn in colour
            for _, list in pairs(set) do
                for k = 1, #list do if type(list[k]) ~= "number" then markPics[name] = false end end
                if #list == 0 then markPics[name] = false end
            end
            if markPics[name] == false then say("the game has no pictures for the " .. name .. " marks in the item list; they are drawn in color") end
        end
    end
    return markPics[style] or nil
end

function ItemBox.forgetStylePics() markPics = nil end -- for the offline test

function ItemBox:paintMarks()
    local at, grid = self.picAt or {}, (self.mode == "icons")
    local usedR, usedP = 0, 0
    local c = HOVER_RGB or { 0.55, 1.0, 0.55 } -- the hover colour from the Settings page, green unless changed;
                                               -- the marks follow it rather than a fixed gold
    local tint = Vector4.new(c[1], c[2], c[3], 1.0) -- the game frame in that colour
    local function square(x, y, w, h, alpha)
        if usedR >= MAX_MARKS or w <= 0 or h <= 0 then return end
        usedR = usedR + 1
        local r = self.marks[usedR]
        if r == nil then r = Kit.rect(self.markLayer, 0, 0, 1, 1, WHITE); self.marks[usedR] = r end
        r.colour = Vector4.new(c[1], c[2], c[3], alpha)
        r:SetPos(x, y); r:SetSize(w, h); r.hidden = false
    end
    self.pieces = self.pieces or {}
    local function piece(pic, x, y, w, h)
        if usedP >= MAX_PIECES or w <= 0 or h <= 0 then return end
        usedP = usedP + 1
        local s = self.pieces[usedP]
        if s == nil then
            s = ui.Sprite.new(self.markLayer)
            s.colour = WHITE
            pcall(function() s.clickthrough = true end)
            self.pieces[usedP] = s
        end
        s.spriteID = pic
        s.colour = tint
        s:SetPos(x, y); s:SetSize(w, h); s.hidden = false
    end
    local pics = stylePics("frame")
    -- One box: a band (strong = false) or the item (true). openL and openR mean the band goes on from the line before or to the next.
    local function draw(x, y, w, h, strong, openL, openR)
        local list = pics and (strong and pics.sel or pics.band)
        if list == nil then square(x, y, w, h, strong and STRONG or SOFT) return end
        square(x, y, w, h, strong and 0.22 or 0.12) -- a faint fill inside the frame: the open group's tray
        if #list == 9 then -- nine pieces; an open end uses the middle column's pieces, so it has no edge there
            local k = math.max(2, math.min(8, math.min(w, h) // 4))
            local xs, ws = { x, x + k, x + w - k }, { k, w - 2 * k, k }
            local ys, hs = { y, y + k, y + h - k }, { k, h - 2 * k, k }
            for row = 1, 3 do
                for col = 1, 3 do
                    local from = col
                    if (col == 1 and openL) or (col == 3 and openR) then from = 2 end
                    piece(list[(row - 1) * 3 + from], xs[col], ys[row], ws[col], hs[row])
                end
            end
        elseif #list == 3 then -- left end, middle, right end
            local k = math.max(2, math.min(h // 3, w // 3))
            piece(openL and list[2] or list[1], x, y, k, h)
            piece(list[2], x + k, y, w - 2 * k, h)
            piece(openR and list[2] or list[3], x + w - k, y, k, h)
        else
            piece(list[1], x, y, w, h)
        end
    end
    local pad = grid and math.max(1, (GAP[self.size] or 2) // 2) or 2
    -- The game draws an item's picture a little up and to the left of the middle of its square, so in the grid the marks are moved up
    -- and left by NUDGE pixels for every 32 of picture size.
    local nudge = grid and math.max(1, math.floor((self.size or 32) * MARK_NUDGE / 32 + 0.5)) or 0
    local wide = nil -- the rows view: a mark covers the whole row, picture and name. Not written "grid and nil or ...", which is never nil
    if not grid then wide = ROW_W - 4 end
    local selected = (self.selectedOf ~= nil) and self.selectedOf() or nil
    local base, run, sel = self:placeOf(1) - 1, nil, nil
    local function keyAt(place) return (self.inGroup ~= nil) and self.inGroup(place) or nil end
    local function flush()
        if run == nil then return end
        local openL = grid and keyAt(run[6] - 1) == run[5]
        local openR = grid and keyAt(run[7] + 1) == run[5]
        draw(run[1] - pad - nudge, run[2] - pad - nudge, run[3] - run[1] + 2 * pad, run[4] - run[2] + 2 * pad, false, openL, openR)
        run = nil
    end
    for n = 1, self.perPage do
        local p = at[n]
        if p == nil then break end
        local line = grid and p[2] or n -- a line of the grid is told by its height on screen, since shelves move lines down
        local key = keyAt(base + n)
        if run ~= nil and (key ~= run[5] or line ~= run[8]) then flush() end
        if key ~= nil then
            local x2, y2 = p[1] + (wide or p[3]), p[2] + p[4]
            if run == nil then run = { p[1], p[2], x2, y2, key, base + n, base + n, line } else run[3], run[4], run[7] = x2, y2, base + n end
        end
        if sel == nil and selected ~= nil and Items.ids[self:at(n)] == selected then sel = p end
    end
    flush()
    if sel ~= nil then draw(sel[1] - pad - nudge, sel[2] - pad - nudge, (wide or sel[3]) + 2 * pad, sel[4] + 2 * pad, true, false, false) end
    for k = usedR + 1, #self.marks do self.marks[k].hidden = true end
    for k = usedP + 1, #self.pieces do self.pieces[k].hidden = true end
end

end }
