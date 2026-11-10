-- Too Many Runes - the exceptions
--
-- Almost everything the plugin shows is read straight from the game's own data. This file holds the rest: the few facts
-- the game does NOT record anywhere, plus the numbers and names we had to work out by hand to read its data. Each entry
-- says where the fact came from. If the game changes (a new item, a renamed list), this is the first place to look.
--
-- The plugin carries no fact typed in from the RuneScape Wiki. (Brown dye and its single use were the last: you confirmed them in the game on
-- 2026-10-28, so they are hand-written facts now, see playerFacts.dyes.) Everything is read from the game (the toolbelt, the masterwork armour steps,
-- the numbering of the quests needed to wear things), or is something you told us (playerFacts), or, where nothing holds it (the glorious bar's
-- recipe, what most achievement numbers mean), was removed. The survey
-- MODE = "sources" in settings.lua is what looked for the game's own source of each. The last unverified table, ensoulInputs (which
-- items go into the ensoul rituals for cloth and thread), was removed: the ritual window itself lists them, see
-- playerFacts.rituals.ensoul.
--
-- This file is plain data: it only describes things, it does not do anything. The code that uses each table is named in
-- the line above it. Add a line here and the plugin picks it up; nothing else needs to change.
--
-- How the sections are arranged:
--   1. How the game numbers things        (numbers worked out from the game)
--   2. Names of game data we rely on      (the lists and settings that link items together)
--   3. Facts the game does not record     (custom-fit armour ...)
--   4. Facts added by the developer          (each tagged source = "player": see the note at the top of that section)

return {

    ------------------------------------------------------------------------------------------------
    -- 1. HOW THE GAME NUMBERS THINGS
    ------------------------------------------------------------------------------------------------

    -- A recipe can list up to six requirements, each a TYPE number and a VALUE (RECIPE_REQUIREMENT_TYPE_n / _VALUE_n).
    -- For a skill the type is the skill's own number (read from the game's skill guides, so it is not written here).
    -- These five are not skills. Used by: recipes/parse.lua, recipes/unlocks.lua, recipes/guides.lua.
    requirementTypes = {
        quest       = 61, -- the value is a place in the game's quest list
        achievement = 62, -- the value is a plain number; no list the game hands to a plugin explains it (only the Necromancy ones are
                          -- named, see below)
        blueprint   = 63, -- the value is column 1 of a data row named INVENT_BLUEPRINT_... (Invention blueprints)
        method      = 64, -- the value says WHICH special way of making it this is (see "methods" below); the game has no names for them
        house       = 67, -- no value at all: the item is built in your player-owned house (house furniture)
    },

    -- Type 64's values. The game does not name them; these names were worked out from the items that share each number
    -- (survey "requirements", round 20) and confirmed in game. A number that is not listed here is simply not shown.
    -- Used by: recipes/parse.lua (the "Method:" row).
    methods = {
        [1]  = "Artefact restoration",      -- 244 Archaeology artefacts (Avian song-egg player, Blackfire lance ...)
        [2]  = "Soil screening",            -- Senntisten soil, Ancient gravel, Saltwater mud ...
        [17] = "Sawmill",                   -- Plank, Oak plank ... Eternal plank
        [22] = "Overload, finishing step",  -- Overload (3), Batch of overload, the salves and the supreme / elder versions
        [23] = "Overload, mixing step",     -- the "(unfinished)" overloads, made from extreme potions and torstol
        [25] = "Fletching progress",        -- Primal crossbows Mk. 1 to 5 (and the off-hand and martial versions)
    },
    methodRowStart = "Method: ", -- what the row starts with
    houseRow = "Built in your house", -- the row shown for type 67


    -- Making the Necromancy equipment (the Deathwarden robes and the rest) is unlocked by a "Kili's Knowledge"
    -- achievement. The recipe stores only a plain number for it (requirement type 62) and no game list explains that
    -- number. But the game keeps a list of the items of every tier (NECRO_MAKEX_EQUIPMENT_UPGRADES_T60 ...) and names
    -- the achievement of a tier the same way (CHEEVO_NECROMANCY_UNDERWORLD_EQUIPMENT_UPGRADE_T60 = "Kili's Knowledge IV").
    -- So the achievement is found through the tier the item belongs to. Checked against the wiki: Tier 60 = Kili's
    -- Knowledge IV, Tier 70 = Kili's Knowledge V. This is the start of those achievements' internal names.
    -- Used by: recipes/unlocks.lua.
    kiliAchievement = "CHEEVO_NECROMANCY_UNDERWORLD_EQUIPMENT_UPGRADE_",

    ------------------------------------------------------------------------------------------------
    -- 2. NAMES OF GAME DATA WE RELY ON
    ------------------------------------------------------------------------------------------------

    -- Some items are made by changing another item rather than from a list of materials. The game stores each of these
    -- as a setting on one of the two items, pointing at the other. A survey of every item showed which settings are
    -- real "made from" links (others, like worn / broken armour, are not).
    --   find    = the setting's name
    --   forward = true : the setting is on the EARLIER item and points at what it becomes
    --   forward = false: the setting is on the NEW item and points at what it was made from
    --   label   = the words shown above the item it was made from
    --   role    = (optional) marks the link so other code can find it: the masterwork armour draft and unfinished piece
    -- Used by: recipes/links.lua, recipes/manual.lua.
    linkRules = {
        { find = "SMITHING_NEXT_UPGRADE",          forward = true,  label = "Upgraded from:" },
        { find = "CRAFTING_ARMOUR_UPGRADE_OBJECT", forward = false, label = "Upgraded from:", role = "unfinished" },
        { find = "CRAFTING_ARMOUR_DRAFT_OBJECT",   forward = false, label = "Drafted from:",  role = "draft" },
        { find = "INVENT_BASE_OBJECT",             forward = false, label = "Based on:" },
        -- (3.0.70: the item points at its augmented version - INVENT_AUGMENTED_VERSION and INVENT_NONSTANDARD_AUGMENTED_VERSION, the survey
        -- of 3.0.68. An augmented item is shown "Augmented from:" its item and "Augmented with:" the Augmentor, see links.lua.)
        { find = "AUGMENTED_VERSION",              forward = true,  label = "Based on:" },
        { find = "DYE_RESULT",                     forward = true,  label = "Dyed from:" },
        { find = "CRAFTING_PROGRESS_PRODUCT",      forward = true,  label = "Worked from:" },
    },

    -- Some items have a few RECIPE_ settings (a level, the XP) but no ingredients, because the game keeps the real
    -- recipe on a TWIN of the item (survey rounds 11 and 12):
    --   * the old superior scrimshaws point to the new version of themselves (POP_NEW_VERSION), which holds the recipe;
    --   * a worn or broken piece of Dinosaurhide armour points to the fresh piece (ITEM_DEGRADE_FIXEDSTATE).
    -- These are the settings that point at such a twin. Used by: recipes/rituals.lua.
    donorSettings = { "POP_NEW_VERSION", "ITEM_DEGRADE_FIXEDSTATE" },

    -- The toolbelt. The game keeps lists of the tools that have a place on the belt; each entry is the tool itself or a little record
    -- that names it in its TOOLBELT_OBJECT setting (the survey "sources" found these). Recipes do not mention the tools in these lists,
    -- because they are kept on the belt rather than carried. (The two DUNG lists are Dungeoneering's own tools and are left out.)
    -- Nothing here is a fact about the game: these are only the names of the lists to read. Used by: recipes/reading.lua.
    toolbeltLists = { "TOOLBELT_V2_TOOLBELT", "TOOLBELT_V2_CATEGORY_ENUM", "TOOLBELT_V2_CATEGORY_GENERAL", "TOOLBELT_V2_CATEGORY_FISHING",
        "TOOLBELT_V2_CATEGORY_CRAFTING", "TOOLBELT_V2_CATEGORY_FARMING", "TOOLBELT_V2_CATEGORY_SLAYER", "TOOLBELT_V2_CATEGORY_INVENTION",
        "TOOLBELT_V2_CATEGORY_ARCHAEOLOGY", "TOOLBELT_PICKAXES", "TOOLBELT_HATCHETS", "TOOLBELT_MATTOCKS" },

    -- Where an item is made (the "Made at:" rows). The game's smithing screen (forge and anvil) and smelting screen (furnace) each keep the
    -- products they make: the rows filed under each metal in SMITHING_MATERIAL_TO_ITEM_DBROW and SMELTING_MATERIAL_TO_ITEM_DBROW (read in
    -- recipes/reading.lua), plus these plain lists of items. The NAME of the station is not in the game's data (the survey found the
    -- furnaces, forges and anvils only as scenery with no settings): that part is a hand-written fact, see playerFacts.stations below.
    -- Nothing here is a fact about the game: these are only the names of the lists to read. Used by: recipes/reading.lua.
    stationLists = {
        smithed = { "SMITHING_ID_TO_OBJ" },                                        -- every item the smithing screen can make
        smelted = { "SMELTING_MASTERWORK_TABLE", "SMITHING_BAR_SMELTING_SPECIAL_TABLE" }, -- the bars the furnace makes in tiers / specially
    },

    -- The benches' own lists (found by the surveys benches / benchtables): what the game keeps per bench. Key = the bench
    -- (names and pictures: playerFacts.stations.benches), value = the lists to read; a list inside a list is read too, and every item under
    -- them is made at that bench. SPINNING_TABLE_TYPES holds the Crafting and the Fletching spinning lists; the pottery moulds are made at the
    -- wheel and the pots in the FIRE table are fired (the oven); the three FLETCHING_MASTERWORK_CRAFTING_* lists are the masterwork bow's parts.
    -- Used by: recipes/stations.lua (Recipes.benchTables).
    benchLists = {
        sawmill   = { "CONSTRUCTION_HOUSING_SAWMILL_SIMPLE_LOGS_TO_PLANKS", "PLAYER_FORT_SAWMILL_LOGS_TO_PLANKS" },
        spinning  = { "SPINNING_TABLE_TYPES" },
        -- (from the benchrecipes survey: every skill has a urn list in three steps - MOULD (unfired, at the wheel), FIRE (fired, at the oven),
        -- RUNE / TELE / GEM (made in the inventory, so no bench); the clay ring is moulded; a list that does not exist is simply skipped)
        pottery   = { "CRAFTING_POTTERY_MOULD_TABLE", "CRAFTING_CLAYRING_TABLE",
                      "CRAFTING_COOKING_URN_MOULD_TABLE", "CRAFTING_FISHING_URN_MOULD_TABLE", "CRAFTING_MINING_URN_MOULD_TABLE", "CRAFTING_PRAYER_URN_MOULD_TABLE",
                      "CRAFTING_SMITHING_URN_MOULD_TABLE", "CRAFTING_WOODCUTTING_URN_MOULD_TABLE", "CRAFTING_DIVINATION_URN_MOULD_TABLE",
                      "CRAFTING_FARMING_URN_MOULD_TABLE", "CRAFTING_HUNTER_URN_MOULD_TABLE", "CRAFTING_RUNECRAFTING_URN_MOULD_TABLE" },
        oven      = { "CRAFTING_POTTERY_FIRE_TABLE",
                      "CRAFTING_COOKING_URN_FIRE_TABLE", "CRAFTING_FISHING_URN_FIRE_TABLE", "CRAFTING_MINING_URN_FIRE_TABLE", "CRAFTING_PRAYER_URN_FIRE_TABLE",
                      "CRAFTING_SMITHING_URN_FIRE_TABLE", "CRAFTING_WOODCUTTING_URN_FIRE_TABLE", "CRAFTING_DIVINATION_URN_FIRE_TABLE",
                      "CRAFTING_FARMING_URN_FIRE_TABLE", "CRAFTING_HUNTER_URN_FIRE_TABLE", "CRAFTING_RUNECRAFTING_URN_FIRE_TABLE" },
        fletchbench = { "FLETCHING_MASTERWORK_CRAFTING_LIMBS", "FLETCHING_MASTERWORK_CRAFTING_GRIP", "FLETCHING_MASTERWORK_CRAFTING_STRING",
                        "FLETCHING_ETERNAL_TABLE" }, -- (the eternal staves, wands and orbs: the survey of 3.0.67)
        -- the loom (found by the survey benchrecipes, LOOM_TABLES 7042 with LOOM_TABLE_NAMES 7043, CRAFTING_WEAVE_TABLE 7044 (9 entries,
        -- among them the Strip of cloth, the Strip of black cloth, the Empty sack and the Basket) and CRAFTING_SEAWEED_NET_TABLE 6971 (the
        -- Empty seaweed net))
        loom      = { "LOOM_TABLES", "CRAFTING_WEAVE_TABLE", "CRAFTING_SEAWEED_NET_TABLE" },
        -- (3.0.68: found by the survey of 3.0.67, which looked for the items with no "Made at" in every list of the game; the stations were
        -- agreed by the developer, 2026-11-07. The furniture and the Dungeoneering Summoning items are in data rows instead: benchRows below.)
        dunganvil    = { "RAND_SMITHING_T1_TABLE", "RAND_SMITHING_T2_TABLE", "RAND_SMITHING_T3_TABLE", "RAND_SMITHING_T4_TABLE", "RAND_SMITHING_T5_TABLE",
                         "RAND_SMITHING_T6_TABLE", "RAND_SMITHING_T7_TABLE", "RAND_SMITHING_T8_TABLE", "RAND_SMITHING_T9_TABLE", "RAND_SMITHING_T10_TABLE" },
        dungfurnace  = { "RAND_SMELTING_TABLE" },
        dungspinning = { "RAND_CLOTH_SPIN_TABLE" },
        dungaltar    = { "RAND_RUNECRAFTING_RUNES_TABLE", "RAND_RUNECRAFTING_STAVES_TABLE", "RAND_RUNECRAFTING_NECRO_RUNES_TABLE" },
        pedestal     = { "RAND_NECROMANCY_MATERIAL_TABLE_LIST" },
        portbench    = { "POP_RUNECRAFT_TRADEABLE", "POP_RUNECRAFT_UNTRADEABLE", "POP_CRAFTING_TRADEABLE", "POP_CRAFTING_UNTRADEABLE" },
        portanvil    = { "POP_SMITHING_TRADEABLE", "POP_SMITHING_UNTRADEABLE" },
        scrimshaw    = { "POP_SCRIMSHAW_TRADEABLE_TABLE", "POP_SCRIMSHAW_UNTRADEABLE_TABLE" },
        soulforge    = { "NECRO_MAKEX_EQUIPMENT_UPGRADES_T20", "NECRO_MAKEX_EQUIPMENT_UPGRADES_T30", "NECRO_MAKEX_EQUIPMENT_UPGRADES_T40",
                         "NECRO_MAKEX_EQUIPMENT_UPGRADES_T50", "NECRO_MAKEX_EQUIPMENT_UPGRADES_T60", "NECRO_MAKEX_EQUIPMENT_UPGRADES_T70_POWER",
                         "NECRO_MAKEX_EQUIPMENT_UPGRADES_T70_TANK", "NECRO_MAKEX_EQUIPMENT_UPGRADES_T80_POWER", "NECRO_MAKEX_EQUIPMENT_UPGRADES_T80_TANK",
                         "NECRO_MAKEX_EQUIPMENT_UPGRADES_T90_POWER", "NECRO_MAKEX_EQUIPMENT_UPGRADES_T90_TANK" },
        tailoring    = { "CRAFTING_ARMOUR_ID_TO_OBJ" },
        lectern      = { "MAGIC_TABLET_TABLE", "DINO_AGILITY_CODEX_TABLE" }, -- (the second: the codices of the lectern on Anachronia)
        singingbowl  = { "CRYSTAL_SINGING_WEAPON_TABLE", "CRYSTAL_SINGING_WEAPON_ATTUNED_TABLE", "CRYSTAL_SINGING_TOOL_TABLE",
                         "CRYSTAL_SINGING_ARMOUR_TABLE", "CRYSTAL_SINGING_ARMOUR_ATTUNED_TABLE" },
        brewery      = { "BREWING_TABLE" },
        ritualsite   = { "NECRO_RITUAL_MAKEX_GLYPHS_FOUNDATIONAL", "NECRO_RITUAL_MAKEX_GLYPHS_ALTERATION" },
        elemental    = { "ELEM_SMITHING_ELEMENTAL_TABLE", "ELEM_SMITHING_BODY_TABLE", "ELEM_SMITHING_MIND_TABLE", "ELEM_SMITHING_CHAOS_TABLE",
                         "ELEM_SMITHING_COSMIC_TABLE" },
        dragonkin    = { "SMITHING_ESSENCE_ITEMS" },
        tanner       = { "CRAFTING_TANNING_TABLE", "CRAFTING_TANNING_CANIFIS_TABLE", "CRAFTING_TANNING_WENDLEWICK_TABLE" },
        churn        = { "COOKING_CHURN_MILK_TABLE", "COOKING_CHURN_CREAM_TABLE", "COOKING_CHURN_BUTTER_TABLE" },
        cradle       = { "QUEST_ZAMORAK_MAKE_RUNES_TABLE" },
        -- (3.0.70: the small stations the survey of 3.0.68 found lists for; named only, no pictures - the developer, 2026-11-07)
        clockmaker   = { "CONSTRUCTION_CLOCKMAKERS_BENCH_1", "CONSTRUCTION_CLOCKMAKERS_BENCH_2", "CONSTRUCTION_CLOCKMAKERS_BENCH_3",
                         "CONSTRUCTION_CLOCKMAKERS_BENCH_4" },
        robustglass  = { "CRAFTING_ROBUST_GLASS_TABLE", "CRAFTING_CRYSTAL_GLASS_TABLE" },
        sandpit      = { "CRAFTING_SAND_TABLE" },
        compost      = { "FARMING_COMPOST_TYPES" },
        blessaltar   = { "HERBLORE_BLESSED_SAND_TABLE" },
        naturealtar  = { "MAKE_BLESSED_OBJECTS" },
        soupstation  = { "POP_SOUP_TABLE" },
        applebarrel  = { "BREWING_INGREDIENTS_TABLE" },
        stump        = { "WOODCUTTING_ARCTIC_LOGS_TABLE" },
        colossus     = { "WILD_ESSENCE_MINE_PROCESS_OBJS" },
        dungglyph    = { "RAND_NECROMANCY_GLYPH_TABLE_LIST" },
        elemfurnace  = { "ELEM_SMITHING_ELEM_BAR_TABLE" },
        doricanvil   = { "PNR_CANNON_TABLE", "PNR_GNOME_TABLE" },
        doricfurnace = { "PNR_BAR_SMELTING_TABLE" },
        eternaltree  = { "FLETCHING_MASTERWORK_INSTANT_ACTION_ETERNAL_TREE" },
        jadfirepit   = { "FIRMAKING_HARDEN_JARO_ROOTS_TABLE" },
        pigmachine   = { "SUMMONING_PIG_MENU" },
        airobelisk   = { "ENCHANT_AIR_ORB_TABLE" },
        waterobelisk = { "ENCHANT_WATER_ORB_TABLE" },
        earthobelisk = { "ENCHANT_EARTH_ORB_TABLE" },
        fireobelisk  = { "ENCHANT_FIRE_ORB_TABLE" },
        -- (3.0.93: found by the item check of 3.0.91 - the game's own lists; names as the game has them, pictures the developer's)
        drafting     = { "ARCH_STORMGUARD_WORKSHOP_DRAFTING_BENCH_TRADEABLE_TABLE" },
        trough       = { "POF_FOOD_TABLE_INSECTS" },
        jalarast     = { "MAKE_SPLITBARK_TABLE" },
        botanist     = { "HERBLORE_BOTANIST_BENCH_PREPARED_POTIONS" },
    },
    -- Every list whose name starts with one of these words is read too (3.0.93: the drafting bench's untradeable list, the trough's other
    -- foods, the botanist's other potions - their names are found in the game's own table of list names).
    -- 3.1.15 (the developer: "Read the names from the game"): these benches take the name the game gives its scenery - a Loc whose own
    -- (debug) name has all these words; the most common such name, as a bench can be in the game more than once. The name typed in
    -- playerFacts.stations.benches stays if the game has none. Used by: recipes/stations.lua (bench names).
    benchNamesFromGame = {
        drafting = { "DRAFTING", "BENCH" },
        botanist = { "BOTANIST", "BENCH" },
    },
    benchListPrefixes = {
        drafting = { "ARCH_STORMGUARD_WORKSHOP_DRAFTING_BENCH_" },
        trough   = { "POF_FOOD_TABLE_" },
        botanist = { "HERBLORE_BOTANIST_BENCH_" },
    },
    -- Lists whose KEYS are items as well as their values (both sides are read): the Summoning pouches and scrolls.
    benchKeyLists = {
        obelisk = { "LORE_POUCH_COUNT_ENUM" },
    },
    -- Stations kept in the game's data rows (read in the same pass as the furniture plans, recipes/guides.lua): key -> the start of the
    -- rows' names and the columns that hold the items made there. (CONSTRUCTION_HOUSE_...: column 5 is the furniture; RAND_LORE_...:
    -- the Dungeoneering pouches and scrolls in columns 6 and 7 - the survey of 3.0.67.)
    benchRows = {
        { key = "furniture", prefix = "CONSTRUCTION_HOUSE_", columns = { 5 } },
        { key = "obelisk",   prefix = "RAND_LORE_",          columns = { 6, 7 } },
    },
    -- Items an NPC makes from materials the game lists itself (3.0.69, the survey of 3.0.68). Patchy: the items on his four lists, each
    -- carrying its two materials in the settings PATCHY_ITEM_1 and PATCHY_ITEM_2. The fur shop: its lists say, for each item it makes,
    -- the fur (MATERIAL), how many (QUANTITY, 1 when the item is not on it) and a second material for some (MATERIAL2, one of it). The coins
    -- they charge are not in these lists. The words and pictures are the developer's (2026-11-07). Used by: recipes/player.lua.
    npcMade = {
        patchy  = { lists = { "PATCHY_CATEGORY_1", "PATCHY_CATEGORY_2", "PATCHY_CATEGORY_3", "PATCHY_CATEGORY_4" }, prefix = "PATCHY_ITEM_",
                    line = "Made by: Patchy", sprite = "patchy" },
        furshop = { material = "HUNTING_CUSTOMFURSHOP_MATERIAL", material2 = "HUNTING_CUSTOMFURSHOP_MATERIAL2",
                    quantity = "HUNTING_CUSTOMFURSHOP_QUANTITY", line = "Made at: Custom Fur Clothing", sprite = "furshop" },
    },

    -- Little pictures beside a crafting station's name ("Made at: Furnace"). The game's world map has an icon for most stations (config.MapElement:
    -- each has a configName and a spriteID); the survey stationicons (5,843 map elements) found these. Key = the word the recipe
    -- rows use (recipes/stations.lua, player.lua), value = the map element's configName; the plugin finds its spriteID in the game (it
    -- scans config.MapElement once, in the background), so nothing here is a sprite number. The RS3 pictures are used, not the LEGACY ones.
    -- No icon exists in the map data for the Forge (only Archaeology warforge sites) or for Aggie (her element has spriteID -1). The developer
    -- asked (2026-10-28) for the Forge to use the furnace's picture (its rows say sprite = "furnace"); Aggie's row stays text. Found but
    -- not used yet (no recipe row names these stations): POTTERY_ICON_RS3, LOOM_ICON_RS3, SPINNINGWHEEL_ICON_RS3, POH_SAWMILL_ICON_RS3,
    -- FLETCHING_WORKBENCH_ICON_RS3, COOKING_STORE_ICON_RS3 (a shop). Add a line here and give the row sprite = "<key>" to use one. Used by:
    -- recipes/stations.lua (Recipes.stationSprite), ui/details.lua.
    -- The game's own record of the imbuing steps of the Eternal magic staffs, wands and orbs (found by a survey): a list of the
    -- weapons (key -> item) and, on each item, the key of the next stage and the progress needed to reach it. Used by recipes/player.lua.
    imbuing = {
        list = "RUNECRAFTING_WEAPON_ID_TO_OBJ",
        nextStage = "RUNECRAFTING_WEAPON_IMBUING_NEXT_STAGE",
        progress = "RUNECRAFTING_WEAPON_IMBUING_PROGRESS_REQUIRED",
        -- 1 on a tier that essence can take to the next one (the saturated tier has no 1: its next step is a sacrifice)
        imbuable = "RUNECRAFTING_WEAPON_IMBUING_IMBUABLE",
    },
    -- Pictures the developer picked (sprite numbers, 2026-11-07): these win over the map icons below.
    stationSpriteNumbers = {
        furniture = 4590, obelisk = 22572, dunganvil = 22548, dungfurnace = 22552, dungspinning = 22556, dungaltar = 22571, pedestal = 35894,
        portbench = 16387, portanvil = 22548, scrimshaw = 16387, soulforge = 22552, tailoring = 22489, lectern = 35014, singingbowl = 26315,
        brewery = 22536, ritualsite = 35894, elemental = 22548, dragonkin = 22548, tanner = 22550, churn = 22549, cradle = 12638,
        drafting = 22489, trough = 32242, jalarast = 13099, botanist = 22483, -- (3.0.93, the developer)
        patchy = 5780, furshop = 22528, fletching = 34630,
        rift = 6896, -- (the energy rift, on the energies' "Converted at" rows: the developer, 3.1.41)
        shop = 22500, src_drop = 11414, -- (3.1.15, the developer: the "Sold at" rows and the "Dropped by" rows)
        src_clue = 35233, -- (3.1.16, the developer: the Treasure Trail reward rows)
    },
    stationIcons = {
        furnace = "FURNACE_ICON_RS3",
        anvil   = "ANVIL_ICON_RS3",
        altar   = "RUNECRAFTING_ALTAR_ICON_RS3", -- every rune altar's map icon is this one picture
        range   = "COOKING_TRAINING_ICON_RS3",   -- the world map's Cooking icon (map element 4166, spriteID 22480): used only when the list
                                                 -- below cannot be read
        inventor = "INVENTION_WORKBENCH_ICON_RS3", -- the world map's Inventor's workbench icon (found by the survey stationicons)
        -- Found by the same survey, drawn once a recipe row names the station (the rules for these wait for the survey "benches"):
        pottery   = "POTTERY_ICON_RS3",
        loom      = "LOOM_ICON_RS3",
        spinning  = "SPINNINGWHEEL_ICON_RS3",
        sawmill   = "POH_SAWMILL_ICON_RS3",       -- the woodworking bench shares this picture (from the developer, 2026-10-29)
        fletching = "FLETCHING_WORKBENCH_ICON_RS3",
        water   = "WATER_SOURCE_ICON_RS3",       -- the world map's water source icon (map element 2438, spriteID 22567): the game's own
                                                 -- Sink scenery points at
                                                 -- the element WATER_SOURCE_ICON (595), of which this is the RS3 picture (the survey "water")
    },
    -- Pictures the game lists itself: the world map key's sprite lookups (found by the survey cookingtables). Key = the same word as
    -- above, value = the list's name: WORLDMAP_KEY_COOKINGRANGE_SPRITE_LOOKUP holds two pictures, 22551 (the current one) then 1323 (the
    -- old one), the same order as the cookery shop's list (22525, 1320), whose first picture is the map element COOKING_STORE_ICON_RS3's.
    -- The first entry is used. Used by: recipes/stations.lua (Recipes.stationIconStep).
    stationIconLists = {
        range = "WORLDMAP_KEY_COOKINGRANGE_SPRITE_LOOKUP",
        ritual = "WORLDMAP_KEY_RITUAL_SITE_SPRITE_LOOKUP",                  -- the ritual site (found by a look at the world map key)
        archaeologist = "WORLDMAP_KEY_ARCHAEOLOGY_RESTORATION_SPRITE_LOOKUP", -- the Archaeology restoration (the workbench)
        -- the gathering skills' map icons, beside the rows of the Source tab (recipes/gather.lua; names found by the survey gather2)
        src_mining = "WORLDMAP_KEY_MININGSITE_SPRITE_LOOKUP",
        src_woodcutting = "WORLDMAP_KEY_WOODCUTTINGSTUMP_SPRITE_LOOKUP",
        src_fishing = "WORLDMAP_KEY_FISHINGSPOT_SPRITE_LOOKUP",
        src_farming = "WORLDMAP_KEY_FARMINGPATCH_SPRITE_LOOKUP",
        src_hunter = "WORLDMAP_KEY_HUNTER_RESOURCE_SPRITE_LOOKUP",
        src_divination = "WORLDMAP_KEY_WISPSITE_SPRITE_LOOKUP",
        src_archaeology = "WORLDMAP_KEY_ARCHAEOLOGY_EXCAVATION_SITE_SPRITE_LOOKUP",
    },
    -- The game's cooking lists (found by the survey cookingtables): COOKING_OVEN_TABLES is a list of lists, one per kind of food,
    -- of what a range cooks; COOKING_FIRE_TABLES the same for a bonfire (its fish list is the oven's own). RAND_OVEN_COOKING_TABLES
    -- (cave fish and the cave potato, the Daemonheim foods) is another oven list. A food in an oven list only is "Range"; in a fire list too,
    -- "Range or Bonfire". The mixing, churning and drinks lists are made in the inventory and are not read.
    -- Used by: recipes/stations.lua (Recipes.cookingTables).
    cookingLists = {
        oven = { "COOKING_OVEN_TABLES", "RAND_OVEN_COOKING_TABLES" },
        fire = { "COOKING_FIRE_TABLES" },
    },

    -- The Grand Exchange's own list of item sets (the survey "where": list 1087, 183 entries, number -> the set's item). Used by:
    -- recipes/player.lua (to know which items are sets; what to say about them is a hand-written fact, playerFacts.sets).
    exchangeSetLists = { "EXCHANGE_ITEM_SETS" },

    -- Every skill has a guide (the lists SKILLGUIDE_RUNECRAFT, SKILLGUIDE_HERBLORE ...): one entry per thing the skill
    -- makes or does, with a level, an item and sometimes a line of text. For a few dozen items (the runes, the weapon
    -- poisons, the Perfect juju potions, the wines ...) the guide is the ONLY place that gives a level or says what goes
    -- into them. These are the guides of the skills that make things. Used by: recipes/guides.lua.
    guideSkills = { "SMITHING", "HERBLORE", "COOKING", "CRAFTING", "FLETCHING", "RUNECRAFT", "SUMMONING", "CONSTRUCTION" },

    -- The names of every skill as the skill guides spell them (SKILLGUIDE_<name>). Each guide knows which skill number
    -- it belongs to, which is how the plugin learns the game's numbering. Used by: recipes/reading.lua.
    guideLookupSkills = { "SMITHING", "CRAFTING", "COOKING", "FLETCHING", "HERBLORE", "FIREMAKING", "MINING",
        "WOODCUTTING", "FISHING", "CONSTRUCTION", "RUNECRAFTING", "PRAYER", "MAGIC", "RANGED", "SUMMONING",
        "FARMING", "HUNTER", "DIVINATION", "INVENTION", "ARCHAEOLOGY", "NECROMANCY", "THIEVING", "SLAYER",
        "AGILITY", "DUNGEONEERING", "ATTACK", "STRENGTH", "DEFENCE", "CONSTITUTION" },

    -- The game's own order of its skills, used to fill in any number the guides did not mention (checked against the
    -- 22 numbers the guides gave; the survey then showed that 12 is Runecrafting). Used by: recipes/reading.lua.
    skillOrder = { "ATTACK", "STRENGTH", "RANGED", "MAGIC", "DEFENCE", "CONSTITUTION", "PRAYER", "AGILITY",
        "HERBLORE", "THIEVING", "CRAFTING", "RUNECRAFTING", "MINING", "SMITHING", "FISHING", "COOKING",
        "FIREMAKING", "WOODCUTTING", "FLETCHING", "SLAYER", "FARMING", "CONSTRUCTION", "HUNTER", "SUMMONING",
        "DUNGEONEERING", "DIVINATION", "INVENTION", "ARCHAEOLOGY", "NECROMANCY" },

    ------------------------------------------------------------------------------------------------
    -- 3. FACTS THE GAME DOES NOT RECORD
    ------------------------------------------------------------------------------------------------

    -- Items whose NAME says what they are made from. If an item's name (lowercase) starts with "prefix", the item it is
    -- made from is the item whose name is "fromPrefix" followed by the rest of the name.
    --   prefix      the start of the item's name
    --   fromPrefix  the start of the other item's name ("" = the rest of the name on its own)
    --   label/note  the words shown with it
    --   onlyIfNothingElse = true: used only when the game links the item to nothing at all
    -- Used by: recipes/manual.lua.
    nameRules = {
        -- Custom-fit armour has no recipe of its own and the game records no link to the piece it is fitted to, so the
        -- trimmed piece is found by name ("Custom-fit X" is made from "X").
        { prefix = "custom-fit ", fromPrefix = "", label = "Custom-fitted from:" },
        -- Masterwork melee armour: "Unfinished riveted X" comes after "Partially riveted X" (the names show the order).
        { prefix = "unfinished riveted masterwork melee ", fromPrefix = "partially riveted masterwork melee ",
          label = "Made from:", onlyIfNothingElse = true },
    },

    -- Masterwork magic and ranged armour is made in steps - a draft, then an unfinished piece, then the finished piece. The game links
    -- the finished piece to both of the others (CRAFTING_ARMOUR_DRAFT_OBJECT and CRAFTING_ARMOUR_UPGRADE_OBJECT, see linkRules above)
    -- and the plugin reads those links the other way round, so the kinds, the pieces and the order all come from the game. Only the
    -- words shown are written here (each line is cut to fit the info box). Used by: recipes/manual.lua.
    tailoring = {
        draftText      = { "A masterwork draft. The game", "links these finished pieces", "to it:" },
        unfinishedThen = { "Finished into the piece:" },
    },

    -- Geodes (the geode check of 3.1.39). The game's Mining guide names the rocks that give geodes - "Higher chance at finding geodes when
    -- mining copper and tin rocks", each entry free-to-play or members - and its milestone "Geodes when mining" says: "Level 50
    -- free-to-play core mining nodes and below yield sedimentary geodes. Member core mining nodes yield igneous geodes", and rarely
    -- metamorphic ones (the game's setting "Receiving igneous geodes when mining: if turned off this will also stop giving metamorphic
    -- geodes"). The geodes are found by their debug names. Which rocks the guide's "primal rocks" are the game does not say: that list is
    -- from the RuneScape Wiki (2026-11-09). Used by: recipes/gather.lua (addGeodes).
    geodes = {
        f2p     = { "MINING_GEODE_F2P" },                         -- Sedimentary geode
        members = { "MINING_GEODE_MEMBERS", "MINING_GEODE_RARE" }, -- Igneous geode, Metamorphic geode
        guideName = "^higher chance at finding geodes when mining (.-) rocks$", -- (the guide entry's name, in lower case)
        primal = { "novite", "bathus", "marmaros", "kratonium", "fractite", "zephyrium", "argonite", "katagon", "gorgonite", "promethium" },
    },

    ------------------------------------------------------------------------------------------------
    -- 4. FACTS TYPED IN BY THE DEVELOPER
    ------------------------------------------------------------------------------------------------

    -- Facts the developer checked in the game and typed in, for things the game's own data does not say
    -- (as far as the surveys could tell). They are NOT from the wiki and NOT from the game; each is tagged source = "player" with the
    -- day it was said, so they can all be found (search this file for  source = "player"), checked again and replaced by something the
    -- game says as soon as a way to read it is found. They show on the Recipe tab like any other recipe (users see no difference), and a
    -- recipe built from one carries  fromPlayer = "<name of the fact>"  in its data. USE_PLAYER_FACTS (settings.lua) false switches
    -- every one of them off. The game's own words always come first: a fact is used only for an item that has nothing from the game
    -- that says how it is got. The code that uses this section: recipes/player.lua.
    playerFacts = {
        -- A creature's binding contract - "Binding contract (ripper demon)" - is got by defeating that creature with a plain Binding contract
        -- in the backpack (told by the developer, 2026-11-07). It is not made at the Summoning obelisk (the plain contract is). Shown in place
        -- of anything else for these items; the creature is the part of the item's name in brackets.
        bindingContracts = { source = "player", said = "2026-11-07", prefix = "binding contract (", material = "Binding contract",
                             line = "Defeat %s with a Binding contract in your backpack." },
        -- A god's crest turns a piece of Dormant anima core armour into that god's piece, in the backpack: "Crest of Zaros" + "Dormant
        -- anima core helm" = "Anima core helm of Zaros" (told by the developer, 2026-11-08; the crest check of 3.0.99 found nothing in the
        -- game's data that says so - the crests and the dormant pieces are only listed as boss drops). All three items are found by their
        -- names in the game; of two items with the crest's name, the tradeable one (the other is a cosmetic from Solomon's store).
        animaCrests = { source = "player", said = "2026-11-08", pattern = "^anima core (%a+) of (%a+)$", dormant = "dormant anima core %s",
                        crest = "crest of %s", line = "Use the crest on the dormant piece in your backpack." },
        -- Which dig site a dig spot (a hotspot: "Centurion remains") or a damaged artefact that has no dig spot ("The Book of Blood
        -- (damaged)") belongs to, where the
        -- game's data does not say. The start-up console lists the ones still missing ("DIG SITE MISSING ..."), already written as lines to
        -- copy here. A dig site is
        -- written as the game names it ("Kharid-et", "Everlight", "Infernal Source", "Stormguard Citadel", "Warforge", "Senntisten",
        -- "Daemonheim", "Orthen",
        -- "Moonrise"), or a list of them: { "Kharid-et", "Everlight" }. Every item the dig spot gives then shows that dig site's picture,
        -- and "@kharid-et" finds it.
        -- Used by: recipes/gather.lua.
        digSites = {
            source = "player", said = "2026-10-29",
            links = {
                -- ["Centurion remains"] = "Kharid-et",
            },
            -- Quest items: they are not found at a dig site, so they are not listed as "DIG SITE MISSING" (the developer, 2026-10-29). Dig spots and
            -- damaged artefacts, by the name the console prints.
            quest = {
                "Standing stone debris", "Runic debris", "Orthen rubble", "Crystalised rubble", "Centurion remains",
                "Golden scarab (damaged)", "Damaged soul beacon", "Centurion's dress sword (damaged)",
                "Dragonkin remains", "The Book of Blood (damaged)", "The Book of Ice (damaged)", "The Book of Shadow (damaged)", "The Book of Smoke (damaged)",
            },
        },
        -- Gathered items that only the game's skill guides know (no table says where): what the developer said. ignore = no source wanted;
        -- places = { { skill, place }, ... } as sources (the first entry gets the guide's level; skill in capitals: "WOODCUTTING", "FARMING" ...);
        -- drops = a plain "Monster drop" row. Names are the item's name as the console prints them. Used by: recipes/gather.lua.
        gathered = {
            source = "player", said = "2026-10-30",
            -- minigame items; the wooden knot can be ignored too (developer, 2026-10-30)
            ignore = { "Thatch spar (light)", "Thatch spar (medium)", "Thatch spar (dense)", "Wooden knot" },
            places = {
                ["Eucalyptus logs"] = { { "WOODCUTTING", "Eucalyptus tree" } },        -- "from trees in game of the same name"
                -- "gotten from farming, but just list them as gotten from their respective trees in a farming tree patch"
                ["Straight root"] = { { "WOODCUTTING", "Straight root tree" }, { "FARMING", "Tree patch" } },
                -- Curly root is not got from a farming tree patch: it is obtained from curly jade roots (developer, 2026-10-30)
                ["Curly root"] = { { "WOODCUTTING", "Curly jade roots" } },
            },
            -- where an item is found, in words (shown under its sources): petrified roots come from the same location as bark and logs
            -- (developer, 2026-10-30); the game's skill guide says "Fenmoor on Havenhythe" for the bark and the logs
            where = { ["Petrified roots"] = { "Fenmoor on Havenhythe" } },
            drops = { "Whip vine" },                                                    -- "a mob drop"
            dropText = "Monster drop",
        },
        -- "the runes only require Pure or Impure essence and are used at rune altars; the altar they are used at corresponds to their
        -- names, i.e. fire runes come from the fire rune altar, soul runes come from the soul rune altar"
        -- An item counts as a rune when it is in the Runecrafting skill guide (the game's own list) and its name is "<word> rune" where
        -- the game has a rune altar named "<Word> Altar" (the data rows RUNECRAFTING_ALTAR_*; the altar's name is read from the game).
        runes = {
            source = "player", said = "2026-10-26",
            suffix = " rune",                              -- the end of a rune's name
            altarSuffix = " altar",                        -- the end of an altar's name, in lower case
            madeAt = "Made at: ",                          -- the row that names the altar
            essences = { "Pure essence", "Rune essence" },  -- the items every other rune is made from (found by these names)
            essenceLabel = "Materials (any one of):",
            -- "impure essence is only used for bone, spirit, flesh and miasma runes. Pure essence and rune essence are used for all other
            -- runes" (2026-10-28): these four runes (the word before " rune") are made from the impure essence alone
            impureRunes = { bone = true, spirit = true, flesh = true, miasma = true },
            impureEssences = { "Impure essence" },
        },
        -- Energy (the developer, 2026-11-09, checked on the RuneScape Wiki): harvesting a wisp gives its energy as well as its memories (the
        -- Source tab: the same wisps as the memories), and a memory is converted into the energy of the same kind at an energy rift
        -- ("Pale memory" -> "Pale energy"; an enriched memory too). Used by: recipes/player.lua, recipes/gather.lua (addEnergies).
        energy = {
            source = "player", said = "2026-11-09",
            suffix = " energy", memorySuffix = " memory", enrichedPrefix = "enriched ",
            -- (several items share each name: the real ones' debug names, lower case - "DIV_MEMORY12", "DIV_MEMORY_SUPER4", EDIV_ for Elder -
            -- the developer, 2026-11-09; RAND_DIVINATION_... are Dungeoneering's and are left out)
            memoryDebug = "^e?div_memory%d+$", enrichedDebug = "^e?div_memory_super%d+$", energyDebug = "^e?div_energy",
            madeAt = "Converted at: an energy rift",
            station = "energy-rift", -- (the row's search word, as a crafting station's: a click on it lists every energy made at a rift)
            memoryLabel = "Materials (any one of):",
        },
        -- The Eternal magic tiers are imbued with pure essence or rune essence at any Runecrafting altar (developer, 2026-10-28).
        -- Every item named "Eternal magic <staff, wand or orb> (<tier>)" shows this (the game's data does not say it). The tier an item is
        -- imbued from, and the progress that takes, are the game's own: see `imbuing` above (recipes/player.lua reads them).
        imbued = {
            source = "player", said = "2026-10-28",
            prefix = "eternal magic ", kinds = { "staff", "wand", "orb" },
            madeAt = "Made at: Any Runecrafting altar",
            essences = { "Pure essence", "Rune essence" },
            essenceLabel = "Materials (any one of):",
            -- "its the progress divided by 12" (2026-10-28), then corrected the same day with the wiki's tables for the orb / wand (essence per tier:
            -- meagre 50, weak 50, lesser 100, moderate 150, greater 200, saturated 250) and the staff (60, 60, 120, 180, 240, 300): "the
            -- same across the wand imbuing processes as well, the staff is slightly more". The game's own PROGRESS_REQUIRED of each tier
            -- (orb / wand 500, 500, 1000, 1500, 2000, 2500; staff 600, 600, 1200, 1800, 2400, 3000) divided by 10 gives every one of those
            -- numbers, so one essence is 10 progress.
            -- The progress is that of the tier being made (what it takes to reach it), not that of the tier before it.
            progressPerEssence = 10,
        },
        -- Items such as soft clay are made at any water source in the game, such as fountains and wells (developer, 2026-10-28).
        -- A recipe that offers two or more of these containers as a choice (soft clay: bucket, jug or bowl of water) shows one row instead,
        -- "Water source" (developer, 2026-10-28: the game's water picture is shown instead of spelling out "(fountain, well)"); the game's other
        -- choices in the same recipe stay. sprite = the key of the picture (stationIcons below: the world map's water source icon, drawn beside
        -- the words like a crafting station's).
        -- Used by: recipes/parse.lua (multiMaterial).
        water = {
            source = "player", said = "2026-10-28",
            containers = { "Bucket of water", "Jug of water", "Bowl of water" },
            label = "Water source",
            sprite = "water",
            minimum = 2,
            -- More items are made with water sources, such as vials of water, buckets and waterskins (developer, 2026-10-29).
            -- The containers themselves are made at a water source too, from the empty container: their recipe shows "Made at: Water
            -- source" (the water picture, a click searches @water) and the empty container as the material. byName: the filled item's name
            -- (lower case) -> the names the empty container may have, the first one the item list has is used (the sinks survey, confirmed
            -- Bucket / Empty bucket, Jug / Empty jug, Vial / Empty vial, Bowl, Waterskin (0); there is no Empty bowl or Empty waterskin).
            -- An item for which the game gives a recipe or words of its own keeps those: this is only for the ones with none. WHICH items
            -- are filled at a water source is the game's own list
            -- WATERSOURCE_FILL_TABLE (read by Recipes.waterFillTable); byName is only for the empty containers and for names that list lacks.
            -- Used by: recipes/player.lua (Recipes.playerFact for the recipe, Recipes.playerWaterUse for the Uses lists, Recipes.waterReport).
            filled = {
                madeAt = "Made at: ", materialsLabel = "Materials:",
                byName = {
                    ["vial of water"]   = { "Vial", "Empty vial" },
                    ["bucket of water"] = { "Bucket", "Empty bucket" },
                    ["jug of water"]    = { "Jug", "Empty jug" },
                    ["bowl of water"]   = { "Bowl", "Empty bowl" },
                    ["waterskin (4)"]   = { "Waterskin (0)", "Empty waterskin" },
                },
            },
        },
        -- The Glorious bar is made from a partially folded alloy bar at an anvil (developer, 2026-10-29).
        -- The game's data holds no recipe for the Glorious bar (survey sources/bars, the item has no RECIPE_ setting, and the Partially
        -- folded alloy bar's data has no word on folding but its name), so the recipe is hand-written: "Made at: Anvil", then the bar to fold and
        -- how many times. byName: the item's name (lower case) -> { from = the name of the item that is folded, folds = how many times }.
        -- Corrected by the developer, 2026-10-29: the bar is not used on the anvil, it is hammered at the anvil to gain progress; the 1001
        -- is the progress
        -- the game shows ("Folding progress 60/1001" at 60 XP in). So: useLabel (the line above the bar) and progressLabel (the line after
        -- it, %s = 1,001).
        -- Used by: recipes/player.lua (Recipes.playerFact for the recipe, Recipes.playerFoldUse for the Uses lists).
        folding = {
            source = "player", said = "2026-10-29",
            madeAt = "Made at: ", station = "Anvil", sprite = "anvil",
            useLabel = "Hammer it at the anvil for progress:",
            progressLabel = "Folding progress needed: %s",
            byName = {
                ["glorious bar"] = { from = "Partially folded alloy bar", folds = 1001 },
            },
        },
        -- Vial of water 17492 is used only to make Dungeoneering potions; vial of water 227 cannot make the Dungeoneering ones (developer,
        -- 2026-10-29). The Uses lists are filed under the ingredient's NAME (so a noted or copied item finds the list), which put the
        -- Dungeoneering potions on the ordinary Vial of water and every potion on the Dungeoneering one. byName: the item's name (lower
        -- case) -> the item numbers that have a Uses list of their own: it holds only the recipes that name exactly that number, and every
        -- other item of that name shows the rest.
        -- Used by: recipes/player.lua (Recipes.usesOwn), recipes/uses.lua (usedAdd, usedList; the console says how many each list holds).
        usesByNumber = {
            source = "player", said = "2026-10-29",
            byName = {
                ["vial of water"] = { 17492 },
            },
        },
        -- "all the moulds are bought; the halberds are bought"
        -- A mould counts when it is a tool kept on the toolbelt (the game's own list) whose name ends in "mould" AND the game gives no
        -- words of its own on how it is got (TOOLBELT_UNLOCK_INFO says so for some: those words are shown instead).
        -- A halberd counts when its name is one of these (lower case).
        bought = {
            source = "player", said = "2026-10-26",
            mouldSuffix = " mould",
            halberds = { "bronze halberd", "iron halberd", "steel halberd", "black halberd", "mithril halberd", "adamant halberd", "rune halberd" },
            text = "Bought from a shop.",
        },
        -- "armour sets are 'crafted' at the Grand Exchange: you need all the pieces of the set to 'Exchange' it for the set box"
        -- An item counts when its name has one of these words in it and the game marks it as sold on the Grand Exchange. (The pieces of a
        -- set are not listed: nothing in the game's data has been found that says which they are.)
        sets = {
            source = "player", said = "2026-10-26",
            words = { "armour set", "armor set" },
            text = "Exchange every piece of the set for it at the Grand Exchange.",
        },
        -- "the rune bar is made at the furnace, the rune chest plate is made at the forge but is finished at the anvil. When the item comes
        -- out of the forge it is labeled as unfinished smithing item but has data on what's being crafted, the current heat, the current
        -- progress and the experience left in the item."
        -- Which items are made where comes from the game's own lists (stationLists above and the rows of the smithing and smelting
        -- screens); only the names of the stations, and what the forge hands over, are hand-written. An item the smelting lists make, or a bar
        -- (a metal the smithing lists file products under) that needs Smithing, is made at the furnace; an item the smithing screen makes is
        -- made at the forge and finished at the anvil. The code that uses this: recipes/stations.lua.
        -- "usually all potions, flasks and salves in the game are named something like Prayer potion (3); the (3) stands for the amount of
        -- doses left in a potion, so all the items missing recipes for potions should just point back to their 3 dose versions; flasks are
        -- just made by using a (1)(2)(3) or (4) dose potion on a potion flask; salves are made at the 6 dose level but also have levels
        -- (1)-(6): these recipes should just point back to the flask that has a recipe already that corresponds to its name"
        -- Which level of a family is made is read from the game (the level that has a recipe); the levels below are only used when more
        -- than one level has a recipe. A flask / salve is told by the end of its name. Used by: recipes/doses.lua.
        -- What the ritual selection window shows for a ritual (read in the game by the developer, who opened the window and clicked each
        -- ritual; the survey ritualui printed what the window said): how long the ritual site lasts ("Durability"), how many light sources it
        -- needs, and every glyph with how many (the game's ritual data names only the first glyph); { glyph name, how many, glyph item number }.
-- site = the one place the ritual can be done, when the window says so. All 14 rituals of the window are here (the window lists 14).
-- Key: the ritual's name, lower case.
        -- Used by: recipes/player.lua (Recipes.ritualFacts), shown by recipes/parse.lua. A ritual not listed keeps the old rows.
        rituals = {
            source = "player", said = "2026-10-27",
            byName = {
                ["lesser communion"] = { durability = 1, light = 4, glyphs = { { "Elemental I", 1, 55638 }, { "Commune I", 2, 55644 } }, site = "City of Um" },
                ["greater communion"] = { durability = 1, light = 6, glyphs = { { "Elemental II", 2, 55639 }, { "Commune I", 1, 55644 }, { "Commune II", 2, 55645 } }, site = "City of Um" },
                ["powerful communion"] = { durability = 1, light = 10, glyphs = { { "Elemental III", 4, 55640 }, { "Commune II", 2, 55645 }, { "Commune III", 2, 55646 } }, site = "City of Um" },
                ["lesser necroplasm"] = { durability = 1, light = 4, glyphs = { { "Elemental I", 1, 55638 }, { "Reagent I", 2, 55641 } } },
                ["greater necroplasm"] = { durability = 1, light = 6, glyphs = { { "Elemental I", 1, 55638 }, { "Elemental II", 2, 55639 }, { "Reagent II", 2, 55642 } } },
                ["powerful necroplasm"] = { durability = 1, light = 10, glyphs = { { "Elemental II", 2, 55639 }, { "Elemental III", 4, 55640 }, { "Reagent III", 2, 55643 } } },
                ["lesser essence"] = { durability = 1, light = 4, glyphs = { { "Elemental I", 2, 55638 }, { "Change I", 2, 55647 } } },
                ["greater essence"] = { durability = 1, light = 6, glyphs = { { "Elemental II", 2, 55639 }, { "Change II", 3, 55648 } } },
                ["powerful essence"] = { durability = 1, light = 10, glyphs = { { "Elemental III", 4, 55640 }, { "Change II", 2, 55648 }, { "Change III", 2, 55649 } } },
                ["lesser ensoul material"] = { durability = 1, light = 4, glyphs = { { "Elemental I", 2, 55638 }, { "Change I", 1, 55647 } } },
                ["ensoul material"] = { durability = 1, light = 6, glyphs = { { "Elemental I", 1, 55638 }, { "Elemental II", 2, 55639 }, { "Change II", 2, 55648 } } },
                ["greater ensoul material"] = { durability = 1, light = 6, glyphs = { { "Elemental II", 3, 55639 }, { "Change II", 2, 55648 } } },
                ["ensoul spectral lens"] = { durability = 1, light = 6, glyphs = { { "Elemental II", 3, 55639 }, { "Change II", 2, 55648 }, { "Change I", 1, 55647 } } },
                ["manifest ectoplasm"] = { durability = 1, light = 10, glyphs = { { "Elemental II", 2, 55639 }, { "Change III", 2, 55649 }, { "Reagent III", 4, 55643 } } },
            },
            -- ENSOULED CLOTH AND THREAD (this replaced the old, unverified table ensoulInputs). The three "ensoul material" rituals
            -- make an ensouled BAR, ensouled CLOTH or ensouled THREAD depending on which item you select as the input; the game's ritual rows
            -- name only the bar. The ritual window (interface 1224, read by the survey ritualui, raw copy in ritual-window-14.json) lists every
            -- input option of each ritual under "Input (select an option)": the unensouled bar, five pieces of armour, and thread or wool.
            -- The option lists below are copied from the window ({ item number, name }). WHICH output an option gives (armour -> cloth,
            -- thread or wool -> thread, the unensouled bar -> the bar) follows the kind of item; the window showed all three outputs, but
            -- it was not read option by option, so that split is the one part still unconfirmed in game (UNKNOWNS.md).
            -- Key: the item's name, lower case. bar = the ensouled bar the same ritual makes (lower case): its game row gives the level, time,
            -- XP, site tier, quest and first glyph, and the rest comes from byName above. Used by: recipes/rituals.lua (Recipes.ensoulFamily).
            ensoul = {
                ["lesser ensouled cloth"] = { bar = "lesser ensouled bar", inputs = { { 25835, "Spider silk hood" }, { 25837, "Spider silk robe top" },
                    { 25839, "Spider silk robe bottom" }, { 25843, "Spider silk gloves" }, { 25841, "Spider silk boots" } } },
                ["lesser ensouled thread"] = { bar = "lesser ensouled bar", inputs = { { 1734, "Thread" } } },
                ["ensouled cloth"] = { bar = "ensouled bar", inputs = { { 4089, "Mystic hat" }, { 4091, "Mystic robe top" }, { 4093, "Mystic robe bottom" },
                    { 4095, "Mystic gloves" }, { 4097, "Mystic boots" } } },
                ["ensouled thread"] = { bar = "ensouled bar", inputs = { { 43977, "Springsheared wool" }, { 43975, "Summerdown wool" },
                    { 43981, "Fallfaced wool" }, { 43979, "Winterwold wool" } } },
                ["greater ensouled cloth"] = { bar = "greater ensouled bar", inputs = { { 24992, "Hood of subjugation" }, { 24995, "Garb of subjugation" },
                    { 24998, "Gown of subjugation" }, { 25007, "Gloves of subjugation" }, { 25004, "Boots of subjugation" } } },
                ["greater ensouled thread"] = { bar = "greater ensouled bar", inputs = { { 29864, "Algarum thread" } } },
            },
        },
        -- "magic vial of water is being removed from the game": no recipe, ingredient choice or Uses list mentions the items named here
        -- (lower case). The item itself is still in the item list. Used by: recipes/player.lua (Recipes.isRemoved).
        removed = {
            source = "player", said = "2026-10-27",
            names = { "magic vial of water", "cursed energy" }, -- (cursed energy: removed from the game, developer 2026-10-31)
        },
        doses = {
            source = "player", said = "2026-10-27",
            potionLevel = 3, flaskLevel = 6, salveLevel = 6,
            flaskWord = " flask", salveWord = " salve",    -- the end of a flask's / salve's name (lower case), before the level
            pointer = "Made as: ",                         -- the row that names the level that is made
            flaskItem = "Potion flask",                    -- what the potion is used on (found in the item list by this name)
            useLines = { "Use a potion on a Potion flask:" },
            potionLabel = "Plus one of these potions:",
        },
        -- "Aggie can be listed as another crafting station ... orange dye is not crafted at Aggie, it is made in the inventory"
        -- The game's data holds no recipe for the six basic dyes (the dye survey found only their shop category and a drop sound), so how
        -- they are made is told here. Red, yellow and blue dye are made at Aggie in Draynor Village; orange, green and purple are made in the
        -- inventory by using two of those dyes together. The ingredients and amounts (3 redberries, 2 onions, 2 woad leaves, one of each dye) were
        -- proposed to the developer, who corrected only where orange dye is made. Aggie's own dialogue, caught by the drops survey on
        -- 2026-10-30, confirms the three she makes: red = 3 redberries + 5 coins, yellow = 2 onions + 5 coins, blue = 2 woad leaves + 5
        -- coins (orange, green and purple are not in her dialogue). The 5 coins are not recorded. The items are found in the item list by
        -- name.
        -- Key: the dye's name, lower case. at = "aggie" or "inventory"; each { amount, item name } is one material.
        -- Used by: recipes/player.lua (Recipes.playerFact for the recipe, Recipes.playerDyeUse for the Uses lists).
        dyes = {
            source = "player", said = "2026-10-27",
            madeAt = "Made at: ", aggie = "Aggie (Draynor Village)",
            inventoryLine = "Made in: your inventory",
            materialsLabel = "Materials:", togetherLabel = "Use together:", orTogetherLabel = "Or use together:",
            -- Brown dye and Dyed undead dragon leather: first put in from the wiki on 2026-10-27 at the developer's request, and confirmed
            -- in the game by
            -- the developer on 2026-10-28, so they are hand-written facts like the rest. Brown dye is made by mixing two dyes of opposing
            -- colours (blue +
            -- orange, red + green, or yellow + purple; 1 of each is assumed, no amounts were said), and its only use is making dyed undead dragon
            -- leather (1 undead dragon leather + 1 brown dye, Crafting level 90).
            -- (alternatives = several ways to make it: each is its own list of { amount, item name }; needs = a requirement row; no "at" = no
            -- "Made at" row)
            byName = {
                ["brown dye"] = { at = "inventory", alternatives = {
                    { { 1, "Blue dye" }, { 1, "Orange dye" } },
                    { { 1, "Red dye" }, { 1, "Green dye" } },
                    { { 1, "Yellow dye" }, { 1, "Purple dye" } },
                } },
                ["dyed undead dragon leather"] = { needs = "Needs: Crafting level 90",
                    { 1, "Undead dragon leather" }, { 1, "Brown dye" } },
                ["red dye"]    = { at = "aggie", { 3, "Redberries" } },
                ["yellow dye"] = { at = "aggie", { 2, "Onion" } },
                ["blue dye"]   = { at = "aggie", { 2, "Woad leaf" } },
                ["orange dye"] = { at = "inventory", { 1, "Red dye" }, { 1, "Yellow dye" } },
                ["green dye"]  = { at = "inventory", { 1, "Yellow dye" }, { 1, "Blue dye" } },
                ["purple dye"] = { at = "inventory", { 1, "Red dye" }, { 1, "Blue dye" } },
            },
        },
        stations = {
            source = "player", said = "2026-10-26",
            madeAt = "Made at: ", becomes = "Becomes: ", finishedAt = "Finished at: ",
            furnace = "Furnace", forge = "Forge", anvil = "Anvil",
            burialAnvil = "Burial anvil", -- (3.0.92: for the items the game marks SMITHING_BURIAL_ITEM; the wiki recipe check found them)
            inventor = "Inventor's workbench",            -- (developer, 2026-10-29)
            archaeologist = "Archaeologist's workbench",  -- (developer, 2026-10-29)
            -- The benches (the lists that say which item is made where are Exceptions.benchLists; the NAMES are the developer's words, except where
            -- "guess" is noted). sprite = the key of the picture (Exceptions.stationIcons); the woodworking bench shares the sawmill's picture
            -- (developer, 2026-10-29). The search word is the key: @sawmill @woodworking @spinning @loom @pottery @oven @fletchbench.
            benches = {
                sawmill     = { name = "Sawmill",             sprite = "sawmill" },     -- (developer, 2026-10-29)
                woodworking = { name = "Woodworking bench",   sprite = "sawmill" },     -- (developer, 2026-10-29)
                spinning    = { name = "Spinning wheel",      sprite = "spinning" },    -- (developer, 2026-10-29)
                loom        = { name = "Loom",                sprite = "loom" },        -- (developer, 2026-10-29)
                pottery     = { name = "Pottery wheel",       sprite = "pottery" },     -- (the world map key calls the icon POTTERYWHEEL)
                -- (developer, 2026-10-29): where the FIRE table's pots are fired
                oven        = { name = "Pottery oven",        sprite = "pottery" },
                -- (developer, 2026-10-29: the masterwork bow's parts are the game's own list)
                fletchbench = { name = "Fletching workbench", sprite = "fletching" },
                -- The Fletching workbench is not the place for the sapphire grip (developer, 2026-10-30; it was asked about the masterwork
                -- bow's "sapphire chains and decorated
                -- grip supports", which the game's Fletching workbench list holds but whose recipes need Runecrafting, Magic and Crafting).
                -- exclude: the
                -- bench's key -> words (lower case) in the names of the items that are NOT shown as made there.
                -- (3.0.68, the developer's names, 2026-11-07; the key is the search word: @furniture @obelisk @dunganvil ...)
                furniture    = { name = "Furniture workbench",              sprite = "furniture" },
                obelisk      = { name = "Summoning obelisk",                sprite = "obelisk" },
                dunganvil    = { name = "Anvil (Dungeoneering)",            sprite = "dunganvil" },
                dungfurnace  = { name = "Furnace (Dungeoneering)",          sprite = "dungfurnace" },
                dungspinning = { name = "Spinning wheel (Dungeoneering)",   sprite = "dungspinning" },
                dungaltar    = { name = "Runecrafting altar (Dungeoneering)", sprite = "dungaltar" },
                pedestal     = { name = "Pedestal (Dungeoneering)",         sprite = "pedestal" },
                portbench    = { name = "Workbench (player-owned port)",    sprite = "portbench" },
                portanvil    = { name = "Anvil (player-owned port)",        sprite = "portanvil" },
                scrimshaw    = { name = "Scrimshaw crafter",                sprite = "scrimshaw" },
                soulforge    = { name = "Soul forge",                       sprite = "soulforge" },
                tailoring    = { name = "Tailoring",                        sprite = "tailoring" },
                lectern      = { name = "Lectern",                          sprite = "lectern" },
                singingbowl  = { name = "Crystal singing bowl",             sprite = "singingbowl" },
                brewery      = { name = "Brewery",                          sprite = "brewery" },
                ritualsite   = { name = "Ritual site",                      sprite = "ritualsite" },
                elemental    = { name = "Elemental Workshop workbench",     sprite = "elemental" },
                dragonkin    = { name = "Dragonkin anvil",                  sprite = "dragonkin" },
                tanner       = { name = "Tanner",                           sprite = "tanner" },
                churn        = { name = "Dairy churn",                      sprite = "churn" },
                cradle       = { name = "Offering cradle",                  sprite = "cradle" },
                -- (3.0.70: the small stations, words only)
                clockmaker   = { name = "Clockmaker's bench" },
                robustglass  = { name = "Robust glass machine" },
                sandpit      = { name = "Sandpit" },
                compost      = { name = "Compost bin" },
                blessaltar   = { name = "Altar (blessing)" },
                naturealtar  = { name = "Altar of nature" },
                soupstation  = { name = "Soup creation station (player-owned port)" },
                applebarrel  = { name = "Apple barrel" },
                stump        = { name = "Woodcutting stump" },
                colossus     = { name = "Exalted colossus" },
                dungglyph    = { name = "Glyph spot (Dungeoneering)" },
                elemfurnace  = { name = "Furnace (Elemental Workshop)" },
                doricanvil   = { name = "Anvil (Doric's hut)" },
                doricfurnace = { name = "Furnace (Doric's hut)" },
                eternaltree  = { name = "Eternal magic tree" },
                jadfirepit   = { name = "Firepit (Jadinko Lair)" },
                pigmachine   = { name = "Pig machine" },
                airobelisk   = { name = "Obelisk of Air" },
                waterobelisk = { name = "Obelisk of Water" },
                earthobelisk = { name = "Obelisk of Earth" },
                fireobelisk  = { name = "Obelisk of Fire" },
                -- (3.0.93: names as the game has them - the developer; the wizard makes the splitbark: "Made by:")
                drafting     = { name = "Drafting bench",                   sprite = "drafting" },
                trough       = { name = "Trough",                           sprite = "trough" },
                jalarast     = { name = "Wizard Jalarast",                  sprite = "jalarast", by = true },
                botanist     = { name = "Botanist's workbench",             sprite = "botanist" },
                -- (the Stealing Creation pouches are on the Summoning list too, but made at the creation kiln: not shown as the obelisk's)
                exclude     = { fletchbench = { "sapphire chain", "decorated grip support" }, obelisk = { "(class ", "clay deposit", "binding contract (" } },
                -- (the Summoning list also holds the creature's binding contracts - "Binding contract (abyssal demon)" - which are not made at
                -- the obelisk: the developer, 2026-11-07. The plain "Binding contract" is.)
                -- The loom's own lists are in benchLists. These five names are only the fallback if the game would not hand those lists over
                -- (they were my proposal from the Crafting guide's "Other" filter; the survey showed all five are made at the loom).
                loomItems   = { "strip of cloth", "strip of black cloth", "empty sack", "basket", "empty seaweed net" },
                -- A made item whose name has this word and whose recipe needs Construction is made at the woodworking bench ("frames",
                -- developer, 2026-10-29).
                frameWord   = "frame",
            },
            unfinished = "Unfinished smithing item",      -- what comes out of the forge (found in the item list by this name)
            holdsLabel = "Kept on the item itself:",
            holds = { "the item being made", "its current heat", "its current progress", "the experience left in it" },
            -- All foods are cooked from raw at a range or a campfire (developer, 2026-10-28). The game's cooking tables say which food is cooked
            -- where (Exceptions.cookingLists); these are the words for it. Used by: recipes/stations.lua (cookingPlace).
            cooking = {
                range = "Range",                 -- in an oven list only
                both  = "Range or Bonfire",      -- in an oven list and a fire list
                fire  = "Bonfire",                -- in a fire list only (none is, in the game's data)
            },
        },
    },
}
