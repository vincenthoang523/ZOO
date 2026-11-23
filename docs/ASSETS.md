# Roblox assets

Everything is uploaded to group `229775176`. Uploads are permanent, so a changed model is uploaded again under a new `_vN` name rather than replacing the old one.

## Blender kits (Model assets)

| Asset id | Kit | Source file |
|---|---|---|
| 121294579115273 | ZooKit (first full kit) | `blender/export/ZooKit.glb` |
| 127314970843295 | ZooKit_Enclosure_v2 | `blender/export/ZooKit_Enclosure_v2.glb` |
| 100753643072663 | ZooKit_Plants_v2 | `blender/export/ZooKit_Plants_v2.glb` |
| 115179040051603 | ZooKit_Plants_v3 | `blender/export/ZooKit_Plants_v3.glb` |
| 140253047514197 | ZooKit_Trees_v4 | `blender/export/ZooKit_Trees_v4.glb` |
| 118420671503999 | ZooKit_Trader_v1 | `blender/export/ZooKit_Trader_v1.glb` |
| 108658743696915 | ZooKit_Props_v2 | `blender/export/ZooKit_Props_v2.glb` |
| 87748702725793 | ZooKit_Board_v2 (single-pole Top Earners board) | `blender/export/ZooKit_Board_v2.glb` |
| 74251838140516 | ZooKit_EnclosurePalm_v3 (mesh enclosure with rock wall and waterfall, curved palm) | `blender/export/ZooKit_EnclosurePalm_v3.glb` |
| 117771398757994 | ZooKit_Enclosure_v4 (rock behind the waterfall pool) | `blender/export/ZooKit_Enclosure_v4.glb` |
| 85122827813192 | ZooKit_Race (gravel race loop, start arch, log, hay, rocks, mud, boost ring, sign-up pad, opened gate) | `blender/export/ZooKit_Race.glb` |
| 111350055854999 | ZooKit_Race_v2 (thin boost ring, round island ground, border fence) | `blender/export/ZooKit_Race_v2.glb` |
| 70951429730671 | ZooKit_RaceStones_v1 (the track's pebbles and edging stones in 8 sectors, `RaceStones1`-`8`) | `blender/export/ZooKit_RaceStones_v1.glb` |
| 131718121123170 | ZooKit_RaceStones_v2 (the same stones, every face turned outward; this is the one in use) | `blender/export/ZooKit_RaceStones_v2.glb` |

In Studio, the imported pieces become templates in `ServerStorage.ZooKit`, and copies of them are placed in `workspace.Zoo.Art`.

## Importing a kit into Studio

- **Scale:** 1 Blender unit = 1 stud.
- **Axes:** the importer maps Blender (x, y, z) to mesh-local (-x, z, y). Work out the import's transform from one mesh centre you know, then give each piece's pivot an extra half turn (`CFrame.Angles(0, math.pi, 0)`).
- **Colours:** colours are lost on import. Each mesh is named `<Piece>__<colour>`, and the import script sets `MeshPart.Color` from that suffix.

## Waterfall texture (Image assets)

| Asset id | Image | Source file |
|---|---|---|
| 76830687438614 | WaterfallBody: soft wavy bands, body layer of the fall and the pool | `blender/export/WaterfallBody.png` |
| 123457945444194 | WaterfallWisps: thin tapered wisps, two layers on the fall | `blender/export/WaterfallWisps.png` |
| 81721995905362 | FoamPuffs: 2x2 flipbook of foam clusters for splash, spray, mist and churn | `blender/export/FoamPuffs.png` |
| 74750638253978 | Droplets: 2x2 flipbook of droplets | `blender/export/Droplets.png` |
| 71013397557210 | WaterfallStreaks_v2: hard streaks (replaced by Body and Wisps; unused) | `blender/export/WaterfallStreaks.png` |
| 82233352105274 | WaterfallStreaks (first try, streaks ran sideways on the Beam; unused) | none |

A Beam lays an image's height along its length, so streaks have to be drawn vertically. For a flipbook, setting the emitter's FlipbookFramerate to 0 and FlipbookStartRandom to true gives each particle one random frame that it keeps.

## Icons (Image assets)

The icon ids are kept in `Config.ICONS` in `src/ReplicatedStorage/Zoo/Config.luau`. There are two packs:

- **FOLK icon pack:** uploaded 2026-11-15.
- **Free Icon Pack v3.1:** uploaded 2026-11-16.

To change an icon everywhere, swap its id in `Config.ICONS`.

## Particle images (Creator Store decals)

Free decals from the Creator Store, not ours. Particles use the decal's image id, which differs from its decal id. In `ZooClient`, the `FX` table holds the image ids. The decal ids below are for finding each one again on the store.

| Use | Image id | Decal id |
|---|---|---|
| Snow, Frozen | 4485122848 | 4485122860 |
| Rain streak | 18975587175 | 18975587206 |
| Rain splash ring | 103532369150032 | 100938956257211 |
| Meteor glow (head halo, core, sparks) | 90676085484425 | 113705035723267 |
| Meteor dust cloud | 116843503185853 | 96685992574014 |
| Gold (coin) | 99051818597913 | 89043974367538 |
| Diamond (gem) | 743807896 | 743807897 |
| Rainbow (4-point glint) | 112882057182762 | 98450296135718 |
| Matrix (0 / 1) | 7603617427 / 7603634841 | 7603617460 / 7603634848 |
| Soaked (water drop) | 377760449 | 377760451 |
| Misty (cloud puff) | 13678395731 | 13678395771 |
| Electric (bolt) | 13701253806 | 13701253844 |
| Cosmic (star) | 5639840603 | 5639840621 |

## Not set yet

`Config.PASSES` and `Config.PRODUCTS` are still `0`, so the shop shows "SOON". `Config.GROUP_ID` is also still `0`, so the Free Reward doesn't ask players to join the group.

## Game passes and developer products (universe 10776824767)

Created through Open Cloud on 2026-11-19. Pass prices lowered on 2026-11-23 so all three cost 427 Robux together. Icons are drawn by `blender/make_pass_icons.py` and saved in `blender/export/icons/`.

| Id | Kind | Name | Robux |
|---|---|---|---|
| 2096448686 | Game pass | VIP (+20% cash) | 79 |
| 2094550605 | Game pass | 2x Money | 199 |
| 2093692759 | Game pass | 2x Luck | 149 |
| 3733847302 | Developer product | Luck Boost (2x luck, 5 min) | 49 |
| 3733847308 | Developer product | Starter Pack ($25K + 30 min 2x luck) | 99 |
| 3733847314 | Developer product | Double Offline Cash | 25 |

## Race layout

The track's pebbles and edging stones are 24 MeshParts (`pebble1`-`8`, `pebbleLight1`-`8`, `rock1`-`8`) inside `RaceTrack`, one set per 45-degree sector. Don't merge them back into one mesh each: Roblox draws a single mesh of thousands of loose chips spread over 320 studs with long stray triangles. In Studio they were placed from the build stats, then raised to match the current script (edging stones +0.2, pebbles +0.03); the placed meshes are v2, built by the current script. Stones are made by `_stone()`, which turns every face outward: Blender's recalc_face_normals left about half of them inside out, and Roblox showed those hollow. The old one-piece meshes are in `ServerStorage.OldEnclosures.RaceTrackStones_v0`.

The track mesh is visual only. `RaceBuilder` lays the collision as invisible parts: 120 boxes under the gravel, rim boxes between the hedge and the track, wedge ramps down the outer shoulder, and a 72-piece wall in the border fence. The ring, obstacle, grid and pad positions are in `ReplicatedStorage.Zoo.RaceLayout`, which uses the same numbers as `blender/race_layout.py`. To move anything, edit both files, then run `require(game.ServerStorage.RaceBuilder:Clone()).build()` from the command bar.
