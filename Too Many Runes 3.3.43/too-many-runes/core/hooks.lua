-- Too Many Runes - Add-on hooks
--
-- Other plugins ("add-ons") can add to Too Many Runes without changing its code, the way plugins use PrettyUI. They can add:
-- 1. a tab of their own in the window's top row, after Item search, with a page the add-on draws itself
-- 2. a button for the item open in the details, in a row at the top of the Info box
-- Too Many Runes does nothing with these itself. It only shows what an add-on adds. Every call into an add-on is guarded:
-- an add-on's error prints one warning and never breaks Too Many Runes, and a part that fails 3 times is taken away.
--
-- How an add-on uses them
--   plugin.json:  "requiredDependencies": { "TooManyRunes": "too-many-runes" }
--                 (from the Plugin Hub, use Too Many Runes' mod.io number without quotes). The game starts Too Many Runes first.
--                 Turning on an add-on turns on Too Many Runes too, and the add-on gets what main.lua returns as TooManyRunes.
--   main.lua:
--     if TooManyRunes == nil or (TooManyRunes.hooksVersion or 0) < 1 then return end
--     local tmr = TooManyRunes.addon("My add-on")      -- the add-on's own handle; its name shows in warnings. Signing up again under
--                                                      -- the same name (after a reload) takes the old tab and buttons away first.
--     tmr.addPage({ key = "mine", label = "Mine",
--         build = function(layer) end,                 -- draws the page into this layer once, when the tab is added. If it fails,
--                                                      -- the tab is taken away.
--         layout = function(w, h) end,                 -- the page's size, when it is opened and when the window is resized
--         refresh = function() end })                  -- the tab was opened (again)
--     tmr.addItemButton({ key = "mine", label = "Mine", tooltip = "words shown while the mouse is over it",
--         shows = function(itemId) return true end,    -- show it for this item? Leave it out to show it for every item.
--         onClick = function(itemId, amount) end,       -- what it does: the add-on decides
--         amount = true })                              -- optional, hooksVersion 2: a small number box (1 to 9999) after the button.
--                                                       -- It starts at 1 for each item, and onClick gets it as "amount".
--     function PluginShutdown() tmr.remove() end        -- the add-on is switched off or reloaded: its tab and buttons go
--     TooManyRunes.isJunk(itemId), TooManyRunes.openItem(itemId) -- hooksVersion 4: is it junk by the plugin's rules, and open it
--     local lines, marks = TooManyRunes.hoverText(itemId) -- hooksVersion 3: the item's hover box as plain lines (its title, each
--                                                       --   line, then its "+N options" line), and the same lines with colour marks
--   Each returns true when it was taken, or false when its input was wrong (a key, a label and a function are needed).
--
-- What add-ons can rely on: Too Many Runes can call an add-on's functions later (on a click or a timer). An add-on talks to the
-- Too Many Runes that is already running, and it can draw into its window with PrettyUI. The game does not tell Too Many Runes when
-- an add-on is switched off, which is why tmr.remove() exists. Reloading Too Many Runes switches its add-ons off, and they have to
-- be started again by hand.
--
-- Keeping old add-ons working: a hook keeps working in later versions once it is out. New inputs are optional, so an old add-on can
-- leave them out, or a new function is added and the old one kept. hooksVersion goes up by one when something is added.
--
-- main.lua loads this file straight away, not one file a frame like the rest, because an add-on may sign up before the window
-- exists. What it adds waits in these lists, and pages/item_search.lua and ui/details.lua show it once they exist
-- (AddonHooks.onChange).
return { run = function(T)
local _ENV = T

AddonHooks = { addons = {}, pages = {}, buttons = {} }
local AH = AddonHooks
local MAX_FAILS = 3

local function changed()
    for _, f in pairs(AH.listeners or {}) do pcall(f) end
end
-- Lets a part of Too Many Runes itself (the item list's tabs, the details) hear when the add-ons' tabs or buttons change.
function AH.listen(name, f) AH.listeners = AH.listeners or {}; AH.listeners[name] = f end

local warned = {}
local function warn(owner, what, err)
    local key = owner .. "|" .. what
    if warned[key] then return end
    warned[key] = true
    print("Too Many Runes: the add-on \"" .. owner .. "\" had an error (" .. what .. "): " .. tostring(err))
end
local function listOf(part) return (part.kind == "page") and AH.pages or AH.buttons end
local function takeOut(part)
    local list = listOf(part)
    for k = #list, 1, -1 do if list[k] == part then table.remove(list, k) end end
    part.gone = true
end
-- Calls one of an add-on's functions, guarded. Returns ok and the answer. A missing function is fine and gives ok, nil.
function AH.call(part, what, fn, ...)
    if type(fn) ~= "function" or part.gone then return true, nil end
    local ok, answer = pcall(fn, ...)
    if not ok then
        warn(part.owner, what, answer)
        part.fails = (part.fails or 0) + 1
        if part.fails >= MAX_FAILS then
            print("Too Many Runes: the add-on \"" .. part.owner .. "\"'s " .. ((part.kind == "page") and "tab" or "button") .. " \"" ..
                part.label .. "\" kept failing and was taken away.")
            takeOut(part)
            changed()
        end
    end
    return ok, answer
end

-- Takes a part away for good and prints a line saying why, for example when its tab could not be drawn (ui/window.lua).
function AH.drop(part, why)
    if part.gone then return end
    print("Too Many Runes: the add-on \"" .. part.owner .. "\"'s " .. ((part.kind == "page") and "tab" or "button") .. " \"" .. part.label ..
        "\" was taken away: " .. why .. ".")
    takeOut(part)
    changed()
end

local function short(s, n)
    s = tostring(s or "")
    return (#s > n) and string.sub(s, 1, n) or s
end

local api = { hooksVersion = 4 } -- 1: tabs and item buttons; 2: an item button's number box, "amount"; 3: hoverText;
                                 -- 4: isJunk and openItem
-- Is this item junk by Too Many Runes' own rules (settings.lua)? true or false, or nil while the item list is still being read.
function api.isJunk(itemId)
    if Items == nil or Items.slotOf == nil or AH.pages == nil then return nil end
    local slot = Items.slotOf[itemId]
    if slot == nil then return nil end
    return Items.is(slot, Items.JUNK) == true
end
-- Opens this item on the Item search tab, the same as a click in Recently viewed. true when it was opened.
function api.openItem(itemId)
    if Recent == nil or Recent.openItem == nil or AH.pages == nil or type(itemId) ~= "number" then return false end
    return (pcall(Recent.openItem, itemId))
end
-- The hover box's words for an item (ui/details.lua): plain lines, and the same lines with their colour marks. nil when it has none.
function api.hoverText(itemId)
    if Details == nil or Details.hoverFor == nil or AH.pages == nil then return nil end
    local ok, stats, title, titleMarks = pcall(Details.hoverFor, itemId)
    if not ok or title == nil then return nil end
    local lines, marks = { title }, { titleMarks or title }
    for _, l in ipairs(stats or {}) do
        lines[#lines + 1] = tostring(l.text or "")
        marks[#marks + 1] = tostring(l.markup or l.text or "")
    end
    local okF, foot = false, nil
    if Details.footerFor ~= nil then okF, foot = pcall(Details.footerFor, itemId) end
    if okF and type(foot) == "string" then lines[#lines + 1] = foot; marks[#marks + 1] = foot end
    return lines, marks
end
function api.addon(name)
    name = short(name, 40)
    if name == "" then name = "an add-on" end
    local old = AH.addons[name]
    if old ~= nil then pcall(old.remove) end -- signed up again after a reload: its old parts go first
    local h, mine = {}, {}
    AH.addons[name] = h
    local function add(kind, def)
        if type(def) ~= "table" or type(def.key) ~= "string" or def.key == "" then return false end
        local part = { kind = kind, owner = name, key = name .. "/" .. def.key, label = short(def.label or def.key, 24), def = def }
        local list = listOf(part)
        for k = #list, 1, -1 do -- the same key again: the new one takes the old one's place
            if list[k].key == part.key then list[k].gone = true; table.remove(list, k) end
        end
        list[#list + 1] = part
        mine[#mine + 1] = part
        changed()
        return true
    end
    -- After Too Many Runes has shut down, its lists are gone (main.lua empties everything). An add-on that then calls remove(), or
    -- anything else, is told "done" or "no", and nothing more happens.
    local function shutDown() return AH.pages == nil or AH.buttons == nil or AH.addons == nil end
    function h.addPage(def)
        if shutDown() then return false end
        if type(def) ~= "table" or type(def.build) ~= "function" then return false end
        return add("page", def)
    end
    function h.addItemButton(def)
        if shutDown() then return false end
        if type(def) ~= "table" or type(def.onClick) ~= "function" then return false end
        return add("button", def)
    end
    function h.remove()
        if shutDown() then mine = {}; return true end
        for _, part in ipairs(mine) do takeOut(part) end
        mine = {}
        if AH.addons[name] == h then AH.addons[name] = nil end
        changed()
        return true
    end
    return h
end
AH.api = api

end }
