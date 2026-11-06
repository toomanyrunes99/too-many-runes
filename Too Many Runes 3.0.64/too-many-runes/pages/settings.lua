-- Too Many Runes - The Settings page
-- Opened by the "Settings" button at the top right (ui/window.lua); the same button goes back. Each setting is a button that shows its
-- choice; a click moves to the next choice. Every choice is saved at once (Saved, core/util.lua) and used again at the next start-up.
-- The starting values are the ones in settings.lua (HIDE, WHEEL_UP_NEXT, GAME_MENU, SCAN_SPEED; the hover colour is HOVER_TINT in ui/kit.lua).
return { run = function(T)
local _ENV = T

local page = { key = "settings", label = "Settings", noTab = true }

local HOVER_COLOURS = {
    { label = "Green", v = { 0.55, 1.0, 0.55 } }, -- (the starting colour: HOVER_TINT in ui/kit.lua)
    { label = "Gold",  v = { 1.0, 0.8, 0.4 } },
    { label = "Blue",  v = { 0.55, 0.75, 1.0 } },
    { label = "Red",   v = { 1.0, 0.5, 0.45 } },
}
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
local DEFAULTS = { wheel = WHEEL_UP_NEXT, menu = GAME_MENU, hover = HOVER_TINT, speed = SCAN_SPEED, debug = SHOW_DEBUG_NAMES }
local SAVED_KEYS = { "collapsed", "debug_names", "recent_open", "details_tab", "filter", "game_menu", "hide_noted", "hide_broken", "hide_unfinished", "hide_junk",
                     "hover", "scan_speed", "tab", "view", "wheel_up", "win_w", "win_h", "win_x", "win_y" } -- (not "favourites")

-- Use the saved choices now (before anything is shown).
local saved = Saved.get("wheel_up")
if saved == "next" then WHEEL_UP_NEXT = true elseif saved == "back" then WHEEL_UP_NEXT = false end
saved = Saved.get("game_menu")
if saved == "on" then GAME_MENU = true elseif saved == "off" then GAME_MENU = false end
saved = Saved.get("debug_names")
if saved == "on" then SHOW_DEBUG_NAMES = true elseif saved == "off" then SHOW_DEBUG_NAMES = false end
local hoverAt = indexOf(HOVER_COLOURS, function(e) return e.label == Saved.get("hover") end)
local function applyHover() local c = HOVER_COLOURS[hoverAt].v; HOVER_TINT = Vector4.new(c[1], c[2], c[3], 1.0) end
if Saved.get("hover") ~= nil then applyHover() end
local speedAt = indexOf(SPEEDS, function(e) return tostring(e.v) == tostring(Saved.get("scan_speed") or SCAN_SPEED) end)
local function applySpeed()
    local s = SPEEDS[speedAt]
    SCAN_SPEED = s.v
    if not Scan.timed then Scan.factor = SCAN_SPEED end
    ITEMS_PER_TICK = s.items or NORMAL_ITEMS
    Scan.boost = s.boost or 1
end
if Saved.get("scan_speed") ~= nil then applySpeed() end

-- The settings: { words, value() -> the button's words, click() }
local function onOff(flag) return flag and "On" or "Off" end
local ROWS = {
    { heading = "The item list:" },
    { words = "Hide noted items",      value = function() return onOff(Filters.hide.noted) end,      click = function() Filters.setHide("noted", not Filters.hide.noted) end },
    { words = "Hide broken items",     value = function() return onOff(Filters.hide.broken) end,     click = function() Filters.setHide("broken", not Filters.hide.broken) end },
    { words = "Hide unfinished items", value = function() return onOff(Filters.hide.unfinished) end, click = function() Filters.setHide("unfinished", not Filters.hide.unfinished) end },
    { words = "Smart hide (lent, shop, event, puzzle, lamp ... items)", value = function() return onOff(Filters.hide.junk) end,
      click = function()
          Filters.setHide("junk", not Filters.hide.junk)
          if Recipes.clearUsedLists then Recipes.clearUsedLists() end -- (the Uses lists leave hidden junk out: make them again)
      end },
    { words = "Mouse wheel up goes to the", value = function() return (WHEEL_UP_NEXT == false) and "Page before" or "Next page" end,
      click = function()
          WHEEL_UP_NEXT = (WHEEL_UP_NEXT == false)
          Saved.set("wheel_up", WHEEL_UP_NEXT and "next" or "back")
      end },
    { heading = "Looks and the game:" },
    { words = "Colour of a picture under the mouse", value = function() return HOVER_COLOURS[hoverAt].label end,
      click = function()
          hoverAt = hoverAt % #HOVER_COLOURS + 1
          applyHover()
          Saved.set("hover", HOVER_COLOURS[hoverAt].label)
      end },
    { words = "Recipe / Uses / Source in the game's right-click menu", value = function() return onOff(GAME_MENU ~= false) end,
      click = function()
          GAME_MENU = (GAME_MENU == false)
          Saved.set("game_menu", GAME_MENU and "on" or "off")
      end },
    { words = "Show the game's debug name in the item info", value = function() return onOff(SHOW_DEBUG_NAMES == true) end,
      click = function()
          SHOW_DEBUG_NAMES = not (SHOW_DEBUG_NAMES == true)
          Saved.set("debug_names", SHOW_DEBUG_NAMES and "on" or "off")
          Details.refreshInfo()
          if Search.refresh then Search.refresh() end -- (the search finds debug names only while they are shown)
      end },
    { words = "Speed of reading the game's data at start-up", value = function() return Scan.timed and "Automatic" or SPEEDS[speedAt].label end,
      click = function()
          if Scan.timed then return end -- (with a clock the speed looks after itself)
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
    { reset = true, words = "Put every setting back to how it starts for a new player (your Favorites stay)",
      value = function() return page.armed and "Click again to reset" or "Reset settings" end,
      click = function()
          if not page.armed then page.armed = true return end -- (the first click only asks: a second click resets)
          page.armed = false
          page.resetAll()
      end },
    { note = "Changes are saved straight away." },
    { note = "The speed matters only while the game's data is being read (about a minute after start-up)." },
}

page.rows = ROWS -- (for the test, dev/mock_test.lua)
local BUTTON_W, ROW_H = 150, 28

-- Back to how a new player starts: every switch and choice, the list's filter and view, the details tab, the window's size and place.
-- (Favourites stay.) Everything is put right at once and the saved choices are forgotten.
function page.resetAll()
    for _, name in ipairs({ "noted", "broken", "unfinished", "junk" }) do Filters.setHide(name, (HIDE or {})[name] == true) end
    if Recipes.clearUsedLists then Recipes.clearUsedLists() end
    WHEEL_UP_NEXT, GAME_MENU, HOVER_TINT, SHOW_DEBUG_NAMES = DEFAULTS.wheel, DEFAULTS.menu, DEFAULTS.hover, DEFAULTS.debug
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
    -- Moving the window like that leaves its dragging stuck (3.0.34) until it is minimized and opened again, so that is done here too;
    -- resetSize then opens it at the starting size.
    Window.setCollapsed(true)
    Window.resetSize()
    Window.show("search")
    for _, key in ipairs(SAVED_KEYS) do Saved.set(key, "") end
    say("settings reset to how they start for a new player")
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
        local textW = (part.button ~= nil) and (w - BUTTON_W - 30) or (w - 20)
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
        local outside = (y + hk.h <= 0) or (y >= h - ((view.scroll < maxScroll) and 22 or 0)) -- (out of sight: hidden, so not clickable)
        part.text:SetSize(hk.textW, 22 * hk.lines)
        part.text:SetPos(r.heading and 10 or 20, y + 2)
        part.text.hidden = outside
        if part.button ~= nil then
            part.button:place(w - BUTTON_W - 10, y + math.max(0, (22 * hk.lines - 24) // 2))
            part.button:show(not outside)
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
            for k, v in ipairs(Settings.views) do if v == Settings.hubView then table.remove(Settings.views, k) break end end
            for k, b in ipairs(Window.redButtons) do
                for _, part in pairs(Settings.hubView.parts) do if part.button == b then table.remove(Window.redButtons, k) end end
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
