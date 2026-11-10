-- Too Many Runes - start-up file
--
-- This file does no real work. It loads the other files one at a time (one per frame, so the game never freezes), and cleans up when the
-- game switches the plugin off.
--
-- THE FOLDERS
--   core/   the engine: background work (passes), the item list (and the hidden kinds: noted, broken, junk ...), filters and
--           favourites, the search, and the @ search words (query.lua)
--   data/   reading facts from the game (item info)
--   ui/     the building blocks (kit.lua: buttons, text, pictures, frames, tabs), the window (window.lua: tabs, search box, pager, the
--           resize handles on every side), the item list and the details panel, the right-click menu entries (game_menu.lua), the
--           choices that pop up above the search box (suggest.lua) and the Plugins window page (ribbon.lua)
--   recipes/ reading the game's data (moved over from the old plugin; recipes/compat.lua explains how they fit) and the three tabs of the
--           details panel: Recipe (recipe_tab.lua), Uses (uses.lua, uses_tab.lua) and Source (gather.lua, source_tab.lua)
--   pages/  ONE FILE PER PAGE of the window: the tab along the top (Item search), the Recently viewed panel beside the window (recent.lua:
--           opened by the arrow at the top left) and the Settings and Help pages
--           (noTab = true: opened by their own buttons; the Settings page is also in the Plugin Hub, behind its cog). To add a tab: copy
--           pages/item_search.lua's pattern (page.build / layout / refresh, then Window.addPage), give it a new key and label, and add
--           its name to FILES below (before "start").
--   dev/    for the developer only, not loaded by the game: mock_test.lua (texlua dev/mock_test.lua <folder> runs every file against a
--           stand-in game), the API docs and the Plugin Hub listing image
--
-- Every file has the same shape:   return { run = function(T) local _ENV = T  ...  end }
-- All files share one table, T, so a name made in one file (a function, a list) can be used by every file loaded after it.

local VERSION = "3.1.50" -- goes up by one with every build sent: 3.0.01, 3.0.02 ... 3.0.99, then 3.1.00

local FILES = {
    "settings",
    "core/util",
    "core/passes",
    "data/wiki_lists",
    "core/items",
    "core/filters",
    "core/search",
    "data/info",
    "ui/kit",
    "ui/window",
    "ui/item_box",
    "ui/details",
    "recipes/compat",
    "recipes/reading",
    "recipes/parse",
    "recipes/links",
    "recipes/manual",
    "recipes/unlocks",
    "recipes/rituals",
    "recipes/gather",
    "recipes/guides",
    "recipes/get",
    "recipes/copies",
    "recipes/doses",
    "recipes/player",
    "recipes/stations",
    "recipes/uses",
    "recipes/gear",
    "recipes/recipe_tab",
    "recipes/uses_tab",
    "recipes/shops",
    "recipes/source_tab",
    "core/query",
    "ui/game_menu",
    "ui/suggest",
    "pages/item_search",
    "pages/recent",
    "pages/settings",
    "pages/help",
    "ui/ribbon",
    "start",
}

local T = setmetatable({ VERSION = VERSION }, { __index = _ENV }) -- (the game's own names - print, ui, config, Event ... - are still found)

-- The game's file loader once answered "nothing" for a file that was there, so an empty answer is asked for again a few times.
local function loadFile(name)
    local ok, module = pcall(require, name)
    for _ = 1, 3 do
        if not ok or type(module) == "table" then break end
        ok, module = pcall(require, name)
    end
    if not ok then
        print("Too Many Runes: could not load " .. name .. ".lua - " .. tostring(module))
        return false
    end
    if type(module) ~= "table" or type(module.run) ~= "function" then
        print("Too Many Runes: " .. name .. ".lua is missing or empty. Copy the whole plugin folder again and restart the game.")
        return false
    end
    local okRun, err = pcall(module.run, T)
    if not okRun then
        print("Too Many Runes: error while starting " .. name .. ".lua - " .. tostring(err))
        return false
    end
    return true
end

local queue, finished = {}, false
for _, name in ipairs(FILES) do queue[#queue + 1] = name end

local function loadNext()
    local name = table.remove(queue, 1)
    if name == nil or not loadFile(name) or #queue == 0 then finished = true end
end

-- The game calls this when the plugin is switched off or reloaded: take the window down, stop the background work and empty the shared
-- table (without that, every reload left a whole copy of the plugin in the game's memory).
-- (No event handler is ever unsubscribed: that crashed the game once. A handler that is no longer needed just returns at once.)
function PluginShutdown()
    finished, queue = true, {}
    pcall(function() if T.Window ~= nil then T.Window.shutdown() end end)
    pcall(function() if T.Passes ~= nil then T.Passes.stop() end end)
    local names = {}
    for k in pairs(T) do names[#names + 1] = k end
    for _, k in ipairs(names) do rawset(T, k, nil) end
end

-- One file per frame. If the game sends no frames for 3 seconds, everything is loaded at once.
local framesSeen, waited = false, 0
Event.Draw.Subscribe("tmr3_boot", function()
    if finished then return end
    framesSeen = true
    loadNext()
end)
Event.Logic.Subscribe("tmr3_boot", function()
    if finished or framesSeen then return end
    waited = waited + 1
    if waited >= 150 then
        print("Too Many Runes " .. VERSION .. ": no frames to start from; loading everything at once.")
        while not finished do loadNext() end
    end
end)
