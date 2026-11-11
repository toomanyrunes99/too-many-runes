-- Too Many Runes - Starting up (loaded last)
-- Opens the tab you had open last time, starts the clock, and prints the version.
return { run = function(T)
local _ENV = T

Window.layout()
local saved = Saved.get("tab")
Window.show(Window.pages[saved or ""] and saved or Window.order[1])
if START_MINIMIZED ~= false or Saved.get("collapsed") == "yes" then Window.setCollapsed(true) end -- (settings.lua, START_MINIMIZED)
Window.refreshStatus()
Window.starting = false
if not Window.collapsed then -- (minimized, it stays put away and the rune icon shows instead: ui/window.lua, THE RUNE ICON)
    pcall(function() Window.win.root.hidden = false end) -- (hidden while the files loaded: ui/window.lua)
    pcall(function() Window.win:Show() end) -- (PrettyUI's own showing too - it shows the minimize button again, which it hid with
    -- the window while the files loaded, and has it fit the title bar's drag layer round itself: ui/window.lua, Minimize)
end
Window.placeGrip()

-- The clock: the small jobs done every so often.
local wasLoaded = false
local putAway = nil -- ("closed" or "minimized": the window's own jobs were done once when it was put away, and wait till it is opened)
Passes.add("clock", function()
    if Window.win == nil then return end
    ItemBox.tick() -- (finish a page whose pictures did not all fit in the last tick)
    if tickCount % 25 == 0 and not wasLoaded then
        -- while the item list loads, the open tab shows it growing; when it is complete, the search runs again over all of it
        wasLoaded = Items.loaded
        if wasLoaded then
            Search.refresh()
        elseif not Search.active and not Window.collapsed then
            local page = Window.pages[Window.active]
            pcall(page.grow or page.refresh, false)
            Window.refreshPager()
        end
        Window.refreshStatus()
    end
    local away = Window.closed and "closed" or (Window.collapsed and "minimized" or nil)
    if away ~= nil then
        Window.tickIcon() -- (the runes going round on the minimized icon; nothing while closed)
        if putAway ~= away then putAway = away; Window.tickHint(); Window.placeGrip() end -- (the hint and the resize handles hidden, once)
        return
    end
    putAway = nil
    Window.tickHint() -- (the changing hint in the empty search box)
    if tickCount % 5 == 0 then Window.keepClearRed() end -- (PrettyUI gives the X its own colour back after the mouse was over it)
    if tickCount % 10 == 0 then Window.watch() end       -- (moved?)
    if tickCount % 5 == 0 then Window.placeGrip() end    -- (the resize corner follows the window and stays on top)
    if tickCount % 50 == 0 then pcall(function() Window.status:MoveToFront() end) end -- (keep the status above the title bar)
end, nil, true)

say(VERSION .. " started.")

end }
