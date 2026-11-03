-- Append after the production AudioFeedback/Soundscape bundle. Execute on the
-- existing Studio Client. All test audio is muted; no gameplay is changed.
local root=Instance.new('Folder');root.Name='AudioRuntimeVerification';root.Parent=workspace
local audio=Soundscape.new(root);audio.musicGroup.Volume=0;audio.effectsGroup.Volume=0
local camera=workspace.CurrentCamera;local originalCamera=camera.CFrame
local checks={}
local function check(name,fn) fn();table.insert(checks,name) end
local ok,err=pcall(function()
 game:GetService('ContentProvider'):PreloadAsync({audio.bank['9119816710'],audio.bank['9118941667'],audio.bank['9114583503']})
 local playerRoot=assert(game.Players.LocalPlayer.Character:FindFirstChild('HumanoidRootPart'))
 local pos=playerRoot.Position+Vector3.new(0,4,-8)
 check('music starts disabled and never auto-starts a track',function()
  audio:_musicStep();assert(audio.musicMuted and audio.current==nil and audio.musicGroup.Volume==0)
  for _,track in ipairs(audio.tracks) do assert(not track.IsPlaying) end
 end)
 check('character listener and distance survive a distant camera',function()
  local kind,object=game.SoundService:GetListener();assert(kind==Enum.ListenerType.ObjectPosition and object==playerRoot)
  camera.CFrame=CFrame.new(playerRoot.Position+Vector3.new(0,150,150))
  assert(audio:_distance(pos)<10)
  audio:setLoop('zoom','charge',pos,1,1);local loop=assert(audio.loops.zoom)
  assert(loop.sound.RollOffMode==Enum.RollOffMode.Linear and loop.sound.RollOffMinDistance==14)
  assert(loop.sound.RollOffMaxDistance>=75)
  audio:stopLoop('zoom',true);camera.CFrame=originalCamera
 end)
 local d=Instance.new('Model');d.Parent=root
 local function state(s)
  d:SetAttribute('State',s);d:SetAttribute('HP',100);d:SetAttribute('Life',1);d:SetAttribute('SnapshotAt',workspace:GetServerTimeNow())
  d:SetAttribute('WarmupStart',workspace:GetServerTimeNow());d:SetAttribute('WarmupDuration',2);d:SetAttribute('Velocity',Vector3.zero)
 end
 check('warmup creates a spatial power-up; repeated frames reuse it',function()
  state('Warmup');audio:updateDrone(d,pos,workspace:GetServerTimeNow())
  local record=audio.droneStates[d];local loop=assert(audio.loops[record.workKey])
  assert(loop.sound.Looped and loop.sound.SoundGroup==audio.effectsGroup and loop.anchor.Position==pos)
  audio:updateDrone(d,pos,workspace:GetServerTimeNow());assert(audio.loops[record.workKey].sound==loop.sound)
 end)
 check('pause releases the charge immediately',function()
  d:SetAttribute('WorkPaused',true);audio:updateDrone(d,pos,workspace:GetServerTimeNow());assert(audio.loopCount==0);d:SetAttribute('WorkPaused',false)
 end)
 check('six-loop limit preserves higher-priority work',function()
  for n=1,12 do audio:setLoop('flight'..n,'flight',pos,.7,1) end
  assert(audio.loopCount==6);audio:setLoop('important','breaker_charge',pos,1,1);assert(audio.loopCount==6 and audio.loops.important)
 end)
 check('out-of-range work cannot create a voice',function()
  local before=audio.voices;audio:setLoop('far','charge',pos+Vector3.new(1000,0,0),1,1);assert(not audio.loops.far and audio.voices==before)
 end)
 check('three rubble variants load; the family is bounded',function()
  for _,id in ipairs({'9125869504','9125869495','9125869138'}) do game:GetService('ContentProvider'):PreloadAsync({audio.bank[id]});assert(audio.bank[id].IsLoaded) end
  for _=1,10 do audio.cooldowns.rubble=0;audio:play('rubble',pos) end;assert(audio.cueVoices.rubble==4)
 end)
 check('breaker contact and fracture are distinct bounded spatial voices',function()
  audio:play('breaker_contact',pos);audio:play('breaker_fracture',pos)
  assert(audio.cueVoices.breaker_contact==1 and audio.cueVoices.breaker_fracture==1)
  local contact,fracture
  for sound in pairs(audio.active) do
   if sound.Name=='breaker_contact' then contact=sound end
   if sound.Name=='breaker_fracture' then fracture=sound end
  end
  assert(contact and fracture and contact.SoundId~=fracture.SoundId)
  assert(contact.PlaybackSpeed<fracture.PlaybackSpeed and contact.RollOffMode==Enum.RollOffMode.Linear)
 end)
 check('mute clears all action voices and prevents new ones',function()
  audio:toggleEffects();assert(audio.loopCount==0 and audio.voices==0)
  audio:setLoop('muted','charge',pos,1,1);audio:play('rubble',pos);assert(audio.voices==0)
 end)
 audio:toggleEffects();audio.effectsGroup.Volume=0
 check('stale work expires without a renderer cleanup callback',function()
  audio:setLoop('stale','charge',pos,1,1);assert(audio.loops.stale);audio.loops.stale.seen=os.clock()-1;audio:update();assert(not audio.loops.stale)
 end)
 check('rebuilt native buttons connect to the shared effects mix',function()
  local gui=Instance.new('ScreenGui');gui.Parent=game.Players.LocalPlayer.PlayerGui;audio:bindUI(gui)
  local button=Instance.new('TextButton');button.Parent=gui
  assert(audio.uiConnection and audio.uiConnection.Connected);gui:Destroy()
 end)
end)
camera.CFrame=originalCamera;audio:destroy();root:Destroy();assert(audio.voices==0)
assert(ok,tostring(err))
return game:GetService('HttpService'):JSONEncode({checks=checks,voiceCountAfterDestroy=audio.voices,scope='Actual client engine loading/lifecycle checks. Muted; no listening or multiplayer claim.'})
