# Changelog

Newest first. "Place vN" is the Roblox place version the change was saved in, where known.

## 2026-11-22

- **Roblox policy fixes** (repo only, not in Studio yet). Robux luck items (2x Luck pass, Luck Boost, Starter Pack) count as "probability modifiers" under Roblox's [paid random items policy](https://create.roblox.com/docs/production/monetization/paid-random-items).
  - **Odds window:** shows every rarity with your odds now and with 2x luck, and every mutation's odds (they follow the live weather). The numbers have 4 significant digits and the window has Roblox's rounding note. It updates live while open. There are now ODDS buttons on the Luck Boost and Starter Pack cards too.
  - **Region check:** `PolicyService.ArePaidRandomItemsRestricted` players see N/A on those three items and can't open their purchase prompts.
  - **/take pass** only removes a pass an admin gave. It no longer removes a pass the player bought with Robux, and older saves where it did are fixed when the player next joins.

- **Admin Panel** (place v95; a red hammer ADMIN button under the left menu, admins only). Replaces typing commands; `/give`, `/take`, `/weather` and `/reset` still work as shortcuts.
  - **Security:** every button calls one RemoteFunction, `Remotes.Admin` (created by `ZooAdmin`). The server re-checks `isAdmin` on every call, rate-limits it, validates every argument and never trusts the client. The `Admin` player attribute only decides whether the button shows. Announcement and countdown text goes through Roblox's text filter.
  - **Players:** everyone in the server with avatar, cash, income and zoo size. GIVE (picks them for the Give tab), GO TO, BRING and KICK (press twice; admins can't be kicked).
  - **Give:** to yourself or the picked player: cash (K/M/B/T, or TAKE), minutes of 2x luck or 2x money, an animal (rarity, mutation, stars), and VIP / Money2x / Luck2x test flags. Both the admin and the player get a toast.
  - **Events:** a tile per weather (Matrix) plus two new server-wide events, 2x LUCK and 2x MONEY for everyone (`Config.BOOST_EVENTS`, applied in ZooServer's `luck()` and `rate()`). Duration in seconds, START and STOP. Running events show a strip with a countdown under the weather banner for every player.
  - **Announce:** a message (150 characters) that pops up as a big card for every player with the admin's Roblox headshot and name, for 5-30 seconds.
  - **Timer:** a titled countdown strip every player sees, which says NOW! at zero.
  - **Server:** players, uptime and place version; random weather on/off; stop all events; respawn everyone.
  - The weather banner, the event strips and the countdown now stack in one column at the top (`topStack`); toasts drop under it. `window()` takes an optional rim colour (the panel is red).
  - Icons: hammer, gear and newspaper from the FOLK pack (`Config.ICONS`).

## 2026-11-21

- **Admin give commands** (place v90): `ServerScriptService.ZooAdmin` adds two chat commands for testing. Only admins can use them (`Config.ADMINS` or the owner of the group that owns the game); for anyone else they do nothing. They run on the server from chat, so there is no remote a client could fire.
  - `/give cash 1.5m` adds cash (K, M, B, T suffixes; a minus amount takes cash away). `/give luck 30` and `/give money 30` add minutes of 2x luck or 2x money.
  - `/give animal mythic rainbow 5` gives an animal with that rarity, mutation (default Normal) and stars (default 5), drawn as a random showcase template. Rarity and mutation also take their number.
  - `/give pass vip` (or `money2x`, `luck2x`, `all`) and `/take pass ...` set a pass on or off in the admin's save (`passGrants`), which overrides the real ownership check on join. No purchase is made or touched; a real purchase clears the override.
  - `exodtust` (135018525) is now in `Config.ADMINS`: they are rank 254 in the group, not the owner, so `/reset` and `/weather` did nothing for them before.

- **Random weather and the Matrix mutation** (place v87):
  - **Weather:** `ServerScriptService.ZooWeather` starts a random weather every 6 to 12 minutes, for 2 to 3 minutes. It is server-wide and shown to everyone through two attributes on `ReplicatedStorage.Zoo`: `Weather` and `WeatherEnds`. Weathers are data in `Config.WEATHERS`: mutation and its chance, duration, icon, colour, Lighting look and falling characters.
  - **Matrix weather:** the sky goes dark green, green code falls down the screen behind the HUD, and a banner at the top shows the weather, the boosted odds and a countdown. Toasts move down under the banner while it is up.
  - **Matrix mutation:** new mutation 5, x8 income. It only rolls during Matrix weather, at 10% (Normal drops from 90% to 80%; Gold, Diamond and Rainbow are unchanged). A Matrix animal keeps its own colours and gets a pulsing green aura round its outline, plus a green glow and sparks, in the zoo and on the roll screen. Its cutout is 25% bigger so the aura fits; the drawing stays the same size.
  - **Odds in one place:** `Config.mutationChances(weather)` gives the roll's mutation odds; Normal takes whatever the others leave.
  - **Testing:** admins can type `/weather` (or `/weather matrix`) to start a weather and `/weather off` to clear it.

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
