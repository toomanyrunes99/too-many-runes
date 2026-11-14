-- Too Many Runes - The Help page
-- Opened by the "?" button at the top right (ui/window.lua); the same button goes back. Written by the developer, in plain words, for a
-- player who has never used the plugin. KEEP THIS UP TO DATE: add a line here whenever a feature is added or changed.
-- How the text is written: "# words" = a heading (gold), "- words" = a bullet point, "" = an empty line, anything else = a paragraph.
-- Everything is on the left; long lines wrap (a bullet's next lines start under its words). The page scrolls with the mouse wheel.
return { run = function(T)
local _ENV = T

local page = { key = "help", label = "Help", noTab = true }

local TEXT = {
    "# The Too Many Runes plugin is an item index for RuneScape!",
    "Look up any item and see how it's made, what it's used for and where you can get it.",
    "",
    "# Searching",
    "Type in the search box at the bottom right:",
    "- A name: iron bar",
    "- An item number: #1205",
    "- A skill: @smithing (add a level if you like: @smithing >60, @smithing <60 or @smithing 60-70)",
    "- A station: @furnace, @anvil, @range, @altar, @energy rift",
    "- Made in the backpack (no station needed): @backpack",
    "- What goes in a compost bin: @compostable, @supercompostable, @ultracompostable",
    "- A kind of item: @food, @potion, @weapon, @armour, @feet, @bow",
    "- Mix them: dragon @smithing or sword >60",
    "- A place things are gathered from: @castra debris, @copper rock, @rock, @tree, @wisp",
    "- Drops and rewards: @araxxi, @boss, @slayer morytania, @medium clue, @shop",
    "- Quest items: @quest, or one quest: @quest ode of the devourer",
    "- More kinds of item: @ore, @bar, @log, @fish, @herb, @seed, @gem, @rune",
    "- Narrow any search: @f2p, @members, @ge, @untradeable, or a right-click option: @teleport, @bury, @read (@f2p @smithing)",
    "While you type, choices pop up above the box. The top line is what you typed. Tab moves down the choices (Shift+Tab up), and a space, Enter or a click puts the yellow one in the box. The mouse wheel scrolls them; Esc or a click elsewhere hides them.",
    "The X clears your search.",
    "",
    "# The item list",
    "- The tabs above the list sort every item into groups (Gear, Artisan ...). Pick one, then its smaller groups from the dropdown on the line under it.",
    "- The Favorites tab lists the items you starred, newest first.",
    "- The second one switches between picture sizes, or a list with names.",
    "- Turn the pages with the arrow buttons or your mouse wheel.",
    "- Items with several forms (doses, charges, augmented ...) share one picture with a number on it. Click it to show the other forms, and click it again to fold them away.",
    "- The arrow at the top left opens the Recently viewed panel: the items you looked at last, newest first.",
    "",
    "# An item's details",
    "Click any item to see it on the right:",
    "- Recipe: what it's made from, where, and the level you need.",
    "- Uses: everything it's used to make.",
    "- Source: where you can mine, catch, cut or dig it up.",
    "- Click a material to jump to it. The back arrow takes you back.",
    "- Click a station or skill picture to see everything made there.",
    "- The star adds the item to your Favorites.",
    "",
    "# In the game",
    "Right-click an item in your backpack, bank or on the ground and pick Recipe, Uses or Source to open it here.",
    "This works on the items inside Too Many Runes too.",
    "",
    "# Settings",
    "The Settings button lets you show the hidden items (noted, broken, Dungeoneering, discontinued and the junk filter), flip the mouse wheel, change the hover colour and more.",
    "The same settings are also in the game's Plugin Hub, behind the cog next to Too Many Runes.",
    "",
    "# Final notes",
    "- After you log in, the plugin needs about a minute to read the game's data. Some recipes and uses only show up once it's done.",
    "- Everything mostly comes from the game's own data, plus a few things I checked by hand. If something looks wrong or is missing, let me know!",
    "- Some information comes from the RuneScape Wiki (runescape.wiki), used under CC BY-NC-SA 3.0.",
}

local LINE_H = 22
local LEFT, BULLET = 12, "\u{2022}  " -- (the bullet sign and two spaces)
page.scroll = 0
page.parts = {}

-- The text as lines that fit the width: { text, x, heading }
local function lines(width)
    if page.cache ~= nil and page.cacheW == width then return page.cache end
    local out = {}
    local bulletW = math.ceil(textWidth(BULLET))
    for _, para in ipairs(TEXT) do
        if para == "" then
            out[#out + 1] = { text = "", x = LEFT }
        elseif string.sub(para, 1, 2) == "# " then
            out[#out + 1] = { text = string.sub(para, 3), x = LEFT, heading = true }
        elseif string.sub(para, 1, 2) == "- " then
            for k, part in ipairs(wrapText(string.sub(para, 3), width - LEFT - 8 - bulletW)) do
                if k == 1 then out[#out + 1] = { text = BULLET .. part, x = LEFT + 8 }
                else out[#out + 1] = { text = part, x = LEFT + 8 + bulletW } end
            end
        else
            for _, part in ipairs(wrapText(para, width - LEFT)) do out[#out + 1] = { text = part, x = LEFT } end
        end
    end
    page.cache, page.cacheW = out, width
    return out
end

local function draw()
    if page.w == nil then return end
    local all = lines(page.w - 30)
    local room = math.max(1, (page.h - 10) // LINE_H)
    page.scroll = math.max(0, math.min(page.scroll, #all - room))
    for k = 1, room do
        local p = page.parts[k]
        if p == nil then
            p = Kit.text(page.sub, 0, 0, 10, LINE_H, "left")
            Kit.wheel(p, page.wheel)
            page.parts[k] = p
        end
        local l = all[page.scroll + k]
        if l == nil then p.hidden = true
        else
            p:SetSize(page.w - l.x - 10, LINE_H)
            p:SetPos(l.x, 6 + (k - 1) * LINE_H)
            p.content = plain(l.text)
            pcall(function() p.rgba = l.heading and 0xE8C060FF or 0xE8DCC0FF end)
            pcall(function() p.alpha = 1.0 end)
            p.hidden = false
        end
    end
    for k = room + 1, #page.parts do page.parts[k].hidden = true end
    if page.scroll + room < #all then -- (the last line says there is more)
        local p = page.parts[room]
        p:SetPos(LEFT, 6 + (room - 1) * LINE_H)
        p.content = "(scroll down for more)"
        pcall(function() p.rgba = 0xE8DCC0FF; p.alpha = 0.6 end)
    end
end

function page.build(layer)
    page.sub = ui.Layer.new(layer)
    page.wheel = function(step)
        if page.wheelTick == tickCount then return end -- (one notch reaches every part under the mouse: act once)
        page.wheelTick = tickCount
        page.scroll = page.scroll + step * 3
        draw()
    end
    Kit.wheel(page.sub, page.wheel)
end

function page.layout(w, h)
    page.w, page.h = w, h
    page.sub:SetPos(0, 0); page.sub:SetSize(w, h)
    draw()
end

function page.refresh(newSearch) end

Window.addPage(page)

end }
