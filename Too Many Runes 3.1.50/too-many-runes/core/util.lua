-- Too Many Runes - Small helpers used everywhere
return { run = function(T)
local _ENV = T

function say(message) print("Too Many Runes: " .. message) end
function detail(...) if LOG_DETAILS == true then print(...) end end

-- Say a problem once (not 50 times a second).
local told = {}
function trouble(what, err)
    if told[what] then return end
    told[what] = true
    say(what .. " did not work (" .. tostring(err) .. ")")
end

-- try(fn, ...): run fn and give back what it returns, or nil if it went wrong. (The game can refuse to answer for some items.)
function try(fn, ...)
    local ok, a, b = pcall(fn, ...)
    if ok then return a, b end
    return nil
end

-- Read thing[key] (one property of a game object, or one place of a game list) without crashing when the game will not hand it over:
-- nil when it cannot be read.
local function index(thing, key) return thing[key] end
function field(thing, key)
    local ok, value = pcall(index, thing, key)
    if ok then return value end
    return nil
end
valueAt = field

-- A yes / no value of the game: some are true / false, others 1 / 0.
function isTrue(v) return v == true or (type(v) == "number" and v ~= 0) end

-- 58328 -> "58,328"
function withCommas(n)
    local s = tostring(n)
    local changed
    repeat s, changed = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2") until changed == 0
    return s
end

-- The game reads "<" as the start of a tag (<col=...>), so a plain "<" is written "<lt>".
function plain(text) return (string.gsub(tostring(text), "<", "<lt>")) end

-- The names in one of the game's id tables (id.Enum, id.Loc, id.NPC ...) as a list of { name = "SOME_NAME", id = number }. (3.0.93: the
-- shop check of 3.0.92 found that going through such a table does not give the names as its keys; this takes whichever side is the name.)
function idNames(domain)
    local list = {}
    pcall(function()
        for k, v in pairs(id[domain]) do
            if type(k) == "string" then list[#list + 1] = { name = k, id = v }
            elseif type(v) == "string" then list[#list + 1] = { name = v, id = k } end
        end
    end)
    return list
end

-- How wide text is in the window's font (a guess of 7 pixels a letter if the game cannot say).
function textWidth(text)
    local width = try(function() return config.Font.MUSEO_SANS_15PT_REGULAR:GetStringWidth(text, false) end)
    if type(width) == "number" then return width end
    return #text * 7
end

-- Shorten text with ".." until it fits the width.
function fitText(text, width)
    if textWidth(text) <= width then return text end
    local cut = #text
    while cut > 1 and textWidth(string.sub(text, 1, cut) .. "..") > width do cut = cut - 1 end
    return string.sub(text, 1, cut) .. ".."
end

-- Break text into lines no wider than width (at spaces; a single over-long word is shortened).
function wrapText(text, width)
    local lines, line = {}, ""
    for word in string.gmatch(text, "%S+") do
        local try_ = (line == "") and word or (line .. " " .. word)
        if textWidth(try_) <= width or line == "" then
            line = try_
        else
            lines[#lines + 1] = line
            line = word
        end
    end
    if line ~= "" then lines[#lines + 1] = line end
    for i, l in ipairs(lines) do lines[i] = fitText(l, width) end
    return lines
end

-- SAVED SETTINGS: kept in the game's own storage for this plugin (PersistentDB), never sent anywhere. Everything is saved as text, so
-- "never saved" (nil) cannot be mistaken for "off".
Saved = {}
-- (3.0.99: what was last read or written is remembered, and a value that has not changed is not written again - the open tab was written
-- to the game's storage every time an item was opened)
local savedCache = {}
function Saved.get(key)
    local v = savedCache[key]
    if v == nil then
        v = try(function() return PersistentDB:GetString(key) end)
        if type(v) ~= "string" then v = "" end
        savedCache[key] = v
    end
    if v ~= "" then return v end
    return nil
end
function Saved.set(key, value)
    local text = tostring(value)
    if savedCache[key] == text then return end
    savedCache[key] = text
    pcall(function() PersistentDB:SetString(key, text) end)
end
function Saved.num(key) return tonumber(Saved.get(key)) end


-- The game screen (every window's parent) and its size (0, 0 when it cannot be read).
function gameArea() return ui.Interfaces:GetComponent(id.Component.TOPLEVEL_V2__GAME_AREA) end
function screenSize()
    local w, h = try(function() local g = gameArea() return g.width, g.height end)
    return (type(w) == "number") and w or 0, (type(h) == "number") and h or 0
end

-- THE SETTINGS STORED ON AN ITEM ("params": ingredient 1, required level ...), as a list of { name = , value = }; with a prefix, only the
-- ones whose name starts with it. Some kinds of data the game will not hand to a plugin: those are skipped.
-- (the kinds of stored data the game will not hand to a plugin - asking for one raises an error - by the number the game uses for the kind)
UNREADABLE_TYPES = { ["-1"] = true, ["8"] = true, ["16"] = true, ["11"] = true, ["28"] = true, ["126"] = true }
function fieldList(thing, prefix)
    local result = {}
    local params = field(thing, "params")
    if params == nil then return result end
    for i = 1, 1000 do
        local p = field(params, i)
        if p == nil then break end
        local name = tostring(field(p, "configName") or "?")
        if (prefix == nil or string.sub(name, 1, #prefix) == prefix) and not UNREADABLE_TYPES[tostring(field(p, "valueType"))] then
            local ok, v = pcall(function() return thing:GetParamValue(p) end)
            if ok and v ~= nil then result[#result + 1] = { name = name, value = v } end
        end
    end
    return result
end
function getField(list, name)
    for _, e in ipairs(list) do if e.name == name then return e.value end end
    return nil
end

-- A game list (an "enum") as a table key -> value. Used for names the game keeps in lists (skills, quests).
function readEnum(enumName, ceiling)
    local map = {}
    local en = try(function() return config.Enum[enumName] end)
    local entries, count = field(en, "values"), field(en, "valueCount")
    if entries == nil or type(count) ~= "number" then return map end
    for e = 1, math.min(count, ceiling or 2000) do
        local entry = field(entries, e)
        if entry ~= nil then
            local key, value = field(entry, 1), field(entry, 2)
            if key ~= nil then map[key] = value end
        end
    end
    return map
end

end }
