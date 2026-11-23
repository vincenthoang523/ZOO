--!nonstrict
-- Sfx: every sound in Draw a Zoo, client only. All of it is licensed Roblox library audio (Roblox, Pro Sound Effects, APM
-- Music); the list with store links is docs/SOUNDS.md. To change a sound, swap its id below.
--
-- So nothing gets annoying:
--   * every play nudges pitch +-4% and volume +-10%: repeats never sound quite the same
--   * each sound has a cooldown (cd, seconds) and a cap on copies playing at once (max)
--   * frequent sounds are quiet; music ducks under the roll reveal and races
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Sfx = {}

-- id: one id, or a list to pick from at random. vol: base volume. pitch: base pitch (default 1).
local SOUNDS = {
	-- UI
	click = { id = 15675032796, vol = 0.35, cd = 0.04, max = 2 },        -- Roblox_UI_Small_Click
	open = { id = 15675028888, vol = 0.22, cd = 0.12 },                  -- Roblox_UI_Whoosh_02
	close = { id = 15675012262, vol = 0.18, cd = 0.12 },                 -- Roblox_UI_Whoosh_04
	toast = { id = 15675055424, vol = 0.25, cd = 0.4 },                  -- Roblox_UI_Cute_Pop
	error = { id = 15675075163, vol = 0.3, cd = 0.6 },                   -- Roblox_UI_Delete
	-- money
	buy = { id = 9113728625, vol = 0.4, cd = 0.3 },                      -- Cash Register 1
	sell = { id = { 9113849492, 9113849651 }, vol = 0.35, cd = 0.25 },   -- Coins Jingle / Coin Throws
	upgrade = { id = 9126073001, vol = 0.4, cd = 0.15 },                 -- Synth Sparkle Bell Ding
	reward = { id = 9116395085, vol = 0.4, cd = 1 },                     -- Magic Glows Chiming Hits 5
	-- drawing and the roll
	brush = { id = 9117187720, vol = 0.1, cd = 0.16, max = 1 },          -- Paint Canvas 11
	finish = { id = 15675037413, vol = 0.4, cd = 0.5 },                  -- Roblox_UI_Paper_Swipe
	spin = { id = 9125805579, vol = 0.3, cd = 0.5 },                     -- Rising Whoosh Build Up
	land = { id = 15675059323, vol = 0.35, cd = 0.05, max = 2 },         -- Roblox_UI_Bright_Click
	reveal = { id = 15675043410, vol = 0.4, cd = 0.5 },                  -- Roblox_UI_Tonal_Stinger
	rare = { id = 9116420454, vol = 0.35, cd = 0.5 },                    -- Magic Tone Shimmer Rattle 3 (Epic and up)
	mutation = { id = 9116418035, vol = 0.35, cd = 0.5 },                -- Magic Tone Falling Shimmer
	star = { id = 9126076030, vol = 0.3, cd = 0.05, max = 3 },           -- Synth Sparkle Tone Burst
	-- race
	beep = { id = 9113880475, vol = 0.35, cd = 0.3 },                    -- Computer Keyboard Beep 3
	go = { id = 9113073033, vol = 0.25, cd = 1 },                        -- Air Horn Whistling 5
	boost = { id = 15675024286, vol = 0.3, cd = 0.3 },                   -- Roblox_UI_Whoosh_01
	cheer = { id = 9113137529, vol = 0.25, cd = 2 },                     -- Applause Nightclub 1
	tick = { id = 15675032796, vol = 0.25, cd = 0.03, max = 3, pitch = 1.4 }, -- prize wheel (the small click, higher)
	-- weather one-shots
	thunder = { id = { 9120018172, 9120018216, 9120018050 }, vol = 0.5, cd = 1.5 }, -- Thunder Distant Boom
	strike = { id = 9116282875, vol = 0.45, cd = 1 },                    -- Lightning Strike Sharp Crack 5
	meteor = { id = { 9114428740, 9114428863 }, vol = 0.18, cd = 1.2 },  -- Fireball Pass By 1 / 2
	-- weather loops (Sfx.ambience)
	rainLoop = { id = 9112854438, vol = 0.35, loop = true },             -- Rain On Leaves 1
	stormLoop = { id = 9112857744, vol = 0.4, loop = true },             -- Rainstorm Distant Summer Rain 1
	windLoop = { id = 9114057104, vol = 0.25, loop = true },             -- Desert Wind Whistley Light Gusts 1
	fogLoop = { id = 9112795571, vol = 0.18, loop = true },              -- Hollow Rumble 2
	nightLoop = { id = 9112764573, vol = 0.2, loop = true },             -- Crickets Night 3
	matrixLoop = { id = 9125548429, vol = 0.12, loop = true },           -- Energy Synth Drone Hum
}
-- calm park music, shuffled; the race has its own track
local MUSIC = { 120231070741138, 87861173435027, 1839737641, 1839737855, 9038622066 } -- Curious Creatures, Warm Summer Days, Happy Walk, Natural Reserve, Lakefront Days (Ukulele Underscore)
local RACE_MUSIC = 104995331412866 -- Fun Of The Chase (Underscore)
local MUSIC_VOL = 0.22

local function group(name, vol)
	local g = SoundService:FindFirstChild(name) or Instance.new("SoundGroup")
	g.Name, g.Volume, g.Parent = name, vol, SoundService
	return g
end
local groups = { sfx = group("ZooSfx", 1), music = group("ZooMusic", 1), ambience = group("ZooAmbience", 1) }
local duck = Instance.new("EqualizerSoundEffect") -- a soft dip in the music under the reveal and races
duck.HighGain, duck.MidGain, duck.LowGain, duck.Parent = 0, 0, 0, groups.music

local rng = Random.new()
local lastAt, playing, pools = {}, {}, {}

local function asset(id) return "rbxassetid://" .. id end
local function pick(id) return if typeof(id) == "table" then id[rng:NextInteger(1, #id)] else id end

-- name: a SOUNDS key. opt.pitch / opt.vol multiply on top of the base and the random nudge. opt.at = a BasePart
-- or Attachment to play from in 3D (else it plays flat). Returns the Sound, or nil if it was held back.
function Sfx.play(name, opt)
	local d = SOUNDS[name]
	if not d then return warn("[Sfx] no sound called", name) end
	local now = os.clock()
	if now - (lastAt[name] or -1e9) < (d.cd or 0.05) then return end
	if (playing[name] or 0) >= (d.max or 2) then return end
	lastAt[name] = now
	local s = table.remove(pools[name] or {}) or Instance.new("Sound")
	s.SoundId = asset(pick(d.id))
	s.SoundGroup = groups.sfx
	s.Volume = d.vol * rng:NextNumber(0.9, 1.1) * (opt and opt.vol or 1)
	s.PlaybackSpeed = (d.pitch or 1) * rng:NextNumber(0.96, 1.04) * (opt and opt.pitch or 1)
	s.RollOffMinDistance, s.RollOffMaxDistance = 20, 400
	s.Parent = opt and opt.at or SoundService
	playing[name] = (playing[name] or 0) + 1
	s:Play()
	local done = false
	local function finish()
		if done then return end
		done = true
		playing[name] -= 1
		pools[name] = pools[name] or {}
		if #pools[name] < 3 then s:Stop() s.Parent = nil table.insert(pools[name], s) else s:Destroy() end
	end
	s.Ended:Once(finish)
	task.delay(12, finish) -- a sound that never loads never ends: free its slot anyway
	return s
end

-- the weather loop: one at a time, fading in and out. nil stops it.
local ambient
function Sfx.ambience(name)
	if ambient and ambient.Name == name then return end
	if ambient then
		local old = ambient
		local tw = TweenService:Create(old, TweenInfo.new(3), { Volume = 0 })
		tw.Completed:Once(function() old:Destroy() end)
		tw:Play()
		ambient = nil
	end
	local d = name and SOUNDS[name]
	if not d then return end
	ambient = Instance.new("Sound")
	ambient.Name, ambient.SoundId, ambient.Looped, ambient.Volume, ambient.SoundGroup = name, asset(pick(d.id)), true, 0, groups.ambience
	ambient.PlaybackSpeed = rng:NextNumber(0.97, 1.03)
	ambient.Parent = SoundService
	ambient:Play()
	TweenService:Create(ambient, TweenInfo.new(3), { Volume = d.vol }):Play()
end

-- music: shuffles the park tracks; Sfx.raceMusic(true) swaps to the race track until false
local music = Instance.new("Sound")
music.Name, music.SoundGroup, music.Volume, music.Parent = "ZooMusic", groups.music, MUSIC_VOL, SoundService
local order, at, racing = {}, 0, false
local function nextTrack()
	if racing then return end
	at += 1
	if at > #order then -- a fresh shuffle that never repeats the last track first
		local last = order[#order]
		order = table.clone(MUSIC)
		for i = #order, 2, -1 do local j = rng:NextInteger(1, i) order[i], order[j] = order[j], order[i] end
		if order[1] == last then order[1], order[#order] = order[#order], order[1] end
		at = 1
	end
	music.Looped, music.SoundId = false, asset(order[at])
	music:Play()
end
music.Ended:Connect(nextTrack)
function Sfx.startMusic() if not music.IsPlaying then nextTrack() end end
function Sfx.raceMusic(on)
	if on == racing then return end
	racing = on
	if on then
		music.Looped, music.SoundId = true, asset(RACE_MUSIC)
		music:Play()
	else
		at -= 1
		nextTrack()
	end
end
-- dips the music for a moment of focus (the roll reveal)
function Sfx.duck(on)
	TweenService:Create(duck, TweenInfo.new(0.4), { HighGain = on and -12 or 0, MidGain = on and -10 or 0, LowGain = on and -8 or 0 }):Play()
end

-- the HUD toggles
function Sfx.setEnabled(kind, on)
	if kind == "music" then
		groups.music.Volume = on and 1 or 0
	else
		groups.sfx.Volume = on and 1 or 0
		groups.ambience.Volume = on and 1 or 0
	end
end

return Sfx
