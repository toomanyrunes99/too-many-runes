-- Too Many Runes - The Settings page
-- Opened by the "Settings" button at the top right (ui/window.lua); the same button goes back. Each setting is a button that shows its
-- choice; a click moves to the next choice. Every choice is saved at once (Saved, core/util.lua) and used again at the next start-up.
-- The starting values are the ones in settings.lua (HIDE, WHEEL_UP_NEXT, GAME_MENU, SCAN_SPEED; the hover colour is HOVER_TINT in ui/kit.lua).
return { run = function(T)
local _ENV = T

local page = { key = "settings", label = "Settings", noTab = true }

-- (the colour tints the picture: the game multiplies the item's own colours by it, so a white tint changes nothing. "Custom" is the
-- player's own hex code, typed on the next row of the Settings page.)
local HOVER_COLOURS = {
    { label = "Green",  v = { 0.55, 1.0, 0.55 } }, -- (the starting colour: HOVER_TINT in ui/kit.lua)
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
    -- the secret one: Shift + click on the button. Three times full speed for ALL the reading (the heavy passes and the ones that run at a
    -- fixed pace: item links, skill guides, station pictures - Scan.boost), four times the items per tick. The game will stutter while it
    -- reads, but it is done in a fraction of the time.
    { label = "*Instant*", v = 3.0, items = 1200, boost = 3, secret = true },
}
local NORMAL_ITEMS = ITEMS_PER_TICK -- (settings.lua's value, used again when Instant is switched off)
local function indexOf(list, test) for k, e in ipairs(list) do if test(e) then return k end end return 1 end

-- The starting values (settings.lua and ui/kit.lua), for the reset button.
local DEFAULTS = { wheel = WHEEL_UP_NEXT, menu = GAME_MENU, hover = HOVER_TINT, speed = SCAN_SPEED, debug = SHOW_DEBUG_NAMES,
                   rgb = HOVER_RGB, outline = HOVER_OUTLINE, seeThrough = (WINDOW_SEE_THROUGH ~= false), group = (GROUP_FORMS ~= false) }
-- (the see-through switch: what was used when the window was made - ui/window.lua - and whether a change waits for the next start)
local seeThrough = (Saved.get("see_through") or (DEFAULTS.seeThrough and "on" or "off")) == "on"
local OUTLINE_ON = ((tonumber(HOVER_OUTLINE) or 0) > 0) and HOVER_OUTLINE or 2 -- (the outline's size when it is switched on)
local SAVED_KEYS = { "collapsed", "debug_names", "recent_open", "details_tab", "filter", "game_menu", "hide_noted", "hide_broken", "hide_junk", "hide_dungeoneering", "hide_discontinued",
                     "hover", "hover_hex", "outline", "see_through", "scan_speed", "tab", "view", "wheel_up", "win_w", "win_h", "win_x", "win_y",
                     "icon_x", "icon_y", "group_forms" } -- (not "favourites"; the minimized rune icon's place too)

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
local hoverAt = indexOf(HOVER_COLOURS, function(e) return e.label == Saved.get("hover") end)
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
end
if Saved.get("scan_speed") ~= nil then applySpeed() end

-- The settings: { words, value() -> the button's words, click() }
local function onOff(flag) return flag and "On" or "Off" end
-- (in groups, each under its heading: what the list hides, searching and browsing, looks, the game's right-click menu, start-up, reset)
local function hideRow(words, name, alsoUses)
    return { words = words, value = function() return onOff(Filters.hide[name]) end,
             click = function()
                 Filters.setHide(name, not Filters.hide[name])
                 if alsoUses and Recipes.clearUsedLists then Recipes.clearUsedLists() end -- (the Uses lists leave these out: make them again)
             end }
end
local ROWS = {
    -- (first, the settings that help to see what is under the mouse)
    { heading = "Accessibility:" },
    { words = "Outline round the item under the mouse", value = function() return onOff((tonumber(HOVER_OUTLINE) or 0) > 0) end,
      click = function()
          HOVER_OUTLINE = ((tonumber(HOVER_OUTLINE) or 0) > 0) and 0 or OUTLINE_ON
          Saved.set("outline", (HOVER_OUTLINE > 0) and "on" or "off")
      end },
    { words = "Colour of a picture under the mouse",
      value = function() local e = HOVER_COLOURS[hoverAt]; return e.custom and ("Custom #" .. customHex) or e.label end,
      click = function()
          hoverAt = hoverAt % #HOVER_COLOURS + 1
          applyHover()
          for _, p in pairs(Window.pages) do if p.box ~= nil then pcall(p.box.paintMarks, p.box) end end -- (the marks are tinted with it)
          Saved.set("hover", HOVER_COLOURS[hoverAt].label)
      end },
    { words = "Your own colour: type a hex code (RRGGBB, like 00FF88 or FF66CC) - it is used at once", input = true, maxLength = 7,
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
          if Search.refresh then Search.refresh() end -- (the search finds debug names only while they are shown)
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
          local shift = false
          pcall(function() shift = Keyboard.IsAvailable() and Keyboard.IsShiftDown() end)
          if shift then
              speedAt = indexOf(SPEEDS, function(e) return e.secret == true end) -- (Shift + click: *Instant*)
          else
              repeat speedAt = speedAt % #SPEEDS + 1 until not SPEEDS[speedAt].secret
          end
          applySpeed()
          Saved.set("scan_speed", tostring(SCAN_SPEED))
      end },
    { note = "The speed matters only while the game's data is being read (about a minute after start-up)." },
    { heading = "Reset:" },
    { reset = true, words = "Reset every setting to its default - how a new player starts (your Favorites stay)",
      value = function() return page.armed and "Click again to reset" or "Reset to default" end,
      click = function()
          if not page.armed then page.armed = true return end -- (the first click only asks: a second click resets)
          page.armed = false
          -- (in a pcall, so a part that goes wrong cannot stop the reset before its message: the console always says so)
          local ok, err = pcall(page.resetAll)
          if ok then say("Settings reset to default.")
          else say("Settings reset to default (one part of it did not work: " .. tostring(err) .. ").") end
      end },
    { note = "Changes are saved straight away." },
}

page.rows = ROWS -- (for the test, dev/mock_test.lua)
local BUTTON_W, ROW_H = 150, 28

-- Back to how a new player starts: every switch and choice, the list's filter and view, the details tab, the window's size and place.
-- (Favourites stay.) Everything is put right at once and the saved choices are forgotten.
function page.resetAll()
    for _, name in ipairs({ "noted", "broken", "junk", "dungeoneering", "discontinued" }) do
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
    if Recent ~= nil and Recent.setOpen ~= nil then Recent.setOpen(false) end -- (the panel starts closed)
    hoverAt = 1
    speedAt = indexOf(SPEEDS, function(e) return tostring(e.v) == tostring(DEFAULTS.speed) end)
    applySpeed()
    Filters.setKey(FILTER_DEFAULT or "all"); Window.filter:select(Filters.key)
    Window.setView(VIEW_DEFAULT); Window.view:select(VIEW_DEFAULT)
    Window.runSearch("")
    for _, d in ipairs(Details.all) do d:showTab(Details.TABS[1].key) end
    pcall(function() -- (the starting place: in the middle, near the top of the game screen)
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

function Settings.refreshAll()
    for _, view in ipairs(Settings.views) do
        for k, r in ipairs(ROWS) do
            local part = view.parts[k]
            if part ~= nil and part.button ~= nil then pcall(function() part.button:setLabel(r.value()) end) end
        end
    end
end
local refreshButtons = Settings.refreshAll

-- Make the words and buttons of every setting on a layer. Returns the view ({ parts }).
local function buildView(parent)
    -- (everything sits on a layer of its own the size of the box, which scrolls with the mouse wheel when the settings do not all fit:
    -- the Plugin Hub's panel is short)
    local layer = ui.Layer.new(parent)
    local view = { parts = {}, layer = layer, scroll = 0 }
    view.wheel = function(step)
        if view.wheelTick == tickCount then return end -- (one notch reaches every part under the mouse: act once)
        view.wheelTick = tickCount
        view.scroll = view.scroll + step * 40
        if view.w ~= nil then view.relayout() end
    end
    Kit.wheel(layer, view.wheel)
    for k, r in ipairs(ROWS) do
        local part = {}
        part.text = Kit.text(layer, 0, 0, 10, 22, "left")
        Kit.wheel(part.text, view.wheel)
        part.text.content = r.heading or r.words or r.note
        if r.heading then pcall(function() part.text.rgba = 0xE8C060FF end) end
        if r.note then pcall(function() part.text.alpha = 0.7 end) end
        if r.input then -- (a box to type in: the hex colour)
            part.input = Kit.input(layer, BUTTON_W, 24, r.placeholder and r.placeholder() or "", r.maxLength)
            part.input.onChange = function(text)
                local ok, used = pcall(r.apply, text)
                if ok and used then Settings.refreshAll() end
            end
        end
        if r.click ~= nil then
            part.button = Kit.button(layer, r.value(), BUTTON_W, 24, function()
                if not r.reset then page.armed = false end -- (any other click calls the reset off)
                local ok, err = pcall(r.click)
                if not ok then trouble("changing a setting", err) end
                Settings.refreshAll()
            end)
            if r.reset then Window.redButtons[#Window.redButtons + 1] = part.button end
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

-- Place a view's words and buttons in a box w wide (long words wrap onto more lines).
local function layoutView(view, w, h)
    view.w, view.h = w, h
    view.relayout = function() layoutView(view, view.w, view.h) end
    view.layer:SetPos(0, 0); view.layer:SetSize(w, h)
    -- how tall it all is, and how far the wheel may scroll
    local heights, total = {}, 8
    for k, r in ipairs(ROWS) do
        local part = view.parts[k]
        local textW = (part.button ~= nil or part.input ~= nil) and (w - BUTTON_W - 30) or (w - 20)
        local lines = (r.heading and 1) or math.max(1, #wrapText(part.text.content, textW))
        heights[k] = { lines = lines, textW = textW,
                       h = (r.heading and 26) or (r.note and (22 * lines + 4)) or math.max(ROW_H, 22 * lines + 6) }
        total = total + heights[k].h
    end
    local maxScroll = math.max(0, total + 8 - h)
    view.scroll = math.max(0, math.min(view.scroll or 0, maxScroll))
    local y = 8 - view.scroll
    for k, r in ipairs(ROWS) do
        local part, hk = view.parts[k], heights[k]
        -- (out of sight: hidden, so not clickable. While "(scroll down for more)" shows at the bottom, a row that would reach into it is
        -- hidden too - otherwise its words or its button run over the hint)
        local hintRoom = (view.scroll < maxScroll) and 22 or 0
        local outside = (y + hk.h <= 0) or (y >= h) or (hintRoom > 0 and y + math.max(22 * hk.lines, 24) > h - hintRoom)
        part.text:SetSize(hk.textW, 22 * hk.lines)
        part.text:SetPos(r.heading and 10 or 20, y + 2)
        part.text.hidden = outside
        if part.button ~= nil then
            part.button:place(w - BUTTON_W - 10, y + math.max(0, (22 * hk.lines - 24) // 2))
            part.button:show(not outside)
        end
        if part.input ~= nil then
            part.input:place(w - BUTTON_W - 10, y + math.max(0, (22 * hk.lines - 24) // 2))
            part.input:show(not outside)
        end
        y = y + hk.h
    end
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
    page.armed = false -- (opening the page again calls a half-done reset off)
    refreshButtons()
end

-- The Plugin Hub's Settings panel: the game empties the layer each time it is shown, so the words and buttons are made again each time
-- (the view made the time before is dropped).
Event.SettingsLayerReady.Subscribe("tmr3_settings", function(event)
    if Settings == nil then return end -- (the plugin was switched off)
    local ok, err = pcall(function()
        local layer = field(event, "component")
        if layer == nil then return end
        if Settings.hubView ~= nil then
            for k = #Settings.views, 1, -1 do if Settings.views[k] == Settings.hubView then table.remove(Settings.views, k) end end
            -- (backwards, so removing one does not skip the next)
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
