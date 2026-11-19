-- Too Many Runes - The search
-- One search box (bottom right of the window) is shared by every tab along the top. Its text is read the same way everywhere:
-- a name or part of one      "yew short"
-- a number                   "68"  (that item first, then names containing 68, then numbers starting with 68)
-- #number                    "#68" (numbers only)
-- Words starting with @ (@smithing, @furnace, @weapon and so on) pick a skill, station or category. core/query.lua handles them.
-- A tab asks Search.list() for the items to show: the matches, or the filter's whole list when the box is empty.
return { run = function(T)
local _ENV = T

Search = { text = "", query = "", idOnly = false, active = false, results = {} }

local function collect()
    local results, seen, q = {}, {}, Search.query
    local function add(slot)
        if slot ~= nil and not seen[slot] then
            seen[slot] = true
            if Filters.passes(slot) then results[#results + 1] = slot end
        end
    end
    -- @skill, @station, @category and levels. core/query.lua picks the items and their order.
    if Search.spec ~= nil and Query ~= nil then
        Query.collect(Search.spec, add)
        Search.results = results
        return
    end
    local isNumber = string.match(q, "^%d+$") ~= nil
    if isNumber then add(Items.slotOf[tonumber(q)]) end -- 1) the item with exactly that number
    if not Search.idOnly then                            -- 2) names that contain the text (and debug names, when they are shown)
        local lower, debug = Items.lower, (SHOW_DEBUG_NAMES == true) and Items.debug or nil
        local qd = string.gsub(q, " ", "_") -- spaces match underscores, so "trail sliding" finds TRAIL_SLIDINGPUZZLE1
        for slot = 1, #lower do
            if string.find(lower[slot], q, 1, true) or (debug ~= nil and debug[slot] ~= nil and string.find(debug[slot], qd, 1, true)) then add(slot) end
        end
    end
    if isNumber then                                     -- 3) numbers that start with it ("100" also finds 1000, 1001 ...)
        local idText = Items.idText
        for slot = 1, #idText do
            if string.sub(idText[slot], 1, #q) == q then add(slot) end
        end
    end
    Search.results = results
end

-- Runs a search. Called when the search box changes, and by refresh when the filter changes.
function Search.run(text)
    Search.pending = nil -- this search replaces one still waiting for the typing to stop
    Search.text = text or ""
    local q = string.lower(Search.text):match("^%s*(.-)%s*$")
    Search.idOnly = string.sub(q, 1, 1) == "#"
    if Search.idOnly then q = string.sub(q, 2):match("^%s*(.-)%s*$") end
    Search.query = q
    local spec = nil
    if Query ~= nil and not Search.idOnly and q ~= "" then
        local okQ, parsed = pcall(Query.parse, q)
        if okQ then spec = parsed else trouble("the search words", parsed) end
    end
    Search.spec = spec
    if Query ~= nil then Query.spec = spec end
    Search.active = (q ~= "")
    if Search.active then collect() else Search.results = {} end
    if Window ~= nil then Window.searchChanged() end
end

-- Runs the same search again over a list that changed. The work in the background does this several times while the game's data is
-- read (the list loaded, copies were put under the hide switches, the groups were made), and a hide switch does it too. The page
-- being looked at is kept, or the last page when the list got shorter. toFirst = true goes to page 1: another tab or group was picked.
function Search.refresh(toFirst)
    local page = (Window ~= nil and Window.pages ~= nil) and Window.pages[Window.active] or nil
    local box = (page ~= nil) and page.box or nil
    local was = (box ~= nil and toFirst ~= true) and box.page or nil
    Search.run(Search.pending or Search.text)
    if was ~= nil and was > 1 then
        pcall(function()
            local n = math.max(1, math.min(was, box:pageCount()))
            if n ~= box.page then box:goTo(n); Window.refreshPager() end
        end)
    end
end

-- While typing, the search waits until the typing stops for SEARCH_WAIT ticks (about 0.16 s) instead of running at
-- every key. Each search looks through every item name and redraws the list, so running it per key makes typing lag.
local SEARCH_WAIT = 8
-- keep = true is the background's way in (the groups were made again): the page being looked at is kept, as Search.refresh does.
-- Typing calls it without keep, and its new search starts at page 1.
function Search.runSoon(text, keep)
    Search.pending, Search.wait = text or "", SEARCH_WAIT
    Search.keepPage = (keep == true)
end
Event.Logic.Subscribe("tmr3_search_wait", function()
    if Search == nil or Search.pending == nil then return end -- the plugin is switched off, or no search is waiting
    Search.wait = Search.wait - 1
    if Search.wait <= 0 then
        if Search.keepPage then Search.keepPage = false; pcall(Search.refresh) else pcall(Search.run, Search.pending) end
    end
end)

-- The slots to show: the matches, or every item the filter lets through when the box is empty.
-- The item box reads this through Groups.of (core/groups.lua). That list is a stand-in, so use #, [i] or ipairs on it,
-- never pairs or next.
function Search.list()
    if Search.active then return Search.results end
    return Filters.current()
end

end }
