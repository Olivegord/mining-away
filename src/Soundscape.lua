-- Client-only Toolbox audio. Gameplay and reward confirmation stay on the server.
-- Asset names, creators and Creator Store links: docs/review/AUDIO_LIGHTING.md.
local SoundService = game:GetService('SoundService')
local ContentProvider = game:GetService('ContentProvider')
local TweenService = game:GetService('TweenService')
local Debris = game:GetService('Debris')
local Soundscape = {}; Soundscape.__index = Soundscape

local TRACKS = {
 {name='Bossa Me (a)',id='1837768517'},
 {name='Heavenly Fields',id='1835928951'},
 {name='The City',id='1835929012'},
}
local CUES = {
 click={id='9126066421',volume=.16,duration=1,cooldown=.075,fallback='volume_slider.ogg'},
 sale={id='soft-sale',localSound='rbxasset://sounds/action_jump_land.mp3',volume=.075,duration=.65,pitch=1.05,cooldown=.8,fallback='action_jump_land.mp3'},
 pickup={id='soft-pickup',localSound='rbxasset://sounds/volume_slider.ogg',volume=.055,duration=.3,pitch=1.45,cooldown=.09,fallback='volume_slider.ogg'},
 pack={id='9126066421',volume=.25,duration=1,pitch=.8,cooldown=.4,fallback='volume_slider.ogg'},
 upgrade={id='91735091370012',pitch=.8,volume=.12,duration=4,cooldown=.45,fallback='volume_slider.ogg'},
 prestige={id='91735091370012',volume=.16,duration=4,pitch=.85,cooldown=2,fallback='volume_slider.ogg'},
 cutting={id='9118614717',volume=.045,duration=.6,pitch=.72,cooldown=.22,fallback='action_jump_land.mp3'},
 orbital={id='9118612324',volume=.16,duration=1.1,pitch=.65,cooldown=.25,fallback='action_jump_land.mp3'},
 mining={id='9125871199',volume=.1,duration=2,cooldown=.16,fallback='action_jump_land.mp3'},
 hit={id='9125871199',volume=.15,duration=2,cooldown=.12,fallback='action_jump_land.mp3'},
 death={id='9125871199',volume=.32,duration=2,pitch=.75,cooldown=.2,fallback='impact_explosion_03.mp3'},
 wake={id='9126066421',volume=.3,duration=1,pitch=.65,cooldown=.5,fallback='action_get_up.mp3'},
 ignite={id='9126066421',volume=.27,duration=1,pitch=1.2,cooldown=.25,fallback='action_get_up.mp3'},
 impact={id='9125871199',volume=.45,duration=2,pitch=.7,cooldown=.15,fallback='impact_explosion_03.mp3'},
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
  voices=0,closed=false,musicMuted=false,effectsMuted=false,combat=false,menu=false,
  nextIndex=1,current=nil,lastMusicVolume=-1,random=Random.new()},Soundscape)
 self.musicGroup=group(folder,'Music',.14)
 self.effectsGroup=group(folder,'Actions',.65)
 local eq=Instance.new('EqualizerSoundEffect');eq.Name='GentleActionMix';eq.LowGain=0;eq.MidGain=-3;eq.HighGain=-12;eq.Parent=self.effectsGroup
 local compressor=Instance.new('CompressorSoundEffect');compressor.Name='ActionPeakControl'
 compressor.Threshold=-18;compressor.Ratio=5;compressor.Attack=.01;compressor.Release=.18;compressor.GainMakeup=0;compressor.Parent=self.effectsGroup
 local preload={}
 for _,track in ipairs(TRACKS) do
  local sound=Instance.new('Sound');sound.Name=track.name;sound.SoundId='rbxassetid://'..track.id
  sound.Volume=0;sound.Looped=false;sound.PlayOnRemove=false;sound.SoundGroup=self.musicGroup;sound.Parent=folder
  table.insert(self.tracks,sound);table.insert(preload,sound)
 end
 -- Reuse one loaded template per asset, even when several cues share a clip.
 for _,cue in pairs(CUES) do if not self.bank[cue.id] then
  local sound=Instance.new('Sound');sound.Name='Toolbox_'..cue.id;sound.SoundId=cue.localSound or 'rbxassetid://'..cue.id
  sound.Volume=0;sound.SoundGroup=self.effectsGroup;sound.Parent=folder
  self.bank[cue.id]=sound;table.insert(preload,sound)
 end end
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
  while not self.closed do self:_musicStep();task.wait(.25) end
 end)
 return self
end
function Soundscape:_musicStep()
 if self.closed then return end
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
 return not self.musicMuted
end
function Soundscape:toggleEffects()
 self.effectsMuted=not self.effectsMuted;self.effectsGroup.Volume=self.effectsMuted and 0 or .65
 return not self.effectsMuted
end
function Soundscape:play(name,position)
 local cue=CUES[name];local now=os.clock()
 if self.closed or self.effectsMuted or not cue or self.voices>=12 or now<(self.cooldowns[name] or 0) then return end
 if position and workspace.CurrentCamera and (position-workspace.CurrentCamera.CFrame.Position).Magnitude>110 then return end
 self.cooldowns[name]=now+cue.cooldown
 local template=self.bank[cue.id];local ready=template and template.IsLoaded
 local sound=ready and template:Clone() or Instance.new('Sound')
 sound.Name=name;sound.SoundGroup=self.effectsGroup
 if not ready then sound.SoundId='rbxasset://sounds/'..cue.fallback end
 local volume=cue.volume/math.sqrt(1+self.voices*.25)
 sound.Volume=0
 sound.PlaybackSpeed=(cue.pitch or 1)*(position and self.random:NextNumber(.96,1.04) or 1)
 sound.Looped=false;sound.PlayOnRemove=false
 local anchor
 if position then
  anchor=Instance.new('Part');anchor.Name='ActionAudio';anchor.Size=Vector3.one*.05
  anchor.Anchored=true;anchor.Transparency=1;anchor.CanCollide=false;anchor.CanTouch=false;anchor.CanQuery=false;anchor.CastShadow=false
  anchor.Position=position;anchor.Parent=self.effectParent
  sound.RollOffMode=Enum.RollOffMode.InverseTapered;sound.RollOffMinDistance=5;sound.RollOffMaxDistance=65
 end
 sound.Parent=anchor or self.folder;self.voices+=1
 sound.Destroying:Once(function() self.voices=math.max(0,self.voices-1) end)
 sound.Ended:Once(function() if anchor then anchor:Destroy() else sound:Destroy() end end)
 sound:Play();fade(sound,.025,volume)
 if name=='cutting' or name=='orbital' or name=='sale' then
  task.delay(math.max(.05,cue.duration-.25),function() if sound.Parent then fade(sound,.22,0) end end)
 end
 Debris:AddItem(anchor or sound,cue.duration+.05)
end
function Soundscape:observeProfile(previous,current)
 -- Joining/reconnecting is silent. Only replicated, confirmed changes make a reward cue.
 if current.pendingTransaction then return end
 previous=self.confirmedProfile or (previous and not previous.pendingTransaction and previous or nil)
 self.confirmedProfile=current
 if not previous then return end
 local before,after=previous.run,current.run
 if before.id~=after.id then
  if #current.fleet>#previous.fleet then self:play('prestige') end
 elseif #after.cards>#before.cards then self:play('upgrade')
 elseif (after.packIndex or 0)>(before.packIndex or 0) then self:play('pack')
 elseif (after.saleEarnings or 0)>(before.saleEarnings or 0) then self:play('sale') end
end
function Soundscape:destroy()
 self.closed=true
 if self.musicTween then self.musicTween:Cancel() end
 self.folder:Destroy()
end
return Soundscape
