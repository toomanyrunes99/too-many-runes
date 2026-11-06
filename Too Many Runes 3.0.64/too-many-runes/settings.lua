-- Too Many Runes - Settings
-- The knobs. Each one has a comment saying what it does. Safe to change; restart the plugin (prl too-many-runes) to see the change.
return { run = function(T)
local _ENV = T

-- THE WINDOW
WINDOW_W, WINDOW_H = 760, 500         -- the starting size of the inside of the window (drag its corner to change it; the size is remembered)
WINDOW_MIN_W, WINDOW_MIN_H = 600, 400 -- the smallest it may be dragged to
DETAILS_W = 290                       -- how wide the right-hand column is (Recipe / Uses / Source at the top, the item's info under it)
COLLAPSED_W = 300                     -- how wide the window is while minimized (the whole bar, frame included)

-- THE ITEM LIST
MAX_ITEM_ID    = 90000 -- item numbers are checked from 0 up to this one
ITEMS_PER_TICK = 300   -- how many item numbers are checked per game tick (50 ticks a second). Lower = gentler, higher = ready sooner
-- SEARCH_HINTS: what the empty search box suggests after its fixed "Search:", one after another (a few seconds each, fading from one
-- to the next)
SEARCH_HINTS = { "name or #number", "Ensouled bar", "@furnace", "@smithing >60", "@loom",
                 "#1205", "@potion", "@mining 30-60", "sword >60", "@food" }
-- SEARCH_SYNONYMS (a hidden extra): other words for the @ search words, so @chestpiece finds what @body finds. typed word = { the @ words
-- it may mean, tried in order } (the first one the game has is used). Plurals work by themselves (@rings, @boots), and so does the start
-- of a word (@smith, @arch). Add your own: lower case, no @.
SEARCH_SYNONYMS = {
    -- worn gear (the game's own slot words: head, body, legs, feet, hands, neck, ring, cape, shield ...)
    helmet = { "head", "helm" }, helm = { "head" }, hat = { "head" }, hood = { "head" }, mask = { "head" }, coif = { "head" }, headgear = { "head" },
    chestpiece = { "body", "torso" }, chest = { "body", "torso" }, torso = { "body" }, platebody = { "body" }, chainbody = { "body" },
    top = { "body" }, shirt = { "body" },
    pants = { "legs" }, trousers = { "legs" }, leggings = { "legs" }, platelegs = { "legs" }, plateskirt = { "legs" }, skirt = { "legs" },
    chaps = { "legs" }, bottoms = { "legs" },
    boots = { "feet" }, boot = { "feet" }, shoes = { "feet" }, shoe = { "feet" }, sandals = { "feet" },
    gloves = { "hands" }, glove = { "hands" }, gauntlets = { "hands" }, vambraces = { "hands" }, bracers = { "hands" },
    necklace = { "neck", "necklace", "amulet" }, amulet = { "neck", "necklace", "amulet" }, ammy = { "neck" }, pendant = { "neck" },
    cloak = { "cape", "back" }, back = { "cape" },
    offhand = { "off-hand", "shield" }, defender = { "shield", "off-hand" }, buckler = { "shield" }, kiteshield = { "shield" },
    -- weapons and ammunition
    weapons = { "weapon" }, wep = { "weapon" }, armor = { "armour" }, ammunition = { "ammo" },
    longbow = { "bow" }, shortbow = { "bow" }, xbow = { "crossbow" }, cbow = { "crossbow" }, staves = { "staff" }, wand = { "wand", "staff" },
    ["2h"] = { "2h-sword", "2h" }, twohanded = { "2h-sword" }, greatsword = { "2h-sword" }, godsword = { "2h-sword" },
    -- food and potions
    eat = { "food" }, pot = { "potion" }, pots = { "potion" }, flask = { "potion" }, brew = { "potion" },
    -- crafting stations
    smelt = { "furnace" }, smelter = { "furnace" }, stove = { "range" }, kitchen = { "range" }, fire = { "bonfire" }, campfire = { "bonfire" },
    wheel = { "spinning" }, kiln = { "oven" }, saw = { "sawmill" },
    -- skills
    wc = { "woodcutting" }, chop = { "woodcutting" }, mine = { "mining" }, rc = { "runecrafting" }, runecraft = { "runecrafting" },
    fm = { "firemaking" }, dg = { "dungeoneering" }, dung = { "dungeoneering" }, con = { "construction" }, cons = { "construction" },
    hunt = { "hunter" }, hunting = { "hunter" }, thieve = { "thieving" }, steal = { "thieving" }, smelting = { "smithing" },
    atk = { "attack" }, att = { "attack" }, str = { "strength" }, hp = { "constitution" }, hitpoints = { "constitution" },
    defense = { "defence" }, mage = { "magic" }, summ = { "summoning" }, div = { "divination" }, inv = { "invention" },
    necro = { "necromancy" }, pray = { "prayer" }, agil = { "agility" }, slay = { "slayer" },
}

RECENT_MAX     = 128   -- how many items the Recently viewed column remembers
RECENT_W       = 250   -- how much wider the window gets for the Recently viewed column
RECENT_ARROW   = { sprite = 17040, w = 21, h = 21, flipWhenOpen = true } -- the arrow that opens the panel (flipWhenOpen: which way it
                                                                         -- points while open; change it if it points the wrong way)
VIEW_DEFAULT   = "icons:32" -- how the list starts the first time: "rows", or "icons:64", "icons:48", "icons:32", "icons:16"
MAX_PICTURES   = 1200  -- the most item pictures on one page (the game allows a plugin about 4,000 parts on screen in all)
MAX_ROWS       = 100   -- the most rows on one page of the rows view (each row is a picture and a button, about 5 parts)
WHEEL_UP_NEXT  = true  -- true: the mouse wheel UP goes to the next page; false: DOWN does (a switch for this comes with the settings page)
FILTER_DEFAULT = "all"      -- which filter the list starts on the first time: "all", "fav", "craftable" or "non" (uncraftable)

-- Clutter that starts hidden (true = hidden). Once the settings page is back (a later stage) the choice there is remembered instead.
HIDE = { noted = true, broken = true, unfinished = true, junk = true }

-- GAME_MENU: true = right-clicking an item in the game (backpack, bank, ground) adds "Recipe: / Uses: / Source: <item>" (ui/game_menu.lua)
GAME_MENU = true

MENU_COLOUR = "00aa00" -- the colour of those entries' words (dark green), as RRGGBB; "" = the game's own colour

-- SHOW_DEBUG_NAMES: true = the Info box under an item also shows the game's own name for it ("Debug name: CANNONBALL"), and the search
-- box finds those names too ("trail_sliding"). (The Settings page switches it.)
SHOW_DEBUG_NAMES = false
-- SMART HIDE (the Settings switch "Smart hide"; called "junk" in the code): the lists below mark an item for it.
JUNK_NAME_WORDS     = { "LENT" }                 -- a word in an item's internal (game) name that marks it as junk
JUNK_NAME_PATTERNS  = { "^cursed energ",         -- (Lua patterns, matched against the lower-case name; ^ = its start, $ = its end)
                        "xp lamp", "reward lamp",   -- xp lamps ("Huge XP lamp") and reward lamps
                        "prismatic star", "prismatic fallen star",
                        "^protean ",                -- protean bars, logs ...
                        " aura$" }                  -- auras ("Resourceful aura")
-- Lua patterns matched against the UPPER-CASE debug name (the game's own name: Settings > "Show the game's debug name"); ^ = its start,
-- $ = its end, %d+ = a number, .* = anything, %f[%w]WORD%f[%W] = WORD as a word of its own
JUNK_DEBUG_PATTERNS = { "^TRAIL_SLIDINGPUZZLE",       -- sliding puzzles
                        "^REINI%a*SATION_%d+",       -- sliding puzzle buttons: REINITIALISATION_03, Reinitialisation_12_inactive
                        "^LORE_.*_NULL$",             -- lore pouches with no known use (LORE_WAR_TURTLE_NULL)
                        "^AURA_%d+_LEVEL_%d+",        -- auras (AURA_1234_LEVEL_2)
                        "MTX",                        -- anything from the shop: MTX_BATCH_..., BOUGHT_MTX_BATCH_...
                        "^POP_CREW_",                 -- Pop_crew_ items (not Pop_melee or Pop_ranged)
                        "XP_?LAMP", "REWARD_LAMP",    -- xp and reward lamps
                        "PRISMATIC_.*STAR",           -- prismatic stars
                        "PROTEAN", "%f[%w]TRH%d*%f[%W]", -- protean items and anything with the TRH tag (TRH88_SCARF_BLUE)
                        "MARKETPLACE" }               -- MARKETPLACE_STORE_OUTFIT_1234
JUNK_TOKEN_WITH     = { "EVENT", "MTX", "SEASON", "PROMO", "REWARD" } -- a debug name with TOKEN and one of these is junk (event tokens ...)
JUNK_CATEGORIES     = { "SMITHING_DEPRECATED" }  -- a game category whose items are junk (the old "Convert" rune gear)
UNFINISHED_PATTERNS = { "^unfinished ", "%(unf%)%s*$", "%(unfinished%)" } -- (Lua patterns, matched against the lower-case name)

-- PICTURES (the game's own picture numbers)
PAGER_ICONS = {
    prev = { normal = 21244, hover = 21245, w = 15, h = 18 },
    next = { normal = 21244, hover = 21245, w = 15, h = 18, flip = true },
}
BACK_SPRITES = { normal = 96664, hover = 96663, disabled = 96665, w = 24, h = 24 }

-- RECIPES (the Recipe tab)
USE_PLAYER_FACTS = true -- true: also show the facts checked by hand in the game where the game's own data says nothing (recipes/exceptions.lua)
SAME_NAME_RULE   = true -- true: an item that is a plain copy of a made item (same name, nothing of its own) shows that item's recipe
DOSE_RULE        = true -- true: a potion / flask / salve level with no recipe ("Prayer potion (1)") points at the level that is made
RECIPE_MAX_LINES = 40   -- the most rows one recipe shows (the Recipe tab scrolls with the mouse wheel when they do not all fit)

-- BACKGROUND WORK (reading recipes and uses after start-up)
BACKGROUND_MS = 5   -- the most milliseconds per game tick (50 a second) the background reading may use; it slows itself down to stay under
SCAN_SPEED    = 0.5 -- the speed of working out the uses and checking each recipe, as the game gives no clock to measure with
                    -- (1 = full speed, which made the game stutter for a few seconds; lower = gentler but slower to finish)

LOG_DETAILS = false -- true: the console also prints loading details (useful when something loads wrongly)

end }
