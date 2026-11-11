-- Too Many Runes - Predictive fill in the search box (in the spirit of Minecraft's command line)
-- While you type, a list of choices pops up just above the box: item names that fit what is typed ("rune pl" -> Rune platebody ...), or,
-- while an @ word is being typed ("@cas"), the @ words that fit ("@castra-debris" ...). Up to MAX_CHOICES; VISIBLE rows show at a time.
--   * The first line is what you are typing yourself, and it is picked (yellow) to begin with: nothing is filled in unless you ask. The
--   others (grey) are the choices.
--   * Tab: pick the next choice down (Shift+Tab: the one above); the list scrolls to keep it in view. The rest of the picked choice shows
--   faintly in the box, after what you typed. Nothing is typed yet.
--   * A space after Tab puts the picked choice in the box, with the space after it, so you can type on.
--   * The mouse wheel over the list scrolls it; a line at the bottom says how many more there are ("(scroll down: 12 more)").
--   * Enter, or a click on a choice: type it into the box (and search it); the list closes.
--   * Esc, or a click anywhere else (the box loses the typing cursor), closes the list; a click back in the box (or typing) brings it back.
-- (The box itself also takes the Tab key as a letter - it shows as a space - so tabs are taken out of what the box reports.)
-- The list only comes up for typing: a search made by a click (a picture, "Made at", the X) closes it. The @ words come from core/query.lua
-- (Query.suggest); the names from the search's own matches (core/search.lua, so the hide switches and the filter apply).
-- (How the files fit together is explained at the top of main.lua.)
return { run = function(T)
local _ENV = T

local MAX_CHOICES, VISIBLE, ROW_H = 100, 8, 20
local MIN_NAME = 2 -- (names are offered once this many letters are typed)
local KEY = { TAB = 80, ESCAPE = 13, ENTER = 84 } -- (the game's key numbers, from the API docs' GameKey list)
local PICKED_RGBA, OTHER_RGBA, OVER_RGBA, MORE_RGBA, GHOST_RGBA = 0xFFFF55FF, 0xAAAAAAFF, 0xD8D8D8FF, 0x8C8C8CFF, 0x8C8C8CFF
local TEXT_LEFT = 10 -- (where the box's own text starts, when the box does not say: the hint "Search:" sits there too)
Suggest = { list = {}, rows = {}, sel = 1, top = 1, total = 0, typed = nil, mine = nil, shown = false }

-- The list: one layer (brought in front of the item list in one go) holding a solid back, a frame, VISIBLE rows and the "more" line.
local layer = ui.Layer.new(Window.content)
layer.hidden = true
local back = Kit.rect(layer, 0, 0, 1, 1, Vector4.new(0.0, 0.0, 0.0, 0.85))
local frame = Kit.frame(layer)
local more = Kit.text(layer, 0, 0, 10, ROW_H, "left")
pcall(function() more.clickthrough = true; more.rgba = MORE_RGBA end)
for k = 1, VISIBLE do
    local r = {}
    r.text = Kit.text(layer, 0, 0, 10, ROW_H, "left")
    pcall(function() r.text.clickthrough = true end)
    r.hit = ui.Layer.new(layer) -- (made last, so it is on top and gets the mouse)
    pcall(function() r.hit.clickthrough = false end)
    r.hit:Subscribe(ui.Hook.ONMOUSEOVER, function() r.over = true; Suggest.paint(); return true end)
    r.hit:Subscribe(ui.Hook.ONMOUSELEAVE, function() r.over = false; Suggest.paint(); return true end)
    r.hit:Subscribe(ui.Hook.ONCLICK, function()
        local i = Suggest.top + k - 1
        if Suggest.list[i] ~= nil then Suggest.sel = i; Suggest.accept() end
        return false
    end)
    Suggest.rows[k] = r
end
-- The faint rest of the picked choice, in the box after the typed words.
local ghost = Kit.text(Window.content, 0, 0, 10, 28, "left")
pcall(function() ghost.clickthrough = true; ghost.isShadowed = false; ghost.rgba = GHOST_RGBA end)
ghost.hidden = true

-- The mouse wheel over the list scrolls it (one row a notch).
local function scroll(dir)
    local n = #Suggest.list
    local top = math.max(1, math.min(Suggest.top + dir, n - VISIBLE + 1))
    if top ~= Suggest.top then Suggest.top = top; Suggest.place() end
end
Kit.wheel(layer, scroll)
Suggest.layer, Suggest.more = layer, more -- (dev/mock_test.lua)
for _, r in ipairs(Suggest.rows) do Kit.wheel(r.hit, scroll) end

-- The box's own text: where it starts, and how wide some words are in its letters.
local function boxText()
    local input = Window.search and Window.search.field and Window.search.field.root
    local left = tonumber(field(field(input, "contentMargin"), "left"))
    local font = nil
    pcall(function() local f = input.text.font; font = (type(f) == "number") and config.Font.FromID(f) or f end)
    local function width(text)
        local w = nil
        if font ~= nil then w = try(function() return font:GetStringWidth(text, true) end) end
        if type(w) ~= "number" then w = textWidth(text) end
        return w
    end
    return (left ~= nil and left > 0) and left or TEXT_LEFT, width
end

-- The @ word at the end of the search text: what comes before it, and the word typed so far (spaces allowed: "@castra deb"). nil when the
-- text does not end in an @ word, or a level or number comes after it ("@smithing >60").
local function atTail(text)
    local at = nil
    for p in string.gmatch(text, "()@") do at = p end
    if at == nil then return nil end
    local before, typed = string.sub(text, 1, at - 1), string.sub(text, at + 1)
    for tok in string.gmatch(typed, "%S+") do
        if string.match(tok, "^[<>=]") or string.match(tok, "^%d") then return nil end
    end
    return before, typed
end

-- Item names that fit the typed words, best first: names that start with them, then names that only hold them; shorter names first. One
-- of each name, from the search's own matches. Returns the best `max` and how many names fit in all.
local function nameChoices(q, max)
    local best, count = {}, 0
    local function better(a, b)
        if a.starts ~= b.starts then return a.starts end
        if #a.lower ~= #b.lower then return #a.lower < #b.lower end
        return a.lower < b.lower
    end
    local seen = {}
    for _, slot in ipairs(Search.results or {}) do
        local lower = Items.lower[slot]
        if lower ~= nil and not seen[lower] then
            seen[lower] = true
            count = count + 1
            local c = { lower = lower, name = Items.names[slot], starts = string.sub(lower, 1, #q) == q }
            if #best < max or better(c, best[#best]) then
                local at = #best + 1
                while at > 1 and better(c, best[at - 1]) do at = at - 1 end
                table.insert(best, at, c)
                if #best > max then best[#best] = nil end
            end
        end
    end
    return best, count
end

-- Colours only: the picked row yellow, the others grey (a row under the mouse a little lighter); and the faint rest in the box.
function Suggest.paint()
    for k, r in ipairs(Suggest.rows) do
        local i = Suggest.top + k - 1
        local colour = (i == Suggest.sel) and PICKED_RGBA or (r.over and OVER_RGBA or OTHER_RGBA)
        pcall(function() r.text.rgba = colour end)
    end
    local c = Suggest.list[Suggest.sel]
    local text = Search.text or ""
    local rest = nil
    if Suggest.shown and c ~= nil and not c.own and #c.fill > #text and string.lower(string.sub(c.fill, 1, #text)) == string.lower(text) then
        rest = string.sub(c.fill, #text + 1)
    end
    if rest == nil then ghost.hidden = true; return end
    pcall(function()
        local x, y, w = Window.searchBox()
        local left, width = boxText()
        local at = left + width(text)
        if at + 8 >= w then ghost.hidden = true; return end -- (no room: the box is full)
        ghost:SetPos(x + at, y)
        ghost:SetSize(w - at - 30, 28)
        ghost.content = plain(rest)
        ghost.hidden = false
        ghost:MoveToFront()
    end)
end

-- Show the list (or hide it), just above the search box: the rows from Suggest.top, and the "more" line when there are more.
function Suggest.place()
    local n = #Suggest.list
    if n == 0 or Window.collapsed or Window.closed then
        Suggest.shown = false
        layer.hidden = true
        ghost.hidden = true
        return
    end
    Suggest.top = math.max(1, math.min(Suggest.top, n - VISIBLE + 1))
    local rowsShown = math.min(VISIBLE, n)
    local below = n - (Suggest.top + rowsShown - 1)
    if Suggest.total > n then below = below + (Suggest.total - n) end -- (the ones past MAX_CHOICES are counted too)
    local moreText = nil
    if below > 0 then moreText = "(scroll down: " .. ((below > 99) and "99+" or tostring(below)) .. " more)"
    elseif Suggest.top > 1 then moreText = "(scroll up for the start)" end
    local ok = pcall(function()
        local x, y, w = Window.searchBox()
        local h = (rowsShown + (moreText and 1 or 0)) * ROW_H + 6
        layer:SetPos(x, y - h - 2)
        layer:SetSize(w, h)
        back:SetPos(0, 0); back:SetSize(w, h)
        frame:place(0, 0, w, h)
        for k, r in ipairs(Suggest.rows) do
            local c = (k <= rowsShown) and Suggest.list[Suggest.top + k - 1] or nil
            r.text.hidden = c == nil
            r.hit.hidden = c == nil
            if c ~= nil then
                local ry = 3 + (k - 1) * ROW_H
                r.text:SetPos(8, ry); r.text:SetSize(w - 16, ROW_H)
                r.text.content = plain(c.label)
                r.hit:SetPos(0, ry); r.hit:SetSize(w, ROW_H)
            else
                r.over = false
            end
        end
        more.hidden = moreText == nil
        if moreText ~= nil then
            more:SetPos(8, 3 + rowsShown * ROW_H); more:SetSize(w - 16, ROW_H)
            more.content = moreText
        end
        layer.hidden = false
        layer:MoveToFront()
    end)
    Suggest.shown = ok
    if not ok then layer.hidden = true end
    Suggest.paint()
end

function Suggest.close()
    Suggest.list, Suggest.sel, Suggest.top, Suggest.total, Suggest.typed, Suggest.mine = {}, 1, 1, 0, nil, nil
    Suggest.place()
end

-- What was typed changed: find the choices for it. (Nothing comes up once the only choice is what is typed.)
function Suggest.update(text)
    text = text or ""
    local list, total = {}, 0
    local before, typed = atTail(text)
    if typed ~= nil then
        local words, all = {}, 0
        if Query ~= nil and Query.suggest ~= nil then
            local ok, got, count = pcall(Query.suggest, typed, MAX_CHOICES)
            if ok and type(got) == "table" then words, all = got, tonumber(count) or #got end
        end
        local own = Recipes.materialSlug(typed)
        for _, w in ipairs(words) do
            if w ~= own then list[#list + 1] = { label = "@" .. w, fill = before .. "@" .. w } end -- (not the word typed: it is line 1)
        end
        total = all
    else
        local q = string.lower(text):match("^%s*(.-)%s*$")
        if #q >= MIN_NAME and string.sub(q, 1, 1) ~= "#" and Search.spec == nil then
            local names, all = nameChoices(q, MAX_CHOICES)
            for _, c in ipairs(names) do
                if c.lower ~= q then list[#list + 1] = { label = c.name, fill = c.name } end -- (not the name typed: it is line 1)
            end
            total = all
        end
    end
    -- line 1: what is being typed, picked to begin with (only when there are choices to go with it)
    if #list > 0 then
        local label = (typed ~= nil) and ("@" .. typed) or text
        table.insert(list, 1, { label = label, fill = text, own = true })
        if #list > MAX_CHOICES then list[#list] = nil end
    end
    Suggest.list, Suggest.sel, Suggest.top, Suggest.total, Suggest.typed, Suggest.mine = list, 1, 1, math.max(total + 1, #list), text, nil
    Suggest.place()
end

-- Type the picked choice into the box and search it (Enter or a click); the list closes.
function Suggest.accept()
    local c = Suggest.list[Suggest.sel]
    if c == nil then return end
    Suggest.mine = c.fill
    Window.runSearch(c.fill)
    Suggest.close()
end

-- Is the mouse on the list? (A click on a choice takes the typing cursor from the box first: the list must stay for that click.)
local function mouseOnList()
    for _, r in ipairs(Suggest.rows) do if r.over then return true end end
    local ok, over = pcall(function() return layer.isMouseOver == true end)
    return ok and over
end

-- Was the box's change a click elsewhere (it lost the typing cursor) or Esc?
local function leftBox(why)
    if why == nil then return false end
    local result = ui.InputFieldActionResult
    local ok, hit = pcall(function() return why == result.SUBMIT_ON_FOCUS_LOSS or why == result.SUBMIT_ON_ESCAPE end)
    if ok and hit then return true end
    local s = string.upper(tostring(why))
    return string.find(s, "FOCUS", 1, true) ~= nil or string.find(s, "ESCAPE", 1, true) ~= nil
end

-- Typing (the box's own report of a change) looks for choices; a search the plugin made itself (a picked choice) does not; any other new
-- search (a click on a picture, the X, a filter) closes the list, and so does a click anywhere else.
local onChange = Window.search.onChange
Window.search.onChange = function(text, why)
    text = text or ""
    if string.find(text, "[\t\r\n]") then -- (Tab and Enter are keys for the list, not letters for the box)
        text = string.gsub(text, "[\t\r\n]", "")
        pcall(function() Window.search:setText(text) end)
    end
    -- a space typed while a choice (not line 1) is picked: that choice goes in the box, with the space after it
    local c = Suggest.list[Suggest.sel]
    if c ~= nil and not c.own and Suggest.typed ~= nil and text == Suggest.typed .. " " and not leftBox(why) then
        local filled = c.fill .. " "
        Suggest.mine = filled
        Window.runSearch(filled)
        pcall(Suggest.update, filled)
        return
    end
    local typed = (text ~= Search.text) and (text ~= Suggest.mine)
    onChange(text)
    if leftBox(why) then
        if not mouseOnList() then pcall(Suggest.close) end
    elseif typed then
        -- (the search runs once the typing stops - core/search.lua - and the names offered come from its results, so the list follows it:
        -- Window.searchChanged below. Meanwhile the faint rest of the old choice goes, since the words under it changed.)
        if Search.pending ~= nil then
            Suggest.waiting = text
            pcall(function() ghost.hidden = true end)
        else
            pcall(Suggest.update, text)
        end
    end
end
local searchChanged = Window.searchChanged
Window.searchChanged = function(...)
    searchChanged(...)
    local t = Search.text
    if Suggest.waiting ~= nil then -- (typed while the search waited: the list for it now)
        local w = Suggest.waiting
        Suggest.waiting = nil
        if t == w then pcall(Suggest.update, t) return end
    end
    if #Suggest.list > 0 and t ~= Suggest.typed and t ~= Suggest.mine then pcall(Suggest.close) end
end
local layout = Window.layout
Window.layout = function(...)
    layout(...)
    if #Suggest.list > 0 then pcall(Suggest.place) end
end
local setCollapsed = Window.setCollapsed
Window.setCollapsed = function(...)
    setCollapsed(...)
    pcall(Suggest.place)
end

-- A click back in the box brings the list back for what is in it (it went away when the box lost the typing cursor). (A named hook of our
-- own: the box's own click handling carries on, so it still gets the cursor.)
pcall(function()
    Window.search.field.root:Subscribe(ui.Hook.ONCLICK, "tmr3_suggest_back", function()
        if #Suggest.list == 0 and (Search.text or "") ~= "" then pcall(Suggest.update, Search.text) end
        return true
    end)
end)

-- The keys, while the list is showing.
local function keyIs(key, name)
    return (GameKey ~= nil and GameKey[name] ~= nil and key == GameKey[name]) or tonumber(key) == KEY[name]
end
pcall(function()
    Event.KeyDown.Subscribe("tmr3_suggest", function(ev)
        if Suggest == nil or not Suggest.shown then return end
        local n = #Suggest.list
        if n == 0 then return end
        local key = field(ev, "gameKey")
        local shift = (tonumber(field(ev, "modifiers")) or 0) % 2 == 1 -- (bit 1: Shift)
        if keyIs(key, "TAB") then
            if shift then Suggest.sel = (Suggest.sel <= 1) and n or (Suggest.sel - 1) else Suggest.sel = Suggest.sel % n + 1 end
            -- (keep the picked one in view)
            if Suggest.sel < Suggest.top then Suggest.top = Suggest.sel
            elseif Suggest.sel > Suggest.top + VISIBLE - 1 then Suggest.top = Suggest.sel - VISIBLE + 1 end
            Suggest.place()
        elseif keyIs(key, "ENTER") then
            pcall(Suggest.accept)
        elseif keyIs(key, "ESCAPE") then
            pcall(Suggest.close)
        end
    end)
end)

end }
