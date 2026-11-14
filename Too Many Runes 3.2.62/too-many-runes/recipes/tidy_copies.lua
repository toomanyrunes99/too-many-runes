-- Too Many Runes - Two kinds of copies sorted under the hide switches
--   * Dungeoneering's own items: the game's name for them STARTS with "rand_" (so a "grand_..." name never counts) -> under the
--   Dungeoneering switch (Items.DUNG), like the ones the wiki list already marks
--   * the game's "dummy" items -> under the Junk switch (Items.JUNK): every item with "dummy" in the game's name (crafting-menu copies,
--   house room icons, display copies: POH_DUMMY_KITCHEN, ARTISAN_MITHRIL_DUMMY, DIV_DUMMY_BOON9 ...), and every item with "dummy" as a word
--   in its own name ("Shade luring dummy", "Mcm expo xp boost dummy"), even one sold on the Grand Exchange ("Dummy wand dark",
--   GFXHELPER_DARK_WAND_DUMMY) - the developer asked for all of them.
-- Never touched: an item sold in a reward shop, a "rand_" item sold on the Grand Exchange, or one already marked (noted, junk ...). (The
-- developer: nothing that might be gRAND_ by accident, and no reward shop items, may be swept away.) "Tradeable" does not protect an item:
-- the game calls Dungeoneering's own items tradeable, as they can be traded inside a dungeon (Fractite bar, Raw heim crab, Kratonium ore,
-- Bathus arrows, the daggers (p)); none is sold on the Grand Exchange. Read once, after the item list and the reward shops, a few thousand
-- items a tick; then the lists are shown again.
return { run = function(T)
local _ENV = T

local PER_TICK = 4000
local k, done = 1, false
local count = { dung = 0, junk = 0 }

local function step()
    if done or not Items.loaded or not Shops.ready then return end
    local n = #Items.ids
    local last = math.min(k + PER_TICK - 1, n)
    for slot = k, last do
        local dbg = Items.debug[slot]
        if dbg ~= nil and (Items.flags[slot] or 0) == 0 and Shops.byItem[Items.ids[slot]] == nil then
            local flag = nil
            if string.sub(dbg, 1, 5) == "rand_" then
                if not Items.ge[slot] then flag, count.dung = Items.DUNG, count.dung + 1 end
            elseif string.find(dbg, "dummy", 1, true) or string.find(Items.lower[slot] or "", "%f[%a]dummy%f[%A]") then
                flag, count.junk = Items.JUNK, count.junk + 1
            end
            if flag ~= nil then
                Items.flags[slot] = flag
                Groups.keys[slot], Groups.rank[slot], Groups.top[slot] = nil, nil, nil
                pcall(Groups.keyOf, slot) -- (worked out again straight away with the new mark - left empty, a group already in the list
                                          -- compared a number with nothing: "attempt to compare nil with number", core/groups.lua)
            end
        end
    end
    k = last + 1
    if k > n then
        done = true
        detail("Too Many Runes: " .. count.dung .. " Dungeoneering items (rand_) and " .. count.junk .. " dummy copies put under the hide switches")
        if count.dung + count.junk > 0 then
            Filters.invalidate()
            if Search.refresh then pcall(Search.refresh) end
        end
    end
end
Passes.add("tidy copies", step, function() return done end, function() done = true end)

end }
