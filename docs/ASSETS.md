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
| 130780260830533 | ZooKit_Trader_v2 (trader stall in the enclosure gateway style) | `blender/export/ZooKit_Trader_v2.glb` |

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

## Not set yet

`Config.PASSES` and `Config.PRODUCTS` are still `0`, so the shop shows "SOON". `Config.GROUP_ID` is also still `0`, so the Free Reward doesn't ask players to join the group.
