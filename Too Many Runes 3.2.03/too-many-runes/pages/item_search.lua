-- Too Many Runes - The "Item search" tab
-- The item box on the left (every item the search and filter let through, the forms of an item grouped: core/groups.lua) and the item
-- details on the right.
return { run = function(T)
local _ENV = T

local page = { key = "search", label = "Item search" }

function page.build(layer)
    page.box = ItemBox.new(layer, function(itemId, place)
        local changed, at = Groups.click(place) -- (a group's picture: its other forms unfold, or fold away; another open group folds)
        if not changed then changed, at = Groups.foldUnless(itemId, place) end -- (another item: the open group folds)
        if changed then
            page.refresh(false)
            local want = at and ((at - 1) // page.box.perPage + 1) -- (folding a group before it moved it: keep it on screen)
            if want ~= nil and want ~= page.box.page then page.box:goTo(want) end
            Window.refreshPager()
        end
        page.details:open(itemId)
    end)
    page.box.countOf, page.box.hoverNote, page.box.inGroup = Groups.countAt, Groups.noteAt, Groups.openAt
    page.box.selectedOf = function() return page.details.itemId end -- (the item open on the right is marked in the list)
    page.details = Details.new(layer)
    local open = page.details.open
    page.details.open = function(self, ...) -- (any other way an item is opened - a material, the back arrow - moves the mark too)
        local result = open(self, ...)
        if Groups.foldUnless(self.itemId) then page.refresh(false); Window.refreshPager() end -- (not one of the open group's forms)
        pcall(page.box.paintMarks, page.box)
        return result
    end
end

function page.layout(w, h)
    local dw = math.min(DETAILS_W, w - 240)
    page.box:place(0, 0, w - dw - 6, h)
    page.details:place(w - dw, 0, dw, h)
end

function page.refresh(newSearch)
    page.box:setList(Groups.of(Search.list(), newSearch), newSearch)
    page.box:render()
end

-- The item list grew while loading: draw the page again only if it was not full (new items are added at the end of the list).
function page.grow()
    local box, list = page.box, Groups.of(Search.list())
    if math.min(box.perPage, #list - (box.page - 1) * box.perPage) ~= box.shown or Groups.changedUpTo(box.page * box.perPage) then
        page.refresh(false)
    end
end

function page.pageInfo() return page.box.page, page.box:pageCount() end
function page.goTo(n) page.box:goTo(n) end

Window.addPage(page)

end }
