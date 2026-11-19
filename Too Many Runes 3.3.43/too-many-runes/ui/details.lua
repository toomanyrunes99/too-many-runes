-- Too Many Runes - The item details (the right-hand column)
--   header box   the item's picture, name and favourite star, and a short line of facts
--   tabs' box    tabs (Recipe / Uses / Source), the Back arrow (top right), and the open tab's rows
--   Info box     the rest of the item's facts (data/info.lua); the ID, value and right-click lines are dim
-- The Info box is exactly as tall as what it shows (hidden with nothing); the tabs' box takes the rest of the column.
--
-- The tabs of the top box are a list, so adding one is one call (from any file loaded before the pages):
--   Details.setTab(key, label, function(itemId) return rows [, label] end)
-- Each row is plain text ("Materials:") or a table:
--   { text = "2 x Plank", icon = an item number }   a picture of the item; a click opens it (Back returns)
--   { text = "Made at: Furnace", pic = a sprite }    a picture beside the words (a crafting station); picW, picH give its size
--                                                     when it is not the usual square, as with the RuneScape Wiki's button
-- The second answer, when given, is the tab's label for this item ("Guide", "Needs" ... instead of "Recipe").
-- Calling setTab again with the same key replaces that tab's contents: recipes/recipe_tab.lua does that for the Recipe tab.
-- When the rows do not all fit, the mouse wheel over the box scrolls them.
return { run = function(T)
local _ENV = T

Details = { TABS = {}, all = {} }
Details.__index = Details

-- Adds a tab to the top box. widest (optional) is the longest label the tab will ever show ("Uses (99+)"); the buttons are
-- sized to their words instead. labelOf(itemId) (optional) gives the tab's words for an item while another tab is open
-- ("Uses (49)", "Recipe (3)", "Source (2)"), so they change with every item.
function Details.setTab(key, label, render, widest, labelOf)
    for _, tab in ipairs(Details.TABS) do
        if tab.key == key then tab.label, tab.render, tab.widest, tab.labelOf = label, render, widest or tab.widest, labelOf return end
    end
    Details.TABS[#Details.TABS + 1] = { key = key, label = label, render = render, widest = widest, labelOf = labelOf }
end
local function notYet() return { "Uses are being moved over to", "the new window: they come back", "in the next stage." } end
Details.setTab("recipe", "Recipe", notYet)
Details.setTab("uses", "Uses", notYet)
Details.setTab("source", "Source", notYet) -- filled in by recipes/source_tab.lua

-- Shows the open tab of every details column again. The recipe files call this when they finish reading something.
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
local TWO_LINE_EXTRA = 16 -- an item button whose words take two lines is this much taller
local BUTTON_PAD = 26     -- a button keeps this much of its width free around its words
local ADDON_H = 22        -- the add-ons' buttons for the open item, in a row at the top of the Info box (core/hooks.lua)
local AMOUNT_W = 52       -- an add-on button's number box
local SLOTS_PER_LAYER, MAX_SLOTS = 8, 40            -- rows are kept in small layers of 8; never more than 40 rows on screen
local SITE_ICON, SITE_GAP, SITE_MAX = 40, 6, 9      -- the dig sites' pictures (Source tab): 40 x 40 (smaller when many), at most 9
local GRID_ICON, GRID_STEP = 32, 36                 -- an icon grid row (the Uses tab): 32 x 32 pictures, 36 apart
local HEADING_RGBA = 0xD9B25FFF                     -- a line ending in ":" ("Materials:") is drawn in gold
local STARS = try(function()
    local s = id.Sprite
    return { off = { normal = s.RAND_SPEEDRUN_STAR_SILVER_0, hover = s.RAND_SPEEDRUN_STAR_BRONZE_0, w = STAR, h = STAR },
             on  = { normal = s.RAND_SPEEDRUN_STAR_GOLD_0, hover = s.RAND_SPEEDRUN_STAR_GOLD_0, w = STAR, h = STAR } }
end)

-- Fits the facts line under the name beside the star. It tries tighter gaps first, then shorter words ("Untradeable", "F2P"),
-- and only cuts the line as a last resort.
function fitFacts(text, width)
    text = tostring(text or "")
    if textWidth(text) > width then text = string.gsub(text, "%s+|%s+", " | ") end
    if textWidth(text) > width then text = string.gsub(text, "Not tradeable", "Untradeable") end
    if textWidth(text) > width then text = string.gsub(text, "Free%-to%-play", "F2P") end
    return fitText(text, width)
end

-- Wraps the lines under the name onto a second line when they do not fit beside the star. Words are put on a line while they
-- fit: the facts by their " | " parts, and the Hidden by line by its switch names. The words "Hidden by:" stay alone on the
-- first line when the first name does not fit after them. At most two lines; a second line that still does not fit is shortened.
local function packRows(pieces, sep, width, fit)
    local rows, cur = {}, nil
    for _, p in ipairs(pieces) do
        local try = (cur ~= nil) and (cur .. sep .. p) or p
        if cur ~= nil and textWidth(try) > width then rows[#rows + 1] = cur; cur = p else cur = try end
    end
    if cur ~= nil then rows[#rows + 1] = cur end
    if #rows > 2 then rows[2] = table.concat(rows, sep, 2); for k = #rows, 3, -1 do rows[k] = nil end end
    for k, r in ipairs(rows) do rows[k] = fit(r, width) end
    return rows
end
local function factsRows(text, width)
    text = tostring(text or "")
    if text == "" then return {} end
    if textWidth(text) <= width then return { text } end
    local pieces = {}
    for p in string.gmatch(text, "[^|]+") do p = string.match(p, "^%s*(.-)%s*$"); if p ~= "" then pieces[#pieces + 1] = p end end
    return packRows(pieces, "  |  ", width, fitFacts)
end
local function hiddenRows(names, width)
    if names == nil or #names == 0 then return {} end
    local pieces = { "Hidden by:" }
    for k, nm in ipairs(names) do pieces[#pieces + 1] = nm .. ((k < #names) and "," or "") end
    -- "Hidden by:" and the first name stay together when they fit; a name is never split in the middle.
    local first = pieces[1] .. " " .. pieces[2]
    if textWidth(first) <= width then table.remove(pieces, 1); pieces[1] = first end
    return packRows(pieces, " ", width, fitText)
end

-- The header box at the top: the item's picture, name and star, and under the name a short dim line of facts ("Free-to-play  |
-- Not tradeable  |  Quest item"). HEAD_H is its inside height.
local HEAD_H = HEADER_H + LINE_H - 2

-- Has the game's data all been read? Until then the tabs' counts are not known, so no tab is drawn dim and none is picked for
-- the item.
local function dataReady()
    local ok, r = pcall(function()
        return Recipes.allRead() and Recipes.usedState.ready == true and (Gather == nil or Gather.ready == true)
    end)
    return ok and r == true
end
local function hasCount(label) return type(label) == "string" and string.find(label, "(", 1, true) ~= nil end

function Details.new(parent)
    local d = setmetatable({ itemId = nil, history = {}, info = {}, infoTexts = {}, rows = {}, slots = {}, rowLayers = {}, scroll = 0,
                             x = 0, y = 0, w = 200, h = 200 }, Details)
    Details.all[#Details.all + 1] = d
    -- One wheel notch reaches every part under the mouse (the words, their layer and the box), so only the first one in a tick
    -- counts.
    d.wheel = function(step)
        if d.wheelTick == tickCount then return end
        d.wheelTick = tickCount
        -- 3 lines a notch. A long list (a bar's uses can be hundreds) goes almost a box at a time.
        d:scrollBy(step * (((d.lineCount or 0) > 60) and math.max(3, (d.visible or 3) - 1) or 3))
    end
    -- three boxes: the header (top), the tabs' box, the Info box (bottom)
    d.head, d.top, d.bottom = Kit.frame(parent), Kit.frame(parent), Kit.frame(parent)
    local head, top = d.head.inner, d.top.inner

    -- wantTab is the tab last clicked. An item with nothing on that tab opens on the first tab that has something
    -- (Details:pickTab), but the next item goes back to the clicked one.
    d.wantTab = Saved.get("details_tab") or Details.TABS[1].key
    d.tab = d.wantTab
    d.tabs = Kit.tabStrip(parent, TABS_ROW, function(key)
        d.wantTab = key
        Saved.set("details_tab", key)
        d:showTab(key)
    end, DETAILS_TAB_STYLE) -- the game's tab pictures: DETAILS_TAB_STYLE in settings.lua
    d.tabs.cut = BOX_AT -- the tab pictures end at the box's top line (ui/kit.lua, Kit.gameTab)
    for _, tab in ipairs(Details.TABS) do d.tabs:add(tab.key, tab.label, math.ceil(textWidth(tab.widest or tab.label) + 20)) end
    d.back = Kit.picture(parent, BACK_SPRITES, function() d:goBack() end)
    d.back:setUsable(false)
    Kit.wheel(top, d.wheel)

    d.icon = Kit.itemIcon(head, ICON_W, ICON_H)
    d.icon.hidden = true
    -- The mouse over the item's picture shows the hover box, like the game's: its combat stats and teleport places
    -- (Details.showTip).
    pcall(function() d.icon.clickthrough = false end)
    d.icon:Subscribe(ui.Hook.ONMOUSEOVER, function()
        d.iconOver = true
        pcall(function() d:readStats() end) -- read now: the teleport places are known only once the game's tables are read
        -- Every item has a hover box, as in the game. A plain one is just its title and "+N options".
        d.footer = Details.footerFor(d.itemId)
        if d.statsTitle ~= nil and d.statsTitle ~= "" then Kit.hoverIn(d.icon); pcall(Details.showTip, d) end
        return true
    end)
    d.icon:Subscribe(ui.Hook.ONMOUSELEAVE, function() d.iconOver = false; Kit.hoverOut(d.icon); Details.hideTip(); return true end)
    d.addonBtns, d.addonShown = {}, {} -- the add-ons' buttons (Details:readAddons, Details:placeAddonButtons)
    d.name = { Kit.text(head, 0, 0, 10, LINE_H, "left"), Kit.text(head, 0, 0, 10, LINE_H, "left") }
    d.facts = Kit.text(head, 0, 0, 10, LINE_H, "left")
    pcall(function() d.facts.rgba = DIM_RGBA end)
    d.hiddenBy = Kit.text(head, 0, 0, 10, LINE_H, "left") -- "Hidden by: Junk filter", between the name and the facts line
    pcall(function() d.hiddenBy.rgba = DIM_RGBA end)
    d.hiddenBy.hidden = true
    d.hiddenBy2 = Kit.text(head, 0, 0, 10, LINE_H, "left") -- the second lines, when they do not fit on one
    d.facts2 = Kit.text(head, 0, 0, 10, LINE_H, "left")
    local seconds = { d.hiddenBy2, d.facts2 }
    for k = 1, 2 do local t = seconds[k]; if t ~= nil then pcall(function() t.rgba = DIM_RGBA end); t.hidden = true end end
    d.facts.content = "Click an item to see it here."
    if STARS ~= nil then
        d.star = Kit.picture(head, STARS.off, function()
            if d.itemId ~= nil then Filters.toggleFavourite(d.itemId); d:paintStar() end
        end)
        d.star:show(false)
    end
    return d
end

function Details:place(x, y, w, h)
    local wider = (w ~= self.w)
    self.x, self.y, self.w, self.h = x, y, w, h
    -- A new width with an item open: its name and the lines under it are fitted to it again.
    if wider and self.itemId ~= nil then self:fitName(); self:fillHead() end
    self:arrange()
end
-- Fits the open item's name on one or two lines for the box's width. A longer name's second line is shortened, and no lines are
-- left over.
function Details:fitName()
    local width = (self.w or DETAILS_W or 310) - 2 - 46 - STAR - 10
    local parts = wrapText(self.nameText or "", width)
    if #parts > 2 then
        parts[2] = fitText(table.concat(parts, " ", 2), width)
        for k = #parts, 3, -1 do parts[k] = nil end
    end
    self.nameLines = parts
    for k = 1, 2 do self.name[k].content = plain(parts[k] or "") end
end

-- Sizes the three boxes and puts their contents in place.
function Details:arrange()
    local w = self.w
    local n = #self.infoLines
    -- The "Hidden by" line, and it and the facts line on two lines each when needed: the header grows past three lines.
    local open = (self.itemId ~= nil)
    local hidRows = open and (self.hidRows or {}) or {}
    local factRows = open and (self.factRows or {}) or {}
    local nLines = #(self.nameLines or {}) + #hidRows + math.max(1, #factRows)
    local extra = open and math.max(0, nLines * LINE_H - HEAD_H) or 0
    local headIn = HEAD_H + extra
    local headH = headIn + 2
    local shownAddons = (self.itemId ~= nil) and (self.addonShown or {}) or {}
    -- The add-ons' buttons take as many rows as they need, so no button is left out.
    local off = (n > 0 and #shownAddons > 0) and (self:addonRows(shownAddons) * (ADDON_H + 4) + 2) or 0
    local infoH = (n > 0) and math.min(n * LINE_H + 8 + off, self.h - headH - 140) or 0
    self.head:place(self.x, self.y, w, headH)
    local tabsY = self.y + headH + 4
    self.top:place(self.x, tabsY + BOX_AT, w, self.h - headH - 4 - BOX_AT - ((infoH > 0) and (infoH + 6) or 0))
    self.topAt = { x = self.x + 1, y = tabsY + BOX_AT + 1 } -- the inside of the tabs' box on the page, for the icon grid's hover label
    self.bottom:show(infoH > 0)
    if infoH > 0 then self.bottom:place(self.x, self.y + self.h - infoH, w, infoH) end

    -- the tabs on top of the tabs' box, the back arrow at the row's right end
    self.tabs:place(self.x + 4, tabsY)
    self.tabs.maxW = w - 36 -- the tabs' words carry a count ("Recipe (3)", "Uses (99+)"), so they are fitted in (ui/kit.lua)
    self.tabs:fit()
    self.back:place(self.x + w - 28, tabsY + math.max(0, (BOX_AT - 24) // 2))
    self:layoutRows()

    -- the header: picture, name (one or two lines), star; the facts line under the name
    self.icon:SetPos(6, (headIn - ICON_H) // 2)
    local nameW = w - 2 - 46 - STAR - 10
    local name = self.nameLines or {}
    local y1 = (open and nLines >= 3) and 0 or ((HEADER_H - 4 - LINE_H) // 2)
    for k = 1, 2 do
        self.name[k]:SetSize(nameW, LINE_H)
        self.name[k]:SetPos(46, y1 + (k - 1) * LINE_H)
    end
    if self.itemId == nil then
        self.facts:SetSize(w - 18, LINE_H); self.facts:SetPos(8, (HEAD_H - LINE_H) // 2)
    else
        local under = y1 + ((#name > 1) and 2 or 1) * LINE_H
        for _, row in ipairs({ { self.hiddenBy, hidRows[1] }, { self.hiddenBy2, hidRows[2] }, { self.facts, factRows[1] or "" },
                               { self.facts2, factRows[2] } }) do
            if row[2] ~= nil then
                row[1]:SetSize(w - 2 - 46 - 6, LINE_H); row[1]:SetPos(46, under)
                under = under + LINE_H
            end
        end
    end
    self.hiddenBy.hidden = (hidRows[1] == nil)
    self.hiddenBy2.hidden = (hidRows[2] == nil)
    self.facts2.hidden = (factRows[2] == nil)
    if self.star ~= nil then self.star:place(w - 2 - STAR - 6, (headIn - STAR) // 2) end

    -- The Info box's lines, the last ones dim (the ID, value and right-click lines). When there are more lines than fit, the last
    -- line that fits says how many more there are.
    local fits = (infoH > 0) and math.max(1, (infoH - 4 - off) // LINE_H) or 0
    self:placeAddonButtons(shownAddons, off > 0 and infoH >= off)
    for k = 1, n do
        local t = self.infoTexts[k]
        if t == nil then
            t = { text = Kit.text(self.bottom.inner, 0, 0, 10, LINE_H, "left") }
            self.infoTexts[k] = t
        end
        t.text:SetSize(w - 18, LINE_H)
        t.text:SetPos(8, 4 + off + (k - 1) * LINE_H)
        t.text.content = (self.infoMarks or {})[k] or plain(self.infoLines[k])
        if n > fits and k == fits then t.text.content = plain("... " .. (n - fits + 1) .. " more lines - make the window taller") end
        local dim = (self.infoDim or {})[k] == true
        if t.dim ~= dim then t.dim = dim; pcall(function() t.text.rgba = dim and DIM_RGBA or TEXT_RGBA end) end
        t.text.hidden = k > fits
    end
    for k = n + 1, #self.infoTexts do self.infoTexts[k].text.hidden = true end
end

-- The lines of the Info box: the facts, each wrapped to the box's width (none while no item is open).
function Details:buildInfoLines()
    local lines, dim, marks, room = {}, {}, {}, self.w - 20
    if self.itemId ~= nil then
        for i, line in ipairs(self.info) do
            local text = (type(line) == "table") and line.text or line
            local parts = wrapText(tostring(text), room)
            for _, part in ipairs(parts) do
                lines[#lines + 1] = part
                if self.dimFrom ~= nil and i >= self.dimFrom then dim[#lines] = true end
            end
            -- a stats line's coloured version (recipes/stats.lua), when it fits on one line
            if type(line) == "table" and line.markup ~= nil and #parts == 1 then marks[#lines] = line.markup end
        end
    end
    self.infoLines, self.infoDim, self.infoMarks = lines, dim, marks
end
Details.infoLines = {}

-- The hover box. The item's combat stats (recipes/stats.lua) are not in the Info box, which they make too long, but in a box
-- like the game's own hover box: the title ("Wield Ek-ZekKil", the name in orange), a line under it, then the stats, each line
-- centred, with the numbers in the game's light blue. It is drawn on the game screen, not in the window, so it can be taller than
-- the window. It shows while the mouse is over the item's picture at the top of the details, and it also lists the places a
-- teleport item goes to (recipes/extras.lua).
-- hoverFor gives the hover box's lines for any item, title included. It is the same box wherever an item's picture is hovered:
-- the item's own picture here, and the big item grid (ui/item_box.lua).
function Details.hoverFor(itemId, item)
    local stats = {}
    if itemId == nil or Stats == nil then return stats, nil, nil end
    item = item or try(config.Obj.FromID, itemId)
    if item == nil then return stats, nil, nil end
    -- Food first, then a potion's effects, then the rest, as in the game's box (Jug of wine: Heals, Adrenaline, then its stat change).
    local okF, food, isFood = false, nil, false
    if Stats.foodLines ~= nil then okF, food, isFood = pcall(Stats.foodLines, item) end
    -- A potion that restores health itself (Saradomin brew: "Restores 1000 health.") shows no food lines. The game's box has no
    -- "Heals:" or adrenaline line for it, but "Doesn't drain adrenaline." near the end. Food with a potion's stat changes (Beer)
    -- keeps them.
    local pot = nil
    if Extras ~= nil and Extras.potionHover ~= nil then
        local okE, p = pcall(Extras.potionHover, itemId, item, false)
        if okE and type(p) == "table" then pot = p end
    end
    local potionHeals = false
    for _, l in ipairs(pot or {}) do if type(l.text) == "string" and string.match(l.text, "^Restores [%d,]+ health%.$") then potionHeals = true end end
    if okF and type(food) == "table" and not potionHeals then for _, l in ipairs(food) do stats[#stats + 1] = l end end
    for _, l in ipairs(pot or {}) do stats[#stats + 1] = l end
    local ok, lines = pcall(Stats.lines, itemId, item)
    if ok and type(lines) == "table" then for _, l in ipairs(lines) do stats[#stats + 1] = l end end
    -- a Summoning pouch's or scroll's lines, as in the game's box
    if Extras ~= nil and Extras.familiarHover ~= nil then
        local okF2, fam = pcall(Extras.familiarHover, itemId)
        if okF2 and type(fam) == "table" then for _, l in ipairs(fam) do stats[#stats + 1] = l end end
    end
    -- "Teleports to: ..." or "When worn: ..." (recipes/extras.lua)
    local okP, tele = false, nil
    if Extras ~= nil and Extras.teleportLines ~= nil then okP, tele = pcall(Extras.teleportLines, itemId, item) end
    if okP and type(tele) == "table" then
        for _, l in ipairs(tele) do stats[#stats + 1] = (type(l) == "table") and l or { text = l } end
    end
    -- a relic, currency, Archaeology mystery or farm animal line, at the end like the teleport line. There is no "To wear: ..." line.
    if Extras ~= nil and Extras.lines ~= nil then
        local okX, extra = pcall(Extras.lines, itemId, item)
        if okX and type(extra) == "table" then for _, l in ipairs(extra) do stats[#stats + 1] = { text = tostring(l) } end end
    end
    local okT, title, markup = pcall(Stats.title, item)
    if not okT then title, markup = nil, nil end
    return stats, title, markup
end
function Details:readStats(item)
    self.stats, self.statsTitle, self.statsTitleMarkup = Details.hoverFor(self.itemId, item)
end
-- The box's last line, like the game's "+4 options": how many entries Too Many Runes' right-click menu has for the item, Cancel
-- and its Recipe / Uses / Source (or Info) entries (ui/game_menu.lua). A stacked item's forms go in front: "4 forms - +3 options".
function Details.footerFor(itemId, note)
    local n = nil
    if GameMenu ~= nil and GameMenu.optionCount ~= nil then
        local ok, c = pcall(GameMenu.optionCount, itemId)
        if ok and type(c) == "number" then n = c end
    end
    local words = (n ~= nil and n > 0) and ("+" .. n .. (n == 1 and " option" or " options")) or nil
    if note ~= nil and note ~= "" then words = words and (note .. " | " .. words) or note end -- as in "+2 forms | +2 options"
    return words
end
-- Shows the box for an item picture somewhere else (the big item grid). It goes when the mouse leaves that picture (its owner).
function Details.showItemTip(itemId, icon, note, anchor)
    local stats, title, markup = Details.hoverFor(itemId)
    if title == nil or title == "" then return nil end
    local owner = { stats = stats, statsTitle = title, statsTitleMarkup = markup, itemId = itemId, iconOver = true, icon = icon,
                    footer = Details.footerFor(itemId, note), anchor = anchor }
    Details.showTip(owner)
    return owner
end
-- The game's own hover box: a near-black box with off-white words in a smaller font, 16 pixels a line where the window's words
-- take 20. The fonts it tries are in TIP_FONTS below; if the game has none of them, the window's own 15pt is used.
local TIP_BG = Vector4.new(15 / 255, 14 / 255, 12 / 255, 0.96)
local TIP_LINE = Vector4.new(102 / 255, 90 / 255, 58 / 255, 1.0)
-- The hover box border, matching the game's item box: four 1-pixel rings from the outside in (dark, gold, brown, dark brown).
-- The gold ring's corners are dark, which makes them look rounded. Its two lines (under the name, and above "+3 options") are a
-- dark line over a gold one, running right across to the border.
local function rgb(r, g, b) return Vector4.new(r / 255, g / 255, b / 255, 1.0) end
local FRAME = { rgb(46, 37, 26), rgb(112, 100, 68), rgb(89, 72, 46), rgb(51, 40, 29) }
local FRAME_CORNER = rgb(48, 39, 28)
local RULE_DARK = rgb(46, 37, 26)
local TIP_TEXT = 0xDACEC7FF
local TIP_MAX = 350 -- the widest an add-on button's words get
-- The game's item box sizes: up to 318 pixels wide outside (316 inside the line), with lines wrapping at about 300. The name on
-- top is one size bigger (13pt). There are 6 pixels more between the name's line and the first words, and between the last
-- words and the "+3 options" line. "+3 options" sits 9 pixels from the right edge.
local TIP_W = 316
local TIP_WRAP = 302
-- The words are 11pt, the same size as the game's "+3 options" line, with 16 pixels a line as in the game. 12pt and 13pt are
-- too big next to the game's own boxes. TIP_FONTS lists the fonts to try, in order.
local TIP_FONTS = { { "MUSEO_SANS_11PT_REGULAR", 16 }, { "MUSEO_SANS_12PT_REGULAR", 16 }, { "MUSEO_SANS_13PT_REGULAR", 16 } }
local tipFont = nil
local function pickTipFont()
    if tipFont ~= nil then return tipFont end
    tipFont = { id = id.Font.MUSEO_SANS_15PT_REGULAR, cfg = nil, h = LINE_H }
    for _, f in ipairs(TIP_FONTS) do
        local okI, fid = pcall(function() return id.Font[f[1]] end)
        local okC, cfg = pcall(function() return config.Font[f[1]] end)
        if okI and fid ~= nil and okC and cfg ~= nil then tipFont = { id = fid, cfg = cfg, h = f[2] }; break end
    end
    return tipFont
end
-- the item's name on top: 13pt, one size bigger than the words (then 14pt, then 12pt)
local titleFont = nil
local function pickTitleFont()
    if titleFont ~= nil then return titleFont end
    titleFont = pickTipFont()
    for _, f in ipairs({ { "MUSEO_SANS_13PT_REGULAR", 18 }, { "MUSEO_SANS_14PT_REGULAR", 18 }, { "MUSEO_SANS_12PT_REGULAR", 16 } }) do
        local okI, fid = pcall(function() return id.Font[f[1]] end)
        local okC, cfg = pcall(function() return config.Font[f[1]] end)
        if okI and fid ~= nil and okC and cfg ~= nil then titleFont = { id = fid, cfg = cfg, h = f[2] }; break end
    end
    return titleFont
end
local function titleWidth(text)
    local f = pickTitleFont()
    if f.cfg ~= nil then
        local ok, w = pcall(function() return f.cfg:GetStringWidth(text, true) end)
        if ok and type(w) == "number" then return w end
    end
    return nil
end
-- The font of the "+3 options" line, as in the game's box.
local footFont = nil
local function pickFootFont()
    if footFont ~= nil then return footFont end
    local box = pickTipFont()
    footFont = box
    local order = { { "MUSEO_SANS_11PT_REGULAR", 15 }, { "MUSEO_SANS_12PT_REGULAR", 16 } } -- 11pt first, as the game's "+3 options" line
    for _, f in ipairs(order) do
        local okI, fid = pcall(function() return id.Font[f[1]] end)
        local okC, cfg = pcall(function() return config.Font[f[1]] end)
        if okI and fid ~= nil and okC and cfg ~= nil then footFont = { id = fid, cfg = cfg, h = f[2] }; break end
    end
    return footFont
end
local function footWidth(text)
    local f = pickFootFont()
    if f.cfg ~= nil then
        local ok, w = pcall(function() return f.cfg:GetStringWidth(text, true) end)
        if ok and type(w) == "number" then return w end
    end
    return nil
end
local function tipWidth(text)
    local f = pickTipFont()
    if f.cfg ~= nil then
        local ok, w = pcall(function() return f.cfg:GetStringWidth(text, true) end)
        if ok and type(w) == "number" then return w end
    end
    return textWidth(text)
end
-- Wraps a coloured line to the width, keeping its colours. Each line it becomes opens again the colours it had there, as the
-- game's box wraps "Restores 317 prayer points, and renews 545 prayer points over the duration." with "545 prayer points" still
-- green.
local function markupWrap(markup, width)
    local words, cur, col = {}, nil, nil
    local function piece(t)
        for chunk, space in string.gmatch(t, "([^ ]*)( ?)") do
            if chunk ~= "" then
                if cur == nil then cur = { pieces = {}, plain = "" }; words[#words + 1] = cur end
                cur.pieces[#cur.pieces + 1] = { chunk, col }
                cur.plain = cur.plain .. chunk
            end
            if space ~= "" then cur = nil end
            if chunk == "" and space == "" then break end
        end
    end
    local pos = 1
    while pos <= #markup do
        local a, b, tag = string.find(markup, "(<[^>]*>)", pos)
        if a == nil then piece(string.sub(markup, pos)); break end
        if a > pos then piece(string.sub(markup, pos, a - 1)) end
        local c = string.match(tag, "^<col=(%x+)>$")
        if c ~= nil then col = c elseif tag == "</col>" then col = nil end
        pos = b + 1
    end
    local lines, line, linePlain = {}, {}, ""
    local function flush()
        if #line == 0 then return end
        local out, open = {}, nil
        for wi, w in ipairs(line) do
            if wi > 1 then out[#out + 1] = " " end
            for _, pc in ipairs(w.pieces) do
                if pc[2] ~= open then
                    if open ~= nil then out[#out + 1] = "</col>" end
                    if pc[2] ~= nil then out[#out + 1] = "<col=" .. pc[2] .. ">" end
                    open = pc[2]
                end
                out[#out + 1] = plain(pc[1])
            end
        end
        if open ~= nil then out[#out + 1] = "</col>" end
        lines[#lines + 1] = { plain = linePlain, show = table.concat(out) }
        line, linePlain = {}, ""
    end
    for _, w in ipairs(words) do
        local joined = (linePlain == "") and w.plain or (linePlain .. " " .. w.plain)
        if linePlain ~= "" and tipWidth(joined) > width then flush(); joined = w.plain end
        line[#line + 1] = w
        linePlain = joined
    end
    flush()
    return lines
end
Details.markupWrap = markupWrap -- for the offline test
local function tipWrap(text, width) -- words wrapped to the width, measured in the box's own font
    local out, cur = {}, ""
    for word in string.gmatch(tostring(text), "%S+") do
        local joined = (cur == "") and word or (cur .. " " .. word)
        if cur ~= "" and tipWidth(joined) > width then out[#out + 1] = cur; cur = word else cur = joined end
    end
    if cur ~= "" then out[#out + 1] = cur end
    if #out == 0 then out[1] = "" end
    return out
end
local tip = nil
local function tipParts()
    if tip ~= nil then return tip end
    local area = gameArea()
    tip = { line = Kit.rect(area, 0, 0, 1, 1, FRAME[1]), bg = Kit.rect(area, 0, 0, 1, 1, TIP_BG), rule = Kit.rect(area, 0, 0, 1, 1, TIP_LINE),
            rule2 = Kit.rect(area, 0, 0, 1, 1, TIP_LINE), texts = {}, shown = false } -- rule2 is the line above "+3 options"
    -- the border's inner rings, its four dark corners, and the dark line over each of the two lines
    tip.rings = { Kit.rect(area, 0, 0, 1, 1, FRAME[2]), Kit.rect(area, 0, 0, 1, 1, FRAME[3]), Kit.rect(area, 0, 0, 1, 1, FRAME[4]) }
    tip.corners = {}
    for k = 1, 4 do tip.corners[k] = Kit.rect(area, 0, 0, 1, 1, FRAME_CORNER) end
    tip.ruleDark = Kit.rect(area, 0, 0, 1, 1, RULE_DARK)
    tip.rule2Dark = Kit.rect(area, 0, 0, 1, 1, RULE_DARK)
    return tip
end
local function tipExtras(t) -- the border's rings and corners, and the dark lines
    local list = {}
    if t.ruleDark ~= nil then list[#list + 1] = t.ruleDark end
    if t.rule2Dark ~= nil then list[#list + 1] = t.rule2Dark end
    for _, r in ipairs(t.rings or {}) do list[#list + 1] = r end
    for _, c in ipairs(t.corners or {}) do list[#list + 1] = c end
    return list
end
function Details.hideTip()
    if tip == nil or not tip.shown then return end
    tip.shown, tip.owner, tip.item = false, nil, nil
    tip.line.hidden, tip.bg.hidden, tip.rule.hidden, tip.rule2.hidden = true, true, true, true
    for _, part in ipairs(tipExtras(tip)) do part.hidden = true end
    if tip.foot ~= nil then tip.foot.hidden = true end
    for _, t in ipairs(tip.texts) do t.hidden = true end
    if tip.wikiPic ~= nil then tip.wikiPic.hidden = true end
end
function Details.hideTipOf(owner) -- the mouse left a picture: only its own box goes, not one a neighbour just opened
    if tip ~= nil and tip.shown and tip.owner == owner then Details.hideTip() end
end
function Details.showTip(d)
    local t = tipParts()
    local font = pickTipFont()
    local LH = font.h
    local rows, widest = {}, 0
    if d.words ~= nil then -- just some words (an add-on button's), wrapped to the box's width, all alike
        for _, p in ipairs(tipWrap(d.words, TIP_MAX - 20)) do rows[#rows + 1] = { plain = p, show = plain(p) }; widest = math.max(widest, tipWidth(p)) end
    else
        rows[1] = { plain = d.statsTitle or "", show = d.statsTitleMarkup or plain(d.statsTitle or "") }
        widest = titleWidth(rows[1].plain) or tipWidth(rows[1].plain)
    end
    for _, l in ipairs(d.stats or {}) do
        local parts = tipWrap(l.text, TIP_WRAP)
        if l.wiki then -- the wiki's button, then the words: "(wiki) Info:"
            rows[#rows + 1] = { plain = l.text, show = plain(l.text), wiki = true }
            widest = math.max(widest, (WIKI_ICON.w or 48) + 4 + tipWidth(l.text))
        elseif #parts <= 1 then
            rows[#rows + 1] = { plain = l.text, show = l.markup or plain(l.text) }
            widest = math.max(widest, tipWidth(l.text))
        else
            if l.markup ~= nil and not l.colour then -- a line with colours in it keeps them when it wraps
                for _, r in ipairs(markupWrap(l.markup, TIP_WRAP)) do rows[#rows + 1] = r; widest = math.max(widest, tipWidth(r.plain)) end
            else
                for _, p in ipairs(parts) do -- a line all in one colour (a dim enchantment line) keeps it when it wraps
                    rows[#rows + 1] = { plain = p, show = l.colour and ("<col=" .. l.colour .. ">" .. plain(p) .. "</col>") or plain(p) }
                    widest = math.max(widest, tipWidth(p))
                end
            end
        end
    end
    local footer = (d.words == nil) and d.footer or nil
    if footer ~= nil then widest = math.max(widest, (footWidth(footer) or tipWidth(footer)) + 8) end
    local item = (d.words == nil)
    local w = math.min(TIP_MAX, math.ceil(widest) + 20)
    -- The game's box fits its words (Bury Bones, Eat Swordfish, Use Raw bear meat: 6 pixels from the gold line to the widest line,
    -- each side), up to TIP_W. Only a Summoning pouch's or scroll's box is always TIP_W wide, with its "+3 options" further in.
    local footIn = 1
    if item then
        local fam = false
        if Extras ~= nil and Extras.familiarNow ~= nil and type(d.itemId) == "number" then
            local okF, f = pcall(Extras.familiarNow, d.itemId)
            fam = okF and f ~= nil
        end
        if fam and #rows > 1 then w = math.max(TIP_W, math.ceil(widest) + 14); footIn = 5
        else w = math.min(TIP_W, math.ceil(widest) + 10) end
    end
    local h
    if not item then h = #rows * LH + 8
    elseif #rows == 1 then h = (footer ~= nil) and 50 or 30 -- just the name: "+3 options" right under it, its line where the name's would be
    else h = #rows * LH + ((footer ~= nil) and (22 + LH + 4) or 18) end
    local mx, my = nil, nil
    if Window ~= nil and Window.mouse ~= nil then mx, my = Window.mouse() end
    mx, my = mx or 300, my or 300
    local sw, sh = 0, 0
    pcall(function() sw, sh = screenSize() end)
    local x, y
    if d.words ~= nil then -- a button's words go above the mouse, not over the buttons beside it, or under it at the screen's top
        x = math.max(2, mx - w // 2)
        y = my - h - 14
        if y < 2 then y = my + 22 end
    else
        -- Under the item, in the middle of it, as the game's; above it when there is no room below. An item with no place given (the
        -- open item's own picture) is taken as a small square round the mouse. The picture's own place on the screen (xyGlobal, from
        -- the game) puts the box under it wherever the window is.
        local a = nil
        if d.icon ~= nil then
            pcall(function()
                local g = d.icon.xyGlobal
                local iw, ih = d.icon.width, d.icon.height
                if g ~= nil and type(g.x) == "number" and type(iw) == "number" and iw > 0 then a = { x = g.x, y = g.y, w = iw, h = ih or iw } end
            end)
        end
        a = a or d.anchor or { x = mx - 16, y = my - 16, w = 32, h = 32 }
        x = math.floor(a.x + a.w / 2 - w / 2)
        y = a.y + a.h + 4
        if sh > 0 and y + h > sh - 2 then y = a.y - h - 4 end
    end
    -- never off the screen, even when pushed into a corner
    if sw > 0 then x = math.max(2, math.min(x, sw - w - 2)) else x = math.max(2, x) end
    if sh > 0 then y = math.max(2, math.min(y, sh - h - 2)) else y = math.max(2, y) end
    -- the game's border: four rings from x - 2 in, then the box's inside. t.line is the gold ring.
    t.line:SetPos(x - 2, y - 2); t.line:SetSize(w + 4, h + 4)
    for k, r in ipairs(t.rings) do r:SetPos(x - 2 + k, y - 2 + k); r:SetSize(w + 4 - 2 * k, h + 4 - 2 * k) end
    t.bg:SetPos(x + 2, y + 2); t.bg:SetSize(w - 4, h - 4)
    local cx, cy = { x - 1, x + w, x - 1, x + w }, { y - 1, y - 1, y + h, y + h }
    for k, c in ipairs(t.corners) do c:SetPos(cx[k], cy[k]); c:SetSize(1, 1) end
    t.ruleDark:SetPos(x + 2, y + 25); t.ruleDark:SetSize(w - 4, 1)
    t.rule:SetPos(x + 2, y + 26); t.rule:SetSize(w - 4, 1)
    local wikiRow = nil
    for k, r in ipairs(rows) do
        local tx = t.texts[k]
        if tx == nil then
            tx = Kit.text(gameArea(), 0, 0, 10, LH); t.texts[k] = tx
            pcall(function() tx.font = font.id; tx.rgba = TIP_TEXT end)
        end
        local rowH = LH
        if k == 1 then -- an item's name in the bigger font; an add-on button's words in the box's own
            local want = item and pickTitleFont() or font
            t.firstFont = t.firstFont or {}
            if t.firstFont[1] ~= want.id then pcall(function() tx.font = want.id end); t.firstFont[1] = want.id end
            if item then rowH = want.h end
        end
        local ty = y + 4 + (k - 1) * LH
        if item then ty = (k == 1) and (y + 5) or (y + 4 + (k - 1) * LH + 10) end
        if r.wiki then
            -- the button and the words together in the middle of the box
            local iw, ih = WIKI_ICON.w or 48, WIKI_ICON.h or 17
            local tw = math.ceil(tipWidth(r.plain)) + 4
            local left = x + (w - (iw + 4 + tw)) // 2
            if t.wikiPic == nil then
                t.wikiPic = ui.Sprite.new(gameArea())
                t.wikiPic.colour = WHITE
                pcall(function() t.wikiPic.spriteID = WIKI_ICON.sprite end)
            end
            t.wikiPic:SetSize(iw, ih)
            t.wikiPic:SetPos(left, ty + (LH - ih) // 2)
            wikiRow = true
            tx:SetSize(tw, LH)
            tx:SetPos(left + iw + 4, ty)
        else
            tx:SetSize(w, rowH)
            tx:SetPos(x, ty)
        end
        tx.content = r.show
        tx.hidden = false
    end
    if t.wikiPic ~= nil then t.wikiPic.hidden = not wikiRow end
    for k = #rows + 1, #t.texts do t.texts[k].hidden = true end
    -- the last line, right-aligned under a line, as the game's: "+3 options"
    if footer ~= nil then
        local fy = (#rows == 1) and (y + 29) or (y + 21 + #rows * LH)
        t.rule2Dark:SetPos(x + 2, fy - 4); t.rule2Dark:SetSize(w - 4, 1)
        t.rule2:SetPos(x + 2, fy - 3); t.rule2:SetSize(w - 4, 1)
        local ff = pickFootFont()
        if t.foot == nil then
            t.foot = Kit.text(gameArea(), 0, 0, 10, LH)
            pcall(function() t.foot.font = ff.id; t.foot.rgba = TIP_TEXT end)
        end
        local fw = math.ceil(footWidth(footer) or tipWidth(footer)) + 4
        t.foot:SetSize(fw, LH); t.foot:SetPos(x + w - footIn - fw, fy)
        t.foot.content = plain(footer)
        t.foot.hidden = false
    elseif t.foot ~= nil then
        t.foot.hidden = true
    end
    t.rule2.hidden = (footer == nil)
    t.rule2Dark.hidden = (footer == nil)
    t.line.hidden, t.bg.hidden, t.rule.hidden = false, false, (d.words ~= nil or #rows <= 1) -- an add-on button's words: no line under them
    t.ruleDark.hidden = t.rule.hidden
    for _, r in ipairs(t.rings) do r.hidden = false end
    for _, c in ipairs(t.corners) do c.hidden = false end
    for _, part in ipairs({ t.line, t.rings[1], t.rings[2], t.rings[3], t.bg, t.corners[1], t.corners[2], t.corners[3], t.corners[4],
                            t.ruleDark, t.rule }) do pcall(function() part:MoveToFront() end) end
    pcall(function() t.rule2Dark:MoveToFront() end)
    pcall(function() t.rule2:MoveToFront() end)
    for k = 1, #rows do local tx = t.texts[k]; pcall(function() tx:MoveToFront() end) end
    if footer ~= nil then pcall(function() t.foot:MoveToFront() end) end
    if wikiRow then pcall(function() t.wikiPic:MoveToFront() end) end
    t.shown, t.owner, t.item = true, d, d.itemId
end
-- Shows the hover box with just some words: an add-on button's tooltip. It goes when the mouse leaves the button, the item
-- changes or the window is closed (the check below).
function Details.showWordsTip(d, text)
    local words = setmetatable({ stats = {}, words = tostring(text), iconOver = true, icon = d.icon },
        { __index = function(_, k) if k == "itemId" then return d.itemId end end })
    Details.showTip(words)
end

-- The add-ons' buttons for the open item (core/hooks.lua): which show for it (each add-on's shows(itemId), guarded), and their
-- row at the top of the Info box, as many as fit across it.
function Details:readAddons()
    local shown = {}
    if self.itemId ~= nil and AddonHooks ~= nil then
        for _, part in ipairs(AddonHooks.buttons) do
            local show = true
            if part.def.shows ~= nil then
                local ok, answer = AddonHooks.call(part, "deciding whether its button shows", part.def.shows, self.itemId)
                show = ok and answer and true or false
            end
            if show and not part.gone then shown[#shown + 1] = part end
        end
    end
    self.addonShown = shown
end
-- How wide an add-on's button is, with its number box, and how many rows the buttons take at this width.
local function addonWide(part) return math.ceil(textWidth(part.label) + 20) + (part.def.amount and (AMOUNT_W + 4) or 0) end
function Details:addonRows(shown)
    local rows, x = 1, 6
    for _, part in ipairs(shown) do
        local wide = addonWide(part)
        if x > 6 and x + wide > self.w - 8 then rows, x = rows + 1, 6 end
        x = x + wide + 6
    end
    return rows
end
function Details:placeAddonButtons(shown, room)
    local used, x, y = {}, 6, 3
    for _, part in ipairs(shown) do
        local e = self.addonBtns[part]
        if e == nil then
            local w = math.ceil(textWidth(part.label) + 20)
            local d = self
            e = { w = w, b = Kit.button(self.bottom.inner, part.label, w, ADDON_H, function()
                if d.itemId == nil then return end
                local amount = nil
                if e.box ~= nil then amount = math.max(1, math.min(9999, tonumber(e.count) or 1)) end
                AddonHooks.call(part, "its button", part.def.onClick, d.itemId, amount)
            end) }
            self.addonBtns[part] = e
            -- amount = true: a small box for a number after the button, digits only, 1 to 9999, back to 1 for each item
            if part.def.amount then
                e.box = Kit.input(self.bottom.inner, AMOUNT_W, ADDON_H, "1", 4)
                e.box:setText("1")
                e.count = "1"
                e.box.onChange = function(text)
                    local digits = string.gsub(tostring(text or ""), "%D", "")
                    e.count = digits
                    if digits ~= text then e.box:setText(digits) end
                end
            end
            local words = part.def.tooltip
            if type(words) == "string" and words ~= "" then -- named hooks of our own, so the button's own handling carries on
                pcall(function()
                    e.b.sb.root:Subscribe(ui.Hook.ONMOUSEOVER, "tmr3_addon_tip", function() pcall(Details.showWordsTip, d, words) return true end)
                    e.b.sb.root:Subscribe(ui.Hook.ONMOUSELEAVE, "tmr3_addon_tip", function() Details.hideTip() return true end)
                end)
            end
        end
        used[part] = true
        local wide = e.w + ((e.box ~= nil) and (AMOUNT_W + 4) or 0)
        if x > 6 and x + wide > self.w - 8 then x, y = 6, y + ADDON_H + 4 end -- the next row
        local fitsRow = room
        e.b:show(fitsRow)
        if fitsRow then e.b:place(x, y) end
        if e.box ~= nil then
            if e.countFor ~= self.itemId then e.countFor = self.itemId; e.count = "1"; e.box:setText("1") end -- another item: back to 1
            e.box:show(fitsRow)
            if fitsRow then e.box:place(x + e.w + 4, y) end
        end
        if fitsRow then x = x + wide + 6 end
    end
    for part, e in pairs(self.addonBtns) do
        if not used[part] then
            e.b:show(false)
            if e.box ~= nil then e.box:show(false) end
            if part.gone then
                pcall(function() e.b.sb.root:Destroy() end)
                if e.box ~= nil then pcall(function() e.box.field.root:Destroy() end) end
                self.addonBtns[part] = nil
            end
        end
    end
end
if AddonHooks ~= nil then
    AddonHooks.listen("item buttons", function()
        for _, d in ipairs(Details.all) do
            pcall(function() d:readAddons(); if d.itemId ~= nil then d:arrange() end end)
        end
    end)
end

function Details.destroyTip()
    if tip == nil then return end
    -- A numbered loop, since ipairs stops at the first missing part, and tip.foot is missing until a box has had "+3 options".
    local parts = { tip.line, tip.bg, tip.rule, tip.rule2, tip.foot } -- also the "+3 options" line and its rule
    for k = 1, 5 do
        local part = parts[k]
        if part ~= nil then pcall(function() part:Destroy() end) end
    end
    for _, part in ipairs(tipExtras(tip)) do pcall(function() part:Destroy() end) end
    for _, tx in ipairs(tip.texts) do pcall(function() tx:Destroy() end) end
    if tip.wikiPic ~= nil then pcall(function() tip.wikiPic:Destroy() end) end
    tip = nil
end
-- Every tick while the box is up: it goes away if its item changed, its picture was hidden, or the window was closed or folded,
-- since the picture's mouse-leave does not come then.
Event.Logic.Subscribe("tmr3_hoverbox", function()
    if tip == nil or not tip.shown then return end
    local d = tip.owner
    -- Guarded, so a picture that is gone cannot make this fail 50 times a second. The box just goes.
    local ok, keep = pcall(function()
        return d ~= nil and d.iconOver and not d.icon.hidden and d.itemId == tip.item
               and not (Window ~= nil and (Window.closed or Window.collapsed))
    end)
    if not ok or not keep then Details.hideTip() end
end)

function Details:renderInfo()
    self:buildInfoLines()
    self:arrange()
end

-- Finds which hide switches (Settings, turned on) keep the open item out of the item list, for the header's "Hidden by" line.
function Details:readHidden()
    self.hiddenText, self.hiddenNames = nil, nil
    local slot = (self.itemId ~= nil and Items ~= nil and Items.slotOf ~= nil) and Items.slotOf[self.itemId] or nil
    if slot ~= nil and Filters ~= nil and Filters.hiddenBy ~= nil then
        local okH, names = pcall(Filters.hiddenBy, slot)
        if okH and type(names) == "table" and #names > 0 then
            self.hiddenNames = names
            self.hiddenText = "Hidden by: " .. table.concat(names, ", ")
        end
    end
    self:fillHead()
end

-- Puts the Hidden by and facts words in the header's lines, each wrapped onto a second line when it does not fit beside the star.
function Details:fillHead()
    local width = (self.w or DETAILS_W or 310) - 2 - 46 - STAR - 10
    self.hidRows = hiddenRows(self.hiddenNames, width)
    self.factRows = factsRows(self.factsText, width)
    self.hiddenBy.content = plain(self.hidRows[1] or "")
    self.hiddenBy2.content = plain(self.hidRows[2] or "")
    if self.itemId ~= nil then
        self.facts.content = plain(self.factRows[1] or "")
        self.facts2.content = plain(self.factRows[2] or "")
    end
end

-- Reads the Info box again for every open item, after a setting that changes it was switched (SHOW_DEBUG_NAMES) or a hide
-- switch was flipped.
function Details.refreshInfo()
    for _, d in ipairs(Details.all or {}) do
        if d.itemId ~= nil then
            pcall(function()
                local lines, _, facts, dimFrom = Info.lines(d.itemId)
                if lines ~= nil then d.info, d.dimFrom, d.factsText = lines, dimFrom, facts end
                d:readStats()
                d:readHidden() -- a hide switch was flipped
                d:renderInfo()
            end)
        end
    end
end

-- Shows the favourite star, filled when the item is a favourite.
function Details:paintStar()
    if self.star == nil then return end
    self.star:show(self.itemId ~= nil)
    self.star:setPics(Filters.isFavourite(self.itemId) and STARS.on or STARS.off)
end

-- The tab to open for this item: the one last clicked, unless it has nothing for this item and another tab has something (then the first
-- such tab). Only once the game's data is read - before that no tab knows its count.
function Details:pickTab()
    local want = self.wantTab or self.tab
    if self.itemId == nil or not dataReady() then return want end
    local function has(t)
        if t.labelOf == nil then return true end
        local ok, l = pcall(t.labelOf, self.itemId)
        return ok and hasCount(l)
    end
    for _, t in ipairs(Details.TABS) do if t.key == want and has(t) then return want end end
    for _, t in ipairs(Details.TABS) do if has(t) then return t.key end end
    return want
end

-- Opens an item. keepTrail = true when it was reached from inside the details (an ingredient, a use), so Back can return.
function Details:open(itemId, keepTrail)
    if not self.noRecent and Recent ~= nil then Recent.add(itemId) end -- adds it to Recently viewed (pages/recent.lua)
    if keepTrail and self.itemId ~= nil then
        self.history[#self.history + 1] = self.itemId
        if #self.history > 30 then table.remove(self.history, 1) end
    elseif not keepTrail then
        self.history = {}
    end
    self.back:setUsable(#self.history > 0)
    self.itemId = itemId
    local lines, item, facts, dimFrom = Info.lines(itemId)
    self.info = lines or { "The game has no item " .. itemId .. "." }
    self.dimFrom = (lines ~= nil) and dimFrom or nil
    self:readStats(item)
    self:readAddons()

    -- the header: picture, name (two lines if it is long) and the facts line
    self.icon.hidden = not Kit.setItem(self.icon, itemId)
    local name = (item ~= nil and field(item, "name")) or ("Item " .. itemId)
    self.nameText = name
    self:fitName()
    self.factsText = facts -- put in its lines by Details:fillHead, from readHidden below
    self:readHidden()
    self:paintStar()
    self:renderInfo()
    self:showTab(self:pickTab())
    if self.onOpen ~= nil then pcall(self.onOpen, itemId) end -- the search page shows it in the item list too
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

-- Opens a tab of the top box. keepScroll = true means the same item is shown again (new data came in), so it stays where the
-- wheel left it. Only a click on a tab is remembered as the tab to open next time (Details.new). A tab with nothing in it is
-- drawn dim.
function Details:showTab(key, keepScroll)
    local tab = nil
    for _, t in ipairs(Details.TABS) do if t.key == key then tab = t end end
    tab = tab or Details.TABS[1]
    self.tab = tab.key
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
    -- a tab with no count has nothing for this item: dim (once the data is read)
    local ready = (self.itemId ~= nil) and dataReady()
    for _, t in ipairs(Details.TABS) do
        self.tabs:setEmpty(t.key, ready and t.labelOf ~= nil and not hasCount(self.tabs.labels[t.key]))
    end
    self.rows, self.lineCache = rows, nil
    if not keepScroll then self.scroll = 0 end
    self:arrange()
end

-- The rows of the top box. The rows are turned into lines that fit the box (long words wrap onto more lines), and the lines from
-- self.scroll on are drawn into "slots". A slot is one line on screen with its parts (words, and a picture or button when that
-- line needs one), made the first time they are needed and then reused, never destroyed.

-- The rows as lines: { text, kind = "text" / "item" / "pic", id = item number, pic = sprite, h = height, heading = true }.
function Details:rowLines()
    local width = self.top.w or 200
    if self.lineCache ~= nil and self.lineCacheW == width then return self.lineCache end -- worked out once per item and width
    local lines = {}
    for _, row in ipairs(self.rows or {}) do
        if type(row) ~= "table" then row = { text = row } end
        local text = tostring(row.text or "")
        if type(row.iconGrid) == "table" and #row.iconGrid > 0 then
            -- items as pictures only, as many to a line as fit; the mouse over one shows its name ("Varrock teleport (Magic 25)")
            local per = math.max(1, math.floor((width - 12) / GRID_STEP))
            for i = 1, #row.iconGrid, per do
                local part, ids = {}, {}
                for j = i, math.min(#row.iconGrid, i + per - 1) do part[#part + 1] = row.iconGrid[j]; ids[#ids + 1] = row.iconGrid[j].id end
                lines[#lines + 1] = { kind = "icons", items = part, text = "[" .. table.concat(ids, " ") .. "]", indent = 10, h = GRID_STEP }
            end
        elseif type(row.sites) == "table" and #row.sites > 0 then
            -- the dig sites: their pictures side by side, and under them the name of the one the mouse is over
            lines[#lines + 1] = { kind = "sites", sites = row.sites, text = "", indent = 10, h = SITE_ICON + LINE_H + 8 }
        elseif type(row.icon) == "number" then
            -- an item button: its words on two lines (a taller button) when they do not fit on one, so "Meteorite cannonball (level ..." is
            -- not cut off
            local room = width - ROW_ICON_W - 22 - BUTTON_PAD -- the button's own words have less room than the button
            text = string.gsub(text, "%s+", " ") -- one space between words, as the lines are measured. Otherwise a two-line button would be made
                                                  -- for "Super attack mix (2)  (level 47)", whose words fit on one line
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
            local hasPic = type(row.pic) == "number" or type(row.picItem) == "number" -- picItem: a station shown with an item's picture
            local pw = tonumber(row.picW) -- a picture that is not the usual square
            local indent = hasPic and (pw and (10 + pw + 6) or (ROW_ICON_W + 12)) or 10
            for k, part in ipairs(wrapText(text, width - indent - 8)) do
                local line = { kind = "text", text = part, indent = indent, h = LINE_H }
                if k == 1 and hasPic then
                    line.kind, line.pic, line.picItem, line.h = "pic", row.pic, row.picItem, PIC_ROW_H
                    line.picW, line.picH = pw, tonumber(row.picH)
                    -- a picture that searches: a click on the picture of "Made at: Furnace" searches "@furnace", and a skill on the Source tab
                    -- searches "@mining"
                    if type(row.query) == "string" and row.query ~= "" then line.query = row.query end
                end
                if string.sub(part, -1) == ":" or row.heading then line.heading = true end
                lines[#lines + 1] = line
            end
            if text == "" then lines[#lines + 1] = { kind = "text", text = "", indent = 10, h = LINE_H } end
        end
    end
    self.lineCache, self.lineCacheW = lines, width
    return lines
end

-- Slot k, made when first needed, in layers of 8 so no layer gets a long list of parts.
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
        -- The colour of a button's words, read from a brand-new one (not under the mouse or pressed), for the two-line words.
        if Details.wordsRGBA == nil then pcall(function() Details.wordsRGBA = s.button.sb.content.rgba end) end
        Kit.wheel(s.button:root(), self.wheel)
    end
    return s.button
end
-- The two lines of words for a two-line item button, made the first time a slot needs them. They are made inside the button, so
-- they move with it when it is drawn in front (otherwise some two-line buttons show blank), and in the colour of a fresh
-- button's words.
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
        s.icon:Subscribe(ui.Hook.ONMOUSEOVER, function() -- the outline and the colour (ui/kit.lua)
            Kit.hoverIn(s.icon)
            if s.itemId ~= nil then -- the game's hover box, as in the item list
                local ok, owner = pcall(Details.showItemTip, s.itemId, s.icon)
                if ok then s.tipOwner = owner end
            end
            return true
        end)
        s.icon:Subscribe(ui.Hook.ONMOUSELEAVE, function()
            Kit.hoverOut(s.icon)
            if s.tipOwner ~= nil then s.tipOwner.iconOver = false; pcall(Details.hideTipOf, s.tipOwner); s.tipOwner = nil end
            return true
        end)
        s.icon:Subscribe(ui.Hook.ONCLICK, function()
            if s.tipOwner ~= nil then pcall(Details.hideTipOf, s.tipOwner); s.tipOwner = nil end
            if s.itemId ~= nil then self:open(s.itemId, true) end
            return false
        end)
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

-- The pictures of an icon grid line, made when first needed, then reused. The mouse over one outlines it and shows its name above
-- it (the window's hover label, as in the item list). A click opens that item (Back returns).
local function hideGrid(s)
    for _, p in ipairs(s.gridPics or {}) do p.hidden = true end
    if s.gridItems ~= nil and Window ~= nil and Window.hideHover ~= nil then pcall(Window.hideHover) end
    s.gridItems = nil
end
function Details:gridPic(s, j)
    s.gridPics = s.gridPics or {}
    local p = s.gridPics[j]
    if p ~= nil then return p end
    p = Kit.itemIcon(s.layer, GRID_ICON, GRID_ICON)
    Kit.wheel(p, self.wheel)
    p:Subscribe(ui.Hook.ONMOUSEOVER, function()
        Kit.hoverIn(p)
        local e = s.gridItems and s.gridItems[j]
        if e ~= nil and s.gridAt ~= nil then
            -- the game's hover box; the level goes in its last line: "Magic 25 | +3 options"
            local note = string.match(tostring(e.tip or ""), "%(([^%(%)]+)%)%s*$")
            local ok, owner = pcall(Details.showItemTip, e.id, p, note)
            if ok and owner ~= nil then
                s.gridTips = s.gridTips or {}
                s.gridTips[j] = owner -- kept beside the picture, since a game picture takes no values of ours
            else
                local px, py = Window.areaOrigin()
                local at = self.topAt or { x = 0, y = 0 }
                pcall(Window.showHover, e.tip or "", px + at.x + s.gridAt[j][1], py + at.y + s.gridAt[j][2], GRID_ICON)
            end
        end
        return true
    end)
    p:Subscribe(ui.Hook.ONMOUSELEAVE, function()
        Kit.hoverOut(p); pcall(Window.hideHover)
        local o = s.gridTips and s.gridTips[j]
        if o ~= nil then o.iconOver = false; pcall(Details.hideTipOf, o); s.gridTips[j] = nil end
        return true
    end)
    p:Subscribe(ui.Hook.ONCLICK, function()
        local e = s.gridItems and s.gridItems[j]
        local o = s.gridTips and s.gridTips[j]
        if o ~= nil then pcall(Details.hideTipOf, o); s.gridTips[j] = nil end
        if e ~= nil then pcall(Window.hideHover); self:open(e.id, true) end
        return false
    end)
    s.gridPics[j] = p
    return p
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
-- the same for a station shown with an item's picture (the robust glass machine ...): a picture of its own, since an item's picture and a
-- sprite number do not share one
local function slotObjPic(s)
    if s.objPic == nil then
        s.objPic = Kit.itemIcon(s.layer, ROW_ICON_H, ROW_ICON_H)
        Kit.wheel(s.objPic, s.wheel)
        s.objPic:Subscribe(ui.Hook.ONMOUSEOVER, function() if s.query ~= nil then Kit.hoverIn(s.objPic) end return true end)
        s.objPic:Subscribe(ui.Hook.ONMOUSELEAVE, function() Kit.hoverOut(s.objPic) return true end)
        s.objPic:Subscribe(ui.Hook.ONCLICK, function()
            if s.query ~= nil and Window ~= nil and Window.runSearch ~= nil then Window.runSearch(s.query) end
            return false
        end)
    end
    return s.objPic
end
local function hidePics(s)
    if s.pic then s.pic.hidden = true end
    if s.objPic then s.objPic.hidden = true end
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
    -- A layer with no size shows nothing, so each row layer covers the whole box.
    for _, layer in ipairs(self.rowLayers) do layer:SetPos(0, 0); layer:SetSize(w, self.top.h or 200) end
    local shownLast = first - 1
    for i = first, #lines do
        local l = lines[i]
        local needsMore = (i < #lines) and (total > room) -- keep a line free for "more below" unless this is the very last line
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
    hideGrid(s)
    if s.text then s.text.hidden = true end
    if s.button then s.button:show(false) end
    if s.words then s.words[1].hidden, s.words[2].hidden = true, true end
    if s.icon then s.icon.hidden = true end
    hidePics(s)
end

function Details:drawLine(s, l, y, w)
    s.wheel = self.wheel
    local t = slotText(s)
    s.query = l.query -- a picture that searches; nil for every other line
    if l.kind == "icons" then
        s.itemId = nil
        t.hidden = true
        hideSites(s)
        if s.icon then s.icon.hidden = true end
        if s.button then s.button:show(false) end
        if s.words then s.words[1].hidden, s.words[2].hidden = true, true end
        hidePics(s)
        s.gridItems, s.gridAt = l.items, {}
        for j, e in ipairs(l.items) do
            local p = self:gridPic(s, j)
            local x, py = 8 + (j - 1) * GRID_STEP, y + (GRID_STEP - GRID_ICON) // 2
            p:SetPos(x, py)
            s.gridAt[j] = { x, py }
            p.hidden = not Kit.setItem(p, e.id)
        end
        for j = #l.items + 1, #(s.gridPics or {}) do s.gridPics[j].hidden = true end
        return
    end
    hideGrid(s)
    if l.kind == "sites" then
        s.itemId = nil
        t.hidden = true
        if s.icon then s.icon.hidden = true end
        if s.button then s.button:show(false) end
        if s.words then s.words[1].hidden, s.words[2].hidden = true, true end
        hidePics(s)
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
            s.caption = Kit.text(s.layer, 0, 0, 10, LINE_H) -- centred: the name of the dig site under the mouse
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
        if b.w ~= bw or b.h ~= bh then b.w, b.h = bw, bh; pcall(function() b.sb.root:SetSize(bw, bh) end) end -- only when it changed
        local by = y + (l.h - bh) // 2
        b:place(ROW_ICON_W + 14, by)
        if l.text2 ~= nil then
            -- Two lines: the button's own words cannot break a line (they show as one cut-off line), so two lines of our own lie on top of an
            -- empty button. The mouse goes through them to it.
            b:setLabel("")
            local t1, t2 = self:slotWords(s, b)
            local ox, oy = ROW_ICON_W + 14, by -- where the button is; 0, 0 when the words are inside it
            if s.wordsInButton then ox, oy = 0, 0 end
            t1:SetPos(ox, oy + bh // 2 - LINE_H + 1); t1:SetSize(bw, LINE_H)
            t2:SetPos(ox, oy + bh // 2 - 1);          t2:SetSize(bw, LINE_H)
            t1.content, t2.content = plain(l.text), plain(l.text2)
            t1.hidden, t2.hidden = false, false
            pcall(function() t1:MoveToFront(); t2:MoveToFront() end) -- in front of the button's own parts
        else
            b:setLabel(plain(l.text))
            if s.words then s.words[1].hidden, s.words[2].hidden = true, true end
        end
        b:show(true)
        t.hidden = true
        hidePics(s)
        return
    end
    s.itemId = nil
    if s.icon then s.icon.hidden = true end
    if s.button then s.button:show(false) end
    if s.words then s.words[1].hidden, s.words[2].hidden = true, true end
    if l.kind == "pic" and l.pic == nil and l.picItem ~= nil then
        local p = slotObjPic(s)
        pcall(function() p.colour = WHITE end)
        p:SetPos(10, y + (PIC_ROW_H - ROW_ICON_H) // 2)
        if s.objItem ~= l.picItem and Kit.setItem(p, l.picItem) then s.objItem = l.picItem end
        p.hidden = false
        if s.pic then s.pic.hidden = true end
    elseif l.kind == "pic" then
        local p = slotPic(s)
        pcall(function() p.colour = WHITE end)
        local pw, ph = l.picW or ROW_ICON_H, math.min(PIC_ROW_H, l.picH or ROW_ICON_H) -- the wiki's button is not square
        p:SetSize(pw, ph)
        p:SetPos(10, y + (PIC_ROW_H - ph) // 2)
        pcall(function() p.spriteID = l.pic end)
        p.hidden = false
        if s.objPic then s.objPic.hidden = true end
    else
        hidePics(s)
    end
    t:SetSize(w - l.indent - 6, l.h)
    t:SetPos(l.indent, y)
    t.content = plain(l.text)
    pcall(function() t.rgba = l.heading and HEADING_RGBA or TEXT_RGBA end)
    pcall(function() t.alpha = l.note and 0.7 or 1.0 end)
    t.hidden = false
end

end }
