-- Too Many Runes - The Settings page
-- Opened by the "Settings" button at the top right (ui/window.lua); the same button goes back. The settings are split over four tabs.
-- Each setting is a button that shows its choice, and a click moves to the next choice; the custom color is typed or picked from a
-- grid. Every choice is saved at once (Saved, core/util.lua) and used again at the next start-up. The starting values are the ones in
-- settings.lua (HIDE, WHEEL_UP_NEXT, GAME_MENU, SCAN_SPEED, HOVER_COLOUR). The same page is shown in the Plugin Hub's settings panel.
return { run = function(T)
local _ENV = T

local page = { key = "settings", label = "Settings", noTab = true }

-- The colour tints the picture: the game multiplies the item's own colours by it, so a white tint changes nothing. "Custom" is
-- the player's own hex code, typed on the next row of the Settings page.
local HOVER_COLOURS = {
    { label = "Green",  v = { 0.55, 1.0, 0.55 } }, -- ui/kit.lua's colour until this page is read; the starting colour is HOVER_COLOUR
    { label = "Gold",   v = { 1.0, 0.8, 0.4 } },
    { label = "Blue",   v = { 0.55, 0.75, 1.0 } },
    { label = "Red",    v = { 1.0, 0.5, 0.45 } },
    { label = "Purple", v = { 0.8, 0.6, 1.0 } },
    { label = "Cyan",   v = { 0.5, 1.0, 1.0 } },
    { label = "Orange", v = { 1.0, 0.65, 0.3 } },
    { label = "Pink",   v = { 1.0, 0.6, 0.85 } },
    { label = "Yellow", v = { 1.0, 1.0, 0.45 } },
    { label = "Custom", custom = true },
}
-- A hex colour code ("00FF88" or "#00ff88") as { r, g, b } from 0 to 1, and the code in capitals; nil if it is not one.
local function parseHex(text)
    local hex = string.upper((string.gsub(tostring(text or ""), "^%s*#?", "")))
    hex = string.gsub(hex, "%s+$", "")
    if not string.match(hex, "^%x%x%x%x%x%x$") then return nil end
    return { tonumber(string.sub(hex, 1, 2), 16) / 255, tonumber(string.sub(hex, 3, 4), 16) / 255, tonumber(string.sub(hex, 5, 6), 16) / 255 }, hex
end
local DEFAULT_HEX = "00FF88"
local customHex = select(2, parseHex(Saved.get("hover_hex"))) or DEFAULT_HEX
local SPEEDS = {
    { label = "Gentle (slowest)", v = 0.25 },
    { label = "Smooth", v = 0.5 },
    { label = "Fast (may stutter)", v = 1.0 },
    -- Turbo. Three times full speed for all the reading (the heavy passes and the ones that run at a fixed pace: item
    -- links, skill guides, station pictures; Scan.boost), and four times the items per tick. The game may stutter while it reads, but
    -- it is done in a fraction of the time.
    { label = "Turbo", v = 3.0, items = 1200, boost = 3, icons = 1000 }, -- 1000 pictures a tick is a whole page at once
}
local NORMAL_ITEMS = ITEMS_PER_TICK -- settings.lua's value, used by every speed but Turbo
local function indexOf(list, test) for k, e in ipairs(list) do if test(e) then return k end end return 1 end
-- The starting hover colour is settings.lua's HOVER_COLOUR (Gold).
local HOVER_START = indexOf(HOVER_COLOURS, function(e) return not e.custom and e.label == HOVER_COLOUR end)
do local c = HOVER_COLOURS[HOVER_START].v; HOVER_TINT = Vector4.new(c[1], c[2], c[3], 1.0); HOVER_RGB = { c[1], c[2], c[3] } end

-- The starting values (settings.lua and ui/kit.lua), for the reset button.
local DEFAULTS = { wheel = WHEEL_UP_NEXT, menu = GAME_MENU, hover = HOVER_TINT, speed = SCAN_SPEED, debug = SHOW_DEBUG_NAMES,
                   rgb = HOVER_RGB, outline = HOVER_OUTLINE, seeThrough = (WINDOW_SEE_THROUGH ~= false), group = (GROUP_FORMS ~= false) }
-- The see-through switch: what was used when the window was made (ui/window.lua), and whether a change waits for the next start.
local seeThrough = (Saved.get("see_through") or (DEFAULTS.seeThrough and "on" or "off")) == "on"
local OUTLINE_ON = ((tonumber(HOVER_OUTLINE) or 0) > 0) and HOVER_OUTLINE or 2 -- the outline's size when it is switched on
local SAVED_KEYS = { "collapsed", "debug_names", "recent_open", "details_tab", "filter", "game_menu", "hide_noted", "hide_broken", "hide_junk", "hide_dungeoneering", "hide_discontinued", "hide_minigames",
                     "hover", "hover_hex", "outline", "see_through", "scan_speed", "tab", "view", "wheel_up", "win_w", "win_h", "win_x", "win_y",
                     "icon_x", "icon_y", "group_forms" } -- not "favourites"; the minimized rune icon's place is reset too

-- Use the saved choices now (before anything is shown).
local saved = Saved.get("wheel_up")
if saved == "next" then WHEEL_UP_NEXT = true elseif saved == "back" then WHEEL_UP_NEXT = false end
saved = Saved.get("game_menu")
if saved == "on" then GAME_MENU = true elseif saved == "off" then GAME_MENU = false end
saved = Saved.get("debug_names")
if saved == "on" then SHOW_DEBUG_NAMES = true elseif saved == "off" then SHOW_DEBUG_NAMES = false end
saved = Saved.get("group_forms")
if saved == "on" then GROUP_FORMS = true elseif saved == "off" then GROUP_FORMS = false end
saved = Saved.get("outline")
if saved == "on" then HOVER_OUTLINE = OUTLINE_ON elseif saved == "off" then HOVER_OUTLINE = 0 end
local hoverAt = Saved.get("hover") and indexOf(HOVER_COLOURS, function(e) return e.label == Saved.get("hover") end) or HOVER_START
local function applyHover()
    local e = HOVER_COLOURS[hoverAt]
    local c = e.custom and (parseHex(customHex) or { 1, 1, 1 }) or e.v
    HOVER_TINT = Vector4.new(c[1], c[2], c[3], 1.0)
    HOVER_RGB = { c[1], c[2], c[3] }
end
if Saved.get("hover") ~= nil then applyHover() end
local speedAt = indexOf(SPEEDS, function(e) return tostring(e.v) == tostring(Saved.get("scan_speed") or SCAN_SPEED) end)
local function applySpeed()
    local s = SPEEDS[speedAt]
    SCAN_SPEED = s.v
    Scan.factor = SCAN_SPEED
    ITEMS_PER_TICK = s.items or NORMAL_ITEMS
    Scan.boost = s.boost or 1
    -- How many new item pictures a page puts up per tick: Turbo a whole page in one tick, the other speeds 36 a tick. (The game then
    -- takes a moment to draw a picture it has not shown before; TMR cannot speed that up.)
    ItemBox.ICONS_PER_TICK = s.icons or 36
end
applySpeed() -- always: every speed sets the items per tick, the boost and the pictures per tick

-- The settings: { words, value() giving the button's words, click() }
local function onOff(flag) return flag and "On" or "Off" end
-- The rows come in groups, each under its heading: what the list hides, searching and browsing, looks, the game's right-click
-- menu, start-up, reset. hideRow makes the row for one hide switch.
local function hideRow(words, name, alsoUses)
    return { words = words, value = function() return onOff(Filters.hide[name]) end,
             click = function()
                 Filters.setHide(name, not Filters.hide[name])
                 if alsoUses and Recipes.clearUsedLists then Recipes.clearUsedLists() end -- the Uses lists leave these out, so make them again
                 if Details ~= nil and Details.refreshInfo ~= nil then pcall(Details.refreshInfo) end -- redraws the "Hidden by" line
             end }
end
local ROWS = {
    -- First come the settings that help to see what is under the mouse.
    { heading = "Accessibility:" },
    { words = "Outline round the item under the mouse", value = function() return onOff((tonumber(HOVER_OUTLINE) or 0) > 0) end,
      click = function()
          HOVER_OUTLINE = ((tonumber(HOVER_OUTLINE) or 0) > 0) and 0 or OUTLINE_ON
          Saved.set("outline", (HOVER_OUTLINE > 0) and "on" or "off")
      end },
    { words = "Color of a picture under the mouse",
      value = function() local e = HOVER_COLOURS[hoverAt]; return e.custom and ("Custom #" .. customHex) or e.label end,
      click = function()
          hoverAt = hoverAt % #HOVER_COLOURS + 1
          applyHover()
          for _, p in pairs(Window.pages) do if p.box ~= nil then pcall(p.box.paintMarks, p.box) end end -- the marks are tinted with it
          Saved.set("hover", HOVER_COLOURS[hoverAt].label)
      end },
    { words = "Custom color: Type any valid Hex code", input = true, maxLength = 7,
      current = function() return customHex end,
      placeholder = function() return customHex end,
      apply = function(text)
          local _, hex = parseHex(text)
          if hex == nil then return false end
          customHex = hex
          Saved.set("hover_hex", hex)
          hoverAt = indexOf(HOVER_COLOURS, function(e) return e.custom == true end)
          applyHover()
          Saved.set("hover", "Custom")
          return true
      end },
    { words = "See-through window (follows the game's own interface transparency setting)",
      value = function() return onOff(seeThrough) end,
      click = function()
          seeThrough = not seeThrough
          Saved.set("see_through", seeThrough and "on" or "off")
          pcall(Window.applySeeThrough, seeThrough)
      end },
    { heading = "Hide from the item list:" },
    hideRow("Noted items", "noted"),
    hideRow("Broken items", "broken"),
    hideRow("Dungeoneering items", "dungeoneering"),
    hideRow("Discontinued items (no longer obtainable)", "discontinued"),
    hideRow("Minigame items (Castle Wars, Barbarian Assault, Stealing Creation ...)", "minigames"), -- the hide switch for Misc > Minigames
    hideRow("Junk filter (removed, MTX, lent, event, puzzle, lamp, loyalty ... items)", "junk", true),
    { heading = "Searching and browsing:" },
    { words = "Group the forms of an item under one picture (doses, charges, augmented ...)", value = function() return onOff(GROUP_FORMS ~= false) end,
      click = function()
          GROUP_FORMS = (GROUP_FORMS == false)
          Saved.set("group_forms", GROUP_FORMS and "on" or "off")
          if Search.refresh then Search.refresh() end
      end },
    { words = "Mouse wheel down goes to the", value = function() return (WHEEL_UP_NEXT == false) and "Next page" or "Page before" end,
      click = function()
          WHEEL_UP_NEXT = (WHEEL_UP_NEXT == false)
          Saved.set("wheel_up", WHEEL_UP_NEXT and "next" or "back")
      end },
    { words = "Show and search the game's debug names", value = function() return onOff(SHOW_DEBUG_NAMES == true) end,
      click = function()
          SHOW_DEBUG_NAMES = not (SHOW_DEBUG_NAMES == true)
          Saved.set("debug_names", SHOW_DEBUG_NAMES and "on" or "off")
          Details.refreshInfo()
          if Search.refresh then Search.refresh() end -- the search finds debug names only while they are shown
      end },
    { heading = "The game's right-click menu:" },
    { words = "Recipe / Uses / Source entries on items", value = function() return onOff(GAME_MENU ~= false) end,
      click = function()
          GAME_MENU = (GAME_MENU == false)
          Saved.set("game_menu", GAME_MENU and "on" or "off")
      end },
    { heading = "Start-up:" },
    { words = "Speed of reading the game's data", value = function() return SPEEDS[speedAt].label end,
      click = function()
          speedAt = speedAt % #SPEEDS + 1 -- each click picks the next speed
          applySpeed()
          Saved.set("scan_speed", tostring(SCAN_SPEED))
      end },
    { note = "The speed matters only while the game's data is being read (about a minute after start-up)." },
    { heading = "Reset:" },
    { reset = true, words = "Reset every setting to its default - how a new player starts (your Favorites stay)",
      value = function() return page.armed and "Click again to reset" or "Reset to default" end,
      click = function()
          if not page.armed then page.armed = true return end -- the first click only asks; a second click resets
          page.armed = false
          -- In a pcall, so a part that goes wrong cannot stop the reset before its message. The console always reports the reset.
          local ok, err = pcall(page.resetAll)
          if ok then say("Settings reset to default.")
          else say("Settings reset to default (one part of it did not work: " .. tostring(err) .. ").") end
      end },
    { note = "Changes are saved straight away." },
}

page.rows = ROWS -- shared for the offline test
local BUTTON_W, ROW_H = 150, 28

-- The settings are split over tabs so only a few show at once. Each heading above belongs to one tab, and every row under a heading
-- goes with it.
local TABS = { { key = "looks", label = "Accessibility" }, { key = "hide", label = "Hide items" }, { key = "browse", label = "Browsing" },
               { key = "other", label = "Other" } }
local TAB_OF_HEADING = { ["Accessibility:"] = "looks", ["Hide from the item list:"] = "hide", ["Searching and browsing:"] = "browse",
                         ["The game's right-click menu:"] = "other", ["Start-up:"] = "other", ["Reset:"] = "other" }
do
    local cur = TABS[1].key
    for _, r in ipairs(ROWS) do
        if r.heading ~= nil then cur = TAB_OF_HEADING[r.heading] or cur end
        r.tab = cur
    end
end
local TABS_H = 26          -- the height of the tabs
local TOP = TABS_H + 14    -- where the rows start, under the tabs
local MAX_W = 640          -- the rows are never wider than this, so a button stays near its words in a wide window
local STRIPE = Vector4.new(1, 1, 1, 0.04)                          -- the faint band behind every other row
local BAND = Vector4.new(227 / 255, 194 / 255, 122 / 255, 0.18)    -- the gold band behind the row under the mouse
local ON_RGBA = 0x7FD67FFF -- "On" is green; "Off" is dim (DIM_RGBA); any other value keeps the normal text colour
-- The colour picker under the custom colour row: a grid of swatches, shown when the typing box is clicked. PICK_COLS hues across, six
-- shades of each from light to dark, and a row of greys at the bottom.
local PICK_COLS, PICK_SIZE, PICK_GAP = 12, 18, 2
local PICK_HEXES = {}
do
    local function hex(r, g, b) return string.format("%02X%02X%02X", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5)) end
    local function hsv(h, s, v) -- hue 0-360, saturation and brightness 0-1, to a hex code
        local c = v * s
        local x = c * (1 - math.abs((h / 60) % 2 - 1))
        local m = v - c
        local r, g, b = 0, 0, 0
        if h < 60 then r, g = c, x elseif h < 120 then r, g = x, c elseif h < 180 then g, b = c, x
        elseif h < 240 then g, b = x, c elseif h < 300 then r, b = x, c else r, b = c, x end
        return hex(r + m, g + m, b + m)
    end
    for _, sv in ipairs({ { 0.3, 1 }, { 0.6, 1 }, { 1, 1 }, { 1, 0.8 }, { 1, 0.6 }, { 1, 0.4 } }) do
        for col = 0, PICK_COLS - 1 do PICK_HEXES[#PICK_HEXES + 1] = hsv(col * 360 / PICK_COLS, sv[1], sv[2]) end
    end
    for col = 0, PICK_COLS - 1 do local g = 1 - col * 0.8 / (PICK_COLS - 1); PICK_HEXES[#PICK_HEXES + 1] = hex(g, g, g) end
end
local PICK_ROWS = #PICK_HEXES // PICK_COLS
local PICK_H = PICK_ROWS * (PICK_SIZE + PICK_GAP) + 16 -- the room the open picker and its border take under its row
local function hexColour(h) local c = parseHex(h) or { 1, 1, 1 }; return Vector4.new(c[1], c[2], c[3], 1.0) end

-- Colours a setting's button by its value, so the page can be read at a glance. The red Reset button is left alone.
local function paintValue(r, button, label)
    if r.reset or button.setTextColour == nil then return end
    button:setTextColour((label == "On") and ON_RGBA or (label == "Off") and DIM_RGBA or TEXT_RGBA)
end

-- Back to how a new player starts: every switch and choice, the list's filter and view, the details tab, the window's size and
-- place. Favourites stay. Everything is put right at once and the saved choices are forgotten.
function page.resetAll()
    for _, name in ipairs({ "noted", "broken", "junk", "dungeoneering", "discontinued", "minigames" }) do
        Filters.setHide(name, (HIDE or {})[name] == true)
    end
    if Recipes.clearUsedLists then Recipes.clearUsedLists() end
    WHEEL_UP_NEXT, GAME_MENU, HOVER_TINT, SHOW_DEBUG_NAMES = DEFAULTS.wheel, DEFAULTS.menu, DEFAULTS.hover, DEFAULTS.debug
    HOVER_OUTLINE, customHex = DEFAULTS.outline, DEFAULT_HEX
    GROUP_FORMS, HOVER_RGB = DEFAULTS.group, DEFAULTS.rgb
    seeThrough = DEFAULTS.seeThrough
    pcall(Window.applySeeThrough, seeThrough)
    for _, view in ipairs(Settings.views) do
        for _, part in pairs(view.parts) do if part.input ~= nil then part.input:setText("") end end
    end
    Details.refreshInfo()
    if Recent ~= nil and Recent.setOpen ~= nil then Recent.setOpen(false) end -- the panel starts closed
    hoverAt = HOVER_START
    speedAt = indexOf(SPEEDS, function(e) return tostring(e.v) == tostring(DEFAULTS.speed) end)
    applySpeed()
    Shelves.setTab("all"); pcall(ShelfTabs.paint) -- back on the All tab
    Window.setView(VIEW_DEFAULT); Window.view:select(VIEW_DEFAULT)
    Window.runSearch("")
    for _, d in ipairs(Details.all) do d.wantTab = nil; d:showTab(Details.TABS[1].key) end
    pcall(function() -- the starting place: in the middle, near the top of the game screen
        local sw, sh = screenSize()
        if sw > 0 and sh > 0 then Window.win.root:SetPos(math.floor((sw - WINDOW_W - 16) / 2), math.floor(sh * 0.06)) end
    end)
    -- Moving the window like that leaves its dragging stuck until it is minimized and opened again, so that is done here too; resetSize
    -- then opens it at the starting size.
    Window.setCollapsed(true)
    Window.resetSize()
    Window.show("search")
    for _, key in ipairs(SAVED_KEYS) do Saved.set(key, "") end
end

-- The settings are shown in two places, built from the same ROWS: this page of the window, and the Settings panel of the game's Plugin
-- Hub (its cog in the Manage tab: Event.SettingsLayerReady, "hasSettingsIcon" in plugin.json). Both change the same values, and a click
-- in either one updates the buttons of both (Settings.refreshAll).
Settings = { views = {} }

Settings.tab = TABS[1].key -- the open tab, the same in both places

-- Opens a tab in every place the settings are shown, scrolled back to the top.
function Settings.openTab(key)
    Settings.tab = key
    for _, view in ipairs(Settings.views) do
        view.scroll = 0
        view.pickerOpen = false -- the colour picker closes when another tab opens
        pcall(function() view.tabs:select(key) end)
        if view.w ~= nil and view.relayout ~= nil then pcall(view.relayout) end
    end
end

-- Every tick: the gold band goes behind the row the mouse is on (its words, button or typing box), so it is clear which setting a
-- click will change.
Event.Logic.Subscribe("tmr3_settings_hover", function()
    if Settings == nil then return end -- the plugin was switched off
    for _, view in ipairs(Settings.views) do
        pcall(function()
            if view.w == nil then return end
            -- the colour picker, a moment after a click away from its box
            if view.pickerOpen and view.pickerCloseAt ~= nil and tickCount >= view.pickerCloseAt then
                view.pickerOpen, view.pickerCloseAt = false, nil
                if view.relayout ~= nil then view.relayout() end
            end
            local at = nil
            for k, part in ipairs(view.parts) do
                if at == nil and part.rowY ~= nil then
                    local over = (part.text.isMouseOver == true)
                    if not over and part.button ~= nil then over = part.button:isHovered() end
                    if not over and part.input ~= nil then over = (part.input.field.root.isMouseOver == true) end
                    if not over and part.pickPanel ~= nil and view.pickerOpen then over = (part.pickPanel.isMouseOver == true) end
                    if not over and part.swatches ~= nil and view.pickerOpen then -- the open colour picker belongs to its row
                        for _, sw in ipairs(part.swatches) do if sw.isMouseOver == true then over = true break end end
                    end
                    if over then at = part end
                end
            end
            -- Between two swatches the mouse is on nothing: the band stays on the picker's row while the picker is open.
            if at == nil and view.pickerOpen and view.bandAt ~= nil and view.bandAt.swatches ~= nil and not view.band.hidden then
                at = view.bandAt
            end
            if at == nil then
                if not view.band.hidden then view.band.hidden = true end
            elseif view.bandAt ~= at or view.band.hidden then
                view.band:SetPos(10, at.rowY); view.band:SetSize(view.cw - 14, at.rowH)
                view.band.hidden = false
            end
            view.bandAt = at
        end)
    end
end)

function Settings.refreshAll()
    for _, view in ipairs(Settings.views) do
        for k, r in ipairs(ROWS) do
            local part = view.parts[k]
            if part ~= nil and part.button ~= nil then
                pcall(function() local label = r.value(); part.button:setLabel(label); part.valueLabel = label; paintValue(r, part.button, label) end)
            end
            if part ~= nil and part.preview ~= nil then pcall(function() part.preview.colour = hexColour(r.current()) end) end -- the live preview
        end
    end
end
local refreshButtons = Settings.refreshAll

-- Makes the words and buttons of every setting on a layer. Returns the view ({ parts }).
local function buildView(parent)
    -- Everything sits on a layer of its own the size of the box. It scrolls with the mouse wheel when the settings do not all fit,
    -- since the Plugin Hub's panel is short.
    local layer = ui.Layer.new(parent)
    local view = { parts = {}, layer = layer, scroll = 0 }
    view.wheel = function(step)
        if view.wheelTick == tickCount then return end -- one notch reaches every part under the mouse, so act once
        view.wheelTick = tickCount
        view.scroll = view.scroll + step * 40
        if view.w ~= nil then view.relayout() end
    end
    Kit.wheel(layer, view.wheel)
    -- Made first so they are drawn behind the words and buttons: a faint stripe for each row, then the band for the row under the mouse.
    view.stripes = {}
    for k = 1, #ROWS do view.stripes[k] = Kit.rect(layer, 0, 0, 1, 1, STRIPE); view.stripes[k].hidden = true end
    view.band = Kit.rect(layer, 0, 0, 1, 1, BAND)
    view.band.hidden = true
    -- The tabs along the top. A click opens that tab in both places the settings are shown.
    view.tabs = Kit.tabStrip(layer, TABS_H, function(key) Settings.openTab(key) end)
    for _, t in ipairs(TABS) do view.tabs:add(t.key, t.label) end
    view.tabs:select(Settings.tab)
    for k, r in ipairs(ROWS) do
        local part = {}
        part.text = Kit.text(layer, 0, 0, 10, 22, "left")
        Kit.wheel(part.text, view.wheel)
        part.text.content = r.heading or r.words or r.note
        if r.heading then pcall(function() part.text.rgba = 0xE8C060FF end) end
        if r.note then pcall(function() part.text.alpha = 0.7 end) end
        if r.input then -- a box to type in: the hex colour
            part.input = Kit.input(layer, BUTTON_W, 24, r.placeholder and r.placeholder() or "", r.maxLength)
            part.input.onChange = function(text, why)
                local ok, used = pcall(r.apply, text)
                if ok and used then Settings.refreshAll() end
                -- A click away from the box (or Esc) closes the colour picker. Not at once: the click may be on a swatch, which must
                -- still be there to get it, so the tick check below closes it a moment later.
                local left = false
                pcall(function()
                    local result = ui.InputFieldActionResult
                    left = (why == result.SUBMIT_ON_FOCUS_LOSS or why == result.SUBMIT_ON_ESCAPE)
                end)
                if not left and why ~= nil then
                    local s = string.upper(tostring(why))
                    left = (string.find(s, "FOCUS", 1, true) ~= nil or string.find(s, "ESCAPE", 1, true) ~= nil)
                end
                if left and view.pickerOpen then
                    local onSwatch = (part.pickPanel ~= nil and part.pickPanel.isMouseOver == true)
                    for _, sw in ipairs(part.swatches) do if sw.isMouseOver == true then onSwatch = true break end end
                    if onSwatch then
                        view.pickerCloseAt = nil -- inside the picker: a swatch's own click closes it, a click in a gap leaves it open
                    else
                        view.pickerOpen, view.pickerCloseAt = false, nil -- a click anywhere else: closed at once
                        if view.relayout ~= nil then view.relayout() end
                    end
                end
            end
            -- The live preview: a square of the custom colour beside the box, with a thin light edge so a dark colour still shows.
            part.previewEdge = Kit.rect(layer, 0, 0, 24, 24, Vector4.new(0.6, 0.55, 0.43, 1.0))
            part.preview = Kit.rect(layer, 0, 0, 20, 20, hexColour(r.current()))
            -- A click in the box opens the colour picker under the row. The swatches are made the first time, as most players never
            -- open it. A named hook of the plugin's own, so the box's own click handling carries on and it still gets the cursor.
            part.swatches = {}
            local function openPicker()
                if #part.swatches == 0 then
                    -- A dark panel behind the swatches. It takes the clicks that land in the gaps between them, so such a click
                    -- counts as inside the picker and does not close it.
                    -- Round it, the same border as the item hover box (ui/details.lua): four 1-pixel rings from the outside in
                    -- (dark, gold, brown, dark brown), then the dark inside.
                    part.pickRings = {}
                    for k, c in ipairs({ { 46, 37, 26 }, { 112, 100, 68 }, { 89, 72, 46 }, { 51, 40, 29 } }) do
                        part.pickRings[k] = Kit.rect(layer, 0, 0, 1, 1, Vector4.new(c[1] / 255, c[2] / 255, c[3] / 255, 1.0))
                    end
                    part.pickPanel = Kit.rect(layer, 0, 0, 1, 1, Vector4.new(15 / 255, 13 / 255, 11 / 255, 1.0))
                    pcall(function() part.pickPanel.clickthrough = false end)
                    part.pickPanel:Subscribe(ui.Hook.ONCLICK, function() return false end)
                    Kit.wheel(part.pickPanel, view.wheel)
                    for i, h in ipairs(PICK_HEXES) do
                        local sw = Kit.rect(layer, 0, 0, PICK_SIZE, PICK_SIZE, hexColour(h))
                        pcall(function() sw.clickthrough = false end)
                        sw:Subscribe(ui.Hook.ONCLICK, function() -- a click on a swatch uses that colour and closes the picker
                            pcall(function() part.input:setText(h) end)
                            pcall(r.apply, h)
                            view.pickerOpen, view.pickerCloseAt = false, nil
                            Settings.refreshAll()
                            if view.relayout ~= nil then view.relayout() end
                            return false
                        end)
                        Kit.wheel(sw, view.wheel)
                        part.swatches[i] = sw
                    end
                end
                view.pickerCloseAt = nil
                if not view.pickerOpen then
                    view.pickerOpen = true
                    if view.relayout ~= nil then view.relayout() end
                end
            end
            part.openPicker = openPicker -- shared for the offline test
            pcall(function()
                part.input.field.root:Subscribe(ui.Hook.ONCLICK, "tmr3_colour_pick", function() pcall(openPicker) return true end)
            end)
        end
        if r.click ~= nil then
            part.button = Kit.button(layer, r.value(), BUTTON_W, 24, function()
                if not r.reset then page.armed = false end -- any other click calls the reset off
                local ok, err = pcall(r.click)
                if not ok then trouble("changing a setting", err) end
                Settings.refreshAll()
            end)
            if r.reset then Window.redButtons[#Window.redButtons + 1] = part.button end
            part.valueLabel = r.value()
            paintValue(r, part.button, part.valueLabel)
            Kit.wheel(part.button:root(), view.wheel)
        end
        view.parts[k] = part
    end
    view.more = Kit.text(layer, 0, 0, 10, 22, "left") -- "(scroll down for more)" while the bottom is out of sight
    pcall(function() view.more.alpha = 0.6 end)
    Kit.wheel(view.more, view.wheel)
    Settings.views[#Settings.views + 1] = view
    return view
end

-- Places a view's words and buttons in a box w wide. Long words wrap onto more lines.
local function layoutView(view, w, h)
    view.w, view.h = w, h
    view.relayout = function() layoutView(view, view.w, view.h) end
    view.layer:SetPos(0, 0); view.layer:SetSize(w, h)
    view.tabs:place(10, 6)
    local cw = math.min(w, MAX_W) -- the rows' width: a button stays near its words however wide the window is
    view.cw = cw
    -- How tall the open tab's rows are, and how far the wheel may scroll. Rows of the other tabs are hidden.
    local heights, total = {}, 0
    for k, r in ipairs(ROWS) do
        local part = view.parts[k]
        part.rowY = nil -- set below for a row that can be changed and is in sight: the band under the mouse goes there
        if r.tab == Settings.tab then
            local textW = (part.button ~= nil or part.input ~= nil) and (cw - BUTTON_W - 34) or (cw - 24)
            if part.preview ~= nil then textW = textW - 30 end -- room for the preview square beside the box
            local lines = (r.heading and 1) or math.max(1, #wrapText(part.text.content, textW))
            heights[k] = { lines = lines, textW = textW,
                           h = (r.heading and 26) or (r.note and (22 * lines + 4)) or math.max(ROW_H, 22 * lines + 6) }
            -- An open colour picker makes its row taller: top is the row's own height, the swatches go under it.
            heights[k].top = heights[k].h
            if part.swatches ~= nil and view.pickerOpen then heights[k].h = heights[k].h + PICK_H end
            total = total + heights[k].h
        end
    end
    local maxScroll = math.max(0, total + TOP + 8 - h)
    view.scroll = math.max(0, math.min(view.scroll or 0, maxScroll))
    local y = TOP - view.scroll
    local nth = 0 -- counts the rows that can be changed, for the stripe behind every other one
    for k, r in ipairs(ROWS) do
        local part, hk = view.parts[k], heights[k]
        local stripe = view.stripes[k]
        if hk == nil then -- a row of another tab
            part.text.hidden = true
            stripe.hidden = true
            if part.button ~= nil then part.button:show(false) end
            if part.input ~= nil then part.input:show(false) end
            if part.preview ~= nil then part.preview.hidden, part.previewEdge.hidden = true, true end
            for _, sw in ipairs(part.swatches or {}) do sw.hidden = true end
            if part.pickPanel ~= nil then
                part.pickPanel.hidden = true
                for _, ring in ipairs(part.pickRings) do ring.hidden = true end
            end
        else
            -- Out of sight means hidden, so not clickable: above the rows' start (the tabs are there), below the box, or reaching into
            -- "(scroll down for more)" while that shows at the bottom.
            local hintRoom = (view.scroll < maxScroll) and 22 or 0
            local outside = (y < TOP - 2) or (y >= h) or (y + hk.h > h - hintRoom)
            local settable = (part.button ~= nil or part.input ~= nil)
            if r.heading then nth = 0 end -- the stripes start again under each heading: the second, fourth ... row gets one
            if settable then nth = nth + 1 end
            stripe.hidden = outside or not settable or (nth % 2 == 1)
            stripe:SetPos(10, y); stripe:SetSize(cw - 14, hk.h)
            if settable and not outside then part.rowY, part.rowH = y, hk.h end
            local ty = y + math.max(1, (hk.top - 22 * hk.lines) // 2) -- the words in the middle of their row
            part.text:SetSize(hk.textW, 22 * hk.lines)
            part.text:SetPos(r.heading and 10 or 20, ty)
            part.text.hidden = outside
            local by = y + math.max(0, (hk.top - 24) // 2)
            if part.button ~= nil then
                part.button:place(cw - BUTTON_W - 10, by)
                part.button:show(not outside)
            end
            if part.input ~= nil then
                part.input:place(cw - BUTTON_W - 10, by)
                part.input:show(not outside)
            end
            if part.preview ~= nil then -- the preview square, left of the box
                part.previewEdge:SetPos(cw - BUTTON_W - 40, by); part.preview:SetPos(cw - BUTTON_W - 38, by + 2)
                part.preview.hidden, part.previewEdge.hidden = outside, outside
            end
            if part.swatches ~= nil then -- the picker's swatches under the row, right-aligned with the box
                local open = view.pickerOpen and not outside
                local x0 = cw - 10 - PICK_COLS * (PICK_SIZE + PICK_GAP) + PICK_GAP
                if part.pickPanel ~= nil then
                    local px, py = x0 - 4, y + hk.top + 2
                    local pw, ph = PICK_COLS * (PICK_SIZE + PICK_GAP) - PICK_GAP + 8, PICK_ROWS * (PICK_SIZE + PICK_GAP) - PICK_GAP + 8
                    part.pickPanel.hidden = not open
                    part.pickPanel:SetPos(px, py); part.pickPanel:SetSize(pw, ph)
                    for k, ring in ipairs(part.pickRings) do -- ring 1 is the outermost, 4 pixels out from the inside
                        local o = 5 - k
                        ring.hidden = not open
                        ring:SetPos(px - o, py - o); ring:SetSize(pw + 2 * o, ph + 2 * o)
                    end
                end
                for i, sw in ipairs(part.swatches) do
                    sw.hidden = not open
                    if open then
                        sw:SetPos(x0 + ((i - 1) % PICK_COLS) * (PICK_SIZE + PICK_GAP), y + hk.top + 6 + ((i - 1) // PICK_COLS) * (PICK_SIZE + PICK_GAP))
                    end
                end
            end
            y = y + hk.h
        end
    end
    view.band.hidden = true -- shown again by the next tick's check, at the row under the mouse
    view.more.content = "(scroll down for more)"
    view.more:SetSize(w - 20, 22); view.more:SetPos(20, h - 22)
    view.more.hidden = (view.scroll >= maxScroll)
end

function page.build(layer)
    page.view = buildView(layer)
end

function page.layout(w, h)
    layoutView(page.view, w, h)
end

function page.refresh(newSearch)
    page.armed = false -- opening the page again calls a half-done reset off
    refreshButtons()
end

-- The Plugin Hub's Settings panel: the game empties the layer each time it is shown, so the words and buttons are made again each time
-- (the view made the time before is dropped).
Event.SettingsLayerReady.Subscribe("tmr3_settings", function(event)
    if Settings == nil then return end -- the plugin was switched off
    local ok, err = pcall(function()
        local layer = field(event, "component")
        if layer == nil then return end
        if Settings.hubView ~= nil then
            for k = #Settings.views, 1, -1 do if Settings.views[k] == Settings.hubView then table.remove(Settings.views, k) end end
            -- Backwards, so removing one does not skip the next.
            for k = #Window.redButtons, 1, -1 do
                for _, part in pairs(Settings.hubView.parts) do
                    if part.button == Window.redButtons[k] then table.remove(Window.redButtons, k) break end
                end
            end
        end
        local w, h = field(layer, "width"), field(layer, "height")
        if type(w) ~= "number" or w < 200 then w = 420 end
        if type(h) ~= "number" or h < 100 then h = 400 end
        page.armed = false
        Settings.hubView = buildView(layer)
        layoutView(Settings.hubView, w, h)
    end)
    if not ok then trouble("the Plugin Hub's settings panel", err) end
end)

Window.addPage(page)

end }
