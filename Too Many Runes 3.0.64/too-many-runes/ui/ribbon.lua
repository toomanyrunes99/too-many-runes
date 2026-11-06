-- Too Many Runes - The plugin's page in the game's Plugins window (its ribbon icon)
-- A one-line description and two buttons: "Show Too Many Runes" (brings the window back after its X was pressed) and "Open settings" (the
-- window's Settings page). The game hands over an empty layer each time the page is shown, so the page is built again each time.
return { run = function(T)
local _ENV = T

Ribbon = {}

function Ribbon.build(event)
    local layer = field(event, "component") or event
    if layer == nil then return end
    pcall(function() if Ribbon.view ~= nil then Ribbon.view:Destroy() end end)
    Ribbon.view = nil
    local w, h = field(layer, "width"), field(layer, "height")
    if type(w) ~= "number" or w < 100 or type(h) ~= "number" or h < 100 then w, h = 400, 300 end
    local view = prettyui.SimpleView.new(layer, { width = w, height = h })
    Ribbon.view = view
    view:AddTitle("Too Many Runes")
    view:AddText("An item index: how every item is made, what it is used for and where it comes from. Version " .. VERSION .. ".")
    view:AddSimpleButton("Show Too Many Runes", function() Window.reopen() end, { width = math.max(120, w - 32), marginTop = 12 })
    view:AddSimpleButton("Open settings", function() Window.openPage("settings") end, { width = math.max(120, w - 32) })
end

function Ribbon.shutdown()
    pcall(function() if Ribbon.view ~= nil then Ribbon.view:Destroy() end end)
    Ribbon.view = nil
end

Event.ContentLayerReady.Subscribe("tmr3_ribbon", function(event)
    if Ribbon == nil then return end -- (the plugin was switched off)
    local ok, err = pcall(Ribbon.build, event)
    if not ok then trouble("the Plugins window page", err) end
end)

end }
