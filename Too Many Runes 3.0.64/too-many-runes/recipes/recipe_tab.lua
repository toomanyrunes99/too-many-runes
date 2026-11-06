-- Too Many Runes - The Recipe tab
-- Shows what the recipe readers (the other files in this folder) know about how an item is made, on the Recipe tab of the item details:
-- the levels and quests it needs, where it is made (with the station's picture), the materials (each one a picture: click it to open that
-- item, Back returns), what it is upgraded from, rituals, potion doses, and the facts checked by hand in the game.
return { run = function(T)
local _ENV = T

-- Has everything the recipes depend on been read? (Until then an answer can still change; the tab says so.)
function Recipes.allRead()
    return linkState.ready == true and Recipes.guideReady == true and Recipes.rowsState.ready == true and Recipes.stationScan.done == true
end

-- The rows for one item, in the form the details column draws (ui/details.lua): { text, icon = item number } or { text, pic = sprite }.
-- The old recipe files' rows ({ text, icon, pic, sprite }, text with "<lt>") as rows of the details box (ui/details.lua). The Source tab
-- uses it too.
function Recipes.toDetailRows(list)
    local rows = {}
    for _, r in ipairs(list or {}) do
        -- (the recipe code already wrote "<" as "<lt>" for the old window; the details column does that itself)
        local row = { text = (string.gsub(tostring(r.text or ""), "<lt>", "<")) }
        if type(r.icon) == "number" then
            row.icon = r.icon
        elseif type(r.pic) == "number" then
            row.pic = r.pic                             -- an Invention material's own picture
        elseif r.sprite ~= nil then
            row.pic = Recipes.stationSprite(r.sprite)   -- a crafting station's map icon (nil until the station pictures are read)
        end
        if type(r.query) == "string" then row.query = r.query end -- (a click searches: "@furnace", "@mining")
        if type(r.sites) == "table" then -- (the dig sites' pictures, side by side: recipes/gather.lua; ui/details.lua draws them)
            local list = {}
            for _, e in ipairs(r.sites) do
                local pic = Recipes.stationSprite(e.sprite)
                if pic ~= nil then
                    list[#list + 1] = { pic = pic, over = e.over and Recipes.stationSprite(e.over) or nil, query = e.query, name = e.name }
                end
            end
            row.sites = list
        end
        rows[#rows + 1] = row
    end
    return rows
end

-- The tab is always called "Recipe" (no other label is given back).
local function recipeRows(itemId)
    local obj = try(config.Obj.FromID, itemId)
    if obj == nil then return { "The game has no item " .. itemId .. "." } end
    local data = Recipes.get(itemId, obj)
    local rows = Recipes.toDetailRows(data ~= nil and data.rows or nil)
    local ready = Recipes.allRead()
    if #rows == 0 then rows[1] = ready and "No available recipe(s) in the plugin's data." or "No recipe found yet." end
    if not ready then rows[#rows + 1] = "" ; rows[#rows + 1] = "(Still reading the game's data, so this can change.)" end
    return rows
end
Details.setTab("recipe", "Recipe", recipeRows)

-- The recipe files call this when they finish reading part of the game's data: the open item is shown again with what is known now.
function Recipes.onDataReady() Details.refreshAll() end

end }
