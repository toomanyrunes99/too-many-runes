-- Too Many Runes - The item box
-- A framed box that shows one page of a list of items, as a grid of pictures (the name shows when the mouse is over one) or as rows
-- (picture + name), in as many columns as fit. It fills whatever room it is given, so a bigger window shows more items per page.
-- Any tab can use one:  box = ItemBox.new(layer, onPick)   box:place(x, y, w, h)   box:setList(slots)   box:render()
--
-- The game allows a plugin about 4,000 parts on screen in all (3.0.01: "invalid dynamic ID, expected a value between 0 and 4096"), so
-- a picture is just one part: its name is shown by the window's one shared hover label, a page holds at most MAX_PICTURES pictures
-- (MAX_ROWS rows in the rows view), and the rows' buttons are a fixed width so they never have to be made again.
-- ONE SET OF PARTS FOR EVERY VIEW: picture number n of the page is always the same part, whatever the view (16, 32, 48, 64 or rows) and
-- however big the window is: it is just moved and resized. (3.0.11 kept a separate picture for every line and column it had ever used,
-- so switching views and resizing kept adding parts until the game refused to make more.) So the box never holds more than
-- MAX_PICTURES pictures and MAX_ROWS buttons. (The parts sit in small layers of PER_LAYER each, to keep each layer's list short.)
return { run = function(T)
local _ENV = T

ItemBox = {}
ItemBox.__index = ItemBox

-- New pictures are made at most NEW_PER_TICK a game tick: making a whole 16-pixel page (about 1,000) in one go froze the game for a
-- moment on every reload. A page that is not finished is finished on the next ticks (ItemBox.tick, called by the clock in start.lua);
-- pictures are kept once made, so turning pages costs nothing extra.
ItemBox.NEW_PER_TICK, ItemBox.made, ItemBox.waiting = 150, 0, {}
function ItemBox.tick()
    ItemBox.made = 0
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
local ROW_H, ROW_W, ICON_W, ICON_H = 34, 220, 36, 32 -- (ROW_W: the width of one column of rows)

function ItemBox.new(parent, onPick)
    local box = setmetatable({ frame = Kit.frame(parent), onPick = onPick, list = {}, page = 1, perPage = 1,
                               pics = {}, picLayers = {}, buttons = {}, buttonLayers = {}, rowW = 0 }, ItemBox)
    box.note = Kit.text(box.frame.inner, 0, 0, 10, 22) -- "No items match." when the list is empty
    -- (the wheel: up = next page, down = the page before; WHEEL_UP_NEXT = false turns it round. One wheel notch reaches every part under
    -- the mouse - the picture, its layer and the box - so only the first one in a tick turns the page: 3.0.05 went 1, 4, 7, 10.)
    box.wheel = function(step)
        if box.wheelTick == tickCount then return end
        box.wheelTick = tickCount
        box:turn((WHEEL_UP_NEXT == false) and step or -step)
    end
    Kit.wheel(box.frame.inner, box.wheel)
    return box
end

-- Work out how many columns and rows fit (from the box's size and the view), keeping the first item of the page on screen.
function ItemBox:place(x, y, w, h)
    local first = (self.page - 1) * self.perPage + 1
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
            -- More would fit than a page may hold (MAX_PICTURES): fewer columns and rows, spread out with extra space between them so the
            -- pictures still fill the box. (The pictures stay their size; only the gaps grow.)
            local even = math.sqrt((w - 8) * (h - 8) / cap)
            cols, rows = math.max(1, math.floor((w - 8) / even)), math.max(1, math.floor((h - 8) / even))
            while true do -- (take any extra column or row that still keeps the page within the limit)
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
        local rowW = ROW_W - 4 -- (the width a row really uses: picture, gap, button)
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
    self.ox, self.oy = x + 1, y + 1 -- (the box's inside, from the page's top left: for the hover label)
    self.perPage = self.cols * self.rows
    self.page = (first - 1) // self.perPage + 1
    self.note:SetSize(w, 22)
    self.note:SetPos(0, h // 2 - 11)
end

function ItemBox:pageCount() return math.max(1, math.ceil(#self.list / self.perPage)) end
function ItemBox:at(i) return self.list[(self.page - 1) * self.perPage + i] end
function ItemBox:setList(list, toFirstPage)
    self.list = list
    if toFirstPage then self.page = 1 end
end
function ItemBox:goTo(n) self.page = n; self:render() end

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

-- Picture n of the page (the same part in every view). Its item is worked out when it is clicked or pointed at, so it is always the one
-- shown. (nil when no more may be made this tick: the page is then finished on the next tick.)
function ItemBox:pic(n)
    local s = self.pics[n]
    if s ~= nil then return s end
    if n > (MAX_PICTURES or 1200) or not mayMake(1) then return nil end
    s = Kit.itemIcon(layerFor(self, self.picLayers, n), 32, 32)
    self.pics[n] = s
    Kit.wheel(s, self.wheel)
    s:Subscribe(ui.Hook.ONMOUSEOVER, function()
        Kit.hoverIn(s)
        local slot = self:at(n)
        local at = self.picAt and self.picAt[n]
        if slot ~= nil and at ~= nil then -- (an outline round it: 3.0.79)
            self.outline = self.outline or Kit.outline(self.frame.inner)
            pcall(function() self.outline:show(at[1], at[2], at[3], at[4]) end)
        end
        if slot ~= nil and at ~= nil and self.mode == "icons" then -- (the rows show the name already)
            local text = Items.names[slot] .. " (" .. Items.ids[slot] .. ")"
            if self.hover ~= nil then -- (a box outside the window - the Recently viewed panel - has a label of its own)
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
        if self.outline ~= nil then pcall(function() self.outline:hide() end) end
        pcall(Window.hideHover)
        if self.hoverHide ~= nil then pcall(self.hoverHide) end
        return true
    end)
    s:Subscribe(ui.Hook.ONCLICK, function()
        local slot = self:at(n)
        if slot ~= nil then self.onPick(Items.ids[slot]) end
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
        if slot ~= nil then self.onPick(Items.ids[slot]) end
    end)
    self.buttons[n] = b
    Kit.wheel(b:root(), self.wheel)
    return b
end

-- Show the current page. (A part that cannot be made is reported once in the console and left out; the rest of the page still shows.)
function ItemBox:render()
    pcall(Window.hideHover) -- (the pictures are about to change under the mouse)
    if self.outline ~= nil then pcall(function() self.outline:hide() end) end
    local pages = self:pageCount()
    if self.page > pages then self.page = pages end
    if self.page < 1 then self.page = 1 end
    local grid = (self.mode == "icons")
    for _, layer in pairs(self.picLayers) do layer:SetSize(self.w, self.h) end
    for _, layer in pairs(self.buttonLayers) do layer:SetSize(self.w, self.h); layer.hidden = grid end
    self.picAt = {}
    local shown = 0
    for n = 1, self.perPage do
        local slot = self:at(n)
        if slot == nil then break end
        local x, y
        if grid then
            local r, c = (n - 1) // self.cols + 1, (n - 1) % self.cols + 1
            x, y = self.left + (c - 1) * self.stepX, self.top + (r - 1) * self.stepY
        else
            local c, r = (n - 1) // self.rows + 1, (n - 1) % self.rows + 1 -- (filled down the first column, then the next, like a newspaper)
            x, y = self.left + (c - 1) * self.colStep, self.top + (r - 1) * self.rowStep
        end
        local ok, err = pcall(function()
            local s = self:pic(n)
            local b = (not grid) and self:button(n) or nil
            if s == nil or (not grid and b == nil) then ItemBox.waiting[self] = true return end -- (finished on the next tick)
            self.picAt[n] = { x, y, grid and self.size or ICON_W, grid and self.size or ICON_H }
            if grid then s:SetSize(self.size, self.size) else s:SetSize(ICON_W, ICON_H) end
            s:SetPos(x, y)
            Kit.hoverOut(s)
            s.hidden = not Kit.setItem(s, Items.ids[slot])
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
    self.shown = math.max(0, math.min(self.perPage, #self.list - (self.page - 1) * self.perPage))
    self.note.content = (#self.list == 0) and (Items.loaded and (self.emptyText or "No items match.") or "Loading items...") or ""
end

end }
