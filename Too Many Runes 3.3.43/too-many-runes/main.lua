-- Too Many Runes - start-up file
--
-- This file does no real work. It loads the other files one at a time (one per frame, so the game never freezes), and cleans up when the
-- game switches the plugin off.
--
-- The folders
--   core/   the engine: background work (passes), the item list (and the hidden kinds: noted, broken, junk ...), filters and
--           favourites, the search, and the @ search words (query.lua)
--   data/   facts read from the game (item info), and the lists, recipes and teleport places from the RuneScape Wiki (wiki_*.lua)
--   ui/     the building blocks (kit.lua: buttons, text, pictures, frames, tabs), the window (window.lua: tabs, search box, pager, the
--           resize handles on every side), the item list and the details panel, the right-click menu entries (game_menu.lua), the
--           choices that pop up above the search box (suggest.lua) and the Plugins window page (ribbon.lua)
--   recipes/ reading the game's data (recipes/compat.lua explains how those files fit together) and the three tabs of the
--           details panel: Recipe (recipe_tab.lua), Uses (uses.lua, uses_tab.lua) and Source (gather.lua, source_tab.lua)
--   pages/  one file per page of the window: the tab along the top (Item search), the Recently viewed panel beside the window
--           (recent.lua: opened by the arrow at the top left) and the Settings and Help pages
--           (noTab = true: opened by their own buttons; the Settings page is also in the Plugin Hub, behind its cog). To add a tab: copy
--           pages/item_search.lua's pattern (page.build / layout / refresh, then Window.addPage), give it a new key and label, and add
--           its name to FILES below (before "start").
--   core/hooks.lua: the add-on hooks, how other plugins add a tab or a button for the open item; what main.lua returns (below)
--   dev/    working files that the game does not load and that are not part of the release: mock_test.lua (texlua
--           dev/mock_test.lua <folder> runs every file against a stand-in game)
--
-- Every file has the same shape:   return { run = function(T) local _ENV = T  ...  end }
-- All files share one table, T, so a name made in one file (a function, a list) can be used by every file loaded after it.

local VERSION = "3.3.43" -- the plugin's version, printed at start-up; it goes up by one with every build

local FILES = {
    "settings",
    "core/util",
    "core/passes",
    "data/wiki_lists",
    "data/wiki_teleports", -- teleport places from the RuneScape Wiki, for items the game gives none for
    "core/items",
    "core/filters",
    "core/search",
    "core/groups",
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
    "recipes/tidy_copies",
    "recipes/quests",
    "recipes/compost",
    "recipes/tags",
    "recipes/extras", -- more facts about an item, from the game's tables
    "recipes/stats", -- the item's combat stats, as the game's hover box shows them
    "recipes/wiki", -- recipes and uses from the RuneScape Wiki, only where the game has none (data/wiki_recipes.lua)
    "recipes/source_tab",
    "core/shelves", -- the item list's groups: the group tabs and the headings
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

-- Memory. The plugin keeps a lot of data that never changes once read (items, recipes, uses: well over 100 MB), and makes small
-- short-lived scraps all the time while its window is open. Lua's memory clean-up is set to "incremental", which does its work in
-- many small pieces. The "generational" mode now and then goes through all the data in one go (a "major" collection), and with this
-- much data that freezes the game for about 8 ticks, every 3.5 minutes after start-up and several times while loading.
-- 150 = it starts again once the memory is 1.5 times what was kept the time before (Lua's own 200 lets it double); 200 = it works
-- twice as fast as Lua's own, so it keeps up. On an older Lua the call fails and nothing changes.
pcall(collectgarbage, "incremental", 150, 200)
local T = setmetatable({ VERSION = VERSION }, { __index = _ENV }) -- the game's own names (print, ui, config, Event ...) are still found

-- The game's file loader can answer "nothing" for a file that is there, so an empty answer is asked for again a few times.
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

-- The add-on hooks (core/hooks.lua) are loaded at once, not a file a frame, because an add-on may sign up as soon as this file
-- has run.
loadFile("core/hooks")

local function loadNext()
    local name = table.remove(queue, 1)
    if name == nil or not loadFile(name) or #queue == 0 then finished = true end
end

-- The game calls this when the plugin is switched off or reloaded: take the window down, stop the background work and empty the
-- shared table, or every reload would leave a whole copy of the plugin in the game's memory.
-- No event handler is ever unsubscribed, because that can crash the game. A handler that is no longer needed just returns at once.
-- Everything is emptied before it is let go because the game or PrettyUI may still hold on to the old window's buttons and
-- pictures, and through them the plugin's lists (without this each reload leaves 3 to 4 MB behind). Emptied, whatever still holds
-- a piece of it holds an empty table. Only the plugin's own tables are emptied, never one the game also has under that name, two
-- levels deep, plus each page's item box and item details.
local function empty(t) if type(t) == "table" then for k in pairs(t) do t[k] = nil end end end
local function emptyEverything()
    local pages = (T.Window and T.Window.pages) or {}
    for _, page in pairs(pages) do
        if type(page) == "table" then empty(page.box); empty(page.details); empty(page) end
    end
    if T.Details ~= nil then for _, d in ipairs(T.Details.all or {}) do empty(d) end end
    for name, module in pairs(T) do
        if type(module) == "table" and rawget(_ENV, name) ~= module then
            for _, part in pairs(module) do
                if type(part) == "table" and rawget(_ENV, name) ~= part then empty(part) end
            end
            empty(module)
        end
    end
end

function PluginShutdown()
    -- Forget the open group first, without drawing anything. Reloading with a group of forms unfolded would freeze the game for 10 to
    -- 14 seconds; this makes it as quick as with every group folded.
    pcall(function() T.Groups.forget() end)
    finished, queue = true, {}
    pcall(function() if T.Window ~= nil then T.Window.shutdown() end end)
    pcall(function() if T.Passes ~= nil then T.Passes.stop() end end)
    -- The start-up watcher of the game's config (recipes/compat.lua) holds the game's own tables (config.Obj ...). It goes first, so
    -- emptyEverything never empties those; a reload would then find config.Obj.FromID gone.
    pcall(function() rawset(T, "config", nil) end)
    pcall(emptyEverything)
    local names = {}
    for k in pairs(T) do names[#names + 1] = k end
    for _, k in ipairs(names) do rawset(T, k, nil) end
    -- Throw everything away at once. Otherwise the copy started by a reload finds about 70 MB of the old copy still there, piling up
    -- over many reloads.
    pcall(collectgarbage, "collect")
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

-- What an add-on gets as TooManyRunes when it lists Too Many Runes as a dependency: the add-on hooks (core/hooks.lua).
return T.AddonHooks and T.AddonHooks.api or nil
