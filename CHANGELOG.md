# Changelog

Newest first. "Place vN" is the Roblox place version the change was saved in, where known.

## 2026-11-20

- **Race polish** (place v77, `ZooKit_Race_v2`):
  - **Thinner rings:** the boost rings are a thin hoop that rests on the gravel. The stone block under each one is gone.
  - **Border:** a rail fence runs round the outside of the race loop, with a tall invisible wall in it, so players can't walk off into the scenery.
  - **Baseplate:** the 2048-stud Horizon slab is replaced by a round island ground just past the foliage, with a grass lip and an earthy underside. A cylinder underneath it (`Colliders.GroundCollider`) does the collision. The old slab is in `OldEnclosures`. The two largest hills were shrunk to 80%, and every hill was pulled in so it sits on the new ground.
  - **Foliage:** the empty south sector, where the old race grounds were, is filled with 150 more trees, bushes, flowers, tufts and rocks. All 1,438 props were lowered onto the ground; a raycast check finds none floating.
  - **Gate:** the swung-open doors now block players (`Colliders.GateDoor`).
  - **Join from the gate:** walking out through the gate asks "Would you like to join the next race?". It shows your racer (CHANGE opens the picker) and has YES / NO THANKS. It only asks on the way out, and not again for 20 seconds.
  - **Fixed:** the earth rim between the hedge and the gravel, and the track's outer shoulder, had no collision. Players dropped into a ditch there that racers couldn't jump out of. Invisible rim boxes and shoulder ramps now cover both.
- **Game passes and products are live:** VIP (199), 2x Money (399) and 2x Luck (299) passes, and the Luck Boost (49), Starter Pack (99) and Double Offline Cash (25) products, each with its own icon (`blender/make_pass_icons.py`). Their ids are in `Config.PASSES` and `Config.PRODUCTS` (place v74).
- **Old race grounds scrapped, gate opened:** the strip of land south of the gate is gone (kept in `ServerStorage.OldEnclosures.RaceGrounds_v1`). The gate's doors now stand swung open into the park.
- **Animal races:** a gravel loop runs round the outside of the hedge (`ZooKit_Race`, built by `race_track()` and friends in `blender/build_zoo_kit.py`, laid out by `ServerStorage.RaceBuilder` from `ReplicatedStorage.Zoo.RaceLayout`).
  - Walk onto the pad inside the gate and press E, pick one of your animals and join the queue. When enough racers are queued (2, or 1 in Studio), everyone is put on the starting grid riding a hopping cutout of their animal, and a 5-second countdown runs.
  - Two laps of the zoo. Everyone runs at the same speed (32). The 11 striped rings give a 2.5-second boost (58), mud patches slow you down (15), and logs, hay bales and rock piles block the way. Jumping is off while racing.
  - The server tracks progress round the loop, so cutting through the park doesn't count. It also handles rings, mud, places and prizes. The HUD shows place and lap, the countdown, GO! and BOOST!.
  - The winner spins the prize wheel: 10 or 30 minutes of income, a 1-hour jackpot, or 5 minutes of 2x Luck or 2x Money. 2x Money is a new boost (`moneyUntil` in the save). Every other finisher gets 2 minutes of income. Settings are in `Config.RACE`.
  - Code: `ServerScriptService.ZooRace` (race), `ServerScriptService.ZooApi` (ZooServer's data for other server scripts), and the Race, race HUD and Prize Wheel sections in `ZooClient`.

## 2026-11-19

- **Side menus, second pass:** the left and right menus are now mirrored columns at the same height, so their rows line up across the screen. All eight buttons are one smaller size (186 x 56, was up to 222 x 68 and 232 x 96), with a 12 px gap.
- **Calm buttons everywhere:** every green action button now uses the calm mint-to-green style with no studs. That covers Sell, Equip, Equip Best, daily Claim, Free reward tasks, editor tabs, Awesome, Owned/Maxed/Claimed states and the price bar on each plot's in-world Upgrade Zoo sign. Only the SHOP menu button keeps its bright lime.
- **Right menu:** Daily, Boost, Draw an Animal and Starter Pack are now one column at the top right. All four are the same width, with the same 16 px gap between them, and are about 10% smaller than before. The boost countdown now sits beside the Boost button.
- **Buy buttons:** the Upgrade and Robux purchase buttons are a calm mint-to-green gradient with no stud texture (`P.calm`).
- **Economy rebalance:** upgrade prices are now a fitted per-level table (`Config.LUCK_COSTS`, `Config.CAP_COSTS`) instead of `500 x 4^level` and `300 x 3^level`. Under the old prices an active player maxed out in about 25 minutes. `tools/balance_sim.py` puts it at about 24 hours with no game passes and about 11 hours with VIP, x2 Money and x2 Luck. Upgrades come minutes apart at the start and about two hours apart at the end.

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
