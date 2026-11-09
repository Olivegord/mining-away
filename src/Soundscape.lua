-- Client-only Toolbox audio. Gameplay and reward confirmation stay on the server.
-- Asset names, creators and Creator Store links: docs/review/AUDIO_LIGHTING.md.
local SoundService = game:GetService('SoundService')
local ContentProvider = game:GetService('ContentProvider')
local TweenService = game:GetService('TweenService')
local Debris = game:GetService('Debris')
local Players = game:GetService('Players')
local Http = game:GetService('HttpService')
local Soundscape = {}; Soundscape.__index = Soundscape

local TRACKS = {
 {name='Bossa Me (a)',id='1837768517'},
 {name='Heavenly Fields',id='1835928951'},
 {name='The City',id='1835929012'},
}
local CUES = {
 click={id='9126066421',volume=.16,duration=1,cooldown=.075,fallback='volume_slider.ogg'},
 sale={id='soft-sale',localSound='rbxasset://sounds/action_jump_land.mp3',volume=.075,duration=.65,pitch=1.05,cooldown=.8,fallback='action_jump_land.mp3'},
 pickup={id='soft-pickup',localSound='rbxasset://sounds/volume_slider.ogg',volume=.11,duration=.3,pitch=1.2,cooldown=.09,fallback='volume_slider.ogg'},
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
 parcel_latch={id='9126066421',volume=.18,duration=.5,pitch=.8,cooldown=.1,fallback='action_get_up.mp3'},
 unload={id='9118941971',volume=.15,duration=.55,pitch=.9,cooldown=.15,fallback='action_jump_land.mp3'},
 courier_sale={id='91735091370012',volume=.1,duration=.8,pitch=1.15,cooldown=.2,fallback='volume_slider.ogg'},
 swarm_launch={id='9118941667',volume=.16,duration=.65,pitch=1.3,cooldown=.2,fallback='action_get_up.mp3'},
 shot={id='9126066421',volume=.19,duration=.45,pitch=1.5,cooldown=.065,fallback='action_get_up.mp3'},
 shield={id='9126066421',volume=.13,duration=.55,pitch=.6,cooldown=.12,fallback='action_jump_land.mp3'},
 reprint={id='91735091370012',volume=.15,duration=.9,pitch=.95,cooldown=.2,fallback='volume_slider.ogg'},
 resonance={id='91735091370012',volume=.12,duration=.8,pitch=.65,cooldown=.14,fallback='volume_slider.ogg'},
 command={id='9126066421',volume=.12,duration=.5,pitch=1.12,cooldown=.12,fallback='volume_slider.ogg'},
 denied={id='9118941971',volume=.1,duration=.4,pitch=.65,cooldown=.25,fallback='volume_slider.ogg'},
 full={id='9126066421',volume=.12,duration=.6,pitch=.7,cooldown=2,fallback='volume_slider.ogg'},
}
local function fade(object,duration,volume)
 local tween=TweenService:Create(object,TweenInfo.new(duration,Enum.EasingStyle.Sine),{Volume=volume})
 tween:Play();return tween
end
local function group(parent,name,volume)
 local value=Instance.new('SoundGroup');value.Name=name;value.Volume=volume;value.Parent=parent;return value
end
function Soundscape.new(effectParent)
 local folder=Instance.new('SoundGroup');folder.Name='DroneBlowerSoundscape';folder.Volume=1;folder.Parent=SoundService
 local self=setmetatable({folder=folder,effectParent=effectParent,tracks={},bank={},cooldowns={},
  voices=0,closed=false,musicMuted=true,effectsMuted=false,combat=false,menu=false,
  loops={},loopCount=0,active={},cueVoices={},droneStates={},
  nextIndex=1,current=nil,lastMusicVolume=-1,random=Random.new()},Soundscape)
 self.musicGroup=group(folder,'Music',0)
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
 for _,track in ipairs(TRACKS) do
  local sound=Instance.new('Sound');sound.Name=track.name;sound.SoundId='rbxassetid://'..track.id
  sound.Volume=0;sound.Looped=false;sound.PlayOnRemove=false;sound.SoundGroup=self.musicGroup;sound.Parent=folder
  table.insert(self.tracks,sound);table.insert(preload,sound)
 end
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
function Soundscape:_musicStep()
 if self.closed or self.musicMuted then return end
 local current=self.current
 local playing=current and current.IsPlaying
 local remaining=playing and current.TimeLength>0 and (current.TimeLength-current.TimePosition) or math.huge
 if playing and remaining>2 then return end
 local nextSound,index
 for offset=0,#self.tracks-1 do
  local i=(self.nextIndex+offset-1)%#self.tracks+1;local candidate=self.tracks[i]
  if candidate.IsLoaded and (candidate~=current or not playing) then nextSound=candidate;index=i;break end
 end
 if not nextSound then return end -- All unavailable: stay quiet and allow later loads to recover.
 self.nextIndex=index%#self.tracks+1;self.current=nextSound
 if current and current~=nextSound then
  fade(current,math.min(2,remaining),0)
  task.delay(2,function() if not self.closed and current~=self.current then current:Stop() end end)
 end
 nextSound.Volume=0;nextSound.TimePosition=0;nextSound:Play();fade(nextSound,2,1)
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
 if self.musicMuted then for _,track in ipairs(self.tracks) do track:Stop() end end
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
function Soundscape:_voice(name,position,looped)
 local cue=CUES[name];local id=cue.ids and cue.ids[self.random:NextInteger(1,#cue.ids)] or cue.id
 local template=self.bank[id];local ready=template and template.IsLoaded
 -- A missing sustained clip stays silent; never loop a generic fallback beep.
 if looped and not ready then return nil end
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
 sound.PlaybackSpeed=(cue.pitch or 1)*(position and self.random:NextNumber(.96,1.04) or 1)
 sound.Looped=looped;sound.PlayOnRemove=false
 local anchor
 if position then
  anchor=Instance.new('Part');anchor.Name='ActionAudio';anchor.Size=Vector3.one*.05
  anchor.Anchored=true;anchor.Transparency=1;anchor.CanCollide=false;anchor.CanTouch=false;anchor.CanQuery=false;anchor.CastShadow=false
  anchor.Position=position;anchor.Parent=self.effectParent
  sound.RollOffMode=Enum.RollOffMode.Linear;sound.RollOffMinDistance=14;sound.RollOffMaxDistance=cue.range or 80
 end
 sound.Parent=anchor or self.folder;self.voices+=1
 self.cueVoices[name]=(self.cueVoices[name] or 0)+1
 self.active[sound]=anchor or false
 sound.Destroying:Once(function()
  self.active[sound]=nil;self.voices=math.max(0,self.voices-1)
  self.cueVoices[name]=math.max(0,(self.cueVoices[name] or 0)-1)
 end)
 return sound,anchor
end
function Soundscape:play(name,position,options)
 local cue=CUES[name];local now=os.clock()
 if self.closed or self.effectsMuted or not cue or self.voices>=22 or now<(self.cooldowns[name] or 0) then return end
 if (self.cueVoices[name] or 0)>=(cue.maxVoices or 5) then return end
 if position and self:_distance(position)>(cue.range or 80) then return end
 self.cooldowns[name]=now+cue.cooldown
 local sound,anchor=self:_voice(name,position,false);if not sound then return end
 local volume=cue.volume/math.sqrt(1+self.voices*.07)*(options and options.level or 1)
 if options and options.pitch then sound.PlaybackSpeed*=options.pitch end
 sound.Ended:Once(function() if anchor then anchor:Destroy() else sound:Destroy() end end)
 sound:Play();fade(sound,cue.attack or .025,volume)
 task.delay(math.max(.05,cue.duration-.22),function() if sound.Parent then fade(sound,.18,0) end end)
 Debris:AddItem(anchor or sound,cue.duration+.05)
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
  if self.voices>=22 then return end
  local sound,anchor=self:_voice(name,position,true);if not sound then return end
  loop={sound=sound,anchor=anchor,name=name,seen=now,step=now};self.loops[key]=loop;self.loopCount+=1
  sound:Play()
 end
 local dt=math.clamp(now-loop.step,1/240,.1);loop.step=now;loop.seen=now
 if loop.anchor then loop.anchor.Position=position end
 local volume=cue.volume*(level or 1)/math.sqrt(1+self.loopCount*.12)
 loop.sound.Volume+=(volume-loop.sound.Volume)*(1-math.exp(-dt*(cue.softLaser and 8 or 14)))
 loop.sound.PlaybackSpeed=(cue.pitch or 1)*(pitch or 1)
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
 local sample={state=state,life=a('Life'),dead=hp<=0 or state=='Destroyed' or state=='Reprinting',
  paused=a('WorkPaused')==true or a('MotionPaused')==true,at=a('SnapshotAt'),chargeAt=a('ChargeAt'),sale=a('CourierSaleSerial') or 0,saleAt=a('CourierSaleAt')}
 local cues,mode=AudioFeedback.drone(record,sample,now)
 -- The production beam renderer owns this rising tone for both real drones
 -- and preview displays. Avoid a second charge loop from the state observer.
 if mode=='charge' and self.chargeFromRenderer then mode=nil end
 for _,name in ipairs(cues) do
  if name~='laser_start' or not self.chargeFromRenderer then self:play(name,position) end
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
  local capacity=current.capacity or 40
  if cargo(before)<(previous.capacity or 40) and cargo(after)>=capacity then self:play('full') end
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
