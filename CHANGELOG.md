# Changelog

Newest first. "Place vN" is the Roblox place version the change was saved in, where known.

## 2026-11-23 (sound and weather)

- **Sound** (new `ReplicatedStorage.Zoo.Sfx`, all licensed Roblox library audio; the list is in `docs/SOUNDS.md`):
  - **Where sounds play:**
    - Every button click, and windows opening and closing.
    - Toasts (a soft pop, or a gentle "no" for errors).
    - Buying, selling, upgrading and rewards.
    - Brush strokes, which play lower with a bigger brush, and finishing a drawing.
    - The roll: a whoosh, ticks when each strip lands, a shimmer for Epic and up or a mutation, stars rising in pitch, and a sting on the verdict.
    - The race: countdown beeps, a horn, a boost whoosh, lap dings, applause for the top 3, and the prize wheel ticking.
  - **Variation:** every play nudges pitch +-4% and volume +-10%.
  - **Not annoying:** each sound has a cooldown and a voice cap.
  - **Music:** soft park music (5 APM tracks shuffled) and a race track. It ducks under the roll reveal.
  - **Toggles:** MUSIC and SOUND toggles sit over the cash and are saved with the player (`sound` in the save, `Remotes.Settings`).
- **Weather:**
  - **Five new weathers, each with its own mutation:**
    - Rain: Soaked x1.5, with blue drips.
    - Snow: Frozen x1.75, with an icy rim and sparkles.
    - Fog: Misty x2, see-through.
    - Thunderstorm: Electric x2.5, with crackling sparks.
    - Meteor Shower: Cosmic x3, with orbiting stars.
  - **3D effects:** rain and snow are particles round the camera, with splash rings on the ground. Storms flash and rumble, and near strikes draw a bolt. Meteor Shower is a starry night with shooting stars.
  - **Ambience:** each weather has its own sound loop.
  - **Timing:** weather comes round every 4-8 minutes (was 6-12).
- **Weather mutations wear off:**
  - They last a random 30 min to 3 h of real time (offline too), then the animal goes back to Normal and its income drops back (`a.me` in the save).
  - My Zoo shows the time left.
  - The Odds window lists only the live weather's mutation.
- **Matrix nerfed:** x8 -> x2.5. Owned Matrix animals were rescaled once, the first time they loaded, and got a timer.

## 2026-11-23

- **Smoother windows:** My Zoo, the trader and the race picker kept every animal card between opens and only rebuild them when your animals change. Tapping a card just moves the gold outline (was a full rebuild of every card: about 200 ms with 30 animals, now under 17 ms). The race picker had been rebuilding on every race update. Windows also fill before the pop animation starts, so a slow first fill no longer eats the start of the animation.
- **Matrix look:** the falling digit columns, which were clipped to a box that showed as a square behind the animal, are replaced by 18 small 1s and 0s floating in a loose ring round it. They bob, fade in and out, and flip between 0 and 1.
- **Rebalanced upgrades:** new costs fitted with `tools/balance_sim.py` (it now takes a schedule instead of one curve). An active player with no passes gets about 6 Enclosure Size and 5 Luck upgrades in the first 30 minutes. After that each upgrade takes about 1.5x as long as the one before, and the zoo is fully maxed after about 24 hours (about 11 hours with every pass). Luck costs: $2.7K to $110B (was $810K to $24B). Size costs: $3K to $56B (was $39K to $20B).
- **Cheaper passes** (set through Open Cloud), so a player with 500 Robux can buy all three: VIP 79 (was 99), 2x Luck 149 (was 250), 2x Money 199 (unchanged). Setting a price re-sends the pass icon (the same picture), so the passes have new icon asset ids.
- Also synced from Studio: `scaled()` fits a window as soon as it's built (for the Admin Panel), and a new admin id in `Config.ADMINS`.

## 2026-11-22

- **Performance** (from a performance check: one world animal drawing took ~11 ms to build on every client):
  - **Pens update in place:** the server only adds or removes the animals that changed (each animal part carries an `Id` attribute), instead of respawning the whole pen on every equip, sale, upgrade or pass purchase. A full pen used to freeze every client in the server for about 140 ms each time.
  - **Lighter world drawings:** animals in the world are drawn at 80 x 56 (step 3) instead of 120 x 84, and their drawings hide past 150 studs (was 300). About 28% fewer GUI instances per animal in the test.
  - **Windows redraw only when needed:** My Zoo, the trader and the race windows rebuild only when your animals or zoo size change, not on every State update (daily claims, race prizes, offline pay). With 50 animals that was about a 200 ms freeze each time.

- **Game page:** the experience is now called "Draw a Zoo" (was "ZDOTTY2TACT"), with a real description (was "GG"), and VR is off. Set through Open Cloud on the start place and the universe. Still to do in the Creator Hub by hand: the age rating (the maturity questionnaire decides it; free drawing needs the 16+ answer).
- **Playtest report fixes** (from a 30-minute test at place v117):
  - **Better animals no longer vanish into storage:** with a full zoo, a new animal that out-earns your weakest one takes its place, and the roll screen says where it went (swapped in, or sent to storage). SELL ALL UNEQUIPPED never sells an animal better than your weakest equipped one.
  - **Judge:** a filled rectangle no longer scores 5 stars (now 3). SIZE peaks at 30-50% of the canvas and falls to 0 for a full canvas, and NEAT drops when the shape runs into all four edges. Every template keeps its stars.
  - **Daily rewards:** after a missed day the window shows Day 1, which is what gets paid. Cash days now pay minutes of your income (Day 1 = 2 min ... Day 7 = 60 min), with the old amounts as a floor for new zoos. CLAIM! is burning gold so it no longer looks like CLAIMED.
  - **Luck past 1024x** now raises the mutation odds (x1.5 at 2048x, x2 at 4096x, x2.5 at 8192x), so luck items still do something for maxed players. The Odds screen shows it.
  - **Starter Pack** is once per player: the rail button hides and the Shop shows OWNED after it's bought (`starterBought` in the save).
  - **TOP EARNERS** title shows again: `Showcase.BoardHeader` is 3.3 deep instead of 2.912, so its text sits clear of the red sign mesh on both sides.
  - **Editor:** FINISH DRAWING keeps the drawing until the roll comes back, and checks for a full zoo first. Fill in the Shape tab won't flood the canvas through a gap in the outline. Picking a template jumps to the Paint tab. The name box stops at 20 characters.
  - **Race:** your own ride shows as a billboard facing your camera, so you can see it from the chase view. The side menus hide while you race.
  - **New players:** until the first animal, DRAW AN ANIMAL wears a START HERE! tag and a DRAW HERE! sign floats over your easel.
  - **Phones:** side menus, the cash readout and the race chips never shrink below 0.65x on touch screens. Windows fit by height with room for their titles, so the editor no longer runs off the bottom of wide screens.
  - **Shop and menus:** BEST! moved from VIP to x2 Money. Closing Odds returns to the window you opened it from. FREE hides once claimed. My Zoo's RELEASE is now SELL (same price as Safari Sam). Selling Epic and up asks SURE? first. My Zoo picks your best earner first, and its $/s no longer overlaps UNEQUIP.
  - **Other:** a lighter Matrix weather tint, tap to skip the roll screen, toasts move to the bottom of the screen while a window is open, showcase animal names only show up close, and the Free Reward asks players to join the group (`Config.GROUP_ID` = 229775176).
  - Also synced: `ZooAdmin` and `ZooApi` changes made in Studio (the Admin Panel's Moderate tab: wipe, ban and unban).
  - Not changed: the game page settings (name, description, age rating, VR), which live in the Creator Hub.

- **Race track no longer looks glitched:** big grey wedges covered the gravel, and edging stones showed as hollow slivers.
  - **Cause:** the pebbles and edging stones were three single meshes, each with thousands of loose chips spread over 320 studs. Roblox drew them with long stray triangles, whatever the render fidelity, even though the uploaded data is clean.
  - **Fix:** they are now 8 sector pieces (`race_stones()` in `blender/build_zoo_kit.py`, uploaded as `ZooKit_RaceStones_v1`), placed inside `RaceTrack` in the workspace and in the `ZooKit` template. Same stones, same spots.
  - **Edging stones:** they sit a little higher (+0.2 studs), and the outer ones a little further in, so none sink until only a sliver shows. Pebbles are +0.03.
  - The old meshes are kept in `ServerStorage.OldEnclosures.RaceTrackStones_v0`.
  - **Hollow stones fixed:** about half the stones were inside out (every face pointing inward), so Roblox hid their near side and they looked hollow or missing a side. `_stone()` now turns every face outward. Uploaded as `ZooKit_RaceStones_v2` and swapped in; a check of all 32,500 stone faces finds none facing inward.

## 2026-11-21

Scripts re-exported from Studio at place v108. This also catches up work saved in Studio but never pushed to the repo: the Admin Panel (`ZooAdmin`), the weather events (`ZooWeather`, Matrix weather), the race reset and solo runs, and the stall build/check helpers.

- **Mutation looks** (place v108): each mutation now looks like its name wherever an animal shows (zoo pens, race mounts, the roll screen, menus). See `MUT_LOOK` and `mutationFx` in `ZooClient`.
  - **Gold:** warm tint, orange rim, sparkles, gold glow.
  - **Diamond:** icy tint, cyan rim, white sparkles.
  - **Rainbow:** the rim cycles through the colours, with rainbow particles.
  - **Matrix:** green tint and an aura of falling 1s and 0s.
- **Race: no more getting stuck** (place v80):
  - **Skid:** each car rides 0.35 studs up on an invisible round skid, so its flat bottom no longer catches on edges in the invisible floor under the gravel.
  - **Walls:** invisible walls run along both gravel edges, so a car can't drop into the ditch or the trench by the fence. They are in the `RaceWall` collision group, so only race cars hit them and people on foot still cross the track.
  - **Reverse:** top reverse speed is 18 (was 10), and steering while reversing works at once.
- **New in the repo:** `ZooAdmin.server.luau`, `ZooWeather.server.luau`, `EnclosureCheck.luau`, `StallCheck.luau`, `StallBuilder.luau`.

## 2026-11-20

- **Race driving:** racers now sit on their animal and drive it like a car (place v78).
  - **The car:** the cutout is built into a small car: an invisible low body with no friction, a VehicleSeat on the cutout's back, a LinearVelocity and an AlignOrientation. The driver's client owns its physics.
  - **Controls:** WASD, the arrow keys, a gamepad or the mobile thumbstick drive the car through the seat.
  - **Speed:** the car pulls away slowly, eases up to 40 in about 5 seconds and coasts down when you let go. S brakes, then reverses at up to 10.
  - **Steering:** the wheel follows the stick with a 0.3-second lag and turns at most 75 degrees a second. It can't turn on the spot, though crawling lets you steer a little to nose out of a crash. Hitting a log, hay or rock drops your speed.
  - **Speed changes:** the server sets each car's top speed: normal 40, boost 62 or mud 16. Boosts accelerate hard; mud and the end of a boost brake you down.
  - **Grid:** the two rows are now further apart so the cars fit. Jumping is off while seated, and anyone who leaves the seat is put back on.
  - **Tested:** a scripted driver finished 2 laps in 69 seconds with 12 boosts.
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
