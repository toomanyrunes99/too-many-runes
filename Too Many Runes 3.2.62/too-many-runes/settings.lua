-- Too Many Runes - Settings
-- The knobs. Each one has a comment saying what it does. Safe to change; restart the plugin (prl too-many-runes) to see the change.
return { run = function(T)
local _ENV = T

-- THE WINDOW
WINDOW_W, WINDOW_H = 805, 537         -- the starting size of the inside of the window (drag its corner to change it; the size is remembered)
WINDOW_MIN_W, WINDOW_MIN_H = 600, 400 -- the smallest it may be dragged to
DETAILS_W = 310                       -- how wide the right-hand column is (Recipe / Uses / Source at the top, the item's info under it)
COLLAPSED_W = 300                     -- how wide the window is while minimized (the whole bar, frame included)
MIN_SPRITE = 24420                    -- the minimize button's picture on the title bar (a sprite number)
-- The tabs: "big" - the game's own tab pictures at PrettyUI's size (the tab row is 42 high instead of 28); "small" - the same pictures
-- scaled down to the row; nil - plain buttons.
MAIN_TAB_STYLE    = "big"     -- the window's tab row ("Item search")
DETAILS_TAB_STYLE = "small"   -- the details column's tabs (Recipe / Uses / Source)
DETAILS_TAB_ROW   = 32        -- how tall the details tabs are with "small" ("big" is 42)
-- The runes the minimized icon goes through, in a random order (item numbers)
ICON_RUNES = { 556, 558, 55337, 555, 4695, 557, 4696, 554, 4697, 4694, 559, 55338, 4699, 564, 562, 9075, 55339, 561, 563, 55340, 560,
               565, 566, 58450 }

-- THE ITEM LIST
MAX_ITEM_ID    = 300000 -- only a safety stop: the reading ends ITEM_ID_GAP numbers after the last item found
ITEM_ID_GAP    = 5000   -- how many numbers in a row with no item end the list (the gaps between items are a few hundred at most)
ITEM_ID_GUESS  = 70000  -- about where the items end today: only for the loading percentage
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
-- the RuneScape Wiki's button, in front of every heading whose information comes from the wiki ("Info from the RuneScape Wiki:"). The
-- game does not say how big a picture is, so w and h are its width and height here: change them if it looks squashed or stretched
WIKI_ICON      = { sprite = 10386, w = 48, h = 17 }
RECENT_ARROW   = { sprite = 17040, w = 21, h = 21, flipWhenOpen = true } -- the arrow that opens the panel (flipWhenOpen: which way it
                                                                         -- points while open; change it if it points the wrong way)
VIEW_DEFAULT   = "icons:32" -- the icon size the list starts with the first time: "icons:16" (Tiny), "icons:32" (Small), "icons:48" (Medium), "icons:64" (Large)
MAX_PICTURES   = 1200  -- the most item pictures on one page (the game allows a plugin about 4,000 parts on screen in all)
MAX_ROWS       = 100   -- the most rows on one page of the rows view (each row is a picture and a button, about 5 parts)
WHEEL_UP_NEXT  = false -- false: the mouse wheel DOWN goes to the next page; true: UP does (a switch on the Settings page)

-- Clutter that starts hidden (true = hidden; the Settings page's switches remember the player's own choice). dungeoneering and
-- discontinued: from the RuneScape Wiki's lists (data/wiki_lists.lua).
HIDE = { noted = true, broken = true, junk = true, dungeoneering = false, discontinued = true, minigames = true } -- (minigames: Misc > Minigames)

-- GAME_MENU: true = right-clicking an item in the game (backpack, bank, ground) adds "Recipe: / Uses: / Source: <item>" (ui/game_menu.lua)
GAME_MENU = true

MENU_COLOUR = "00aa00" -- the colour of those entries' words (dark green), as RRGGBB; "" = the game's own colour

HOVER_COLOUR = "Gold" -- the colour of a picture under the mouse: Green, Gold, Blue, Red, Purple, Cyan, Orange, Pink or Yellow
HOVER_OUTLINE = 2 -- the game's own outline round the shape of the item under the mouse (the picture's outlineWidth; 0 = none, try 1 or 2)
HOVER_BOX = 0     -- a square box round the item picture under the mouse, this many pixels thick, in the hover colour (0 = no box)
WINDOW_SEE_THROUGH = true -- true: the window's background follows the game's own interface transparency setting (the game's
                          -- TOPLEVEL_V2_TRANSPARENCY); false: solid. The Settings page switches it.

-- SHOW_DEBUG_NAMES: true = the Info box under an item also shows the game's own name for it ("Debug name: CANNONBALL"), and the search
-- box finds those names too ("trail_sliding"). (The Settings page switches it.)
SHOW_DEBUG_NAMES = false

-- GROUP_FORMS: true = the forms of one item (doses and charges like "Attack potion (1)" ... "(4)", charged / uncharged / degraded,
-- "Augmented X" with X, and items with the same name) share one picture in the item list, with a number on it; click it to show the others.
-- false = every item has a picture of its own. (The Settings page has a switch for it.)
GROUP_FORMS = true

-- RIGHT_CLICK_WORDS: options in an item's right-click menu that are also search words - "@teleport" finds every item whose menu has
-- "Teleport" (or an option starting with it, like "Teleport to house"). Lower case, no @. Add your own.
RIGHT_CLICK_WORDS = { "teleport", "bury", "scatter", "read", "eat", "drink", "wield", "wear", "open", "rub", "break", "light", "plant" }

-- START_MINIMIZED: true = the window starts minimized to the rune icon every time the plugin is turned on or reloaded (the game is busy
-- drawing the item pictures if the list is shown while the plugin starts). false = it starts the way you left it.
START_MINIMIZED = true
-- THE JUNK FILTER (the Settings switch "Junk filter"; called "junk" in the code): the lists below mark an item
-- for it.
JUNK_NAME_WORDS     = { "LENT" }                 -- a word in an item's internal (game) name that marks it as junk
JUNK_NAME_PATTERNS  = { "^scroll box %(", "^puzzle casket", -- (scroll boxes and puzzle caskets, by name as well)
                        "^cursed energ",         -- (Lua patterns, matched against the lower-case name; ^ = its start, $ = its end)
                        "xp lamp", "reward lamp",   -- xp lamps ("Huge XP lamp") and reward lamps
                        "prismatic star", "prismatic fallen star",
                        "^protean ",                -- protean bars, logs ...
                        " aura$" }                  -- auras ("Resourceful aura")
-- Lua patterns matched against the UPPER-CASE debug name (the game's own name: Settings > "Show the game's debug name"); ^ = its start,
-- $ = its end, %d+ = a number, .* = anything, %f[%w]WORD%f[%W] = WORD as a word of its own
JUNK_DEBUG_PATTERNS = { "^TRAIL_SLIDINGPUZZLE",       -- sliding puzzles
                        "^REINI%a*SATION_%d+",       -- sliding puzzle buttons: REINITIALISATION_03, Reinitialisation_12_inactive
                        "^LORE_.*_NULL$",             -- lore pouches with no known use (LORE_WAR_TURTLE_NULL)
                        "^SC_.*_NULL$",               -- Stealing Creation's blank stand-ins (Null sacred clay: SC_CLAY_NULL)
                        "^AURA_%d+_LEVEL_%d+",        -- auras (AURA_1234_LEVEL_2)
                        "MTX",                        -- MTX items (bought with real money): MTX_BATCH_..., BOUGHT_MTX_BATCH_...
                        "^POP_CREW_",                 -- Pop_crew_ items (not Pop_melee or Pop_ranged)
                        "XP_?LAMP", "REWARD_LAMP",    -- xp and reward lamps
                        "PRISMATIC_.*STAR",           -- prismatic stars
                        "PROTEAN", "%f[%w]TRH%d*%f[%W]", -- protean items and anything with the TRH tag (TRH88_SCARF_BLUE)
                        "%f[%w]WOF%d*%f[%W]",         -- Squeal / Wheel of Fortune prizes (WOF_CASH_BAG_HUGE, WOF33_TROLL_PET_NAME_1)
                        "^REPUTATION_.*_SAVER$", "^REPUTATION_.*_BUFF$", -- Menaphos reputation buffs, not real items (Slayer Feather Buff:
                                                      -- REPUTATION_SLAYER_FEATHER_SAVER; Magic Carpet Skilling Buff ...)
                        "MARKETPLACE",                -- MARKETPLACE_STORE_OUTFIT_1234
                        "%f[%w]TWITCH%f[%W]",         -- Twitch drops and Prime packs - TWITCH as a word of its own,
                                                      -- anywhere: TWITCH_OCT21_PET, POH_TWITCH_JUN18_PET, POF_TWITCH_LOOTCRATE
                        "^FADE_TO_",                  -- the blank stand-ins called "Dummy" (FADE_TO_BLACK_INV, FADE_TO_WHITE_INV)
                        "^PICKPOCKET_GUIDE_",         -- picture-only stand-ins, probably the Thieving guide's (PICKPOCKET_GUIDE_GNOME)
                        -- (second copies of an item, told by their debug names)
                        "^INVIS_",                    -- hidden placeholder copies (the second Emerald necklace: INVIS_NECKLACE2)
                        "^DEPRECATED_",               -- old retired versions (a Rune platebody: DEPRECATED_T5_BOD)
                        "CRAFTING_DUMMY",             -- the game's stand-ins for crafting (VORKATH_TIER92_BODY_CRAFTING_DUMMY)
                        "^TUT%d*_",                   -- tutorial copies (TUT6_BUCKET_WATER)
                        -- (the clue scrolls' single steps clutter the list; the starting clue scrolls - TRAIL17_TRAIL_START_HARD - stay)
                        "^TRAIL_CLUE_",               -- the steps (Trail_clue_hard_Emote...)
                        "^TRAIL.*SEXTANT",            -- sextant clues
                        "^TRAIL.*_SCAN%d",            -- scan clues (..._SCAN014)
                        "^TRAIL.*SCROLL_?BOX",        -- scroll boxes
                        "^TRAIL.*PUZZLE.*CASKET",     -- puzzle caskets
                        "PREMCLUB%d",                 -- Premier Club rewards (BOUGHT_PREMCLUB16_BRONZE)
                        "^LOY_",                      -- Loyalty programme rewards (LOY_WEREWOLF_FEMALE_HEAD_V3)
                        "^BOUGHT_" }                  -- bought rewards (BOUGHT_GAMECARD_KATANA)
-- Items marked by their numbers, first to last (57776 - 57869 are all called "Full slayer helmet" but are not the real slayer helmet)
JUNK_ID_RANGES      = { { 57776, 57869 } }
JUNK_TOKEN_WITH     = { "EVENT", "MTX", "SEASON", "PROMO", "REWARD" } -- a debug name with TOKEN and one of these is junk (event tokens ...)
JUNK_CATEGORIES     = { "SMITHING_DEPRECATED",   -- a game category whose items are junk (the old "Convert" rune gear)
                        "WOF_SKILL_SET_ITEM", "WOF_SKILL_CRATE", "WOF_LAMP", "WOF59_SPIRIT_GEM_EMPTY", "WOF59_SPIRIT_GEM_USED", "WOF49_TIARA",
                        "WOF13_BEACHBALL" }       -- (Squeal of Fortune prizes, by their categories)

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
SCAN_SPEED    = 0.5 -- the speed of working out the uses and checking each recipe, as the game gives no clock to measure with
                    -- (1 = full speed, which made the game stutter for a few seconds; lower = gentler but slower to finish)

LOG_DETAILS = false -- true: the console also prints loading details (useful when something loads wrongly)

end }
