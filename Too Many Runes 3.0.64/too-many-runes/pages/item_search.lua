-- Too Many Runes - The "Item search" tab
-- The item box on the left (every item the search and filter let through) and the item details on the right.
return { run = function(T)
local _ENV = T

local page = { key = "search", label = "Item search" }

function page.build(layer)
    page.box = ItemBox.new(layer, function(itemId) page.details:open(itemId) end)
    page.details = Details.new(layer)
end

function page.layout(w, h)
    local dw = math.min(DETAILS_W, w - 240)
    page.box:place(0, 0, w - dw - 6, h)
    page.details:place(w - dw, 0, dw, h)
end

function page.refresh(newSearch)
    page.box:setList(Search.list(), newSearch)
    page.box:render()
end

-- The item list grew while loading: draw the page again only if it was not full (new items are added at the end of the list).
function page.grow()
    local box = page.box
    if math.min(box.perPage, #Search.list() - (box.page - 1) * box.perPage) ~= box.shown then page.refresh(false) end
end

function page.pageInfo() return page.box.page, page.box:pageCount() end
function page.goTo(n) page.box:goTo(n) end

Window.addPage(page)

end }
