# Sound and weather design (2026-11-23)

## Why
The game has no sound at all, and only one weather (Matrix). Sound makes every action feel rewarding, and slight pitch
variation keeps repeats from sounding robotic. More weathers give players more reasons to stay in the game. Each weather
brings a mutation that only exists while it is on.

## Goals
- Sound effects on every main action, with ±4% pitch and ±10% volume variation on each play.
- Sounds that never get annoying:
  - Each sound has a cooldown and a cap on how many copies play at once.
  - Repeated sounds (cash, brush strokes) play very quietly.
  - The music ducks during the roll reveal and races.
- Soft background music, with Music and SFX toggles on the HUD. Each player's choice is remembered.
- New weathers: Rain, Snow, Fog, Thunderstorm and Meteor Shower, alongside the existing Matrix. Each has its own look
  in the world, its own ambient sound and its own mutation.
- Weather mutations wear off. Each animal gets a random 30 min to 3 h, counted in real time (offline too). When it runs
  out, the animal goes back to Normal and its income drops back.

## Non-goals
- No uploaded audio: every sound comes from the Roblox audio library.
- Gold, Diamond and Rainbow stay permanent and keep their multipliers.
- No Heatwave or Aurora (possible later).

## Anti-goals
- Multipliers that break the game.
- Sounds that grate after an hour of play.
- Weather that hides the park.

## Mutations
Mutations are appended to `Config.MUTATIONS`, because saves store the index.

| Mutation | Weather | Income | Look on the animal |
|---|---|---|---|
| Matrix | Matrix | x2.5 (was x8) | unchanged |
| Soaked | Rain | x1.5 | blue tint, drips |
| Frozen | Snow | x1.75 | icy rim, frost sparkles |
| Misty | Fog | x2 | pale, wisps |
| Electric | Thunderstorm | x2.5 | yellow rim, crackling sparks |
| Cosmic | Meteor Shower | x3 | purple starry tint, orbiting stars |

Matrix animals that players already own have their income rescaled from x8 to x2.5 and get a timer the first time they
load (the first Matrix animal without `me`).

`a.me` is the os.time() at which the mutation ends. The server checks for expired mutations every 15 seconds and when a
player joins.

## Weather
- The gap between weathers drops to 4-8 minutes.
- Rain and snow become 3D particles in a box that follows the camera, replacing the flat screen overlay. Matrix keeps
  its falling code.
- Thunderstorm:
  - The sky flashes and thunder follows 0.3-1.5 s later.
  - Sometimes a bolt strikes inside the park.
- Meteor Shower: night sky with streaking meteors.

## Approach
- One sensible way: all sound plays on the client (nothing to replicate).
- The sounds go in a new `ReplicatedStorage.Zoo.Sfx` module (ZooClient is already 170 KB). It is called as
  `Sfx.play(name)` from the existing code, and it holds the id table, the variation, the cooldowns, the SoundGroups,
  the ducking and the music.
- Weather data stays in `Config.WEATHERS` and the mutation looks stay in ZooClient's `MUT_LOOK`, as they are now.
