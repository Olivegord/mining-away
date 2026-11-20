-- VERSION 2 — "Pressure Strike": the ranged wind strike from the Wind Moveset reference
-- (https://www.youtube.com/watch?v=-RYr9ZNJPGM, video time 30.07–33.30 s; t = video time − 30.07).
--
-- The strike lands on a spot in the world, not on a character:
--   0.05–0.66  five quick pressure pulses: a pale drum drops, a streak curtain hangs under it, a ground ring flashes
--   0.66–0.86  nothing (the held breath)
--   0.86–0.96  a drum falls from high up, core flash and sky halo, then one frame of a huge white tulip
--   0.96–2.75  aftermath and follow-up hits: shock ring, dark spike crown, thrown debris, pillars, halos, a second tulip
--   2.80–3.25  a white column drops, a bright puck lands and runs out as one wide ground ring
--
-- Every layer is a pure function of time, so any moment can be posed and compared with its video frame.
-- Only dust specks and the last smoke curl are particles. Sizes are in studs for a 5-stud character.

local Strike = {}
Strike.__index = Strike
Strike.DURATION = 3.45

local GLOW = 'rbxasset://textures/ui/AvatarExperience/glowLight.png'
local DISC = 'rbxasset://textures/ui/VR/circleWhite.png'
local SMOKE = 'rbxasset://textures/particles/smoke_main.dds'
local TAU = math.pi * 2
local CURVE1 = 1 -- sign of Beam.CurveSize1 for a tangent-continuous curve

local CREAM = Color3.fromRGB(255, 251, 228)
local WARM = Color3.fromRGB(244, 234, 204)
local MIST = Color3.fromRGB(190, 190, 178)
local ASH = Color3.fromRGB(78, 80, 73)
local DARK = Color3.fromRGB(33, 35, 32)

local PULSES = { 0.05, 0.19, 0.32, 0.46, 0.59 }
local BURSTS = { { t = 0.93, s = 1 }, { t = 1.93, s = 0.86 } }
local HITS = {
	{ t = 1.13, r = 7.5, tulip = 0.5, pillar = 20 },
	{ t = 1.33, r = 7, tulip = 0.18, pillar = 22, halo = 16 },
	{ t = 1.73, r = 8, tulip = 0.34, pillar = 24, halo = 14 },
	{ t = 2.12, r = 6, tulip = 0.42, pillar = 10, core = true },
	{ t = 2.33, r = 7.5, tulip = 0.16, pillar = 26, halo = 17 },
	{ t = 2.53, r = 6.5, tulip = 0, pillar = 9 },
	{ t = 2.73, r = 10, tulip = 0, pillar = 0 },
}
local FINAL = 2.86
local SPARKS = { 1.23, 2.36 }
local VOLLEYS = { { t = 0.93, n = 12 }, { t = 1.93, n = 8 }, { t = 2.9, n = 8 } }
local GRAVITY = 120
local DRUM_PROFILE = { 0, 0, 0.3, 0.3, 0.72, 1, 0.92, 1, 1, 0.35 }

local function clamp01(x)
	return math.clamp(x, 0, 1)
end
local function lerp(a, b, x)
	return a + (b - a) * x
end
local function smooth(a, b, x)
	local k = clamp01((x - a) / (b - a))
	return k * k * (3 - 2 * k)
end
local function outCubic(x)
	local i = 1 - clamp01(x)
	return 1 - i * i * i
end
-- keyed curve {x1, v1, x2, v2, ...}; eased between keys unless `straight`
local function ramp(x, k, straight)
	if x <= k[1] then
		return k[2]
	end
	for i = 3, #k, 2 do
		if x <= k[i] then
			local a = (x - k[i - 2]) / (k[i] - k[i - 2])
			if not straight then
				a = a * a * (3 - 2 * a)
			end
			return k[i - 1] + (k[i + 1] - k[i - 1]) * a
		end
	end
	return k[#k]
end
local function frameX(pos, x)
	local side = x:Cross(Vector3.zAxis)
	if side.Magnitude < 0.05 then
		side = x:Cross(Vector3.xAxis)
	end
	return CFrame.fromMatrix(pos, x, side.Unit)
end

---------------------------------------------------------------- ribbon: a ring or arc built from curved beams
local Ribbon = {}
Ribbon.__index = Ribbon

function Ribbon.new(rig, name, segments, twoLayers)
	local self = setmetatable({ rig = rig, n = segments, atts = {}, glow = {}, on = false }, Ribbon)
	for i = 1, segments + 1 do
		local a = Instance.new('Attachment')
		a.Name = name .. i
		a.Parent = rig.host
		self.atts[i] = a
	end
	local function layer(tag, z)
		local list = {}
		for i = 1, segments do
			local b = Instance.new('Beam')
			b.Name = name .. tag .. i
			b.Attachment0, b.Attachment1 = self.atts[i], self.atts[i + 1]
			b.FaceCamera = false
			b.LightInfluence = 0
			b.Segments = 12
			b.TextureSpeed = 0
			b.ZOffset = z
			b.Enabled = false
			b.Parent = rig.host
			list[i] = b
		end
		return list
	end
	self.glow = layer('G', 0)
	if twoLayers then
		self.core = layer('C', 0.03)
	end
	table.insert(rig.all, self)
	return self
end

function Ribbon:hide()
	if self.on then
		self.on = false
		for _, b in self.glow do
			b.Enabled = false
		end
		if self.core then
			for _, b in self.core do
				b.Enabled = false
			end
		end
	end
end

-- p: r, y, w, op, col, le, bright, flat, lean, a0, sweep, shape (crescent arcs), core = {op, col, w, bright}
function Ribbon:draw(p)
	if p.op <= 0.004 or p.w <= 0.001 or p.r <= 0.01 then
		self:hide()
		return
	end
	self.stamp = self.rig.frame
	self.on = true
	local S = self.rig.scale
	local n = self.n
	local sweep = p.sweep or TAU
	local a0 = p.a0 or 0
	local r, y = p.r * S, p.y * S
	local lean = p.lean or 0
	local step = sweep / n
	local curve = (4 / 3) * math.tan(step / 4) * r
	for i = 0, n do
		local a = a0 + step * i
		local ca, sa = math.cos(a), math.sin(a)
		local x = Vector3.new(-sa, 0, ca)
		local wide = p.flat and Vector3.new(ca, 0, sa) or Vector3.new(ca * lean, 1, sa * lean).Unit
		self.atts[i + 1].CFrame = CFrame.fromMatrix(Vector3.new(ca * r, y, sa * r), x, wide)
	end
	local function paint(list, width, op, col, le, bright)
		for i, b in list do
			local u0, u1 = (i - 1) / n, i / n
			local w0, w1, o0, o1 = width, width, op, op
			if p.shape then -- crescent: pointed at both ends, soft tail
				w0, w1 = width * math.sin(math.pi * u0) ^ 0.8, width * math.sin(math.pi * u1) ^ 0.8
				o0, o1 = op * smooth(0, 0.3, u0), op * smooth(0, 0.3, u1)
			end
			b.CurveSize0, b.CurveSize1 = curve, curve * CURVE1
			b.Width0, b.Width1 = w0 * S, w1 * S
			b.Transparency = NumberSequence.new(1 - clamp01(o0), 1 - clamp01(o1))
			b.Color = ColorSequence.new(col)
			b.LightEmission = le
			b.Brightness = bright
			b.Enabled = op > 0.004
		end
	end
	paint(self.glow, p.w, p.op, p.col, p.le or 1, p.bright or 1)
	if self.core then
		local c = p.core
		if c and c.op > 0.004 then
			paint(self.core, p.w * c.w, c.op, c.col, 1, c.bright or 3)
		else
			for _, b in self.core do
				b.Enabled = false
			end
		end
	end
end

---------------------------------------------------------------- streak: one beam between two points
local Streak = {}
Streak.__index = Streak

function Streak.new(rig, name, faceCamera, texture)
	local self = setmetatable({ rig = rig, on = false }, Streak)
	self.a0 = Instance.new('Attachment')
	self.a0.Name = name .. 'A'
	self.a0.Parent = rig.host
	self.a1 = Instance.new('Attachment')
	self.a1.Name = name .. 'B'
	self.a1.Parent = rig.host
	local b = Instance.new('Beam')
	b.Name = name
	b.Attachment0, b.Attachment1 = self.a0, self.a1
	b.FaceCamera = faceCamera
	b.LightInfluence = 0
	b.Segments = 10
	b.TextureSpeed = 0
	b.Enabled = false
	if texture then
		b.Texture = texture
		b.TextureMode = Enum.TextureMode.Stretch
		b.TextureLength = 1
	end
	b.Parent = rig.host
	self.beam = b
	table.insert(rig.all, self)
	return self
end

function Streak:hide()
	if self.on then
		self.on = false
		self.beam.Enabled = false
	end
end

-- straight unless d0/d1 (unit directions of travel at each end) and c0/c1 (bend lengths) are given
function Streak:draw(p0, p1, w0, w1, o0, o1, col, le, bright, d0, d1, c0, c1, tipFade)
	if o0 <= 0.004 and o1 <= 0.004 then
		self:hide()
		return
	end
	self.stamp = self.rig.frame
	self.on = true
	local S = self.rig.scale
	local b = self.beam
	if d0 then
		self.a0.CFrame = frameX(p0 * S, d0)
		self.a1.CFrame = frameX(p1 * S, d1)
		b.CurveSize0, b.CurveSize1 = c0 * S, c1 * S * CURVE1
	else
		self.a0.CFrame = CFrame.new(p0 * S)
		self.a1.CFrame = CFrame.new(p1 * S)
		b.CurveSize0, b.CurveSize1 = 0, 0
	end
	b.Width0, b.Width1 = w0 * S, w1 * S
	if type(tipFade) == 'table' then -- opacity profile along the beam: {u1, k1, u2, k2, ...}, scaled by o0
		local keys = {}
		for i = 1, #tipFade, 2 do
			table.insert(keys, NumberSequenceKeypoint.new(tipFade[i], 1 - clamp01(o0 * tipFade[i + 1])))
		end
		b.Transparency = NumberSequence.new(keys)
	elseif tipFade then -- full strength through the body, dissolving toward the far end
		b.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1 - clamp01(o0)),
			NumberSequenceKeypoint.new(tipFade, 1 - clamp01(o1)),
			NumberSequenceKeypoint.new(1, 1),
		})
	else
		b.Transparency = NumberSequence.new(1 - clamp01(o0), 1 - clamp01(o1))
	end
	b.Color = ColorSequence.new(col)
	b.LightEmission = le
	b.Brightness = bright
	b.Enabled = true
end

-- a flat round sprite on the ground (needs a round texture)
function Streak:disc(r, y, op, col, le, bright)
	if op <= 0.004 or r <= 0.01 then
		self:hide()
		return
	end
	self.stamp = self.rig.frame
	self.on = true
	local S = self.rig.scale
	local b = self.beam
	self.a0.CFrame = CFrame.fromMatrix(Vector3.new(-r, y, 0) * S, Vector3.xAxis, Vector3.zAxis)
	self.a1.CFrame = CFrame.fromMatrix(Vector3.new(r, y, 0) * S, Vector3.xAxis, Vector3.zAxis)
	b.CurveSize0, b.CurveSize1 = 0, 0
	b.Width0, b.Width1 = 2 * r * S, 2 * r * S
	b.Transparency = NumberSequence.new(1 - clamp01(op))
	b.Color = ColorSequence.new(col)
	b.LightEmission = le
	b.Brightness = bright
	b.Enabled = true
end

---------------------------------------------------------------- rig
function Strike.new(parent, cframe, scale)
	local self = setmetatable({ scale = scale or 1, all = {}, frame = 0, last = -1 }, Strike)
	local S = self.scale
	local host = Instance.new('Part')
	host.Name = 'PressureStrikeRig'
	host.Anchored = true
	host.CanCollide = false
	host.CanTouch = false
	host.CanQuery = false
	host.CastShadow = false
	host.Transparency = 1
	host.Size = Vector3.one
	host.CFrame = cframe
	host.Locked = true
	self.host = host

	self.groundRing = Ribbon.new(self, 'GroundRing', 6, true)
	self.shockRing = Ribbon.new(self, 'ShockRing', 6, true)
	self.finalRing = Ribbon.new(self, 'FinalRing', 8, true)
	self.finalBand = Ribbon.new(self, 'FinalBand', 8, false)
	self.finalBandInner = Ribbon.new(self, 'FinalBandInner', 8, false)
	self.tube = Ribbon.new(self, 'DarkTube', 6, false)
	self.halo = {}
	for i = 1, 3 do
		self.halo[i] = { arc = Ribbon.new(self, 'Halo' .. i, 3, true), flare = Streak.new(self, 'HaloFlare' .. i, true, GLOW) }
	end
	self.glowDisc = Streak.new(self, 'GroundGlow', false, GLOW)
	self.fill = Streak.new(self, 'DiscFill', false, DISC)
	self.column = Streak.new(self, 'SkyColumn', true, nil)
	self.columnGlow = Streak.new(self, 'SkyColumnGlow', true, GLOW)

	local rng = Random.new(20261119)
	local function many(count, name, texture)
		local list = {}
		for i = 1, count do
			local seeds = {}
			for k = 1, 6 do
				seeds[k] = rng:NextNumber()
			end
			list[i] = { s = Streak.new(self, name .. i, true, texture), q = seeds, a = (i - 1 + rng:NextNumber() * 0.7) / count * TAU }
		end
		return list
	end
	self.drum = many(40, 'Drum') -- overlapping upright bars: one pale band, streaked, soft below and brightest near its top
	self.curtain = many(16, 'Curtain')
	self.petals = many(36, 'Petal')
	self.spikes = many(22, 'Spike')
	self.pillar = many(4, 'Pillar')
	self.pillarGlow = Streak.new(self, 'PillarGlow', true, GLOW)
	self.flame = many(5, 'CoreFlame')
	self.sparks = many(8, 'Spark')
	self.lines = many(5, 'ThinLine')

	self.debris = {}
	for v, volley in VOLLEYS do
		for i = 1, volley.n do
			local part = Instance.new('Part')
			part.Name = 'Chunk'
			part.Anchored = true
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.CastShadow = false
			part.Material = Enum.Material.Slate
			part.Color = Color3.fromRGB(46 + rng:NextInteger(-8, 10), 47, 43)
			part.Transparency = 1
			part.Size = Vector3.one * 0.05
			part.CFrame = cframe
			part.Parent = host
			local a = rng:NextNumber() * TAU
			local out = Vector3.new(math.cos(a), 0, math.sin(a))
			local up = rng:NextNumber(40, 64) * (v == 1 and 1 or 0.85)
			table.insert(self.debris, {
				part = part,
				t0 = volley.t + rng:NextNumber(0, 0.03),
				p0 = out * rng:NextNumber(2, 7) + Vector3.new(0, 0.4, 0),
				v = out * rng:NextNumber(5, 17) + Vector3.new(0, up, 0),
				life = 2 * up / GRAVITY,
				size = Vector3.new(rng:NextNumber(0.6, 1.3), rng:NextNumber(0.5, 1.1), rng:NextNumber(0.6, 1.3)),
				axis = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)).Unit,
				spin = rng:NextNumber(5, 14),
			})
		end
	end

	local light = Instance.new('PointLight')
	light.Name = 'StrikeLight'
	light.Color = CREAM
	light.Range = 58 * S
	light.Brightness = 0
	light.Shadows = false
	local lamp = Instance.new('Attachment')
	lamp.Name = 'Lamp'
	lamp.Position = Vector3.new(0, 7 * S, 0)
	lamp.Parent = host
	light.Parent = lamp
	self.light = light

	-- particles: pale dust specks at the big moments, one slow smoke curl at the end
	local specks = Instance.new('ParticleEmitter')
	specks.Name = 'Specks'
	specks.Texture = DISC
	specks.Color = ColorSequence.new(CREAM, WARM)
	specks.LightEmission = 0.7
	specks.LightInfluence = 0
	specks.Brightness = 1.6
	specks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05 * S), NumberSequenceKeypoint.new(0.15, 0.24 * S), NumberSequenceKeypoint.new(1, 0.04 * S) })
	specks.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.6, 0.25), NumberSequenceKeypoint.new(1, 1) })
	specks.Lifetime = NumberRange.new(0.7, 1.5)
	specks.Speed = NumberRange.new(9 * S, 30 * S)
	specks.SpreadAngle = Vector2.new(70, 70)
	specks.Drag = 3.2
	specks.Acceleration = Vector3.new(0, -6 * S, 0)
	specks.Rate = 0
	specks.Parent = lamp
	self.specks = specks

	local puff = Instance.new('Attachment')
	puff.Name = 'SmokeAt'
	puff.Position = Vector3.new(0, 3 * S, 0)
	puff.Parent = host
	local smoke = Instance.new('ParticleEmitter')
	smoke.Name = 'Smoke'
	smoke.Texture = SMOKE
	smoke.Color = ColorSequence.new(MIST)
	smoke.LightEmission = 0.15
	smoke.LightInfluence = 0.4
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.5 * S), NumberSequenceKeypoint.new(1, 7 * S) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.72), NumberSequenceKeypoint.new(1, 1) })
	smoke.Lifetime = NumberRange.new(0.5, 0.85)
	smoke.Speed = NumberRange.new(8 * S, 16 * S)
	smoke.SpreadAngle = Vector2.new(16, 16)
	smoke.Rotation = NumberRange.new(0, 360)
	smoke.RotSpeed = NumberRange.new(-60, 60)
	smoke.Drag = 1.6
	smoke.Rate = 0
	smoke.Parent = puff
	self.smoke = smoke

	self.marks = { { 0.93, specks, 18 }, { 1.13, specks, 5 }, { 1.73, specks, 6 }, { 1.93, specks, 14 }, { 2.33, specks, 5 }, { 2.9, specks, 18 }, { 2.97, smoke, 6 } }
	host.Parent = parent
	return self
end

function Strike:Destroy()
	self.host:Destroy()
end

-- draw every layer as it stands at time t (seconds since the strike was cast)
function Strike:Seek(t)
	self.frame += 1
	local up = Vector3.yAxis
	local function best(slot, op)
		if op > slot.op then
			slot.op = op
			return true
		end
		return false
	end

	---------------------------------------------------------- gather what each layer should show
	local ground = { op = 0 }
	local drum = { op = 0 }
	local curtain = { op = 0 }
	local petals = { op = 0 }
	local pillar = { op = 0 }
	local halo = { op = 0 }
	local glow = { op = 0 }
	local flame = { op = 0 }
	local tube = 0
	local tubeScale = 1
	local shock = { op = 0 }
	local lines = 0
	local light = 0

	for k, tp in PULSES do
		local tau = t - tp
		if tau > -0.06 and tau < 0.26 then
			local rk = lerp(4.5, 8, (k - 1) / 4)
			local tail = k == #PULSES and { -0.05, 0, -0.03, 0.3, -0.008, 0.3, 0, 1, 0.035, 1, 0.09, 0 }
				or { -0.05, 0, -0.03, 0.3, -0.008, 0.3, 0, 1, 0.035, 1, 0.11, 0.3, 0.15, 0.3, 0.24, 0 }
			if best(ground, ramp(tau, tail)) then
				ground.r, ground.w, ground.bright = rk * (0.86 + 0.14 * outCubic(tau / 0.07)), 0.36, 3
			end
			-- the drum is faint and high, bright as it passes head height, soft as it lands
			if best(drum, ramp(tau, { -0.045, 0, -0.035, 0.22, -0.006, 0.9, 0.03, 0.62, 0.078, 0 })) then
				drum.r, drum.h, drum.col = 10.5, 4.6, CREAM
				drum.y = ramp(tau, { -0.045, 13.5, 0, 9, 0.035, 6, 0.078, 3 }, true)
			end
			if tau > 0 and best(curtain, 0.6 * ramp(tau, { 0, 0, 0.012, 1, 0.03, 1, 0.115, 0 })) then
				curtain.r, curtain.h = rk, 1 - 0.35 * tau / 0.115
				curtain.col, curtain.le = k >= 4 and ASH or MIST, k >= 4 and 0.05 or 0.6
			end
			if k >= 4 and best(glow, 0.42 * ramp(tau, { 0.02, 0, 0.05, 1, 0.08, 1, 0.12, 0 })) then
				glow.r = 11
			end
			if k == #PULSES then
				lines = 0.4 * ramp(tau, { 0.03, 0, 0.05, 1, 0.08, 1, 0.12, 0 })
			end
			if tau >= 0 then
				light += 1.1 * math.exp(-tau / 0.05)
			end
		end
	end

	for _, burst in BURSTS do
		local tau, s = t - burst.t, burst.s
		if tau > -0.1 and tau < 0.3 then
			if best(ground, 0.3 * ramp(tau, { -0.09, 0, -0.07, 1, -0.03, 1, -0.012, 0 })) then
				ground.r, ground.w, ground.bright = 6 * s, 0.3, 2
			end
			if best(drum, 0.24 * ramp(tau, { -0.09, 0, -0.075, 1, -0.045, 1, -0.03, 0 })) then
				drum.r, drum.h, drum.col = 10 * s, 6, MIST
				drum.y = ramp(tau, { -0.09, 27, -0.03, 17 }, true)
			end
			-- a faint funnel, then one frame of white, then gone
			if best(petals, ramp(tau, { -0.05, 0, -0.036, 0.22, -0.014, 0.3, -0.008, 1, 0.014, 1, 0.031, 0 })) then
				petals.open, petals.s = ramp(tau, { -0.05, 0.45, -0.012, 0.72, 0.03, 1.15 }, true), s
			end
			if best(halo, ramp(tau, { -0.05, 0, -0.04, 1, -0.015, 1, -0.006, 0 })) then
				halo.y, halo.r = 17 * s, 15 * s
			end
			if best(flame, ramp(tau, { -0.05, 0, -0.04, 1, -0.012, 1, -0.004, 0 })) then
				flame.s = s
			end
			local dark = 0.5 * ramp(tau, { -0.05, 0, -0.04, 1, -0.014, 1, -0.006, 0 })
			if dark > tube then
				tube, tubeScale = dark, s
			end
			if best(glow, ramp(tau, { -0.05, 0, -0.035, 0.55, 0.01, 0.72, 0.04, 0 })) then
				glow.r = ramp(tau, { -0.05, 8, 0.03, 16 }, true) * s
			end
			if best(pillar, ramp(tau, { 0.015, 0, 0.03, 1, 0.07, 0.7, 0.16, 0 })) then
				pillar.h, pillar.w = 22 * s, 1.6
			end
			if best(shock, ramp(tau, { 0.02, 0, 0.03, 0.62, 0.1, 0.32, 0.24, 0 })) then
				shock.r = s * ramp(tau, { 0.02, 21, 0.06, 26, 0.12, 29, 0.24, 31.5 }, true)
			end
			if tau >= -0.04 then
				light += 6 * s * math.exp(-math.max(tau, 0) / 0.07) * smooth(-0.04, -0.01, tau)
			end
		end
	end

	for _, hit in HITS do
		local tau = t - hit.t
		if tau > -0.06 and tau < 0.2 then
			if best(ground, ramp(tau, { -0.012, 0, 0, 1, 0.03, 1, 0.16, 0 })) then
				ground.r, ground.w, ground.bright = hit.r * (1 + 0.22 * outCubic(tau / 0.12)), 0.45, 3.5
			end
			if hit.tulip > 0 and best(petals, hit.tulip * ramp(tau, { -0.006, 0, 0.004, 1, 0.035, 0.7, 0.09, 0 })) then
				petals.open, petals.s = ramp(tau, { 0, 0.6, 0.09, 1 }, true), 0.75
			end
			if hit.pillar > 0 and best(pillar, ramp(tau, { -0.006, 0, 0.004, 1, 0.05, 0.8, 0.15, 0 })) then
				pillar.h, pillar.w = hit.pillar, 1.3
			end
			if hit.halo and best(halo, ramp(tau, { -0.05, 0, -0.04, 1, -0.008, 1, 0.03, 0 })) then
				halo.y, halo.r = hit.halo, 12
			end
			if hit.core and best(flame, ramp(tau, { -0.012, 0, 0, 1, 0.03, 1, 0.055, 0 })) then
				flame.s = 0.8
			end
			if best(glow, 0.3 * ramp(tau, { -0.01, 0, 0.005, 1, 0.04, 0.6, 0.1, 0 })) then
				glow.r = 9
			end
			if tau >= 0 then
				light += 2.6 * math.exp(-tau / 0.06)
			end
		end
	end

	-- the finisher
	local ft = t - FINAL
	local colOp = ramp(t, { 2.785, 0, 2.795, 1, 2.82, 1, 2.836, 0 })
	if best(ground, ramp(t, { 2.815, 0, 2.83, 1, 2.85, 1, 2.87, 0 })) then
		ground.r, ground.w, ground.bright = 8, 0.5, 3.5
	end
	if best(pillar, 0.5 * ramp(t, { 2.82, 0, 2.832, 1, 2.86, 0 })) then
		pillar.h, pillar.w = 12, 1
	end
	if best(drum, ramp(ft, { -0.014, 0, -0.002, 1, 0.012, 1, 0.05, 0 })) then
		drum.r, drum.col = ramp(ft, { -0.014, 10.5, 0, 11.5, 0.04, 16.5, 0.05, 18 }, true), CREAM
		drum.h = ramp(ft, { 0, 2.8, 0.05, 0.8 }, true)
		drum.y = drum.h / 2 + 0.1
	end
	if best(glow, ramp(ft, { -0.015, 0, 0, 0.85, 0.04, 0.6, 0.09, 0 })) then
		glow.r = ramp(ft, { -0.015, 10, 0.09, 24 }, true)
	end
	if best(halo, ramp(ft, { 0.02, 0, 0.032, 1, 0.055, 1, 0.085, 0 })) then
		halo.y, halo.r = 14, 13
	end
	if best(curtain, 0.45 * ramp(ft, { 0.02, 0, 0.035, 1, 0.06, 1, 0.1, 0 })) then
		curtain.r, curtain.h, curtain.col, curtain.le = 7, 0.8, MIST, 0.3
	end
	if ft >= -0.02 and ft < 0.5 then
		light += 6 * math.exp(-math.max(ft, 0) / 0.09) * smooth(-0.02, 0, ft)
	end
	light += 3 * colOp

	---------------------------------------------------------- draw
	self.groundRing:draw({
		r = ground.r or 0, y = 0.14, flat = true, w = (ground.w or 0) * 1.7, op = ground.op * 0.3, col = WARM, le = 1, bright = 1.4,
		core = { op = ground.op, col = CREAM, w = 0.56, bright = ground.bright or 3 },
	})

	for _, c in self.drum do
		if drum.op > 0.004 then
			local at = Vector3.new(math.cos(c.a) * drum.r, drum.y, math.sin(c.a) * drum.r)
			local half = Vector3.new(0, drum.h * (0.5 + 0.14 * c.q[1]), 0)
			local o = drum.op * (0.3 + 0.3 * c.q[2])
			local wide = drum.r * (0.2 + 0.2 * c.q[3])
			c.s:draw(at - half, at + half, wide, wide, o, o, drum.col, 0.9, 1.5, nil, nil, nil, nil, DRUM_PROFILE)
		else
			c.s:hide()
		end
	end

	for _, c in self.curtain do
		if curtain.op > 0.004 then
			local q = c.q
			local rr = curtain.r * (0.88 + 0.26 * q[1])
			local base = Vector3.new(math.cos(c.a) * rr, 0.1, math.sin(c.a) * rr)
			local tall = (3.5 + 5 * q[2]) * curtain.h
			local o = curtain.op * (0.55 + 0.45 * q[3])
			c.s:draw(base, base + Vector3.new(0, tall, 0), 0.7 + 1.1 * q[4], 0, o, o * 0.7, curtain.col, curtain.le, 1)
		else
			c.s:hide()
		end
	end

	for _, c in self.petals do
		if petals.op > 0.004 then
			local q, s, open = c.q, petals.s, petals.open
			local dir = Vector3.new(math.cos(c.a), 0, math.sin(c.a))
			local rb = (5.5 + 3 * q[1]) * s
			local rt = rb + (10 + 12 * q[2]) * s * open
			local tall = (24 + 20 * q[3]) * s * (0.55 + 0.45 * open)
			local o = petals.op * (0.35 + 0.65 * q[5])
			local white = petals.op > 0.8
			c.s:draw(dir * rb + up * 0.2, dir * rt + up * tall, (0.3 + 0.5 * q[6]) * s, (2 + 7 * q[4] ^ 1.5) * s, o * 0.85, o, white and CREAM or WARM, 1, white and 2.4 or 1,
				up, (dir * 0.75 + up * 0.66).Unit, tall * 0.45, tall * 0.3, 0.5 + 0.25 * q[1])
		else
			c.s:hide()
		end
	end

	for i, c in self.pillar do
		if pillar.op > 0.004 and pillar.h > 0 then
			local q = c.q
			local base = Vector3.new((q[1] - 0.5) * 1.6, 0.4, (q[2] - 0.5) * 1.6)
			local tall = pillar.h * (i == 1 and 1 or 0.45 + 0.5 * q[3])
			c.s:draw(base, base + Vector3.new((q[4] - 0.5) * 1.5, tall, 0), pillar.w * (i == 1 and 1 or 0.4 + 0.5 * q[5]), 0, pillar.op, pillar.op * 0.5, CREAM, 1, 3)
		else
			c.s:hide()
		end
	end
	if pillar.op > 0.004 and pillar.h > 0 then
		self.pillarGlow:draw(Vector3.new(0, -2, 0), Vector3.new(0, pillar.h * 0.9, 0), 5, 5, pillar.op * 0.4, pillar.op * 0.4, WARM, 1, 1.2)
	else
		self.pillarGlow:hide()
	end

	-- the falling white column that opens the finisher
	if colOp > 0.004 then
		local bottom = ramp(t, { 2.785, 30, 2.822, 5 }, true)
		self.column:draw(Vector3.new(0, bottom, 0), Vector3.new(0, bottom + 34, 0), 4.6, 5.6, colOp, colOp, CREAM, 1, 3)
		self.columnGlow:draw(Vector3.new(0, bottom - 8, 0), Vector3.new(0, bottom + 40, 0), 13, 13, colOp * 0.5, colOp * 0.5, WARM, 1, 1.2)
	else
		self.column:hide()
		self.columnGlow:hide()
	end

	for i, h in self.halo do
		if halo.op > 0.004 then
			local a0 = t * 5 + (i - 1) * TAU / 3
			local sweep = math.rad(72 + 12 * i)
			h.arc:draw({
				r = halo.r, y = halo.y, flat = true, a0 = a0, sweep = sweep, shape = true, w = 1.5, op = halo.op * 0.5, col = WARM, le = 1, bright = 1.5,
				core = { op = halo.op, col = CREAM, w = 0.42, bright = 3.5 },
			})
			local a = a0 + sweep * 0.62
			local at = Vector3.new(math.cos(a) * halo.r, halo.y, math.sin(a) * halo.r)
			local along = Vector3.new(-math.sin(a), 0, math.cos(a))
			h.flare:draw(at - along * 2.6, at + along * 2.6, 1.1, 1.1, halo.op, halo.op, CREAM, 1, 3)
		else
			h.arc:hide()
			h.flare:hide()
		end
	end

	self.tube:draw({ r = 6.5 * tubeScale, y = 3.75 * tubeScale, w = 7.5 * tubeScale, op = tube, col = ASH, le = 0.05, bright = 1 })

	for _, c in self.flame do
		if flame.op > 0.004 then
			local q, s = c.q, flame.s
			local base = Vector3.new((q[1] - 0.5) * 3.4, 0.2, (q[2] - 0.5) * 3.4) * s
			c.s:draw(base, base + Vector3.new((q[3] - 0.5) * 1.6, (3 + 3.5 * q[4]) * s, 0), (1 + 0.8 * q[5]) * s, 0, flame.op, flame.op, CREAM, 1, 4)
		else
			c.s:hide()
		end
	end

	self.glowDisc:disc(glow.r or 0, 0.1, glow.op, WARM, 1, 1.3)

	self.shockRing:draw({
		r = shock.r or 0, y = 0.12, flat = true, w = 3.4, op = shock.op * 0.22, col = MIST, le = 0.9, bright = 1,
		core = { op = shock.op, col = WARM, w = 0.1, bright = 2 },
	})

	-- final ring: measured from the video at 2.86 s (puck) to 3.13 s (last trace)
	local rf = ramp(ft, { -0.014, 10.5, 0, 11.5, 0.04, 16.5, 0.07, 22.5, 0.1, 30, 0.14, 37, 0.21, 47, 0.27, 52, 0.34, 55 }, true)
	local rim = ramp(ft, { -0.012, 0, 0, 1, 0.07, 0.9, 0.14, 0.5, 0.21, 0.22, 0.33, 0 })
	self.finalRing:draw({
		r = rf, y = 0.16, flat = true, w = ramp(ft, { 0, 3, 0.1, 2.6, 0.27, 1.6 }), op = rim * 0.5, col = WARM, le = 1, bright = 1.4,
		core = { op = rim, col = CREAM, w = 0.3, bright = 3 },
	})
	-- the wash behind the rim: strongest against it, thinning toward the middle
	local wash = ramp(ft, { 0.03, 0, 0.06, 0.36, 0.14, 0.2, 0.25, 0 })
	local washWide = 2 + ft * 9
	self.finalBand:draw({ r = rf - 0.6 - washWide / 2, y = 0.13, flat = true, w = washWide, op = wash, col = WARM, le = 0.85, bright = 1 })
	self.finalBandInner:draw({ r = rf - 0.6 - washWide * 1.5, y = 0.12, flat = true, w = washWide, op = wash * 0.4, col = WARM, le = 0.85, bright = 1 })
	self.fill:disc(rf, 0.11, ramp(ft, { -0.012, 0, 0, 0.9, 0.04, 0.5, 0.07, 0.3, 0.12, 0.12, 0.2, 0 }), CREAM, 0.9, 1.3)

	-- the dark crown the first burst leaves; every big hit kicks it again
	local crown = ramp(t, { 0.955, 0, 0.99, 1.16, 1.05, 1 }) * (1 - smooth(3.12, 3.38, t))
	if crown > 0.004 then
		for _, kick in { 1.93, 2.9 } do
			if t >= kick then
				crown *= 1 + 0.2 * math.exp(-(t - kick) / 0.08)
			end
		end
	end
	for _, c in self.spikes do
		if crown > 0.004 then
			local q = c.q
			local dir = Vector3.new(math.cos(c.a), 0, math.sin(c.a))
			local base = dir * (6.5 + 3.5 * q[1])
			local tip = base + (dir * (1.4 + 1.8 * q[2]) + up * (2.4 + 3 * q[3])) * crown
			c.s:draw(base, tip, 1.5 + 1.4 * q[4], 0, 0.74 * math.min(crown, 1), 0.6 * math.min(crown, 1), q[5] > 0.5 and ASH or DARK, 0, 1)
		else
			c.s:hide()
		end
	end

	for i, c in self.sparks do
		local op, far = 0, 0
		for _, ts in SPARKS do
			local tau = t - ts
			if tau >= 0 and tau < 0.13 then
				op, far = ramp(tau, { 0, 0, 0.008, 1, 0.07, 1, 0.13, 0 }), 7 + 150 * tau * (0.6 + 0.6 * c.q[1])
			end
		end
		if op > 0.004 and i % 2 == (t < 2 and 0 or 1) then
			local dir = Vector3.new(math.cos(c.a), 0, math.sin(c.a))
			local at = dir * far + up * (0.8 + 2.2 * c.q[2])
			c.s:draw(at, at + dir * (2.4 + 2 * c.q[3]) + up * 0.5, 0.12, 0.34, op * 0.3, op, CREAM, 1, 3.5)
		else
			c.s:hide()
		end
	end

	for _, c in self.lines do
		if lines > 0.004 then
			local rr = 2.5 + 4 * c.q[1]
			local base = Vector3.new(math.cos(c.a) * rr, 0.2, math.sin(c.a) * rr)
			c.s:draw(base, base + up * (10 + 8 * c.q[2]), 0.16, 0.05, lines, lines * 0.3, CREAM, 1, 1.5)
		else
			c.s:hide()
		end
	end

	local S = self.scale
	local origin = self.host.CFrame
	for _, d in self.debris do
		local tau = t - d.t0
		if tau >= 0 and tau < d.life then
			local pos = d.p0 + d.v * tau - Vector3.new(0, 0.5 * GRAVITY * tau * tau, 0)
			local size = smooth(0, 0.03, tau) * (1 - smooth(d.life - 0.14, d.life, tau))
			d.part.Size = d.size * S * math.max(size, 0.05)
			d.part.CFrame = origin * CFrame.new(pos * S) * CFrame.fromAxisAngle(d.axis, tau * d.spin)
			d.part.Transparency = 0
			d.live = true
		elseif d.live ~= false then
			d.live = false
			d.part.Transparency = 1
			d.part.Size = Vector3.one * 0.05
			d.part.CFrame = origin
		end
	end

	self.light.Brightness = math.min(light * 0.55, 4)
end

-- live playback: Seek plus the particle bursts that fall between the previous call and this one
function Strike:Step(t)
	if t < self.last then
		self.last = -1
	end
	for _, mark in self.marks do
		if mark[1] > self.last and mark[1] <= t then
			mark[2]:Emit(mark[3])
		end
	end
	self.last = t
	self:Seek(t)
end

return Strike
