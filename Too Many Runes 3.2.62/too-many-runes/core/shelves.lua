-- Too Many Runes - Shelves: the item list's groups (3.2.12; 3.2.17: the groups and rules of the tabs design - Gear, Food & potions,
-- Gathering, Artisan, Support, Quests & clues, Rewards & cosmetics, Misc - each with smaller tabs; the skills split as the in-game capes)
-- Every item goes on exactly one shelf (a smaller tab): the first rule in MATCH it passes. The game's data first - whether it can be worn
-- and its style (recipes/gear.lua), the skill its recipe or gathering uses (recipes/uses.lua, recipes/gather.lua), its right-click options
-- (Eat, Drink, Bury ...), the kind words (recipes/tags.lua), tradeable, the quest items - and its name only to fill the gaps.
-- Used two ways:
--   * the tabs (pages/item_search.lua): a main tab for each group, plus All, in the window's top row; the picked group's smaller tabs in a
--     row above the item list
--   * nothing typed in the search: the list is sorted shelf by shelf, each under a gold heading ("Artisan > Smithing (1,001)", ui/item_box.lua)
-- The shelves are worked out once, when everything they need has been read (the pass at the bottom); until then the list is as before.
return { run = function(T)
local _ENV = T

Shelves = { ready = false, of = {}, tab = "all", sub = nil }

local function gearSet(word) return Recipes.gearIndex and Recipes.gearIndex[word] end
local function gear(word, id) local set = gearSet(word); return set ~= nil and set[id] == true end
local function op(word, slot) local set = Items.ops and Items.ops[word]; return set ~= nil and set[slot] == true end
local function tag(word, id) local set = Tags.sets and Tags.sets[word]; return set ~= nil and set[id] == true end
-- (3.2.27) A kind word (recipes/tags.lua). Those are only made once the recipes' uses are worked out (about when the recipes are ready), so
-- until then the first sort goes by the same kind of names: "Grimy guam", "Potato seed", "Air rune", "Uncut ruby", "Iron bar", "Iron ore",
-- "Yew logs" (raw fish cannot be told from raw meat by name: they wait for the second sort).
local NAME_KIND = { herb = { "^grimy ", "^clean " }, seed = { " seeds?$", " sapling$" }, rune = { "%a rune$" }, gem = { "^uncut " },
                    bar = { " bar$" }, ore = { " ore$" }, log = { "logs?$" } }
local function kind(word, slot, id)
    if Tags.ready then return tag(word, id) end
    local name = Items.lower[slot] or ""
    for _, p in ipairs(NAME_KIND[word] or {}) do if string.find(name, p) then return true end end
    return false
end

-- GEAR STYLE (3.2.31). Neck and ring items are Jewellery; then the game's own style mark on the item (recipes/gear.lua, Recipes.styleIndex);
-- for items without one, the skills it needs to be worn (Recipes.wearIndex), then the game's slot words for it (from its category - "bow",
-- "staff" ...).
local STYLE_WORDS = {
    { "necromancy", { "necro" } },
    { "magic",      { "staff", "wand", "orb", "magic" } },
    { "ranged",     { "bow", "thrown", "arrow", "bolt", "dart", "knife", "javelin", "chinchompa", "ammo" } },
    { "melee",      { "sword", "scimitar", "dagger", "mace", "claw", "whip", "spear", "halberd", "maul", "axe", "hammer", "rapier", "flail",
                      "2h", "melee" } },
    { "jewellery",  { "neck", "ring", "amulet", "necklace", "bracelet", "jewel" } },
}
local styleWords = nil -- { { set, style } } for the slot words the game has, made when the shelves are worked out
local function makeStyleWords()
    styleWords = {}
    for word, set in pairs(Recipes.gearIndex or {}) do
        if word ~= "weapon" and word ~= "armour" and word ~= "potion" and type(set) == "table" then
            local l = string.lower(word)
            for _, sw in ipairs(STYLE_WORDS) do
                local hit = false
                for _, w in ipairs(sw[2]) do if string.find(l, w, 1, true) then hit = true break end end
                if hit then styleWords[#styleWords + 1] = { set, sw[1] } break end
            end
        end
    end
end
local function gearRead() return Recipes.gearState ~= nil and Recipes.gearState.ready == true end
-- (3.2.28) Before the equipment pass is read (its slot words and wear requirements), the style goes by the item's name ("Oak shortbow",
-- "Staff of air", "Bronze sword", "Amulet of glory") with the same words.
-- (3.2.29) armour, whose names the weapon words above do not cover: "Black d'hide body", "Leather chaps", "Mystic robe top"
local NAME_ARMOUR = {
    { "necromancy", { "deathwarden", "necromancer", "death guard", "skull lantern", "deathdealer", "first necromancer" } },
    { "magic",      { "robe", "mystic", "wizard", "battlerobe", "infinity", "splitbark", "elemental", "lunar", "ahrim", "virtus", "tectonic" } },
    { "ranged",     { "d'hide", "dragonhide", "coif", "chaps", "vambrace", "leather", "studded", "snakeskin", "karil", "pernix", "sirenic",
                      "elite void ranger", "ranger" } },
}
local function nameStyle(slot)
    local name = Items.lower[slot] or ""
    for _, sw in ipairs(NAME_ARMOUR) do
        for _, w in ipairs(sw[2]) do if string.find(name, w, 1, true) then return sw[1] end end
    end
    local found = nil
    for _, sw in ipairs(STYLE_WORDS) do
        for _, w in ipairs(sw[2]) do
            if string.find(name, w, 1, true) then
                if sw[1] ~= "jewellery" then return sw[1] end
                found = found or sw[1]
            end
        end
    end
    return found
end
local function wordStyle(id, skip)
    local found = nil
    for _, e in ipairs(styleWords) do
        if e[1][id] and e[2] ~= skip then
            if e[2] ~= "jewellery" then return e[2] end
            found = found or e[2]
        end
    end
    return found
end
local function reqStyle(id)
    local req = Recipes.wearIndex and Recipes.wearIndex[id]
    if req == nil then return nil end
    local has = {}
    -- (3.2.30: the wear requirements number the skills from 0 - Attack 0, Defence 1, Ranged 4 - the game's STAT_TO_STRING list, as the
    -- Info box's "To wear:" line reads them; the recipes number them from 1 (skillNames). Read with those, every skill was one off.)
    for s in pairs(req) do
        local ok, n = pcall(Info.statName, s)
        if ok and type(n) == "string" then has[string.lower(n)] = true end
    end
    -- (3.2.31: Defence alone no longer says melee - in RS3 every style's armour needs only Defence; the game's style marks decide those)
    if has.necromancy then return "necromancy" elseif has.magic then return "magic" elseif has.ranged then return "ranged"
    elseif has.attack or has.strength then return "melee" end
    return nil
end
Shelves.reqStyle = reqStyle -- (for the offline test)

-- (3.2.34) THE GAME'S CATEGORIES. Every item's category (recipes/gear.lua: Recipes.catIndex, named by Recipes.categoryName - POH_FURNITURE,
-- MTX_PET, ARCH_MATERIAL, BONEMEAL ...) and, for items sold on the Grand Exchange, its GE category (Recipes.geIndex). The groups check of
-- 3.2.32 - 3.2.33 found 8,513 of the 26,324 items the list shows in "Everything else": the game's categories place about 4,900 of them
-- (the words in the category's name, below; first match wins), and the GE category more (GE_SHELF).
local CAT_RULES = {
    { "misc.cosmetic", { "ORNAMENT", "COSTUME", "OVERRIDE", "^MTX", "^LOY_", "_PET$", "_PET_", "^PET", "BPETS", "FOLLOWER", "^LORE_BABY_",
        "^LORE_MONKEY", "^LORE_SQUIRREL", "^LORE_GIANT_CRAB", "^LORE_COCKATRICE", "^LORE_VULTURE", "^LORE_BULLDOG", "^LORE_TERRIER",
        "^LORE_GREYHOUND", "^LORE_LABRADOR", "^LORE_DALMATION", "^LORE_SHEEPDOG", "^LORE_PLATYPUS", "PUPPY", "KITTEN", "^TOY", "PARTYHAT",
        "EMOTE", "_TITLE", "KEEPSAKE", "RECOLOUR", "^DYE$", "TRAIL14_DYE", "COSMETIC" } },
    { "misc.xp", { "^REWARD", "LAMP", "XPBOOST", "STAR$", "GROUP_URN", "CASH_BAG", "^WOF", "EFFIGY", "STATUE_ROCK", "XP_", "REWARD_LOOT", "LOOT_CRATE",
        "REPUTATION", "RETURNER_PACK", "BUNDLE", "BP3_", "CURRENCY_PACK", "SHOP_PACK", "MYSTERY" } },
    { "questclue.clues", { "^TRAIL_", "CLUE", "CASKET", "PUZZLE" } },
    -- (3.2.47: the collection logs - Boss, Treasure Trail, Slayer, Animal breeding: COLLECTION_LOG - are books; Woodcutting's "LOGS?$"
    -- took them)
    { "questclue.books", { "COLLECTION_LOG" } },
    -- (3.2.49: Misc > Minigames - the game's categories of minigame items: Barbarian Assault, Castle Wars, Soul Wars, Clan Wars' fields,
    -- the Mage Training Arena, Pest Control, Stealing Creation, the Burthorpe games room, the Skilling Championships)
    { "misc.minigames", { "^BARBASSAULT", "^CASTLEWARS", "^SOULWARS", "^CLAN_FIELD", "^MAGICTRAINING", "^PEST_", "^SC_", "^BOARDGAMES",
        "CHAMPIONSHIP" } },
    { "gathering.hunter", { "^HUNTING", "HUNTER" } }, -- (3.2.36: before Crafting's "FUR$" - HUNTING_KEBBITFUR)
    { "artisan.crafting", { "^URN$" } }, -- (3.2.38: every urn - also "(full)", which no recipe makes - so its stack stays together)
    { "artisan.construction", { "CONSTRUCTION", "^POH_", "_POH$", "HOUSE", "FURNITURE", "FLATPACK", "PLANK", "NAIL" } },
    { "questclue.quest", { "DIGSITE", "^RAG%d*_" } }, -- (3.2.42: the old Dig Site quest's finds - VM_DIGSITE_FIND: Old symbol, Old coin ...;
    -- 3.2.43: Rag and Bone Man's bones - RAG_DIRTY_BONE, RAG2_CLEAN_BONE ...)
    { "gathering.archaeology", { "^ARCH_", "ARCHAEOLOGY", "EXCAVAT" } },
    { "support.slayer", { "SLAYER", "^SLAYC_" } },
    { "support.dungeoneering", { "DUNGEONEERING", "DAEMONHEIM", "^DUNG_" } },
    { "artisan.smithing", { "SALVAGE", "SMITH", "METAL_BAR", "_BAR$", "^MASTERWORK_PART", "^MASTERWORK_SWORD_PART", "ARTISAN_PLANS",
        "DRAGON_METAL" } },
    { "gathering.mining", { "^MINING", "_ORE$", "^ORE$", "GEODE", "ROCK$" } },
    { "gathering.farming", { "^POF_", "FARMING", "SEED", "COMPOST", "ROOTS", "SAPLING", "FLOWER", "FRUIT$", "MUSHROOM",
        "ECOSYSTEM" } },
    -- (3.2.43: Prayer, Summoning and Necromancy are three groups)
    { "support.necromancy", { "^NECRO", "ECTO" } },
    { "support.summoning", { "SUMMON", "SPELL_POUCH", "FAMILIAR", "^SUM2", "SIGIL", "CHARM" } },
    { "support.prayer", { "BONE", "ASHES", "PRAYER", "BURIAL", "SACRED_OIL", "OLIVE_OIL" } },
    { "artisan.runecrafting", { "RUNECRAFT", "^RCU_", "RUNE_MULTIPLIER", "RUNEPOUCH", "TALISMAN", "TIARA", "ESSENCE" } },
    { "artisan.fletching", { "XBOWS", "ARROW", "BOW_", "^MASTERWORK_BOW", "SHAFT", "DART", "FLETCH", "THATCHINGSPAR" } },
    { "artisan.crafting", { "CRAFT", "GEM", "JEWEL", "UNSTRUNG", "LEATHER", "HIDE", "FUR$", "POTTERY", "GLASS", "SNAIL_SHELL", "ORIGAMI" } },
    { "artisan.herblore", { "HERB", "UNFINISHED_POTION", "SERUM" } },
    { "artisan.cooking", { "BURNT", "COOK", "INGREDIENT", "^ALUFT", "FOOD", "PIE$", "WINE", "^BREW", "KEG", "MUSH$" } },
    { "gathering.fishing", { "FISH", "TACKLE" } },
    { "gathering.woodcutting", { "LOGS?$", "WOOD", "TREE", "BIRD_NEST" } },
    { "gathering.hunter", { "HUNT", "IMPLING", "BUTTERFLY", "TRAP" } },
    { "gathering.divination", { "DIVINATION", "^DIV_", "MEMORY", "ENERGY", "CHRONICLE" } },
    { "artisan.invention", { "INVENT", "GIZMO", "COMPONENT", "AUGMENT", "ACCUMULATOR" } },
    { "support.thieving", { "THIEV", "PICKPOCKET", "^NTK_ARTEFACT", "LOOTING_BAG", "SAFES_" } },
    { "support.agility", { "AGILITY" } },
    { "artisan.firemaking", { "FIREMAKING", "INCENSE", "PYRE", "^PHOENIX_TWIGS" } },
    { "questclue.books", { "BOOK", "JOURNAL", "PAGE$", "_NOTE$", "LETTER", "DIARY", "SCROLL" } },
    { "misc.tools", { "TOOL", "WATERING_CAN", "CONTAINER$", "WATERSKIN" } },
}
local catCache = {} -- category number -> shelf key or false
local function catShelf(id)
    local n = Recipes.catIndex and Recipes.catIndex[id]
    if n == nil then return nil end
    local c = catCache[n]
    if c == nil then
        c = false
        local name = Recipes.categoryName and Recipes.categoryName(n)
        if type(name) == "string" then
            for _, r in ipairs(CAT_RULES) do
                for _, pat in ipairs(r[2]) do if string.find(name, pat) then c = r[1] break end end
                if c then break end
            end
        end
        catCache[n] = c
    end
    return c or nil
end
-- The Grand Exchange's categories (the GE_CATEGORY numbers): the shelf each one means.
local GE_SHELF = { [1] = "gear.ranged", [2] = "gear.ranged", [3] = "gear.ranged", [4] = "artisan.construction", [5] = "artisan.construction",
    [6] = "artisan.cooking", [8] = "artisan.crafting", [9] = "support.summoning", [10] = "gathering.farming", [11] = "artisan.fletching",
    [12] = "consumables.food", [13] = "artisan.herblore", [14] = "gathering.hunter", [15] = "gathering.hunter", [16] = "gear.jewellery",
    [17] = "gear.magic", [18] = "gear.magic", [19] = "gear.melee", [20] = "gear.melee", [21] = "gear.melee", [22] = "gear.melee",
    [23] = "gear.melee", [24] = "gear.melee", [25] = "artisan.smithing", [26] = "consumables.potions", [28] = "support.prayer",
    [29] = "gear.ranged", [30] = "gear.ranged", [31] = "artisan.runecrafting", [32] = "artisan.runecrafting", [33] = "gathering.farming",
    [34] = "support.summoning", [35] = "misc.tools", [36] = "gathering.woodcutting", [38] = "gathering.mining", [39] = "artisan.smithing",
    [40] = "artisan.firemaking", [41] = "gathering.archaeology", [42] = "gathering.woodcutting", [43] = "gear.necromancy",
    [44] = "gear.necromancy", [45] = "support.necromancy", [46] = "gathering.divination", [47] = "misc.xp", [48] = "support.thieving",
    [50] = "misc.xp" }
local GE_STYLE = { [1] = "ranged", [2] = "ranged", [3] = "ranged", [16] = "jewellery", [17] = "magic", [18] = "magic", [19] = "melee",
    [20] = "melee", [21] = "melee", [22] = "melee", [23] = "melee", [24] = "melee", [29] = "ranged", [30] = "ranged", [43] = "necromancy",
    [44] = "necromancy" }
local function geOf(id) return Recipes.geIndex and Recipes.geIndex[id] end
-- (3.2.34) Gear the game marks with no style of its own - "Broken elder rune platebody", "Augmented Achto Primeval robe top", "Primal full
-- helm + 5" - takes the style of the item it is a form of (the same name without the form words). baseStyle: lower-case name -> style of
-- every marked item, made with each sort.
local baseStyle = {}
local FORM_WORDS = { "^augmented ", "^broken ", " %(broken%)$", " %(uncharged%)$", " %(worn%)$", " %+ %d+$", " %(i%)$", " %(or%)$" }
local function makeBaseStyle()
    baseStyle = {}
    for id, st in pairs(Recipes.styleIndex or {}) do
        local slot = Items.slotOf and Items.slotOf[id]
        local name = slot and Items.lower[slot]
        if st ~= "hybrid" and name ~= nil and baseStyle[name] == nil then baseStyle[name] = st end
    end
end
local function formStyle(slot)
    local name = Items.lower[slot] or ""
    for _ = 1, 3 do
        local was = name
        for _, w in ipairs(FORM_WORDS) do name = string.gsub(name, w, "") end
        if name == was then break end
        if baseStyle[name] ~= nil then return baseStyle[name] end
    end
    return nil
end
-- (3.2.31) Is it worn in the neck or ring slot (the slot words of recipes/gear.lua)? Those always go on the Jewellery shelf.
local function jewellery(id)
    for _, e in ipairs(styleWords) do
        if e[2] == "jewellery" and e[1][id] then return true end
    end
    return false
end
local styleCache = {}
-- (3.2.31) Once the equipment pass is read, the game's own style mark on the item comes first (Recipes.styleIndex: COMBATV2_RANGED_ITEM
-- on the Elite sirenic mask, COMBATV2_MAGIC_WEAPON on a staff ...); jewellery before it, and the old guesses only for items without one.
local function styleOf(slot, id)
    local s = styleCache[id]
    if s == nil then
        if gearRead() then
            local mark = Recipes.styleIndex and Recipes.styleIndex[id]
            if mark == "hybrid" then mark = nil end
            -- (3.2.34: then the style of the item it is a form of, and the Grand Exchange's category)
            s = (jewellery(id) and "jewellery") or mark or formStyle(slot) or GE_STYLE[geOf(id) or -1] or (gear("ammo", id) and "ranged")
                or reqStyle(id) or wordStyle(id) or "other"
        else s = nameStyle(slot) or "other" end
        styleCache[id] = s
    end
    return s
end
-- (3.2.28: before the equipment pass is read, an item that can be worn is one with Wear or Wield on its right-click)
local function isGear(slot, id)
    if gearRead() then return gear("weapon", id) or gear("armour", id) or gear("ammo", id) end
    return op("wear", slot) or op("wield", slot)
end

-- SKILLS: made with a skill (the recipes, Recipes.skillIndex) or gathered with it (recipes/gather.lua), by the skill's name.
local skillNo = {}
-- (3.2.35: skillNo is keyed by the name in lower case. The game's skill names are in capitals - "HERBLORE" - and the rules ask for
-- "Herblore", so until now no item was ever found to be made or gathered with a skill: "Arbuck potion (unfinished)" went to Smithing for
-- the word "unfinished", though its recipe gives Herblore experience. A recipe's skill is the one it needs or the one it gives experience
-- in - Recipes.skillIndex, recipes/uses.lua.)
-- (3.2.37) An item whose recipes use several skills counts only for its MAIN one: the skill with the highest level needed. "Junk refiner"
-- needs Invention 22 and also gives Smithing experience - it was on Smithing. Only the skills these rules ask about count (not Magic, whose
-- spells make planks, bars and pies too). Without any level (experience only), every skill of it counts.
local MAIN_SKILLS = { "herblore", "smithing", "fletching", "cooking", "crafting", "construction", "firemaking", "invention", "runecrafting",
                      "farming", "prayer", "summoning", "necromancy", "archaeology", "divination", "agility" }
local mainOf = {} -- item number -> skill number or false (made each sort)
local function mainSkill(id, t)
    local m = mainOf[id]
    if m ~= nil then return m or nil end
    local best, lv = nil, 0
    for _, name in ipairs(MAIN_SKILLS) do
        local n = skillNo[name]
        local l = n ~= nil and t[n] or nil
        if type(l) == "number" and (l > lv or (l == lv and l > 0 and n < best)) then best, lv = n, l end
    end
    mainOf[id] = best or false
    return best
end
local function made(id, skill)
    local n, t = skillNo[string.lower(skill)], Recipes.skillIndex and Recipes.skillIndex[id]
    if n == nil or t == nil or t[n] == nil then return false end
    local m = mainSkill(id, t)
    return m == nil or m == n
end
local function gathered(id, skill)
    local n = skillNo[string.lower(skill)]
    if n == nil or Gather == nil or Gather.levelIn == nil then return false end
    local ok, lv = pcall(Gather.levelIn, id, n)
    return ok and lv ~= nil
end
local function by(id, skill) return made(id, skill) or gathered(id, skill) end

-- NAMES (only where the game's data has nothing to go by). A word list: plain pieces of the name, or %f patterns for whole short words.
local function words(list)
    local out = {}
    for _, w in ipairs(list) do
        if string.sub(w, 1, 1) == "=" then out[#out + 1] = { pat = "%f[%a]" .. string.sub(w, 2) .. "%f[%A]" }
        elseif string.sub(w, 1, 1) == "~" then out[#out + 1] = { pat = string.sub(w, 2) } -- (3.2.45: "~" = a Lua pattern as it is)
        else out[#out + 1] = { plain = w } end
    end
    return out
end
local function named(slot, list)
    local name = Items.lower[slot] or ""
    for _, w in ipairs(list) do
        if w.plain ~= nil then
            if string.find(name, w.plain, 1, true) then return true end
        elseif string.find(name, w.pat) then return true end
    end
    return false
end
local function raw(slot) return string.sub(Items.lower[slot] or "", 1, 4) == "raw " end
local W = {
    cosmetic = words({ "override", "costume", "outfit", "cosmetic", "christmas", "=easter", "halloween", "santa", "festive", "holiday",
                       "valentine", "(pet)", "=pet" }),
    potion   = words({ "potion", "flask", "brew", "=mix", "overload", "elixir" }),
    rc       = words({ "essence", "talisman", "tiara", "small pouch", "medium pouch", "large pouch", "giant pouch", "massive pouch" }),
    herb     = words({ "(unf)", "grimy" }),
    farm     = words({ "sapling", "seedling", "compost" }),
    smith    = words({}), -- (3.2.36: "unfinished" sent unfinished potions, hides and cooking to Smithing; the recipes say it now)
    mine     = words({ "stone spirit", "=clay" }),
    fletch   = words({ "arrow shaft", "arrowhead", "bowstring", "(u)", "unstrung" }),
    wood     = words({ "wood spirit" }),
    fish     = words({ "=bait" }), -- (3.2.37: not "feather" - Feather of Ma'at, Slayer Feather Buff ...)
    cook     = words({ "=flour", "=dough", "=milk", "=egg", "=eggs" }),
    craft    = words({ "leather", "=hide", "=hides", "thread", "uncut", "=glass", "=cloth", "=wool", "~^harmonic dust$" }), -- (3.2.49: Harmonic dust)
    build    = words({ "=plank", "=planks", "flatpack", "=plans" }),
    fire     = words({ "firelighter", "incense", "pyre log" }),
    -- (3.2.45: bones and ashes only as the last word - not "Moonstone bone dart", "Ports bone pack", "Invoke Lord of Bones incantation
    -- codex"; and only the Summoning charms by name - not "Snake charm", "Seeker's charm")
    prayer   = words({ "~bones?$", "~ashes$", "cleansing crystal" }),
    summon   = words({ "~^gold charm$", "~^green charm$", "~^crimson charm$", "~^blue charm$", "~^elder charm$", "~^abyssal charm$",
                       "~^talon beast charm$", "~^obsidian charm$", "~^ravager charm$", "~^shifter charm$", "~^spinner charm$",
                       "~^torcher charm$" }),
    necro    = words({ "ectoplasm", "necroplasm", "ghostly ink" }),
    hunt     = words({ "=trap", "=snare", "chinchompa", "impling", "=fur", "antler" }),
    arch     = words({ "(damaged)", "=soil" }), -- (3.2.42: not "artefact", "relic" - the Watchtower's Ogre relic and Relic parts)
    div      = words({ "=memory", "=memories", "=energy", "sign of", "portent" }),
    inv      = words({ "gizmo", "component", "augmentor", "divine charge" }), -- (3.2.38: not "siphon" - Divining siphon)
    slayer   = words({ "enchanted gem", "ring of slaying", "slayer" }),
    thieve   = words({ "coin pouch", "lockpick", "stethoscope", "=rogue" }),
    agility  = words({ "mark of grace", "marks of grace", "agility", "course multiplier" }),
    dung     = words({ "daemonheim", "dungeoneering" }),
    tools    = words({ "bolt pouch", "pickaxe", "hatchet", "=knife", "chisel", "=hammer", "tinderbox", "=needle", "=saw", "=bucket", "=vial", "=jug",
                       "=spade", "=rake", "fishing rod", "=net", "toolbelt" }),
    clue     = words({ "clue", "casket", "puzzle box", "sextant", "scroll box", "challenge scroll" }),
    reward   = words({ "=lamp", "=star", "=xp", "mystery box", "=token", "=tokens", "=ticket", "=tickets", "codex" }), -- (3.2.37: not "key", "urn";
    -- 3.2.45: + codex - the ability codices and their shards)
    book     = words({ "=book", "=journal", "=letter", "=page", "=diary", "=notes" }),
}
W.key = words({ "=key" })
local CONFIG_WORDS = { { "slayer", "support.slayer" }, { "^invent", "artisan.invention" }, { "^arch_", "gathering.archaeology" },
                       { "^hunting", "gathering.hunter" }, { "^dung", "support.dungeoneering" } }
-- (3.2.39) The first part of the game's own name, for the items nothing else places (the groups check printed the names of every item
-- still on "Everything else"): con_contracts_... the Construction contracts, poh_ the house, pof_animal_ the farm's animals, rcsiphonxp_
-- ... - and the games's short names of quests: quest_, myq7_ (Myreque), regicide_, mourning_, mm_ (Monkey Madness), hundred_ (Recipe for
-- Disaster) ...
local CONFIG_PREFIXES = { { "con_", "artisan.construction" }, { "poh_", "artisan.construction" }, { "shard_sum2", "support.summoning" },
    { "sum2_", "support.summoning" }, { "rag_", "questclue.quest" }, { "rag2_", "questclue.quest" }, { "rcsiphonxp", "artisan.runecrafting" }, { "pof_", "gathering.farming" },
    { "huntguide", "gathering.hunter" }, { "aluft_", "artisan.cooking" }, { "thigui_", "support.thieving" }, { "necro_", "support.necromancy" },
    { "quest_", "questclue.quest" }, { "myq", "questclue.quest" }, { "regicide_", "questclue.quest" }, { "mourning_", "questclue.quest" },
    { "rocko_", "questclue.quest" }, { "fenk_", "questclue.quest" }, { "glo3_", "questclue.quest" }, { "eyeglo_", "questclue.quest" },
    { "brain_", "questclue.quest" }, { "tbwt_", "questclue.quest" }, { "enakh_", "questclue.quest" }, { "mm_", "questclue.quest" },
    { "hundred_", "questclue.quest" }, { "elr2_minq", "questclue.quest" }, { "dwarf_rock", "questclue.quest" }, { "fever_", "questclue.quest" },
    { "handsand_", "questclue.quest" } }
-- (3.2.49) The game's own names that start with a minigame's name, for Misc > Minigames: before the skills' data, so a minigame's own logs,
-- ores and potions (Trouble Brewing's Scrapey tree logs, Castle Wars' Explosive potion) stay with their minigame
local MINIGAME_PREFIXES = { "barbassault", "castlewars", "soulwars", "snp_", "sc_", "boardgames", "dom_", "brew_", "magictraining",
    "roguesden", "championships", "mob_" }
local function minigameConfig(slot)
    local c = Items.debug and Items.debug[slot] -- (lower case)
    if type(c) ~= "string" then return false end
    c = string.gsub(c, "^_+", "")
    for _, p in ipairs(MINIGAME_PREFIXES) do if string.sub(c, 1, #p) == p then return true end end
    return false
end
local function configShelf(slot)
    local c = Items.debug and Items.debug[slot] -- (lower case)
    if type(c) ~= "string" then return nil end
    for _, e in ipairs(CONFIG_WORDS) do if string.find(c, e[1]) then return e[2] end end
    c = string.gsub(c, "^_+", "")
    for _, e in ipairs(CONFIG_PREFIXES) do if string.sub(c, 1, #e[1]) == e[1] then return e[2] end end
    return nil
end
local SKILL_WORDS = { { "agility", "support.agility" }, { "herblore", "artisan.herblore" }, { "fishing", "gathering.fishing" },
    { "mining", "gathering.mining" }, { "smithing", "artisan.smithing" }, { "cooking", "artisan.cooking" }, { "crafting", "artisan.crafting" },
    { "fletching", "artisan.fletching" }, { "firemaking", "artisan.firemaking" }, { "woodcutting", "gathering.woodcutting" },
    { "farming", "gathering.farming" }, { "hunter", "gathering.hunter" }, { "construction", "artisan.construction" },
    { "runecrafting", "artisan.runecrafting" }, { "thieving", "support.thieving" }, { "slayer", "support.slayer" },
    { "prayer", "support.prayer" }, { "summoning", "support.summoning" }, { "necromancy", "support.necromancy" },
    { "divination", "gathering.divination" }, { "invention", "artisan.invention" }, { "archaeology", "gathering.archaeology" },
    { "dungeoneering", "support.dungeoneering" } }
local function skillWordShelf(slot)
    local name, config = Items.lower[slot] or "", Items.debug and Items.debug[slot] or ""
    for _, e in ipairs(SKILL_WORDS) do
        local w = e[1]
        -- (3.2.45: the item's name only - in the game's own names the skill words were too loose: SHARD_GODWARS_AMULET_NECROMANCY,
        -- NATURE_BOSS_PRAYER_RESTORER)
        if string.find(name, "%f[%a]" .. w .. "%f[%A]") then return e[2] end
    end
    return nil
end
local EARLY_CATS = { URN = "artisan.crafting", BIRD_NEST = "gathering.woodcutting" } -- (game category -> shelf, before anything else)
local function isQuest(slot, id)
    local q = Recipes.stationIndex and Recipes.stationIndex["quest"]
    -- (3.2.49: or the RuneScape Wiki says it is found during a quest and cannot be traded - the older quests' items, which the game's data
    -- does not tie to their quest: data/wiki_lists.lua, WikiLists.questFound)
    local wq = WikiLists ~= nil and WikiLists.is ~= nil and WikiLists.is.questFound or nil
    return (q ~= nil and q[id] == true) or (Items.quests ~= nil and Items.quests[slot] ~= nil) or (wq ~= nil and wq[id] == true)
end

-- THE GROUPS, in the order of the tabs: key, the tab's word, and the sub-groups (key, tab word). The tests are in MATCH, below.
Shelves.GROUPS = {
    { key = "gear", tab = "Gear", subs = { { key = "melee", tab = "Melee" }, { key = "ranged", tab = "Ranged" }, { key = "magic", tab = "Magic" },
        { key = "necromancy", tab = "Necromancy" }, { key = "jewellery", tab = "Jewellery" }, { key = "worn", tab = "Other worn" } } },
    { key = "consumables", tab = "Food & potions", subs = { { key = "food", tab = "Food & drink" }, { key = "potions", tab = "Potions" } } },
    { key = "gathering", tab = "Gathering", subs = { { key = "mining", tab = "Mining" }, { key = "woodcutting", tab = "Woodcutting" },
        { key = "fishing", tab = "Fishing" }, { key = "farming", tab = "Farming" }, { key = "hunter", tab = "Hunter" },
        { key = "archaeology", tab = "Archaeology" }, { key = "divination", tab = "Divination" } } },
    { key = "artisan", tab = "Artisan", subs = { { key = "smithing", tab = "Smithing" }, { key = "crafting", tab = "Crafting" },
        { key = "fletching", tab = "Fletching" }, { key = "herblore", tab = "Herblore" }, { key = "cooking", tab = "Cooking" },
        { key = "construction", tab = "Construction" }, { key = "runecrafting", tab = "Runecrafting" }, { key = "firemaking", tab = "Firemaking" },
        { key = "invention", tab = "Invention" } } },
    { key = "support", tab = "Support", subs = { { key = "prayer", tab = "Prayer" }, { key = "summoning", tab = "Summoning" },
        { key = "necromancy", tab = "Necromancy" }, { key = "slayer", tab = "Slayer" }, -- (3.2.43: Prayer, Summoning, Necromancy apart)
        { key = "thieving", tab = "Thieving" }, { key = "agility", tab = "Agility" }, { key = "dungeoneering", tab = "Dungeoneering" } } },
    { key = "questclue", tab = "Quests & clues", subs = { { key = "quest", tab = "Quest items" }, { key = "clues", tab = "Clues" },
        { key = "books", tab = "Books & lore" } } },
    -- (3.2.40: Rewards & XP and Cosmetics & pets are in Misc - the Rewards tab is gone)
    { key = "misc", tab = "Misc", subs = { { key = "tools", tab = "Tools" }, { key = "xp", tab = "Rewards & XP" },
        { key = "cosmetic", tab = "Cosmetics & pets" },
        -- (3.2.44: the Grand Exchange's armour sets, all in one group - core/groups.lua; 3.2.43 had them on Gear as "Armour sets")
        { key = "sets", tab = "Exchange sets" }, { key = "minigames", tab = "Minigames" }, -- (3.2.49: Minigames)
        { key = "other", tab = "Everything else" } } },
}
-- Where each item goes: the first rule here it passes (the handoff's rank order, 1 to 36). The game's data first - can be worn and its
-- style, the skill a recipe or gathering uses, Eat / Drink / Bury ..., tradeable - and names only to fill the gaps.
local MATCH = {
    -- (3.2.45) FIRST: everything the Dungeoneering hide switch hides (Daemonheim's own items - its gear too) is on Support > Dungeoneering,
    -- and every urn (the game's category URN) on Crafting, folded by tier - core/groups.lua
    { "support.dungeoneering", function(slot, id) return Items.DUNG ~= nil and Items.is(slot, Items.DUNG) end },
    -- (3.2.46: and every bird's nest - the game's category BIRD_NEST - on Woodcutting; some have Farming data, so they went to Farming)
    { "*",                   function(slot, id) local c = Recipes.catIndex and Recipes.catIndex[id]
                                  local n = (c ~= nil and Recipes.categoryName ~= nil) and Recipes.categoryName(c) or nil
                                  return EARLY_CATS[n or ""] end },
    { "gear.melee",          function(slot, id) return isGear(slot, id) and styleOf(slot, id) == "melee" end },
    { "gear.ranged",         function(slot, id) return isGear(slot, id) and styleOf(slot, id) == "ranged" end },
    { "gear.magic",          function(slot, id) return isGear(slot, id) and styleOf(slot, id) == "magic" end },
    { "gear.necromancy",     function(slot, id) return isGear(slot, id) and styleOf(slot, id) == "necromancy" end },
    { "gear.jewellery",      function(slot, id) return isGear(slot, id) and styleOf(slot, id) == "jewellery" end },
    -- (3.2.34: or its category - 3.2.35: only for gear, or an item no recipe makes: the Spirit pengatrice pouch's category is a cockatrice
    -- pet's, but Summoning makes it)
    { "misc.cosmetic",    function(slot, id) return named(slot, W.cosmetic) or (catShelf(id) == "misc.cosmetic"
                                  and (isGear(slot, id) or Recipes.skillIndex == nil or Recipes.skillIndex[id] == nil)) end },
    { "gear.worn",           function(slot, id) return isGear(slot, id) end },
    { "misc.sets",           function(slot, id) local c = Recipes.catIndex and Recipes.catIndex[id]
                                  return c ~= nil and Recipes.categoryName ~= nil and Recipes.categoryName(c) == "EXCHANGE_SET" end },
    -- (3.2.49) a minigame's items: the game's category or its own name for the item (gear stays on Gear, above)
    { "misc.minigames",      function(slot, id) return catShelf(id) == "misc.minigames" or minigameConfig(slot) end },
    { "consumables.potions", function(slot, id) return gear("potion", id) or ((op("drink", slot) or op("eat", slot)) and named(slot, W.potion)) end },
    -- (3.2.36: burnt food is the cook's - it was on Food & drink when it had Eat)
    { "artisan.cooking",     function(slot, id) return string.sub(Items.lower[slot] or "", 1, 6) == "burnt " end },
    { "consumables.food",    function(slot, id) return (op("eat", slot) or op("drink", slot)) and not raw(slot) end },
    -- (3.2.36) THE ORDER: the game's data for every skill comes before any name word (until now each skill's name words came before the
    -- next skill's data: "Bronze bolts (unf)" went to Herblore for "(unf)", though Smithing makes it). Before the skills: XP lamps, stars
    -- and clue scrolls by the game's category, then the quest items (not tradeable, and tied to a quest - they were on the shelves of the
    -- skills used in the quest: Fishing, Cooking ...). A rule that returns a shelf key ("*") puts the item there.
    -- (3.2.37: XP and clue categories only for items no recipe makes - urns are crafted, so they go to Crafting)
    { "*",                   function(slot, id) local c = catShelf(id)
                                  if (c == "misc.xp" or c == "questclue.clues") and (Recipes.skillIndex == nil or Recipes.skillIndex[id] == nil) then
                                      return c end end },
    -- (3.2.37: and keys that cannot be traded - "Goblin kitchen key", "Jail cell key": quest and dungeon keys, they were on Rewards & XP)
    { "questclue.quest",     function(slot, id) return not Items.trade[slot] and (isQuest(slot, id) or named(slot, W.key)) end },
    -- 1. THE GAME'S DATA: kind words, the recipe's skill (the one it needs or gives experience in), the gathering skill, Bury / Plant
    { "artisan.runecrafting", function(slot, id) local ge = geOf(id)
                                  return kind("rune", slot, id) or ge == 31 or ge == 32 or by(id, "Runecrafting")
                                  or (op("break", slot) and string.find(Items.lower[slot] or "", "teleport", 1, true) ~= nil) end },
    { "artisan.herblore",    function(slot, id) return kind("herb", slot, id) or made(id, "Herblore") end },
    { "gathering.farming",   function(slot, id) return kind("seed", slot, id) or op("plant", slot) or by(id, "Farming") end },
    { "artisan.smithing",    function(slot, id) return kind("bar", slot, id) or made(id, "Smithing") end },
    { "gathering.mining",    function(slot, id) return kind("ore", slot, id) or gathered(id, "Mining") end },
    { "artisan.fletching",   function(slot, id) return made(id, "Fletching") end },
    { "gathering.woodcutting", function(slot, id) return kind("log", slot, id) or gathered(id, "Woodcutting") end },
    { "gathering.fishing",   function(slot, id) return kind("fish", slot, id) or gathered(id, "Fishing") end },
    { "artisan.cooking",     function(slot, id) return raw(slot) or made(id, "Cooking") end },
    { "artisan.crafting",    function(slot, id) return kind("gem", slot, id) or made(id, "Crafting") end },
    { "artisan.construction", function(slot, id) return made(id, "Construction") end },
    { "artisan.firemaking",  function(slot, id) return made(id, "Firemaking") end },
    { "support.prayer",      function(slot, id) return op("bury", slot) or op("scatter", slot) or by(id, "Prayer") end },
    { "support.summoning",   function(slot, id) return by(id, "Summoning") end },
    { "support.necromancy",  function(slot, id) return by(id, "Necromancy") end },
    { "gathering.hunter",    function(slot, id) return gathered(id, "Hunter") end },
    { "gathering.archaeology", function(slot, id) return by(id, "Archaeology") end },
    -- (3.2.39: a Divination recipe - transmuting - only when the item's own category says nothing else, or it is named like one: the
    -- Green, Crimson and Blue charms are transmuted too, and were on Divination)
    -- (3.2.42: nor when its Grand Exchange category says otherwise, or the game's own name is a Necromancy one - the mementos, NECRO_
    -- POWERFUL_MEMENTO, are made with Divination but are Necromancy's)
    { "gathering.divination", function(slot, id) local c, ge = catShelf(id), geOf(id)
                                  local cfg = Items.debug and Items.debug[slot] or ""
                                  return gathered(id, "Divination") or (made(id, "Divination")
                                  and (c == nil or c == "gathering.divination" or named(slot, W.div))
                                  and (ge == nil or GE_SHELF[ge] == nil or GE_SHELF[ge] == "gathering.divination")
                                  and string.sub(cfg, 1, 6) ~= "necro_") end },
    { "artisan.invention",   function(slot, id) return made(id, "Invention") end },
    { "support.thieving",    function(slot, id) return gathered(id, "Thieving") end },
    { "support.agility",     function(slot, id) return by(id, "Agility") end },
    { "support.dungeoneering", function(slot, id) return Items.DUNG ~= nil and Items.is(slot, Items.DUNG) end },
    -- 2. the game's category for the item, then its Grand Exchange category
    -- (3.2.45: the Spirit dragon charm's category is the Summoning charms', LORE_CHARM, but it is not one)
    { "*",                   function(slot, id) local c = catShelf(id)
                                  if c == "support.summoning" and Items.lower[slot] == "spirit dragon charm" then c = nil end
                                  return c or GE_SHELF[geOf(id) or -1] end },
    -- (3.2.37) the game's own name for the item (its configName: "MENAPHOS_SLAYER_MAAT_FEATHER", the line under the item number), for a few
    -- sure words
    { "*",                   function(slot, id) return configShelf(slot) end },
    -- 3. NAMES, only where the game's data has nothing to go by
    { "artisan.runecrafting", function(slot, id) return named(slot, W.rc) end },
    { "artisan.herblore",    function(slot, id) return named(slot, W.herb) end },
    { "gathering.farming",   function(slot, id) return named(slot, W.farm) end },
    { "gathering.mining",    function(slot, id) return named(slot, W.mine) end },
    { "artisan.fletching",   function(slot, id) return named(slot, W.fletch) end },
    { "gathering.woodcutting", function(slot, id) return named(slot, W.wood) end },
    { "gathering.fishing",   function(slot, id) return named(slot, W.fish) end },
    { "artisan.cooking",     function(slot, id) return named(slot, W.cook) end },
    { "artisan.crafting",    function(slot, id) return named(slot, W.craft) end },
    { "artisan.construction", function(slot, id) return named(slot, W.build) end },
    { "artisan.firemaking",  function(slot, id) return named(slot, W.fire) end },
    { "support.prayer",      function(slot, id) return named(slot, W.prayer) and not named(slot, W.thieve) end },
    { "support.summoning",   function(slot, id) return named(slot, W.summon) or Items.lower[slot] == "pouch" end },
    { "support.necromancy",  function(slot, id) return named(slot, W.necro) end },
    { "gathering.hunter",    function(slot, id) return named(slot, W.hunt) end },
    { "gathering.archaeology", function(slot, id) return named(slot, W.arch) end },
    { "gathering.divination", function(slot, id) return named(slot, W.div) end },
    { "artisan.invention",   function(slot, id) return named(slot, W.inv) end },
    { "support.slayer",      function(slot, id) return named(slot, W.slayer) end },
    { "support.thieving",    function(slot, id) return named(slot, W.thieve) end },
    { "support.agility",     function(slot, id) return named(slot, W.agility) end },
    { "support.dungeoneering", function(slot, id) return named(slot, W.dung) end },
    { "misc.tools",          function(slot, id) return named(slot, W.tools) end },
    { "questclue.clues",     function(slot, id) return named(slot, W.clue) end },
    { "misc.xp",          function(slot, id) return named(slot, W.reward) end },
    { "questclue.books",     function(slot, id) return op("read", slot) or named(slot, W.book) end },
    -- (3.2.38) last: a skill named in the item's name or in the game's own name for it ("Hefin course multiplier", "Fishing pass")
    { "*",                   function(slot, id) return skillWordShelf(slot) end },
    { "misc.other",          function() return true end },
}

-- Shelf keys: "group.sub". Shelves.byKey[shelf] = { group, sub, label, order }.
Shelves.byKey, Shelves.groupByKey = {}, {}
local order = 0
for _, g in ipairs(Shelves.GROUPS) do
    Shelves.groupByKey[g.key] = g
    for _, sb in ipairs(g.subs) do
        order = order + 1
        Shelves.byKey[g.key .. "." .. sb.key] = { group = g.key, sub = sb.key, label = g.tab .. " > " .. sb.tab, order = order }
    end
end
local matchList = {}
for _, m in ipairs(MATCH) do matchList[#matchList + 1] = { key = m[1], test = m[2] } end
local OTHER = "misc.other"

-- (3.2.29: a reload always opens on All - the tab last open is not brought back)

-- The shelf of an item (by its place in the item list); "Everything else" until the shelves are worked out.
function Shelves.ofSlot(slot) return Shelves.of[slot] or OTHER end

-- Does the item get through the open tabs? (core/filters.lua asks; every item does on All, or before the shelves are worked out)
-- (3.2.47: Favorites is a tab too - "fav", between All and Gear - in place of the dropdown beside the search box; it lets every item
-- through here, and the favourites list itself is core/filters.lua's)
function Shelves.passes(slot)
    if Shelves.tab == "all" or Shelves.tab == "fav" or not Shelves.ready then return true end
    local e = Shelves.byKey[Shelves.of[slot] or OTHER]
    if e == nil or e.group ~= Shelves.tab then return false end
    return Shelves.sub == nil or e.sub == Shelves.sub
end

-- Open a tab: a group ("all" for All) and one of its sub-groups (nil: all of the group).
function Shelves.setTab(key, sub)
    if key ~= "all" and key ~= "fav" and Shelves.groupByKey[key] == nil then return end
    if sub ~= nil and Shelves.byKey[key .. "." .. sub] == nil then sub = nil end
    if key == Shelves.tab and sub == Shelves.sub then return end
    Shelves.tab, Shelves.sub = key, sub -- (not saved: a reload always opens on All - 3.2.29)
    if Filters ~= nil then Filters.key = (key == "fav") and "fav" or "all"; Filters.invalidate() end
    if Search ~= nil then Search.refresh() end
end

-- Where the tabs are: "Artisan > Smithing", "Gear" (a group, all of it), or nil on All.
function Shelves.where()
    if Shelves.tab == "all" or Shelves.tab == "fav" then return nil end
    local g = Shelves.groupByKey[Shelves.tab]
    if Shelves.sub ~= nil then return Shelves.byKey[Shelves.tab .. "." .. Shelves.sub].label end
    return g.tab
end

-- Are the headings shown? (A group's tab, nothing typed in the search, and not the Favorites list - that one keeps its own order. 3.2.22:
-- the All tab lists every item in number order, as it used to.)
function Shelves.active()
    return Shelves.ready and Shelves.tab ~= "all" and Shelves.tab ~= "fav" and not Search.active and Filters.key ~= "fav"
end

-- The list sorted shelf by shelf (each shelf keeps the list's own order).
function Shelves.sort(list)
    local buckets, keys = {}, {}
    for key, e in pairs(Shelves.byKey) do buckets[key] = {}; keys[e.order] = key end
    for _, slot in ipairs(list) do
        local b = buckets[Shelves.of[slot] or OTHER] or buckets[OTHER]
        b[#b + 1] = slot
    end
    local out = {}
    for _, key in ipairs(keys) do
        for _, slot in ipairs(buckets[key]) do out[#out + 1] = slot end
    end
    return out
end

-- Work the shelves out, a part of the item list each tick so the game does not stop for it. (3.2.28) First the moment the item list is
-- read, with what is known then - right-click options (Wear, Wield, Eat, Drink ...), names, the items' own quests - and again each time
-- something better has been read since: the equipment pass (slot words, wear requirements), the kind words, the recipes. After the sort
-- with all of them, it stops. The tabs work from the first sort on; the later ones only move some items to a better shelf.
-- (3.2.33: at the paced speed, Scan.full - 600 a tick at full pace, fewer while the game struggles. It was a fixed 2,000 a tick, the one
-- pass the lag control could not slow down: it started the moment the item list was read and made a big lag spike there.)
local PER_TICK, pos, building = 600, 1, {}
SHELVES_PER_TICK = 400 -- (3.2.61: the most items sorted into groups a tick)
local builtWith, buildingWith, buildingAll, finished = nil, nil, false, false
-- (3.2.34: two sorts, not four - once the equipment pass is read, a few seconds after the items (its styles and the game's categories are
-- what most groups go by), and once everything is. The sort by names alone at the very start and the one in between are gone: each sort
-- costs a pass over every item, and they all fell in the busiest seconds of the start-up.)
local function whatIsRead()
    local g, t = gearRead(), Tags.ready == true
    local r = Recipes.allRead ~= nil and Recipes.allRead() == true
    if not g then return nil, false end
    if t and r then return "gear words recipes", true end
    return "gear", false
end
-- (3.2.34) After a sort, the list is drawn again as it is - not as a new search, which folded an open group of forms and went back to the
-- first page, and made the tabs and lists jump while the plugin loaded. On All (every item, in number order) the groups change nothing
-- that is shown, so it is not drawn again at all.
local function redraw()
    if Groups ~= nil and Groups.rekey ~= nil then pcall(Groups.rekey) end -- (3.2.43: the armour sets' group needs the categories)
    if ShelfTabs ~= nil and ShelfTabs.paint ~= nil then pcall(ShelfTabs.paint) end
    -- (3.2.50: on All too while minigame items are hidden - which items those are is only known now)
    if Shelves.tab == "fav" or (Shelves.tab == "all" and not (Filters ~= nil and Filters.hide.minigames)) then return end
    if Filters ~= nil then Filters.invalidate() end
    if Window == nil or Window.pages == nil then return end
    for key, p in pairs(Window.pages) do
        if key == Window.active then
            if p.refresh ~= nil then pcall(p.refresh, false) end
        else p.searchStale = true end
    end
    if Window.refreshStatus ~= nil then pcall(Window.refreshStatus) end
    if Window.refreshPager ~= nil then pcall(Window.refreshPager) end
end
Passes.add("shelves", function()
    if finished or not Items.loaded then return end
    if pos == 1 then
        local with, all = whatIsRead()
        if with == nil or with == builtWith then return end -- (not read yet, or nothing new read since the last sort)
        buildingWith, buildingAll = with, all
        makeStyleWords()
        makeBaseStyle()
        mainOf = {}
        for n, name in pairs(skillNames or {}) do if type(name) == "string" then skillNo[string.lower(name)] = n end end
        styleCache = {}
    end
    -- (3.2.61: never above SHELVES_PER_TICK a tick - it was Scan.full(600), up to 1,800 a tick once the game coped, and that much a tick
    -- started the catch-up freezes after "recipes ready"; fewer while the game struggles)
    local last = math.min(#Items.ids, pos + math.max(50, math.floor(SHELVES_PER_TICK * math.min(1, Scan.paced()))) - 1)
    for slot = pos, last do
        local id = Items.ids[slot]
        for _, m in ipairs(matchList) do
            local r = m.test(slot, id)
            if r then building[slot] = (type(r) == "string") and r or m.key break end
        end
        -- (3.2.34) Nothing above placed it: the game's category for it, then its Grand Exchange category, before "Everything else"
        if building[slot] == OTHER then building[slot] = catShelf(id) or GE_SHELF[geOf(id) or -1] or OTHER end
    end
    pos = last + 1
    if pos <= #Items.ids then return end
    Shelves.of, building, pos = building, {}, 1
    builtWith, finished = buildingWith, buildingAll
    Shelves.stage = buildingAll and 2 or 1 -- (1: sorted without everything; 2: with all of it)
    Shelves.ready = true
    Shelves.sortedAt = Shelves.sortedAt or {}
    Shelves.sortedAt[#Shelves.sortedAt + 1] = tickCount .. " (" .. builtWith .. ")"
    redraw()
end, function() return finished end, function() finished = true; Shelves.ready = true end)

end }
