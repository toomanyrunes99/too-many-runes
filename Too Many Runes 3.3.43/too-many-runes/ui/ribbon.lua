-- Too Many Runes - The plugin's page in the game's Plugins window (its ribbon icon)
-- A one-line description and two buttons: "Show Too Many Runes" (brings the window back after its X was pressed) and "Open settings" (the
-- window's Settings page). The game hands over an empty layer each time the page is shown, so the page is built again each time.
return { run = function(T)
local _ENV = T

Ribbon = {}

-- Builds the page from the plugin's own parts (words and two buttons) rather than a PrettyUI SimpleView. A SimpleView does not
-- work on this page: PrettyUI's layout code fails with "attempt to call a string value (field 'append')".
function Ribbon.build(event)
    local layer = field(event, "component") or event
    if layer == nil then return end
    Ribbon.parts = nil -- the game has already cleared the layer, so the old parts are gone
    local w, h = field(layer, "width"), field(layer, "height")
    if type(w) ~= "number" or w < 100 or type(h) ~= "number" or h < 100 then w, h = 400, 300 end
    local parts = {}
    -- Everything sits on a layer of its own that the mouse wheel moves up and down. The game's page is short and shows only what
    -- lies inside it, so without this the buttons could be cut off with no way to reach them.
    local inner = layer
    pcall(function() local L = ui.Layer.new(layer); L.clickthrough = true; L:SetPos(0, 0); L:SetSize(w, h); inner = L end)
    local y = 12
    local title = Kit.text(inner, 16, y, w - 32, 28, "left")
    title.content = "Too Many Runes"
    pcall(function() title.rgba = 0xD9B25FFF end) -- gold, like the window's headings
    parts[#parts + 1] = title
    y = y + 34
    for _, line in ipairs(wrapText("An item index: how every item is made, what it is used for and where it comes from. Version " .. VERSION .. ".", w - 32)) do
        local t = Kit.text(inner, 16, y, w - 32, LINE_H, "left")
        t.content = line
        parts[#parts + 1] = t
        y = y + LINE_H
    end
    y = y + 12
    local bw = math.max(120, w - 32)
    local show = Kit.button(inner, "Show Too Many Runes", bw, 26, function() Window.reopen() end)
    show:place(16, y)
    y = y + 32
    local settings = Kit.button(inner, "Open settings", bw, 26, function() Window.openPage("settings") end)
    settings:place(16, y)
    parts[#parts + 1] = show
    parts[#parts + 1] = settings
    Ribbon.parts = parts
    -- The mouse wheel, bound to every part, since the game sends it to the part under the mouse.
    local full, top = y + 26 + 12, 0
    if inner ~= layer and full > h then
        pcall(function() inner:SetSize(w, full) end)
        local function turn(dir)
            top = math.max(0, math.min(full - h, top + dir * LINE_H * 2))
            pcall(function() inner:SetPos(0, -top) end)
        end
        Kit.wheel(layer, turn); Kit.wheel(inner, turn)
        for _, part in ipairs(parts) do Kit.wheel(part.sb and part.sb.root or part, turn) end
    end
end

function Ribbon.shutdown()
    Ribbon.parts = nil -- the game clears the page's layer itself
end

Event.ContentLayerReady.Subscribe("tmr3_ribbon", function(event)
    if Ribbon == nil then return end -- the plugin was switched off
    local ok, err = pcall(Ribbon.build, event)
    if not ok then trouble("the Plugins window page", err) end
end)

end }
