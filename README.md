
# Too Many Runes

Too Many Runes is an item index and recipe viewer for RuneScape 3, based on the popular JEI/NEI/TMI mods from Minecraft. Look up any item and see how it's made, what it's used for and where you can get it.

**Version:** 3.0.64<br>
**Needs:** the PrettyUI plugin

<p align="center"><img src="images/Recording%202026-11-06%20181034.gif" alt="Searching in Too Many Runes"></p>

## Features

* One window with an item list on the left and the item's details on the right
* **Recipe** tab: what an item is made from, where, and the level you need
* **Uses** tab: everything an item is used to make
* **Source** tab: where you can mine, catch, cut or dig it up
* Click a material to jump to it, or a station or skill picture to see everything made there
* Favorites and a Recently viewed panel
* Right-click an item in your backpack, bank or on the ground and pick Recipe, Uses or Source to open it in the plugin
* Settings for hidden items, mouse wheel direction, hover colour and more

## Searching

* A name: `iron bar`
* An item number: `#1205`
* A skill: `@smithing`, with a level if you like: `@smithing >60`, `@smithing <60` or `@smithing 60-70`
* A station: `@furnace`, `@anvil`, `@range`, `@altar`
* A kind of item: `@food`, `@potion`, `@weapon`, `@armour`, `@feet`, `@bow`
* Mix them: `dragon @smithing` or `sword >60`
* A place things are gathered from: `@castra debris`, `@copper rock`

<p align="center"><img src="images/Too%20Many%20Runes%20demo%20compressed.gif" alt="Too Many Runes demo"></p>

## How it works

Most of the data is read from the game itself, plus a few things checked by hand. After you log in, the plugin needs about a minute to read the game's data, so some recipes and uses only show up once it's done.

## Notes

This plugin was made with the help of AI. If something looks wrong or is missing, please report it to Toomanyrunes99@gmail.com.

## Installing (RuneScape Beta)

1. **Download it.** Click **Too Many Runes 3.0.64.zip** at the top of this page, then click the **download button** (the arrow pointing down, on the right).
2. **Unzip it.** Find the zip in your Downloads folder, right-click it, choose **Extract All**, then click **Extract**. Inside you'll find a folder called **too-many-runes**.
3. **Open the plugins folder.** Click the address bar at the top of any File Explorer window, paste this and press Enter:
   ```
   C:\ProgramData\Jagex\RuneScape-BETA\dev_plugins
   ```
   If there's no `dev_plugins` folder, make one with that exact name inside `RuneScape-BETA`.
4. **Copy it in.** Drag the **too-many-runes** folder into `dev_plugins`. It should look like `dev_plugins\too-many-runes\main.lua`, not one folder deeper.
5. **Get PrettyUI.** Install the **PrettyUI** plugin from the in-game Plugin Hub. Too Many Runes needs it to work.
6. **Turn it on.** Start the RuneScape Beta and log in. **[Press alt + ~ to open the console]**, then type:
   ```
   Prf (Plugin Refresh)
   Followed by
   prl too-many-runes
   ```
   **[Check: is this the right command for a first-time load?]**
7. **Wait a minute.** The plugin reads the game's data after you log in, so give it about a minute before every recipe shows up.

### Updating

Delete the old `too-many-runes` folder from `dev_plugins`, then repeat steps 1–4 and step 6.
