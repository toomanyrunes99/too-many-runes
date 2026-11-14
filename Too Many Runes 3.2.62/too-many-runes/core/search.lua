-- Too Many Runes - The search
-- One search box (bottom right of the window) is shared by every tab along the top, and its text is read the same way everywhere:
--   a name or part of one      "yew short"
--   a number                   "68"  (that item first, then names containing 68, then numbers starting with 68)
--   #number                    "#68" (numbers only)
-- (The @ words - @smithing, @furnace, @weapon ... - come back in a later stage.)
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
    -- @skill, @station, @category and levels (core/query.lua does the choosing and the order)
    if Search.spec ~= nil and Query ~= nil then
        Query.collect(Search.spec, add)
        Search.results = results
        return
    end
    local isNumber = string.match(q, "^%d+$") ~= nil
    if isNumber then add(Items.slotOf[tonumber(q)]) end -- 1) the item with exactly that number
    if not Search.idOnly then                            -- 2) names that contain the text (and debug names, when they are shown)
        local lower, debug = Items.lower, (SHOW_DEBUG_NAMES == true) and Items.debug or nil
        local qd = string.gsub(q, " ", "_") -- ("trail sliding" finds TRAIL_SLIDINGPUZZLE1 too)
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

-- The search box changed (or the filter did: refresh).
function Search.run(text)
    Search.pending = nil -- (a search waiting for the typing to stop is replaced by this one)
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

function Search.refresh() Search.run(Search.pending or Search.text) end

-- Typing: the search runs once the typing stops for a moment (SEARCH_WAIT ticks, about 0.16 s), not at every key - each search looks
-- through every item's name and draws the list again, which made typing lag.
local SEARCH_WAIT = 8
function Search.runSoon(text)
    Search.pending, Search.wait = text or "", SEARCH_WAIT
end
Event.Logic.Subscribe("tmr3_search_wait", function()
    if Search == nil or Search.pending == nil then return end -- (the plugin was switched off; nothing typed)
    Search.wait = Search.wait - 1
    if Search.wait <= 0 then pcall(Search.run, Search.pending) end
end)

-- The slots to show: the matches, or (empty box) every item the filter lets through. (What the item box shows goes through Groups.of:
-- that list is a stand-in - use #, [i] or ipairs on it, never pairs or next. core/groups.lua)
function Search.list()
    if Search.active then return Search.results end
    return Filters.current()
end

end }
