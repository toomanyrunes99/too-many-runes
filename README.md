
# Too Many Runes

Too Many Runes is an item index and recipe viewer for RuneScape 3, based on the popular JEI/NEI/TMI mods from Minecraft. Look up any item and see how it's made, what it's used for and where you can get it.

**Version:** 3.2.03<br>
**Needs:** the PrettyUI plugin

<p align="center"><img src="images/click-through-materials.gif" alt="Clicking through a recipe's materials in Too Many Runes"></p>

## Features

* One window with an item list on the left and the item's details on the right
* **Recipe** tab: what an item is made from, where, and the level you need
* **Uses** tab: everything an item is used to make
* **Source** tab: where you can mine, catch, cut, dig up or buy it, and which bosses and clue scrolls give it
* Click a material to jump to it, or a station or skill picture to see everything made there
* The forms of an item (doses, charges, augmented, dyed, upgrades + 1 to + 5 ...) stack under one picture: click it to unfold them
* Favorites and a Recently viewed panel
* Right-click an item in your backpack, bank or on the ground and pick Recipe, Uses or Source to open it in the plugin
* Settings for hidden items, mouse wheel direction, hover colour and more
* A junk filter that hides clutter like MTX, loyalty and event items
* Minimize the window to a small rune icon you can drag anywhere

## Searching

* A name: `iron bar`
* An item number: `#1205`
* A skill: `@smithing`, with a level if you like: `@smithing >60`, `@smithing <60` or `@smithing 60-70`
* A station: `@furnace`, `@anvil`, `@range`, `@altar`, `@energy rift`
* A kind of item: `@food`, `@potion`, `@weapon`, `@armour`, `@feet`, `@bow`
* Mix them: `dragon @smithing` or `sword >60`
* A place things are gathered from: `@castra debris`, `@copper rock`, `@rock`, `@tree`, `@wisp`, `@patch`
* Drops and rewards: `@araxxi`, `@boss`, `@slayer morytania`, `@medium clue`, `@shop`
* Made in the backpack: `@backpack`; quest items: `@quest`; compost: `@compostable`
* More kinds: `@ore`, `@bar`, `@log`, `@fish`, `@herb`, `@seed`, `@gem`, `@rune`
* Narrow any search: `@f2p`, `@members`, `@ge`, `@untradeable`, or a right-click option like `@teleport`

<p align="center"><img src="images/search-suggestions.gif" alt="Search suggestions while typing"></p>

## See it in action

**Item stacks:** the forms of an item share one picture. Click it to unfold them.

<p align="center"><img src="images/item-stacks.gif" alt="Unfolding an item stack"></p>

**Recipe, Uses and Source:** every tab, and clicking through to where things come from.

<p align="center"><img src="images/recipe-uses-source.gif" alt="The Recipe, Uses and Source tabs"></p>

**Crafting stations:** click a station to see everything made there.

<p align="center"><img src="images/crafting-stations.gif" alt="Forge and anvil recipes"></p>

**Sources and places:** search a gathering spot or a shop.

<p align="center"><img src="images/sources-and-place-searches.gif" alt="Searching a herb patch"></p>

**Recently viewed:** jump back to anything you looked at.

<p align="center"><img src="images/recently-viewed.gif" alt="The Recently viewed panel"></p>

**Station searches:** `@altar` and the Eternal magic stages.

<p align="center"><img src="images/altar-search.gif" alt="Searching @altar"></p>

## How it works

Most of the data is read from the game itself, plus a few things checked by hand. After you log in, the plugin needs about a minute to read the game's data, so some recipes and uses only show up once it's done.

## What's new in 3.2.03

* Item stacks: the forms of an item share one picture; click it to unfold them
* "Made in: Backpack" on the Recipe tab, compost bins, quest items and many new search words
* Pictures for more crafting stations
* Less clutter, no lag while typing, and about a quarter of the memory it used before

See [CHANGELOG.md](CHANGELOG.md) for the full list.

## Feedback and collaboration

Feedback and bug reports are welcome here on GitHub (the Issues tab) or in the Too Many Runes post on the RuneScape Plugin Portal Discord. You can also email Toomanyrunes99@gmail.com.

You're welcome to read, use and borrow code from this plugin to build a better item index plugin, or add-ons for this one. Since AI helped make this plugin, AI tools may also be used to review its code. The RuneScape Wiki information inside the plugin stays under the wiki's licence (CC BY-NC-SA 3.0).

## Notes

This plugin was made with the help of AI. If something looks wrong or is missing, please report it (see above).

Some information comes from the RuneScape Wiki (runescape.wiki), used under CC BY-NC-SA 3.0.

## Installing (RuneScape Beta)

1. **Download it.** Click **Too Many Runes 3.1.50.zip** at the top of this page, then click the **download button** (the arrow pointing down, on the right).
2. **Unzip it.** Find the zip in your Downloads folder, right-click it, choose **Extract All**, then click **Extract**. Inside you'll find a folder called **too-many-runes**.
3. **Open the plugins folder.** Click the address bar at the top of any File Explorer window, paste this and press Enter:
   ```
   C:\ProgramData\Jagex\RuneScape-BETA\dev_plugins
   ```
   If there's no `dev_plugins` folder, make one with that exact name inside `RuneScape-BETA`.
4. **Copy it in.** Drag the **too-many-runes** folder into `dev_plugins`. It should look like `dev_plugins\too-many-runes\main.lua`, not one folder deeper.
5. **Get PrettyUI.** Install the **PrettyUI** plugin from the in-game Plugin Hub. Too Many Runes needs it to work.
6. **Turn it on.** Start the RuneScape Beta and log in. **[Press alt + ~ to open the console]**, then type:
Plugin Refresh command:
   ```
   Prf
   ```
   
   Followed by the plugin reload command:
   ```
   prl too-many-runes
   ```
7. **Wait a minute.** The plugin reads the game's data after you log in, so give it about a minute before every recipe shows up.

### Updating

Delete the old `too-many-runes` folder from `dev_plugins`, then repeat steps 1–4 and step 6.
