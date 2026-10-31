--!strict
-- Cosmetic audio follows server-confirmed crystal stages and breaks.
-- Creator Store samples are stored in ReplicatedStorage.CrystalSounds.
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local ContentProvider = game:GetService('ContentProvider')
local TweenService = game:GetService('TweenService')
local Debris = game:GetService('Debris')

local CrystalAudio = {}
CrystalAudio.__index = CrystalAudio

local MAX_VOICES = 24
local STAGE_VOICE_LIMIT = 12 -- Leave room for the final break accents.
local MAX_DISTANCE = 85
local FALLBACK_CRUNCH = 'rbxasset://sounds/action_jump_land.mp3'
local FALLBACK_POP = 'rbxasset://sounds/impact_explosion_03.mp3'

function CrystalAudio.new(parent: Instance)
	local folder = Instance.new('Folder')
	folder.Name = 'CrystalAudio'; folder.Parent = parent
	local bank = ReplicatedStorage:FindFirstChild('CrystalSounds')
	local self = setmetatable({folder = folder, bank = bank, voices = 0, closed = false,
		random = Random.new(), lastStage = -math.huge, lastBreak = -math.huge, variant = 0}, CrystalAudio)
	if bank then task.spawn(function()
		pcall(function() ContentProvider:PreloadAsync(bank:GetChildren()) end)
	end) end
	return self
end

function CrystalAudio:_layer(anchor: BasePart, name: string, volume: number, pitch: number, duration: number, offset: number, bass: number, fadeTime: number?)
	if self.closed or not anchor.Parent or self.voices >= MAX_VOICES then return end
	local template = self.bank and self.bank:FindFirstChild(name)
	local ready = template and template:IsA('Sound') and template.IsLoaded
	local sound = if ready then (template :: Sound):Clone() else Instance.new('Sound')
	sound.Name = name
	if not ready then sound.SoundId = name == 'Pop' and FALLBACK_POP or FALLBACK_CRUNCH end
	sound.Looped = false; sound.PlayOnRemove = false
	local density = 1 / math.sqrt(1 + self.voices * .12)
	local targetVolume = volume * density * self.random:NextNumber(.94, 1.04)
	sound.Volume = 0
	sound.PlaybackSpeed = pitch * self.random:NextNumber(.98, 1.02)
	if not ready and name == 'Pop' then sound.PlaybackSpeed *= 1.8 end
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 10; sound.RollOffMaxDistance = MAX_DISTANCE
	local eq = Instance.new('EqualizerSoundEffect')
	eq.Name = 'StoneTexture'; eq.LowGain = bass; eq.MidGain = 1; eq.HighGain = .5; eq.Parent = sound
	sound.Parent = anchor
	self.voices += 1
	sound.Destroying:Once(function() self.voices = math.max(0, self.voices - 1) end)
	sound.Ended:Once(function() sound:Destroy() end)
	sound:Play(); sound.TimePosition = ready and offset or 0
	TweenService:Create(sound, TweenInfo.new(.012, Enum.EasingStyle.Sine), {Volume = targetVolume}):Play()
	-- Let the short pop finish naturally. Rubble fades over most of its tail,
	-- instead of chopping a still-loud sample after a few frames.
	if ready and name == 'Pop' then duration = sound.TimeLength / sound.PlaybackSpeed + .04 end
	local fade = math.min(fadeTime or duration * .65, duration * .8)
	task.delay(math.max(.025, duration - fade), function()
		if sound.Parent then TweenService:Create(sound, TweenInfo.new(fade, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Volume = 0}):Play() end
	end)
	Debris:AddItem(sound, duration + .06)
end

function CrystalAudio:_importedPop(anchor: BasePart, volume: number, pitch: number)
	if self.closed or self.voices >= MAX_VOICES then return end
	local template = self.bank and self.bank:FindFirstChild('StagePop')
	if not template or not template:IsA('Sound') then return end
	local sound = template:Clone()
	sound.Name = 'StagePop'; sound.Looped = false; sound.PlayOnRemove = false
	sound.TimePosition = 0
	sound.Volume = volume * self.random:NextNumber(.94, 1.04) / math.sqrt(1 + self.voices * .12)
	sound.PlaybackSpeed = pitch
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 10; sound.RollOffMaxDistance = MAX_DISTANCE
	sound.Parent = anchor; self.voices += 1
	sound.Destroying:Once(function() self.voices = math.max(0, self.voices - 1) end)
	sound.Ended:Once(function() sound:Destroy() end)
	-- No trimming, EQ, or extra layers: keep the Toolbox clip's own pop and tail.
	sound:Play()
	Debris:AddItem(sound, math.max(2, sound.TimeLength / sound.PlaybackSpeed + .25))
end

function CrystalAudio:play(position: Vector3, event: string, stage: number, geode: boolean)
	if self.closed then return end
	local camera = workspace.CurrentCamera
	if camera and (position - camera.CFrame.Position).Magnitude > MAX_DISTANCE then return end
	local now = os.clock()
	local breaking = event == 'break'
	if breaking then
		if now - self.lastBreak < .035 then return end
		self.lastBreak = now
	else
		if now - self.lastStage < .025 or self.voices >= STAGE_VOICE_LIMIT then return end
		self.lastStage = now
	end
	if self.voices >= MAX_VOICES then return end
	-- Independent anchors let the debris tail finish after the mined crystal is removed.
	local anchor = Instance.new('Part')
	anchor.Name = breaking and 'CrystalBurst' or 'CrystalCrunch'
	anchor.Size = Vector3.one * .05; anchor.Transparency = 1; anchor.Anchored = true
	anchor.CanCollide = false; anchor.CanTouch = false; anchor.CanQuery = false; anchor.CastShadow = false
	anchor.Position = position; anchor.Parent = self.folder
	Debris:AddItem(anchor, 2.2)
	self.variant = self.variant % 2 + 1
	local crunch = self.variant == 1 and 'CrunchA' or 'CrunchB'
	-- One pitch variation per hit keeps its layers cohesive; each layer has a
	-- smaller extra variation, so consecutive rocks never sound identical.
	local pitch = (geode and .82 or 1) * self.random:NextNumber(.92, 1.08)
	local weight = geode and 1.14 or 1
	if breaking then
		self:_layer(anchor, 'Pop', .3 * weight, 1.08 * pitch, .24, 0, -2, .06)
		self:_layer(anchor, crunch, .35 * weight, 1.24 * pitch, geode and 1.3 or 1.1, .02, 1, .65)
		task.delay(.075, function()
			self:_layer(anchor, crunch, .1 * weight, 1.85 * pitch, .5, .24, -9, .35)
		end)
	else
		-- Play the imported Toolbox pop as-is, with only volume and pitch variation.
		local progression = math.clamp(stage, 1, 3)
		self:_importedPop(anchor, (.22 + progression * .025) * weight, pitch)
	end
end

function CrystalAudio:destroy()
	self.closed = true
	self.folder:Destroy()
end

return CrystalAudio

