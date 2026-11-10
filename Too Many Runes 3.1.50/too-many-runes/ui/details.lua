-- Too Many Runes - The item details (the right-hand column)
--   top box      tabs (Recipe / Uses), the Back arrow (top right), and the open tab's rows
--   bottom box   the item's picture, name and favourite star, and its facts (data/info.lua)
-- The bottom box is exactly as tall as what it shows; the top box takes the rest of the column.
--
-- The tabs of the top box are a list, so adding one is one call (from any file loaded before the pages):
--   Details.setTab(key, label, function(itemId) return rows [, label] end)
-- Each row is plain text ("Materials:") or a table:
--   { text = "2 x Plank", icon = an item number }   a picture of the item; a click opens it (Back returns)
--   { text = "Made at: Furnace", pic = a sprite }    a picture beside the words (a crafting station)
-- The second answer, when given, is the tab's label for this item ("Guide", "Needs" ... instead of "Recipe").
-- (Calling setTab again with the same key replaces that tab's contents: recipes/recipe_tab.lua does that for the Recipe tab.)
-- When the rows do not all fit, the mouse wheel over the box scrolls them.
return { run = function(T)
local _ENV = T

Details = { TABS = {}, all = {} }
Details.__index = Details

-- widest (optional): the longest label the tab will ever show ("Uses (99+)"). (Since 3.0.88 the buttons are sized to their words instead.)
-- labelOf(itemId) (optional): the tab's words for an item while ANOTHER tab is open ("Uses (49)", "Recipe (3)", "Source (2)"), so they
-- change with every item.
function Details.setTab(key, label, render, widest, labelOf)
    for _, tab in ipairs(Details.TABS) do
        if tab.key == key then tab.label, tab.render, tab.widest, tab.labelOf = label, render, widest or tab.widest, labelOf return end
    end
    Details.TABS[#Details.TABS + 1] = { key = key, label = label, render = render, widest = widest, labelOf = labelOf }
end
local function notYet() return { "Uses are being moved over to", "the new window: they come back", "in the next stage." } end
Details.setTab("recipe", "Recipe", notYet)
Details.setTab("uses", "Uses", notYet)
Details.setTab("source", "Source", notYet) -- (filled in by recipes/source_tab.lua)

-- Show the open tab of every details column again (the recipe files call this when they finish reading something).
function Details.refreshAll()
    for _, d in ipairs(Details.all) do
        if d.itemId ~= nil then pcall(d.showTab, d, d.tab, true) end
    end
end

local HEADER_H, ICON_W, ICON_H, STAR = 42, 36, 32, 24
-- The tabs sit on top of the box, as the game's tabs sit on a panel; the back arrow is at the right end of the tab row.
local DETAILS_STYLE = (DETAILS_TAB_STYLE ~= nil and Kit.gameTabsReady()) and DETAILS_TAB_STYLE or nil
local TABS_ROW = (DETAILS_STYLE == "big") and 42 or ((DETAILS_STYLE == "small") and math.max(20, math.min(42, tonumber(DETAILS_TAB_ROW) or 32)) or 24)
-- The box is one thin-lined square. Its top line is where the open tab's picture ends (39 of the picture's 60); the tab pictures are cut
-- off at that line (ui/kit.lua, Kit.gameTab), the closed tabs stand on it and the open one reaches one pixel past it, joining the box.
local BOX_AT = (DETAILS_STYLE ~= nil) and math.floor(math.floor(60 * TABS_ROW / 42 + 0.5) * 39 / 60 + 0.5) or TABS_ROW -- where the box starts
local BODY_Y = 6                                    -- where the rows of the top box start
local ROW_ICON_W, ROW_ICON_H, PIC_ROW_H = 27, 24, 26 -- a row with a picture: the picture's size and the row's height
local TWO_LINE_EXTRA = 16 -- (an item button whose words take two lines is this much taller)
local BUTTON_PAD = 26     -- (a button keeps this much of its width free around its words)
local SLOTS_PER_LAYER, MAX_SLOTS = 8, 40            -- rows are kept in small layers of 8; never more than 40 rows on screen
local SITE_ICON, SITE_GAP, SITE_MAX = 40, 6, 9      -- the dig sites' pictures (Source tab): 40 x 40 (smaller when many), at most 9
local HEADING_RGBA = 0xD9B25FFF                     -- a line ending in ":" ("Materials:") is drawn in gold
local STARS = try(function()
    local s = id.Sprite
    return { off = { normal = s.RAND_SPEEDRUN_STAR_SILVER_0, hover = s.RAND_SPEEDRUN_STAR_BRONZE_0, w = STAR, h = STAR },
             on  = { normal = s.RAND_SPEEDRUN_STAR_GOLD_0, hover = s.RAND_SPEEDRUN_STAR_GOLD_0, w = STAR, h = STAR } }
end)

function Details.new(parent)
    local d = setmetatable({ itemId = nil, history = {}, info = {}, infoTexts = {}, rows = {}, slots = {}, rowLayers = {}, scroll = 0,
                             x = 0, y = 0, w = 200, h = 200 }, Details)
    Details.all[#Details.all + 1] = d
    -- (one wheel notch reaches every part under the mouse - the words, their layer and the box - so only the first one in a tick counts)
    d.wheel = function(step)
        if d.wheelTick == tickCount then return end
        d.wheelTick = tickCount
        -- (3 lines a notch; a long list - a bar's uses can be hundreds - goes almost a box at a time)
        d:scrollBy(step * (((d.lineCount or 0) > 60) and math.max(3, (d.visible or 3) - 1) or 3))
    end
    d.top, d.bottom = Kit.frame(parent), Kit.frame(parent)
    local top, bottom = d.top.inner, d.bottom.inner

    d.tab = Saved.get("details_tab") or Details.TABS[1].key
    d.tabs = Kit.tabStrip(parent, TABS_ROW, function(key) d:showTab(key) end, DETAILS_TAB_STYLE) -- (the game's tab pictures: DETAILS_TAB_STYLE, settings.lua)
    d.tabs.cut = BOX_AT -- (the tab pictures end at the box's top line: ui/kit.lua, Kit.gameTab)
    for _, tab in ipairs(Details.TABS) do d.tabs:add(tab.key, tab.label, math.ceil(textWidth(tab.widest or tab.label) + 20)) end
    d.back = Kit.picture(parent, BACK_SPRITES, function() d:goBack() end)
    d.back:setUsable(false)
    Kit.wheel(top, d.wheel)

    d.icon = Kit.itemIcon(bottom, ICON_W, ICON_H)
    d.name = { Kit.text(bottom, 0, 0, 10, LINE_H, "left"), Kit.text(bottom, 0, 0, 10, LINE_H, "left") }
    if STARS ~= nil then
        d.star = Kit.picture(bottom, STARS.off, function()
            if d.itemId ~= nil then Filters.toggleFavourite(d.itemId); d:paintStar() end
        end)
        d.star:show(false)
    end
    return d
end

function Details:place(x, y, w, h)
    self.x, self.y, self.w, self.h = x, y, w, h
    self:arrange()
end

-- Size the two boxes and put their contents in place.
function Details:arrange()
    local w = self.w
    local n = #self.infoLines
    local infoH = (self.itemId == nil) and 40 or math.min(HEADER_H + n * LINE_H + 8, self.h - 140)
    local tabsY = self.y
    self.top:place(self.x, tabsY + BOX_AT, w, self.h - infoH - 6 - BOX_AT)
    self.bottom:place(self.x, self.y + self.h - infoH, w, infoH)

    -- the tabs on top of the top box, the back arrow at the row's right end
    self.tabs:place(self.x + 4, tabsY)
    self.tabs.maxW = w - 36 -- (the tabs' words carry a count - "Recipe (3)", "Uses (99+)" - so they are fitted in: ui/kit.lua)
    self.tabs:fit()
    self.back:place(self.x + w - 28, tabsY + math.max(0, (BOX_AT - 24) // 2))
    self:layoutRows()

    -- bottom box: header
    self.icon:SetPos(6, (HEADER_H - ICON_H) // 2)
    local nameW = w - 2 - 46 - STAR - 10
    local name = self.nameLines or {}
    local y1 = (#name > 1) and 1 or (HEADER_H - LINE_H) // 2
    for k = 1, 2 do
        self.name[k]:SetSize(nameW, LINE_H)
        self.name[k]:SetPos(46, y1 + (k - 1) * LINE_H)
    end
    if self.star ~= nil then self.star:place(w - 2 - STAR - 6, (HEADER_H - STAR) // 2) end

    -- bottom box: lines (or the note when nothing is open)
    local top = (self.itemId == nil) and ((infoH - 2 - LINE_H) // 2) or HEADER_H
    local align = (self.itemId == nil) and "centre" or "left"
    for k = 1, n do
        local t = self.infoTexts[k]
        if t == nil or t.align ~= align then
            if t ~= nil then t.text.hidden = true end
            t = { text = Kit.text(self.bottom.inner, 0, 0, 10, LINE_H, align), align = align }
            self.infoTexts[k] = t
        end
        t.text:SetSize(w - 18, LINE_H)
        t.text:SetPos(8, top + (k - 1) * LINE_H)
        t.text.content = plain(self.infoLines[k])
        t.text.hidden = false
    end
    for k = n + 1, #self.infoTexts do self.infoTexts[k].text.hidden = true end
end

-- The lines of the bottom box: the facts, each wrapped to the box's width.
function Details:buildInfoLines()
    local lines, room = {}, self.w - 20
    if self.itemId == nil then
        self.infoLines = { "Click an item to see it here." }
        return
    end
    for _, line in ipairs(self.info) do
        for _, part in ipairs(wrapText(line, room)) do lines[#lines + 1] = part end
    end
    self.infoLines = lines
end
Details.infoLines = { "Click an item to see it here." }

function Details:renderInfo()
    self:buildInfoLines()
    self:arrange()
end

-- Read the Info box again for every open item (a setting that changes it was switched: SHOW_DEBUG_NAMES).
function Details.refreshInfo()
    for _, d in ipairs(Details.all or {}) do
        if d.itemId ~= nil then
            pcall(function()
                d.info = Info.lines(d.itemId) or d.info
                d:renderInfo()
            end)
        end
    end
end

function Details:paintStar()
    if self.star == nil then return end
    self.star:show(self.itemId ~= nil)
    self.star:setPics(Filters.isFavourite(self.itemId) and STARS.on or STARS.off)
end

-- Open an item. keepTrail = true when it was reached from inside the details (an ingredient, a use): Back can then return.
function Details:open(itemId, keepTrail)
    if not self.noRecent and Recent ~= nil then Recent.add(itemId) end -- (pages/recent.lua)
    if keepTrail and self.itemId ~= nil then
        self.history[#self.history + 1] = self.itemId
        if #self.history > 30 then table.remove(self.history, 1) end
    elseif not keepTrail then
        self.history = {}
    end
    self.back:setUsable(#self.history > 0)
    self.itemId = itemId
    local lines, item = Info.lines(itemId)
    self.info = lines or { "The game has no item " .. itemId .. "." }

    -- the header: picture and name (two lines if it is long)
    self.icon.hidden = not Kit.setItem(self.icon, itemId)
    local name = (item ~= nil and field(item, "name")) or ("Item " .. itemId)
    local parts = wrapText(name, self.w - 2 - 46 - STAR - 10)
    if #parts > 2 then parts[2] = fitText(table.concat(parts, " ", 2), self.w - 2 - 46 - STAR - 10); parts[3] = nil end
    self.nameLines = parts
    for k = 1, 2 do self.name[k].content = plain(parts[k] or "") end
    self:paintStar()
    self:renderInfo()
    self:showTab(self.tab)
end

function Details:goBack()
    local last = table.remove(self.history)
    if last ~= nil then
        local trail = self.history
        self:open(last, false)
        self.history = trail
        self.back:setUsable(#trail > 0)
    end
end

-- Open a tab of the top box. keepScroll = true: the same item is shown again (new data came in), so stay where the wheel left it.
function Details:showTab(key, keepScroll)
    local tab = nil
    for _, t in ipairs(Details.TABS) do if t.key == key then tab = t end end
    tab = tab or Details.TABS[1]
    self.tab = tab.key
    Saved.set("details_tab", tab.key)
    self.tabs:select(tab.key)
    local rows, label = {}, nil
    if self.itemId ~= nil then
        local ok, result, tabLabel = pcall(tab.render, self.itemId)
        if ok and type(result) == "table" then rows, label = result, tabLabel
        elseif not ok then trouble("the " .. tab.label .. " tab", result); rows = { "Something went wrong here (see the console)." } end
    end
    self.tabs:setLabel(tab.key, (type(label) == "string") and label or tab.label)
    -- the other tabs' words for this item (the Uses tab's count)
    for _, t in ipairs(Details.TABS) do
        if t ~= tab then
            local other = nil
            if self.itemId ~= nil and t.labelOf ~= nil then
                local okL, l = pcall(t.labelOf, self.itemId)
                if okL then other = l end
            end
            self.tabs:setLabel(t.key, (type(other) == "string") and other or t.label)
        end
    end
    self.rows, self.lineCache = rows, nil
    if not keepScroll then self.scroll = 0 end
    self:arrange()
end

-- THE ROWS OF THE TOP BOX
-- The rows are turned into lines that fit the box (long words wrap onto more lines), and the lines from self.scroll on are drawn into
-- "slots": a slot is one line on screen with its parts (words, and a picture or button when that line needs one), made the first time
-- they are needed and then reused, never destroyed.

-- The rows as lines: { text, kind = "text" / "item" / "pic", id = item number, pic = sprite, h = height, heading = true }.
function Details:rowLines()
    local width = self.top.w or 200
    if self.lineCache ~= nil and self.lineCacheW == width then return self.lineCache end -- (worked out once per item and width)
    local lines = {}
    for _, row in ipairs(self.rows or {}) do
        if type(row) ~= "table" then row = { text = row } end
        local text = tostring(row.text or "")
        if type(row.sites) == "table" and #row.sites > 0 then
            -- the dig sites: their pictures side by side, and under them the name of the one the mouse is over
            lines[#lines + 1] = { kind = "sites", sites = row.sites, text = "", indent = 10, h = SITE_ICON + LINE_H + 8 }
        elseif type(row.icon) == "number" then
            -- an item button: its words on two lines (a taller button) when they do not fit on one (3.0.55: "Meteorite cannonball
            -- (level ..." was cut off)
            local room = width - ROW_ICON_W - 22 - BUTTON_PAD -- (the button's own words have less room than the button: 3.0.55 was cut)
            text = string.gsub(text, "%s+", " ") -- (one space between words, as the lines are measured: 3.0.59 made a two-line button
                                                  -- for "Super attack mix (2)  (level 47)", whose words then fitted on one line)
            if textWidth(text) <= room then
                lines[#lines + 1] = { kind = "item", id = row.icon, text = text, h = PIC_ROW_H }
            else
                local parts = wrapText(text, room)
                if #parts <= 1 then
                    lines[#lines + 1] = { kind = "item", id = row.icon, text = fitText(text, room), h = PIC_ROW_H }
                else
                    local rest = fitText(table.concat(parts, " ", 2), room)
                    lines[#lines + 1] = { kind = "item", id = row.icon, text = fitText(parts[1], room), text2 = rest, h = PIC_ROW_H + TWO_LINE_EXTRA }
                end
            end
        else
            local hasPic = type(row.pic) == "number"
            local indent = hasPic and (ROW_ICON_W + 12) or 10
            for k, part in ipairs(wrapText(text, width - indent - 8)) do
                local line = { kind = "text", text = part, indent = indent, h = LINE_H }
                if k == 1 and hasPic then
                    line.kind, line.pic, line.h = "pic", row.pic, PIC_ROW_H
                    -- a picture that searches ("Made at: Furnace" -> "@furnace", a skill on the Source tab -> "@mining"): click the picture
                    if type(row.query) == "string" and row.query ~= "" then line.query = row.query end
                end
                if string.sub(part, -1) == ":" then line.heading = true end
                lines[#lines + 1] = line
            end
            if text == "" then lines[#lines + 1] = { kind = "text", text = "", indent = 10, h = LINE_H } end
        end
    end
    self.lineCache, self.lineCacheW = lines, width
    return lines
end

-- Slot k (made when first needed; in layers of 8 so no layer gets a long list of parts).
function Details:slot(k)
    local s = self.slots[k]
    if s ~= nil then return s end
    local L = (k - 1) // SLOTS_PER_LAYER + 1
    local layer = self.rowLayers[L]
    if layer == nil then
        layer = ui.Layer.new(self.top.inner)
        layer:SetPos(0, 0); layer:SetSize(self.top.w or 200, self.top.h or 200)
        self.rowLayers[L] = layer
        Kit.wheel(layer, self.wheel)
    end
    s = { layer = layer }
    self.slots[k] = s
    return s
end

-- The words of a slot (and its button and pictures, made only when a line needs them).
local function slotText(s)
    if s.text == nil then
        s.text = Kit.text(s.layer, 0, 0, 10, LINE_H, "left")
        Kit.wheel(s.text, s.wheel)
    end
    return s.text
end
function Details:slotButton(s, width)
    if s.button == nil then
        s.button = Kit.button(s.layer, "", width, ROW_ICON_H, function() if s.itemId ~= nil then self:open(s.itemId, true) end end)
        -- (the colour of a button's words, read from a brand-new one - not under the mouse or pressed - for the two-line words: 3.0.90)
        if Details.wordsRGBA == nil then pcall(function() Details.wordsRGBA = s.button.sb.content.rgba end) end
        Kit.wheel(s.button:root(), self.wheel)
    end
    return s.button
end
-- The two lines of words for a two-line item button (made the first time a slot needs them). 3.0.90: they are made INSIDE the button
-- (so they move with it when it is drawn in front - some two-line buttons showed blank) and in the colour of a fresh button's words.
function Details:slotWords(s, b)
    if s.words == nil then
        local ok, a, c = pcall(function()
            return Kit.text(b:root(), 0, 0, 10, LINE_H, "center"), Kit.text(b:root(), 0, 0, 10, LINE_H, "center")
        end)
        if ok and a ~= nil and c ~= nil then s.words, s.wordsInButton = { a, c }, true
        else s.words, s.wordsInButton = { Kit.text(s.layer, 0, 0, 10, LINE_H, "center"), Kit.text(s.layer, 0, 0, 10, LINE_H, "center") }, false end
        local colour = Details.wordsRGBA
        if colour == nil then pcall(function() colour = b.sb.content.rgba end) end
        for _, t in ipairs(s.words) do
            pcall(function() t.clickthrough = true end)
            if colour ~= nil then pcall(function() t.rgba = colour end) end
        end
    end
    return s.words[1], s.words[2]
end
function Details:slotIcon(s)
    if s.icon == nil then
        s.icon = Kit.itemIcon(s.layer, ROW_ICON_W, ROW_ICON_H)
        Kit.wheel(s.icon, self.wheel)
        s.icon:Subscribe(ui.Hook.ONMOUSEOVER, function() Kit.hoverIn(s.icon) return true end) -- (the outline and the colour: ui/kit.lua)
        s.icon:Subscribe(ui.Hook.ONMOUSELEAVE, function() Kit.hoverOut(s.icon) return true end)
        s.icon:Subscribe(ui.Hook.ONCLICK, function() if s.itemId ~= nil then self:open(s.itemId, true) end return false end)
    end
    return s.icon
end
-- The dig sites' pictures of a slot (made when first needed): the mouse over one shows its "over" picture (or turns it gold) and its name
-- under the row; a click searches for everything found there ("@kharid-et").
local function sitePic(s, j)
    s.sitePics = s.sitePics or {}
    local p = s.sitePics[j]
    if p ~= nil then return p end
    p = ui.Sprite.new(s.layer)
    p:SetSize(SITE_ICON, SITE_ICON)
    p.colour = WHITE
    Kit.wheel(p, s.wheel)
    p:Subscribe(ui.Hook.ONMOUSEOVER, function()
        local e = s.siteEntries and s.siteEntries[j]
        if e ~= nil then
            if e.over ~= nil then pcall(function() p.spriteID = e.over end); Kit.itemOutline(p, true) else Kit.hoverIn(p) end
            if s.caption ~= nil then s.caption.content = plain(e.name or "") end
        end
        return true
    end)
    p:Subscribe(ui.Hook.ONMOUSELEAVE, function()
        local e = s.siteEntries and s.siteEntries[j]
        if e ~= nil then pcall(function() p.spriteID = e.pic end) end
        Kit.hoverOut(p)
        if s.caption ~= nil then s.caption.content = "" end
        return true
    end)
    p:Subscribe(ui.Hook.ONCLICK, function()
        local e = s.siteEntries and s.siteEntries[j]
        if e ~= nil and e.query ~= nil and Window ~= nil and Window.runSearch ~= nil then Window.runSearch(e.query) end
        return false
    end)
    s.sitePics[j] = p
    return p
end
local function hideSites(s)
    for _, p in ipairs(s.sitePics or {}) do p.hidden = true end
    if s.caption then s.caption.hidden = true end
    s.siteEntries = nil
end

local function slotPic(s)
    if s.pic == nil then
        s.pic = ui.Sprite.new(s.layer)
        s.pic:SetSize(ROW_ICON_H, ROW_ICON_H)
        s.pic.colour = WHITE
        Kit.wheel(s.pic, s.wheel)
        -- a picture with a search word lights up under the mouse, and a click searches for it (Window.runSearch, ui/window.lua)
        s.pic:Subscribe(ui.Hook.ONMOUSEOVER, function() if s.query ~= nil then Kit.hoverIn(s.pic) end return true end)
        s.pic:Subscribe(ui.Hook.ONMOUSELEAVE, function() Kit.hoverOut(s.pic) return true end)
        s.pic:Subscribe(ui.Hook.ONCLICK, function()
            if s.query ~= nil and Window ~= nil and Window.runSearch ~= nil then Window.runSearch(s.query) end
            return false
        end)
    end
    return s.pic
end

-- Draw the lines from self.scroll on, as many as fit. When some do not fit, the last line says so and the wheel scrolls.
function Details:layoutRows()
    local lines = self:rowLines()
    self.lineCount = #lines
    local room = (self.top.h or 0) - BODY_Y - 2
    local total = 0
    for _, l in ipairs(lines) do total = total + l.h end
    -- how far down the wheel may go: until the last line is on screen (with the "more" line above it)
    local maxScroll = 0
    if total > room then
        local hFromEnd = LINE_H
        maxScroll = #lines
        while maxScroll > 0 and hFromEnd + lines[maxScroll].h <= room do
            hFromEnd = hFromEnd + lines[maxScroll].h
            maxScroll = maxScroll - 1
        end
    end
    self.scroll = math.max(0, math.min(self.scroll or 0, maxScroll))
    self.maxScroll = maxScroll

    local y, k, first = BODY_Y, 0, self.scroll + 1
    local w = self.top.w or 200
    -- (a layer with no size shows nothing: each row layer covers the whole box)
    for _, layer in ipairs(self.rowLayers) do layer:SetPos(0, 0); layer:SetSize(w, self.top.h or 200) end
    local shownLast = first - 1
    for i = first, #lines do
        local l = lines[i]
        local needsMore = (i < #lines) and (total > room) -- (keep a line free for "more below" unless this is the very last line)
        if y + l.h + (needsMore and LINE_H or 0) > BODY_Y + room or k >= MAX_SLOTS - 1 then break end
        k = k + 1
        self:drawLine(self:slot(k), l, y, w)
        y = y + l.h
        shownLast = i
    end
    self.visible = k
    if shownLast < #lines or self.scroll > 0 then
        local more = #lines - shownLast
        k = k + 1
        local s = self:slot(k)
        s.wheel = self.wheel
        local text = (more > 0) and ("(scroll down: " .. more .. " more " .. ((more == 1) and "line" or "lines") .. ")") or "(scroll up for the start)"
        self:drawLine(s, { kind = "text", text = text, indent = 10, h = LINE_H, note = true }, y, w)
    end
    for j = k + 1, #self.slots do self:hideSlot(self.slots[j]) end
end

function Details:scrollBy(step)
    if self.maxScroll == nil or self.maxScroll == 0 then return end
    local before = self.scroll
    self.scroll = math.max(0, math.min(self.scroll + step, self.maxScroll))
    if self.scroll ~= before then self:layoutRows() end
end

function Details:hideSlot(s)
    s.itemId, s.query = nil, nil
    hideSites(s)
    if s.text then s.text.hidden = true end
    if s.button then s.button:show(false) end
    if s.words then s.words[1].hidden, s.words[2].hidden = true, true end
    if s.icon then s.icon.hidden = true end
    if s.pic then s.pic.hidden = true end
end

function Details:drawLine(s, l, y, w)
    s.wheel = self.wheel
    local t = slotText(s)
    s.query = l.query -- (a picture that searches; nil for every other line)
    if l.kind == "sites" then
        s.itemId = nil
        t.hidden = true
        if s.icon then s.icon.hidden = true end
        if s.button then s.button:show(false) end
        if s.words then s.words[1].hidden, s.words[2].hidden = true, true end
        if s.pic then s.pic.hidden = true end
        local n = math.min(#l.sites, SITE_MAX)
        local size = math.max(24, math.min(SITE_ICON, math.floor((w - 20 - (n - 1) * SITE_GAP) / n)))
        local x = math.max(4, math.floor((w - (n * size + (n - 1) * SITE_GAP)) / 2))
        local top = y + 2 + (SITE_ICON - size) // 2
        s.siteEntries = l.sites
        for j = 1, n do
            local p = sitePic(s, j)
            p:SetSize(size, size)
            p:SetPos(x + (j - 1) * (size + SITE_GAP), top)
            pcall(function() p.spriteID = l.sites[j].pic; p.colour = WHITE end)
            p.hidden = false
        end
        for j = n + 1, #(s.sitePics or {}) do s.sitePics[j].hidden = true end
        if s.caption == nil then
            s.caption = Kit.text(s.layer, 0, 0, 10, LINE_H) -- (centred: the name of the dig site under the mouse)
            Kit.wheel(s.caption, s.wheel)
        end
        s.caption:SetSize(w - 10, LINE_H)
        s.caption:SetPos(5, y + SITE_ICON + 5)
        s.caption.content = ""
        s.caption.hidden = false
        return
    end
    hideSites(s)
    if l.kind == "item" then
        s.itemId = l.id
        local icon = self:slotIcon(s)
        icon:SetPos(8, y + (l.h - ROW_ICON_H) // 2)
        icon.hidden = not Kit.setItem(icon, l.id)
        local bw = w - ROW_ICON_W - 22
        local bh = (l.text2 ~= nil) and (ROW_ICON_H + TWO_LINE_EXTRA) or ROW_ICON_H
        local b = self:slotButton(s, bw)
        if b.w ~= bw or b.h ~= bh then b.w, b.h = bw, bh; pcall(function() b.sb.root:SetSize(bw, bh) end) end -- (only when it changed)
        local by = y + (l.h - bh) // 2
        b:place(ROW_ICON_W + 14, by)
        if l.text2 ~= nil then
            -- two lines: the button's own words cannot break a line (3.0.56 showed one cut-off line), so two lines of our own lie on
            -- top of an empty button (the mouse goes through them to it)
            b:setLabel("")
            local t1, t2 = self:slotWords(s, b)
            local ox, oy = ROW_ICON_W + 14, by -- (where the button is; 0, 0 when the words are inside it)
            if s.wordsInButton then ox, oy = 0, 0 end
            t1:SetPos(ox, oy + bh // 2 - LINE_H + 1); t1:SetSize(bw, LINE_H)
            t2:SetPos(ox, oy + bh // 2 - 1);          t2:SetSize(bw, LINE_H)
            t1.content, t2.content = plain(l.text), plain(l.text2)
            t1.hidden, t2.hidden = false, false
            pcall(function() t1:MoveToFront(); t2:MoveToFront() end) -- (in front of the button's own parts)
        else
            b:setLabel(plain(l.text))
            if s.words then s.words[1].hidden, s.words[2].hidden = true, true end
        end
        b:show(true)
        t.hidden = true
        if s.pic then s.pic.hidden = true end
        return
    end
    s.itemId = nil
    if s.icon then s.icon.hidden = true end
    if s.button then s.button:show(false) end
    if s.words then s.words[1].hidden, s.words[2].hidden = true, true end
    if l.kind == "pic" then
        local p = slotPic(s)
        pcall(function() p.colour = WHITE end)
        p:SetPos(10, y + (PIC_ROW_H - ROW_ICON_H) // 2)
        pcall(function() p.spriteID = l.pic end)
        p.hidden = false
    elseif s.pic then
        s.pic.hidden = true
    end
    t:SetSize(w - l.indent - 6, l.h)
    t:SetPos(l.indent, y)
    t.content = plain(l.text)
    pcall(function() t.rgba = l.heading and HEADING_RGBA or TEXT_RGBA end)
    pcall(function() t.alpha = l.note and 0.7 or 1.0 end)
    t.hidden = false
end

end }
