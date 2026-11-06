-- Too Many Runes - Starting up (loaded last)
-- Opens the tab you had open last time, starts the clock, and prints the version.
return { run = function(T)
local _ENV = T

Window.layout()
local saved = Saved.get("tab")
Window.show(Window.pages[saved or ""] and saved or Window.order[1])
if Saved.get("collapsed") == "yes" then Window.setCollapsed(true) end
Window.refreshStatus()
Window.starting = false
pcall(function() Window.win.root.hidden = false end) -- (hidden while the files loaded: ui/window.lua)
Window.placeGrip()

-- The clock: the small jobs done every so often.
local wasLoaded = false
Passes.add("clock", function()
    if Window.win == nil then return end
    ItemBox.tick() -- (finish a page whose pictures did not all fit in the last tick)
    Window.tickHint() -- (the changing hint in the empty search box)
    if tickCount % 5 == 0 then Window.keepClearRed() end -- (PrettyUI gives the X its own colour back after the mouse was over it)
    if tickCount % 10 == 0 then Window.watch() end       -- (moved?)
    if tickCount % 5 == 0 then Window.placeGrip() end    -- (the resize corner follows the window and stays on top)
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
    if tickCount % 50 == 0 then
        local page = Window.pages[Window.active]
        if page ~= nil and page.tick ~= nil then pcall(page.tick) end
        pcall(function() Window.status:MoveToFront() end) -- (keep the status above the title bar)
    end
end, nil, true)

say(VERSION .. " started.")

end }
