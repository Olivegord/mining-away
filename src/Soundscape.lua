-- Client-only Toolbox audio. Gameplay and reward confirmation stay on the server.
-- Asset names, creators and Creator Store links: docs/review/AUDIO_LIGHTING.md.
local SoundService = game:GetService('SoundService')
local ContentProvider = game:GetService('ContentProvider')
local TweenService = game:GetService('TweenService')
local Debris = game:GetService('Debris')
local Players = game:GetService('Players')
local Http = game:GetService('HttpService')
local MusicDirector = require('./MusicDirector')
local Soundscape = {}; Soundscape.__index = Soundscape

local TRACKS = {
 Amber={name='Ambient',id='116857311274471'},
 Ruby={name='Matt’s Emotional Ambient Synthscape',id='81744055232053'},
 Quartz={name='Calm Ambient Dreamscape',id='105147018523009'},
 Violet={name='Sci-Fi Ambient',id='133891253196953'},
 Diamond={name='Deep Ambient',id='102181496252358'},
 Sell={name='Chill Ambient',id='124734593853134'},
}
local FIELD_CONTEXT = {'Amber','Ruby','Quartz','Violet','Diamond'}
local CUES = {
 click={id='9126066421',volume=.16,duration=1,cooldown=.075,fallback='volume_slider.ogg'},
 sale={id='soft-sale',localSound='rbxasset://sounds/action_jump_land.mp3',volume=.075,duration=.65,pitch=1.05,cooldown=.8,fallback='action_jump_land.mp3'},
 sale_confirm={id='9126066421',volume=.26,duration=.22,pitch=.79,cooldown=.14},
 sale_stone={id='9125869495',volume=.35,duration=.25,pitch=.84,cooldown=.048,maxVoices=4},
 sale_gem={id='9125869138',volume=.40,duration=.28,pitch=1.44,cooldown=.048,maxVoices=4},
 sale_credit={id='9126066421',volume=.19,duration=.19,pitch=1.62,attack=.003,cooldown=.045,maxVoices=4},
 sale_dust_credit={id='9125869138',volume=.16,duration=.24,pitch=1.54,attack=.004,cooldown=.065,maxVoices=4},
 gem_reveal={id='91735091370012',volume=.44,duration=1.1,pitch=1.31,attack=.008,cooldown=.11,range=90,maxVoices=3,reserved=true},
 gem_land={id='9125869138',volume=.48,duration=.49,pitch=1.48,cooldown=.055,range=79,maxVoices=4},
 stone_land={id='9125869495',volume=.36,duration=.29,pitch=.71,cooldown=.06,range=62,maxVoices=3},
 pickup={id='soft-pickup',localSound='rbxasset://sounds/volume_slider.ogg',volume=.11,duration=.3,pitch=1.2,cooldown=.09,fallback='volume_slider.ogg'},
 crystal_electric={id='9126066421',volume=.10,duration=.13,pitch=1.6,cooldown=.08,range=42,maxVoices=2},
 crystal_snap={ids={'9125869504','9125869495','9125869138'},volume=.22,duration=.24,pitch=1.12,cooldown=.07,range=60,maxVoices=3,fallback='action_jump_land.mp3'},
 prism_fire={id='9118612324',volume=.65,duration=1.05,pitch=.72,attack=.012,cooldown=.14,range=110,maxVoices=2,reserved=true,fallback='action_jump_land.mp3'},
 prism_blast={id='9125871199',volume=.73,duration=1.1,pitch=.57,attack=.009,cooldown=.055,range=110,maxVoices=4,reserved=true,fallback='impact_explosion_03.mp3'},
 prism_sustain={id='9118614717',loopFallback='139131445232833',volume=.43,pitch=.72,range=118,nearDistance=23,priority=7,reserved=true,softLaser=true},
 prism_charge={id='9119816710',volume=.33,duration=2.1,pitch=.83,cooldown=.1,range=80,priority=4,fallback='volume_slider.ogg'},
 crystal_chip={id='9125869138',volume=.077,duration=.18,pitch=1.40,cooldown=.08,range=48,maxVoices=2},
 crystal_split={id='7158347304',volume=.54,duration=.71,pitch=1.04,attack=.007,cooldown=.105,range=72,maxVoices=3,fallback='action_jump_land.mp3'},
 crystal_impact={id='9125869495',volume=.38,duration=.43,pitch=.63,attack=.007,cooldown=.15,range=62,maxVoices=2,fallback='action_jump_land.mp3'},
 crystal_release_tink={id='9125869138',volume=.30,duration=.29,pitch=1.56,attack=.004,cooldown=.09,range=58,maxVoices=2,fallback='volume_slider.ogg'},
 crystal_fall_tink={id='9125869138',volume=.26,duration=.31,pitch=1.41,attack=.004,cooldown=.065,range=56,maxVoices=3,fallback='volume_slider.ogg'},
 rock_clack={ids={'9125869504','9125869495','9125869138'},volume=.23,duration=.48,pitch=1.05,cooldown=.065,range=65,maxVoices=4,fallback='action_jump_land.mp3'},
 pack_land={id='9125869495',volume=.21,duration=.55,pitch=.8,cooldown=.14,range=34,fallback='action_jump_land.mp3'},
 pack_step={id='9126066421',volume=.16,duration=.38,pitch=1.1,cooldown=.09,range=30,fallback='volume_slider.ogg'},
 pack_open={id='91735091370012',volume=.22,duration=1.65,pitch=1.08,cooldown=.18,range=42,fallback='volume_slider.ogg'},
 upgrade={id='91735091370012',pitch=.8,volume=.12,duration=4,cooldown=.45,fallback='volume_slider.ogg'},
 prestige={id='91735091370012',volume=.16,duration=4,pitch=.85,cooldown=2,fallback='volume_slider.ogg'},
 cutting={id='9118614717',volume=.045,duration=.6,pitch=.72,cooldown=.22,fallback='action_jump_land.mp3'},
 orbital={id='9118612324',volume=.16,duration=1.1,pitch=.65,cooldown=.25,fallback='action_jump_land.mp3'},
 mining={id='9125871199',volume=.22,duration=2,cooldown=.16,fallback='action_jump_land.mp3'},
 hit={id='9125871199',volume=.15,duration=2,cooldown=.12,fallback='action_jump_land.mp3'},
 death={id='9125871199',volume=.32,duration=2,pitch=.75,cooldown=.2,fallback='impact_explosion_03.mp3'},
 wake={id='9126066421',volume=.3,duration=1,pitch=.65,cooldown=.5,fallback='action_get_up.mp3'},
 ignite={id='9126066421',volume=.27,duration=1,pitch=1.2,cooldown=.25,fallback='action_get_up.mp3'},
 impact={id='9125871199',volume=.45,duration=2,pitch=.7,cooldown=.15,fallback='impact_explosion_03.mp3'},
 breaker_contact={id='9125869495',volume=.46,duration=.7,pitch=.68,cooldown=.12,range=85,maxVoices=4,fallback='action_jump_land.mp3'},
 breaker_fracture={id='9125869138',volume=.35,duration=1.1,pitch=1.05,cooldown=.12,range=85,maxVoices=4,fallback='action_jump_land.mp3'},
 rubble={ids={'9125869504','9125869495','9125869138'},volume=.32,duration=1.2,pitch=1.12,cooldown=.055,range=75,maxVoices=4,fallback='action_jump_land.mp3'},
 tool_pipe={ids={'9113500863','9113500510','9113500760'},volume=.42,duration=1.2,pitch=.94,cooldown=.1,range=68,fallback='action_jump_land.mp3'},
 tool_slice={id='9125869138',volume=.36,duration=.72,pitch=1.4,cooldown=.1,range=68,fallback='action_jump_land.mp3'},
 tool_sizzle={id='9118614717',volume=.24,duration=1.45,pitch=.94,cooldown=.1,range=58,fallback='action_jump_land.mp3'},
 tool_stick={id='9126066421',volume=.19,duration=.4,pitch=1.36,cooldown=.1,range=50,fallback='volume_slider.ogg'},
 tool_throw={id='9118941667',volume=.2,duration=.5,pitch=.85,cooldown=.1,range=64,fallback='action_jump_land.mp3'},
 tool_windup={id='9114583503',volume=.15,duration=.52,pitch=1.3,cooldown=.12,range=54,fallback='action_jump_land.mp3'},
 metal_land={id='9125871199',volume=.22,duration=1,pitch=.78,cooldown=.08,fallback='action_jump_land.mp3'},
 ramiel_latch={id='9125871199',volume=.43,duration=.56,pitch=.72,attack=.008,cooldown=.05,nearDistance=22,range=105,maxVoices=4,fallback='action_jump_land.mp3'},
 charge={id='139131445232833',volume=.12,duration=3.05,pitch=.74,cooldown=.1,range=65,priority=3,softLaser=true},
 breaker_charge={id='9114583503',volume=.28,duration=5,pitch=.7,cooldown=.1,range=80,priority=4},
 repair_charge={id='9119816710',volume=.2,duration=3,pitch=1.4,cooldown=.1,range=65,priority=3},
 grow_charge={id='9118941971',volume=.22,duration=1,pitch=.8,cooldown=.1,range=65,priority=2},
 orbital_charge={id='9119816710',volume=.3,duration=3,pitch=.65,cooldown=.1,range=95,priority=4},
 swarm_charge={id='9114583503',volume=.24,duration=5,pitch=1.3,cooldown=.1,range=75,priority=3},
 combat_charge={id='9119816710',volume=.25,duration=3,pitch=.9,cooldown=.1,range=80,priority=4},
 flight={id='9118941667',volume=.18,duration=1,pitch=.85,cooldown=.1,range=60,priority=1},
 cutting_hum={id='9118614717',volume=.13,duration=3,pitch=.70,cooldown=.1,range=80,priority=2,softLaser=true},
 orbital_hum={id='9118612324',volume=.27,duration=3,pitch=.6,cooldown=.1,range=95,priority=4},
 healing={id='9118941971',volume=.14,duration=1,pitch=1.45,cooldown=.1,range=65,priority=2},
 transfer={id='9118941667',volume=.17,duration=1,pitch=1.25,cooldown=.1,range=60,priority=2},
 laser_start={id='139620337204036',volume=.115,duration=.85,pitch=.76,cooldown=.25,range=65,maxVoices=2,softLaser=true,attack=.07},
 laser_stop={id='9118941971',volume=.06,duration=.45,pitch=.65,cooldown=.12,fallback='volume_slider.ogg',softLaser=true,attack=.06},
 dive={id='9118941667',volume=.21,duration=.55,pitch=.65,cooldown=.1,fallback='action_get_up.mp3'},
 heal={id='91735091370012',volume=.12,duration=.8,pitch=1.4,cooldown=.15,fallback='volume_slider.ogg'},
 plant={id='91735091370012',volume=.15,duration=.9,pitch=.85,cooldown=.18,fallback='volume_slider.ogg'},
 claw_snap={id='9126066421',volume=.24,duration=.29,pitch=1.29,cooldown=.08,instant=true,fallback='action_get_up.mp3'},
 parcel_latch={id='9126066421',volume=.18,duration=.5,pitch=.8,cooldown=.1,fallback='action_get_up.mp3'},
 unload={id='9118941971',volume=.15,duration=.55,pitch=.9,cooldown=.15,fallback='action_jump_land.mp3'},
 courier_sale={id='91735091370012',volume=.1,duration=.8,pitch=1.15,cooldown=.2,fallback='volume_slider.ogg'},
 counter_settle={id='9125869495',volume=.14,duration=.38,pitch=.88,cooldown=.2,range=34,maxVoices=2,fallback='action_jump_land.mp3'},
 swarm_launch={id='9118941667',volume=.16,duration=.65,pitch=1.3,cooldown=.2,fallback='action_get_up.mp3'},
 scrap_tap={id='9113500510',volume=.11,duration=.18,pitch=1.46,attack=.006,cooldown=.085,range=29,maxVoices=2,fallback='volume_slider.ogg'},
 shot={id='9126066421',volume=.19,duration=.45,pitch=1.5,cooldown=.065,fallback='action_get_up.mp3'},
 needle_fire={id='9113500510',volume=.21,duration=.20,pitch=1.46,attack=.008,cooldown=.07,range=54,maxVoices=3,fallback='volume_slider.ogg'},
 needle_cock={id='9126066421',volume=.096,duration=.13,pitch=1.47,attack=.012,cooldown=.14,range=38,maxVoices=2,fallback='volume_slider.ogg'},
 needle_hit={ids={'9125869504','9125869138'},volume=.29,duration=.26,pitch=1.32,attack=.008,cooldown=.075,range=59,maxVoices=3,fallback='action_jump_land.mp3'},
 coil_load={id='9119816710',volume=.18,duration=.57,pitch=1.12,attack=.035,cooldown=.16,range=51,maxVoices=2,fallback='volume_slider.ogg'},
 coil_fire={id='9118941667',volume=.28,duration=.36,pitch=.79,attack=.012,cooldown=.13,range=65,maxVoices=3,fallback='action_get_up.mp3'},
 coil_hit={id='9125869495',volume=.47,duration=.49,pitch=.69,attack=.009,cooldown=.13,range=74,maxVoices=3,fallback='impact_explosion_03.mp3'},
 ore_land={id='9125869495',volume=.86,duration=.47,pitch=1.08,instant=true,cooldown=.025,
  nearDistance=34,range=92,maxVoices=5,reserved=true,fallback='action_jump_land.mp3'},
 shield={id='9126066421',volume=.13,duration=.55,pitch=.6,cooldown=.12,fallback='action_jump_land.mp3'},
 reprint={id='91735091370012',volume=.15,duration=.9,pitch=.95,cooldown=.2,fallback='volume_slider.ogg'},
 resonance={id='91735091370012',volume=.12,duration=.8,pitch=.65,cooldown=.14,fallback='volume_slider.ogg'},
 command={id='9126066421',volume=.12,duration=.5,pitch=1.12,cooldown=.12,fallback='volume_slider.ogg'},
 denied={id='9118941971',volume=.1,duration=.4,pitch=.65,cooldown=.25,fallback='volume_slider.ogg'},
 full={id='9126066421',volume=.12,duration=.6,pitch=.7,cooldown=2,fallback='volume_slider.ogg'},
}
-- Owner-provided WAVs, cuts and measurements: assets/audio/downloads/manifest.json.
-- Completed Roblox upload receipts, owned by this experience's creator.
local DOWNLOADS = {rock='96292866549392',laser='88808719170718',ball='136064510893795',
 synth='116172612398887',boom='73460664261612'}
local ROCK_CUTS = {
 small={{start=0,duration=1.735},{start=1.985,duration=1.155},{start=3.390,duration=1.665}},
 medium={{start=5.305,duration=1.415},{start=6.970,duration=2.605},{start=9.825,duration=2.525}},
 large={{start=12.600,duration=1.949583},{start=14.799583,duration=1.885}},
}
if DOWNLOADS.rock then
 CUES.crystal_split={id=DOWNLOADS.rock,volume=1.55,duration=2.7,pitch=1,attack=.003,
  cooldown=.065,range=82,maxVoices=5,rockCuts=true,naturalTail=true,fallback='action_jump_land.mp3'}
end
if DOWNLOADS.laser then
 CUES.laser_start={id=DOWNLOADS.laser,volume=.44,duration=.821521,pitch=1,attack=.006,
  cooldown=.16,range=65,maxVoices=3,naturalTail=true,fallback='volume_slider.ogg'}
end
CUES.ballcaster_charge={id=CUES.coil_load.id,volume=.29,duration=.55,pitch=.94,attack=.035,
 cooldown=.12,range=65,maxVoices=3,fallback='volume_slider.ogg'}
CUES.ballcaster_impact={id=CUES.coil_hit.id,volume=.71,duration=.47,pitch=.60,attack=.004,
 cooldown=.105,nearDistance=23,range=82,maxVoices=4,reserved=true,fallback='impact_explosion_03.mp3'}
CUES.ballcaster_fire=table.clone(CUES.coil_fire)
if DOWNLOADS.ball then
 CUES.ballcaster_fire={id=DOWNLOADS.ball,volume=.47,duration=3.642857,pitch=1,attack=.006,
  cooldown=.13,range=74,maxVoices=3,naturalTail=true,fallback='action_get_up.mp3'}
end
-- Keep the existing Ramiel base intact and leave Nomad's prism_blast untouched.
CUES.ramiel_blast=table.clone(CUES.prism_blast)
if DOWNLOADS.synth and DOWNLOADS.boom then
 CUES.synth_explosion={id=DOWNLOADS.synth,volume=.40,duration=6.741562,pitch=1,attack=.006,
  cooldown=.16,nearDistance=22,range=120,maxVoices=3,reserved=true,naturalTail=true,skipMissing=true}
 CUES.cinematic_boom={id=DOWNLOADS.boom,volume=.46,duration=2.070333,pitch=1,attack=.004,
  cooldown=.16,nearDistance=22,range=120,maxVoices=3,reserved=true,naturalTail=true,skipMissing=true}
 CUES.ramiel_blast.layers={'synth_explosion','cinematic_boom'}
 CUES.orbital.layers={'synth_explosion','cinematic_boom'}
end
local function fade(object,duration,volume)
 local tween=TweenService:Create(object,TweenInfo.new(duration,Enum.EasingStyle.Sine),{Volume=volume})
 tween:Play();return tween
end
local function group(parent,name,volume)
 local value=Instance.new('SoundGroup');value.Name=name;value.Volume=volume;value.Parent=parent;return value
end
function Soundscape.new(effectParent)
 local folder=Instance.new('SoundGroup');folder.Name='DroneBlowerSoundscape';folder.Volume=1;folder.Parent=SoundService
 local self=setmetatable({folder=folder,effectParent=effectParent,bank={},cooldowns={},
  voices=0,closed=false,musicMuted=false,effectsMuted=false,combat=false,menu=false,
  loops={},loopCount=0,active={},cueVoices={},droneStates={},
  nextMusicSample=0,nextMusicCheck=0,musicRetryAt=0,lastMusicVolume=-1,random=Random.new()},Soundscape)
 self.musicDirector=MusicDirector.new(Random.new(),os.clock())
 self.musicGroup=group(folder,'Music',0)
 local music=Instance.new('Sound');music.Name='BackgroundMusic';music.Volume=0
 music.Looped=false;music.SoundGroup=self.musicGroup;music.Parent=folder
 self.music=music
 music.Ended:Connect(function()
  if self.closed or not self.current then return end
  self.current=nil
  self.musicDirector:finished(os.clock())
 end)
 self.effectsGroup=group(folder,'Actions',1)
 self.crystalGroup=group(folder,'OriginalCrystals',1)
 local eq=Instance.new('EqualizerSoundEffect');eq.Name='GentleActionMix';eq.LowGain=0;eq.MidGain=0;eq.HighGain=-3;eq.Parent=self.effectsGroup
 local compressor=Instance.new('CompressorSoundEffect');compressor.Name='ActionPeakControl'
 compressor.Threshold=-8;compressor.Ratio=3;compressor.Attack=.1;compressor.Release=.18;compressor.GainMakeup=0;compressor.Parent=self.effectsGroup
 self.listenerType,self.listenerObject=SoundService:GetListener()
 -- A replacement controller inherits the baseline camera listener rather than
 -- restoring a previous controller's ownership after that controller closes.
 if SoundService:GetAttribute('DroneBlowerListenerOwner') then self.listenerType=Enum.ListenerType.Camera;self.listenerObject=nil end
 self.listenerToken=Http:GenerateGUID(false)
 self:_listenerStep()
 local preload={}
 -- Reuse one loaded template per asset, even when several cues share a clip.
 for _,cue in pairs(CUES) do for _,id in ipairs(cue.ids or {cue.id}) do if not self.bank[id] then
  local sound=Instance.new('Sound');sound.Name='Toolbox_'..id;sound.SoundId=cue.localSound or 'rbxassetid://'..id
  sound.Volume=0;sound.SoundGroup=self.effectsGroup;sound.Parent=folder
  self.bank[id]=sound;table.insert(preload,sound)
 end end end
 for _,sound in ipairs(preload) do task.spawn(function()
  local ok,err=pcall(function()
   ContentProvider:PreloadAsync({sound},function(_,status)
    if not self.closed and status==Enum.AssetFetchStatus.Failure then
     warn('[Drone Blower audio] Could not load '..sound.Name..' ('..sound.SoundId..'); skipping or using a local fallback.')
    end
   end)
  end)
  if not ok and not self.closed then warn('[Drone Blower audio] '..tostring(err)) end
 end) end
 -- No audio download blocks the HUD, player input or drone rendering.
 task.spawn(function()
  while not self.closed do self:_musicStep();self:update();task.wait(.1) end
 end)
 return self
end
function Soundscape:observeMining(world,root,drones,resourceIndex,owner,serverNow)
 local now=os.clock()
 if now<self.nextMusicSample then return end
 self.nextMusicSample=now+1
 local context,fieldId
 local map=world:FindFirstChild('Map')
 local run=map and map:FindFirstChild('CrystalRun')
 if root and run then
  for _,model in ipairs(run:GetChildren()) do
   local bed=model:FindFirstChild('Field')
   if bed and bed:IsA('BasePart') then
    local field=FIELD_CONTEXT[bed:GetAttribute('CrystalZone')]
    local offset=bed.CFrame:PointToObjectSpace(root.Position)
    if field and math.abs(offset.X)<=bed.Size.X*.5 and math.abs(offset.Z)<=bed.Size.Z*.5
     and math.abs(offset.Y)<=bed.Size.Y*.5+12 then
     context=field;fieldId=bed:GetAttribute('FieldId')
     break
    end
   end
  end
 end
 local working=false
 if fieldId then
  for drone in pairs(drones) do
   local state=drone:GetAttribute('State')
   if (state=='Mine' or state=='Warmup' or state=='SpecialMine' or state=='BreakerDive')
    and drone:GetAttribute('Owner')==owner and not drone:GetAttribute('WorkPaused')
    and not drone:GetAttribute('MotionPaused') and AudioFeedback.fresh(drone:GetAttribute('SnapshotAt'),serverNow) then
    local target=resourceIndex[tostring(drone:GetAttribute('TargetId') or '')]
    if target and target.source:GetAttribute('FieldId')==fieldId then working=true;break end
   end
  end
 end
 self.musicDirector:observe(now,context,working)
end
function Soundscape:observeSale(receipt)
 self.musicDirector:sale(os.clock(),receipt)
end
function Soundscape:_musicStep()
 if self.closed or self.musicMuted or self.current then return end
 local now=os.clock()
 if now<self.nextMusicCheck or now<self.musicRetryAt then return end
 self.nextMusicCheck=now+.5
 local context=not self.combat and not self.menu and self.musicDirector:eligible(now)
 local track=context and TRACKS[context]
 if not track then self.pendingTrack=nil;return end
 local music=self.music
 if self.pendingTrack~=track then
  self.pendingTrack=track;self.musicLoadDeadline=now+20
  music.Name=track.name;music.SoundId='rbxassetid://'..track.id
  if not music.IsLoaded then
   task.spawn(function() pcall(ContentProvider.PreloadAsync,ContentProvider,{music}) end)
  end
  return
 end
 if not music.IsLoaded then
  if now>=self.musicLoadDeadline then self.pendingTrack=nil;self.musicRetryAt=now+45 end
  return
 end
 self.pendingTrack=nil
 self.current=track
 self.musicDirector:started(context)
 music.Volume=0;music.TimePosition=0;music:Play();fade(music,3,1)
end
function Soundscape:setContext(combat,menu)
 self.combat=combat==true;self.menu=menu==true
 local volume=self.musicMuted and 0 or (self.combat and .055 or (self.menu and .085 or .14))
 if volume~=self.lastMusicVolume then
  self.lastMusicVolume=volume
  if self.musicTween then self.musicTween:Cancel() end
  self.musicTween=fade(self.musicGroup,.45,volume)
 end
end
function Soundscape:toggleMusic()
 self.musicMuted=not self.musicMuted;self:setContext(self.combat,self.menu)
 if self.musicMuted then
  if self.current then self.musicDirector:finished(os.clock()) end
  self.current=nil;self.pendingTrack=nil;self.music:Stop()
 end
 return not self.musicMuted
end
function Soundscape:toggleEffects()
 self.effectsMuted=not self.effectsMuted;self.effectsGroup.Volume=self.effectsMuted and 0 or 1
 self.crystalGroup.Volume=self.effectsGroup.Volume
 if self.effectsMuted then
  for key in pairs(self.loops) do self:stopLoop(key,true) end
  local active=table.clone(self.active);for sound,anchor in pairs(active) do (anchor or sound):Destroy() end
 end
 return not self.effectsMuted
end
function Soundscape:_distance(position)
 local player=Players.LocalPlayer
 local root=player and player.Character and player.Character:FindFirstChild('HumanoidRootPart')
 local origin=root and root.Position or (workspace.CurrentCamera and workspace.CurrentCamera.CFrame.Position)
 return position and origin and (position-origin).Magnitude or 0
end
function Soundscape:_listenerStep()
 local player=Players.LocalPlayer
 local root=player and player.Character and player.Character:FindFirstChild('HumanoidRootPart')
 local kind,object=SoundService:GetListener()
 if root==self.listenerRoot and (not root or (kind==Enum.ListenerType.ObjectPosition and object==root)) then return end
 if root then
  -- Position follows the character; stereo orientation still follows the camera.
  SoundService:SetListener(Enum.ListenerType.ObjectPosition,root)
  SoundService:SetAttribute('DroneBlowerListenerOwner',self.listenerToken)
 elseif SoundService:GetAttribute('DroneBlowerListenerOwner')==self.listenerToken then
  SoundService:SetListener(Enum.ListenerType.Camera)
 end
 self.listenerRoot=root
end
function Soundscape:_voice(name,position,looped,options)
 local cue=CUES[name];local id=cue.ids and cue.ids[self.random:NextInteger(1,#cue.ids)] or cue.id
 local template=self.bank[id]
 if looped and cue.loopFallback and not (template and template.IsLoaded) then template=self.bank[cue.loopFallback] end
 local ready=template and template.IsLoaded
 -- A missing sustained clip stays silent; never loop a generic fallback beep.
 if (looped or cue.skipMissing) and not ready then return nil end
 local sound=ready and template:Clone() or Instance.new('Sound')
 sound.Name=name;sound.SoundGroup=self.effectsGroup
 if cue.softLaser then
  -- Remove the piercing upper bands on laser voices only. Shared templates
  -- stay untouched, so crystal cracks and other jobs retain their character.
  local eq=Instance.new('EqualizerSoundEffect');eq.Name='SoftLaserTone'
  eq.LowGain=0;eq.MidGain=-9;eq.HighGain=-20;eq.Parent=sound
 end
 if not ready then sound.SoundId='rbxasset://sounds/'..(cue.fallback or 'action_get_up.mp3') end
 sound.Volume=0
 -- Sample a voice once so live charge bends don't pick up frame-to-frame jitter.
 local spread=looped and (cue.softLaser and .02 or .04) or (cue.softLaser and .03 or .08)
 local pitchFactor=self.random:NextNumber(1-spread,1+spread)
 sound.PlaybackSpeed=(cue.pitch or 1)*pitchFactor
 local clipDuration
 if cue.naturalTail and ready then clipDuration=cue.duration end
 if cue.rockCuts and ready then
  local pool=AudioFeedback.rockPool(options and options.rockSize)
  local cuts=ROCK_CUTS[pool]
  self.lastRockCut=self.lastRockCut or {}
  local previous=self.lastRockCut[pool]
  local index=AudioFeedback.variantIndex(#cuts,previous,self.random:NextInteger(1,previous and #cuts-1 or #cuts))
  self.lastRockCut[pool]=index
  local cut=cuts[index]
  -- Engine-enforced bounds prevent another cut playing if a frame stalls.
  sound.PlaybackRegionsEnabled=true
  sound.PlaybackRegion=NumberRange.new(cut.start,cut.start+cut.duration)
  sound.TimePosition=cut.start;clipDuration=cut.duration
 end
 sound.Looped=looped;sound.PlayOnRemove=false
 local anchor
 if position then
  anchor=Instance.new('Part');anchor.Name='ActionAudio';anchor.Size=Vector3.one*.05
  anchor.Anchored=true;anchor.Transparency=1;anchor.CanCollide=false;anchor.CanTouch=false;anchor.CanQuery=false;anchor.CastShadow=false
  anchor.Position=position;anchor.Parent=self.effectParent
  sound.RollOffMode=Enum.RollOffMode.Linear;sound.RollOffMinDistance=cue.nearDistance or 14;sound.RollOffMaxDistance=cue.range or 80
 end
 sound.Parent=anchor or self.folder;self.voices+=1
 self.cueVoices[name]=(self.cueVoices[name] or 0)+1
 self.active[sound]=anchor or false
 sound.Destroying:Once(function()
  self.active[sound]=nil;self.voices=math.max(0,self.voices-1)
  self.cueVoices[name]=math.max(0,(self.cueVoices[name] or 0)-1)
 end)
 return sound,anchor,pitchFactor,clipDuration
end
function Soundscape:play(name,position,options)
 local cue=CUES[name];local now=os.clock()
 if self.closed or self.effectsMuted or not cue or self.voices>=(cue.reserved and 25 or 22) or now<(self.cooldowns[name] or 0) then return end
 if (self.cueVoices[name] or 0)>=(cue.maxVoices or 5) then return end
 if position and self:_distance(position)>(cue.range or 80) then return end
 self.cooldowns[name]=now+cue.cooldown
 local sound,anchor,_,clipDuration=self:_voice(name,position,false,options);if not sound then return end
 local volume=cue.volume/math.sqrt(1+self.voices*.07)*(options and options.level or 1)
 if options and options.pitch then sound.PlaybackSpeed*=options.pitch end
 sound.Ended:Once(function() if anchor then anchor:Destroy() else sound:Destroy() end end)
 if cue.instant then sound.Volume=volume end
 sound:Play()
 if not cue.instant then fade(sound,cue.attack or .025,volume) end
 -- Imported clips keep their decay, including when pitch lowers playback speed.
 local duration=clipDuration and clipDuration/math.max(.1,sound.PlaybackSpeed) or cue.duration
 local tail=clipDuration and .035 or .22
 task.delay(math.max(.05,duration-tail),function() if sound.Parent then fade(sound,clipDuration and .03 or .18,0) end end)
 Debris:AddItem(anchor or sound,duration+.10)
 if cue.layers then
  for _,layer in ipairs(cue.layers) do self:play(layer,position,{level=options and options.level or 1}) end
 end
end
function Soundscape:stopLoop(key,immediate)
 local loop=self.loops[key];if not loop then return end
 self.loops[key]=nil;self.loopCount=math.max(0,self.loopCount-1)
 if immediate or not loop.sound.Parent then (loop.anchor or loop.sound):Destroy()
 else fade(loop.sound,.12,0);Debris:AddItem(loop.anchor or loop.sound,.14) end
end
function Soundscape:setLoop(key,name,position,level,pitch)
 local cue=CUES[name];local loop=self.loops[key];local now=os.clock()
 if self.closed or self.effectsMuted or not cue or typeof(position)~='Vector3' or self:_distance(position)>(cue.range or 80) or (level or 1)<=0 then self:stopLoop(key);return end
 if loop and (loop.name~=name or not loop.sound.Parent) then self:stopLoop(key);loop=nil end
 if not loop then
  -- Six spatial beds, with priority and proximity eviction, leave room for
  -- impacts/rewards. A swarm never creates an unbounded choir of motors.
  if self.loopCount>=6 then
   local worstKey,worstScore
   for candidate,item in pairs(self.loops) do
    local score=(CUES[item.name].priority or 1)*100-self:_distance(item.anchor.Position)
    if not worstScore or score<worstScore then worstKey=candidate;worstScore=score end
   end
   local score=(cue.priority or 1)*100-self:_distance(position)
   if not worstScore or score<=worstScore+5 then return end
   self:stopLoop(worstKey)
  end
  if self.voices>=(cue.reserved and 25 or 22) then return end
  local sound,anchor,pitchFactor=self:_voice(name,position,true);if not sound then return end
  loop={sound=sound,anchor=anchor,name=name,seen=now,step=now,pitchFactor=pitchFactor};self.loops[key]=loop;self.loopCount+=1
  sound:Play()
 end
 local dt=math.clamp(now-loop.step,1/240,.1);loop.step=now;loop.seen=now
 if loop.anchor then loop.anchor.Position=position end
 local volume=cue.volume*(level or 1)/math.sqrt(1+self.loopCount*.12)
 loop.sound.Volume+=(volume-loop.sound.Volume)*(1-math.exp(-dt*(cue.reserved and 21 or cue.softLaser and 8 or 14)))
 loop.sound.PlaybackSpeed=(cue.pitch or 1)*(pitch or 1)*loop.pitchFactor
end
function Soundscape:update()
 if self.closed then return end
 self:_listenerStep()
 local now=os.clock()
 for key,loop in pairs(self.loops) do
  -- Stop even if an interrupted renderer never gets another cleanup callback.
  if now-loop.seen>.3 or not loop.sound.Parent then self:stopLoop(key) end
 end
end
function Soundscape:updateDrone(source,position,now)
 local record=self.droneStates[source]
 if not record then record={workKey={},flightKey={}};self.droneStates[source]=record end
 local function a(name) return source:GetAttribute(name) end
 local state=a('State');local hp=a('HP') or 0
 local player=Players.LocalPlayer
 local sample={state=state,life=a('Life'),dead=hp<=0 or state=='Destroyed' or state=='Reprinting',
  paused=a('WorkPaused')==true or a('MotionPaused')==true,at=a('SnapshotAt'),chargeAt=a('ChargeAt'),sale=a('CourierSaleSerial') or 0,saleAt=a('CourierSaleAt'),
  physical=(a('DeliverySlots') or 0)>0,ownCourier=player and a('Owner')==player.UserId}
 local cues,mode=AudioFeedback.drone(record,sample,now)
 -- The production beam renderer owns this rising tone for both real drones
 -- and preview displays. Avoid a second charge loop from the state observer.
 if mode=='charge' and self.chargeFromRenderer then mode=nil end
 for _,name in ipairs(cues) do
  if name=='counter_settle' then
   local counter=a('SellPosition')
   if typeof(counter)=='Vector3' then self:play(name,counter) end
  elseif name~='laser_start' or not self.chargeFromRenderer then self:play(name,position) end
 end
 if mode then
  local start,duration
  if state=='Warmup' then start=a('WarmupStart');duration=a('WarmupDuration')
  elseif state=='RepairCharge' then start=a('RepairChargeAt');duration=a('RepairChargeDuration')
  elseif state=='BreakerWindup' then start=a('BreakerPhaseAt');duration=.8 end
  local q=start and duration and math.clamp((now-start)/math.max(.01,duration),0,1) or .6
  self:setLoop(record.workKey,mode,position,.65+.35*q,.8+.4*q)
 else self:stopLoop(record.workKey) end
 local velocity=a('Velocity');local speed=typeof(velocity)=='Vector3' and velocity.Magnitude or 0
 if not sample.dead and not sample.paused and AudioFeedback.fresh(sample.at,now) and speed>2 then
  self:setLoop(record.flightKey,'flight',position,math.clamp(speed/18,.2,1),.85+math.min(speed,30)/65)
 else self:stopLoop(record.flightKey) end
end
function Soundscape:forgetDrone(source)
 local record=self.droneStates[source];if not record then return end
 self:stopLoop(record.workKey);self:stopLoop(record.flightKey);self.droneStates[source]=nil
end
function Soundscape:bindUI(root)
 if self.uiConnection then self.uiConnection:Disconnect() end
 local function bind(object)
  if not object:IsA('GuiButton') then return end
  -- Instance-owned connections disappear with rebuilt menus. Do not retain
  -- every historical button in the soundscape's lifetime connection list.
  object.Activated:Connect(function()
   if object.Active and object:GetAttribute('Enabled')~=false then self:play('click') end
  end)
 end
 for _,object in ipairs(root:GetDescendants()) do bind(object) end
 self.uiConnection=root.DescendantAdded:Connect(bind)
end
function Soundscape:observeProfile(previous,current)
 -- Joining/reconnecting is silent. Only replicated, confirmed changes make a reward cue.
 if current.pendingTransaction then return end
 previous=self.confirmedProfile or (previous and not previous.pendingTransaction and previous or nil)
 self.confirmedProfile=current
 if not previous then return end
 local before,after=previous.run,current.run
 local shopChanged=false
 for id,level in pairs(after.shopLevels or {}) do if level>((before.shopLevels or {})[id] or 0) then shopChanged=true;break end end
 if before.id~=after.id then
  if #current.fleet>#previous.fleet then self:play('prestige') end
 elseif #after.cards>#before.cards then self:play('upgrade')
 elseif shopChanged then self:play('upgrade')
 elseif (after.saleEarnings or 0)>(before.saleEarnings or 0) then self:play('sale') end
 if before.id==after.id then
  local function cargo(run) local total=0;for _,units in pairs(run.cargo or {}) do total+=units end;return total end
  local capacity=current.capacity or 100
  if cargo(before)<(previous.capacity or 100) and cargo(after)>=capacity then self:play('full') end
 end
end
function Soundscape:destroy()
 self.closed=true
 if self.musicTween then self.musicTween:Cancel() end
 if self.uiConnection then self.uiConnection:Disconnect() end
 for key in pairs(self.loops) do self:stopLoop(key,true) end
 local active=table.clone(self.active);for sound,anchor in pairs(active) do (anchor or sound):Destroy() end
 self.droneStates={}
 if SoundService:GetAttribute('DroneBlowerListenerOwner')==self.listenerToken then
  local kind,object=SoundService:GetListener()
  if (kind==Enum.ListenerType.ObjectPosition and object==self.listenerRoot) or not self.listenerRoot then
   local previous=self.listenerObject
   if typeof(previous)=='Instance' and not previous.Parent then SoundService:SetListener(Enum.ListenerType.Camera)
   else SoundService:SetListener(self.listenerType,previous) end
  end
  SoundService:SetAttribute('DroneBlowerListenerOwner',nil)
 end
 self.folder:Destroy()
end
return Soundscape
