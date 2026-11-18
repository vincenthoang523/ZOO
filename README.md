# Draw a Zoo

A Roblox game where you draw animals. They walk around your zoo pen and earn cash every second, and you spend that cash on upgrades. Up to 7 players per server.

- **Roblox place:** ZDOTTY2TACT, place id `108109255887789`, universe `10776824767`
- **Owner:** group `229775176` (all assets are uploaded to this group)

This repo is the record of the game's source: scripts, Blender models and where each asset lives. The place in Roblox Studio is still where the game actually runs. Copy any changes made in Studio back into this repo.

## Layout

| Path | What it is |
|---|---|
| `src/ReplicatedStorage/Zoo/Config.luau` | Every tunable number: rarities, mutations, prices, daily rewards, icon ids, animal templates |
| `src/ReplicatedStorage/Zoo/Render.luau` | Drawing format (run-length encoded 240×168 grid), drawing to GUI, the judge's scoring, server-side checks |
| `src/ServerScriptService/ZooServer.server.luau` | Player data, plots, income, rarity rolls, purchases, admin `/reset` |
| `src/ServerStorage/EnclosureBuilder.luau` | Builds the 7 plot enclosures (`workspace.Zoo.Art.Enclosure1-7`) from Parts and copies of the kit props. Run from the command bar |
| `src/ServerStorage/EnclosureCheck.luau` | Checks that no enclosure part is floating or unanchored |
| `src/StarterPlayer/StarterPlayerScripts/ZooClient.client.luau` | All UI (HUD, menus, draw editor, roll screen), walking animals, plot signs, Top Earners board, intro cinematic |
| `blender/build_zoo_kit.py` | Builds every map mesh in code inside Blender and exports `.glb` files |
| `blender/DrawAZoo_Kit.blend` | The Blender scene the script builds |
| `blender/export/` | Exported `.glb` kits as uploaded to Roblox, plus `ZooKit_stats.json` (triangle counts, floating-part check) |
| `blender/renders/` | Preview renders of each piece |
| `docs/ASSETS.md` | Roblox asset ids for every uploaded model and icon |
| `CHANGELOG.md` | What changed, and when |

Script file names follow the Rojo convention: `.server.luau` is a Script, `.client.luau` is a LocalScript, and plain `.luau` is a ModuleScript. They are not synced by Rojo yet, so changes are copied by hand.

## Not in this repo

- **The place file itself**, including the map layout and the parts used as colliders and sign anchors. That lives in Roblox's version history.
- **The reference screenshots** of other games, which belong to their creators.
- **Safari Sam's `Animate` script**, which is Roblox's stock character animation script.
