# Changelog

Newest first. "Place vN" is the Roblox place version the change was saved in, where known.

## 2026-11-19

- **Trader stall rebuilt** in the style of the new enclosure gateways, by `trader_stall()` in `blender/build_zoo_kit.py`, exported as `ZooKit_Trader_v2`.
  - Stone plinth with a cream rim, a plank deck and a cream front step.
  - Four round cream pillars with stone feet, red collars, dark capitals and curved knee braces, carrying beams with a cream cornice.
  - A red and cream gabled canvas roof with scalloped valances front and back, a ridge cap with yellow finials, and red paw medallions on both gables.
  - The ANIMAL TRADER sign stands on the front slope of the roof in a cream frame with two struts and yellow knobs. The text is still the `Sign` part's SurfaceGui.
  - A plank counter with a red band and a paw badge, a fruit basket, a bell and crates; low side walls; a back wall with two shelves of jars and crates; hay bales and crates inside; potted bushes on the front corners; two hanging lanterns.
  - `floating_report()` comes back empty. It also caught that the old stall's fruit floated 0.35 studs above the basket floor; the fruit now rests on it.
  - `ServerStorage.StallBuilder` swaps the art in and moves the invisible colliders to match (deck, counter, counter top, and new back and side walls). Sam is raised onto the new deck. The old art is kept in `ServerStorage.OldSafariStall`.
  - `ServerStorage.StallCheck` checks the placed stall in Studio (everything reaches the plaza through touching parts). `EnclosureCheck.model` gained optional `skip` and `ground` arguments for it.

## 2026-11-18

- **Enclosures:** the part-built enclosures are replaced by one Blender mesh, `ZooKit_EnclosurePalm_v3`, built by `enclosure()` in `blender/build_zoo_kit.py` (place v59).
  - The back rock wall is a solid backbone with low-poly boulders sunk into its face and crest, fused into one rock surface with grass on top. No stacked or floating rocks, and no bushes on the ledges.
  - The fence uses round posts with accent collars and cream domes. Two round rails run through every post. The front corners have stone lantern pillars.
  - The gateway has round pillars, curved knee braces under the beam, a cream cornice, a striped scalloped awning and a paw sign.
  - The waterfall sheet starts inside the cliff's channel, rolls over the lip and drops into a stone-rimmed pond. Two scrolling streak Beams run down it at different speeds. Foam rolls over the lip, and the base has foam, droplets and mist particles. A client script (`Art.WaterfallFX`) pulses ripple rings across the pond.
  - `ServerStorage.EnclosureBuilder` now clones the mesh, tints the accent per plot, adds the props and VFX, and passes `EnclosureCheck` (0 floating, all 7 plots). The old part builder is kept in `ServerStorage.OldEnclosures.EnclosureBuilder_PartsV1`.
- **Waterfall, second pass** (place v61):
  - Rock now rises behind the pool at the top, so the water flows out of the cliff instead of off a cut-off slab. Uploaded as `ZooKit_Enclosure_v4`.
  - The falling water has three layers scrolling at different speeds: soft wavy bands for the body and two layers of thin tapered wisps. The pool on top has its own slow textured flow.
  - The splash uses custom foam-puff and droplet textures, with each particle showing one of four shapes. Particle sizes vary, and the foam squashes and stretches. The droplets point along their flight path. There is also low sideways spray, flat foam spreading on the pond, and a fainter mist. `Art.WaterfallFX` fires random bursts of foam and droplets so the splash never settles into a steady loop.
  - The textures are drawn by `blender/make_water_textures.py`.
- **Enclosure palms:** each palm is set by its trunk foot and turned to lean toward the front of the pen, away from the cliff. A raycast check shows at least 1.5 studs of clearance from the rock in every plot.
- **Palm trees:** the trunk leans most at the base and eases to vertical at the top, so it flows into the upright crown. All 65 palms in the map were swapped, keeping their position and scale.

## 2026-11-17

- **Camera:** after the intro, the camera now sits behind the player and faces their own zoo head-on. Max zoom-out is halved, from 128 to 64 studs (place v52).
- **Menus:** windows now dim the screen behind them. Each window has a blue frame with a detailed header strip (gloss, shine streaks, faint paws), and its content sits in a dark navy panel with a top shadow, so cards and buttons stand out. The draw editor's side panels are navy instead of white (place v51).
- **Center billboard:**
  - Rebuilt in Blender on a single central pole, with a gold-trimmed frame, marquee bulbs and a red TOP EARNERS plaque with a crown. Uploaded as `ZooKit_Board_v2` and placed at 1.3× scale.
  - The screen is now a 7-slot leaderboard: rank badges, avatar headshots, names and $/s, all at fixed text sizes. Your own row is outlined in yellow.
- **Lamps:** dimmed. The glass is frosted SmoothPlastic instead of Neon, and the light is brightness 0.35 (was 1.4), range 12 (was 18).
- **Outskirts:** the clustered scenery is replaced by 1,052 evenly spread pieces on a jittered 20-stud grid. None of them collide, and grass and flowers cast no shadows.

## 2026-11-16

- **Drawing:**
  - 12 eye styles.
  - The server drops eyes and stickers that sit off the drawing.
  - The drawing grid is raised to 240×168, and the drawing screen is bigger.
- **Plot signs:** the upgrade and draw signs now show live plot info.
- **Cash readout:** counts up smoothly instead of jumping.
- **Rebuilt in Blender, with no floating parts:**
  - lamps, benches and easels
  - the trader stall and Safari Sam
- **Foliage:** reworked so each tree and bush reads as a single shape. Acacia canopies now sit on separate levels.
- **New areas:** the outer foliage ring, a gate path and a race strip.
- **Look and feel:**
  - Cartoon lighting: sun and fill, colour correction, soft bloom and a blue atmosphere.
  - Emojis replaced with icons from the icon packs.
  - A new aerial orbit shot in the intro.
- **Animals:** shown as thin cutouts.

## 2026-11-15

- **Map:** first Blender low-poly kit (`ZooKit`), plus new enclosure, plant and tree kits. These replaced the first map, which was built from Roblox parts.
- **Intro:** now plays only on a player's first join, and only counts once it finishes. Admins can use `/reset` to replay it.

## 2026-11-14

- **First version of the game:**
  - core loop: draw → earn → upgrade
  - studded UI with shop placeholders
  - intro cinematic
  - 7 players per server
