-- Prepend the production AudioFeedback and Soundscape bundles. Muted Edit-only
-- component checks; does not start Play or claim a listening/multiplayer test.
assert(not game:GetService('RunService'):IsRunning())
assert(game.PlaceId==124078027733625 and game.GameId==10774898335)
local root=Instance.new('Folder');root.Name='DownloadAudioVerification';root.Parent=workspace
local audio=Soundscape.new(root);audio.effectsGroup.Volume=0;audio.musicGroup.Volume=0
audio.random=Random.new(1857)
local results={}
local function clear()
 for sound,anchor in pairs(table.clone(audio.active)) do (anchor or sound):Destroy() end
 audio.cooldowns={}
 assert(audio.voices==0)
end
local ok,err=pcall(function()
 local ids={'96292866549392','88808719170718','136064510893795','116172612398887','73460664261612'}
 local sounds={};for _,id in ipairs(ids) do table.insert(sounds,assert(audio.bank[id])) end
 game:GetService('ContentProvider'):PreloadAsync(sounds)
 for _,sound in ipairs(sounds) do assert(sound.IsLoaded and sound.TimeLength>0) end
 results.loaded=#sounds
 local point=workspace.CurrentCamera.CFrame.Position
 local bands={}
 for _,size in ipairs({3,5.5,9}) do
  local prior,seen=nil,{}
  for _=1,20 do
   local sound,anchor,_,duration=audio:_voice('crystal_split',point,false,{rockSize=size})
   assert(sound.SoundId=='rbxassetid://96292866549392' and sound.PlaybackRegionsEnabled)
   local region=sound.PlaybackRegion
   assert(region.Min~=prior and region.Max>region.Min and region.Max<=audio.bank[ids[1]].TimeLength)
   assert(math.abs(region.Max-region.Min-duration)<.0001)
   prior=region.Min;seen[tostring(region.Min)]=true
   (anchor or sound):Destroy()
  end
  local count=0;for _ in pairs(seen) do count+=1 end
  assert(count==(size>=7 and 2 or 3));bands[tostring(size)]=count
 end
 results.variants=bands
 for name,id in pairs({laser_start=ids[2],ballcaster_fire=ids[3]}) do
  audio:play(name,point)
  local count=0;for sound in pairs(audio.active) do
   assert(sound.SoundId=='rbxassetid://'..id and not sound.Looped);count+=1
  end
  assert(count==1);clear()
 end
 for _,name in ipairs({'ramiel_blast','orbital'}) do
  audio:play(name,point)
  local seen={};for sound in pairs(audio.active) do seen[sound.Name]=sound.SoundId end
  assert(audio.voices==3 and seen[name] and seen.synth_explosion=='rbxassetid://'..ids[4]
   and seen.cinematic_boom=='rbxassetid://'..ids[5])
  clear()
 end
 results.layeredFamilies=2
 audio:play('prism_blast',point)
 assert(audio.voices==1,'Nomad inherited Ramiel layers');clear()
 for _=1,30 do audio.cooldowns={};audio:play('ramiel_blast',point);audio:play('orbital',point) end
 assert(audio.voices<=25 and audio.cueVoices.synth_explosion<=3 and audio.cueVoices.cinematic_boom<=3)
 audio:toggleEffects();assert(audio.voices==0)
 audio:play('ramiel_blast',point);audio:play('crystal_split',point,{rockSize=9});assert(audio.voices==0)
 results.boundedAndMuted=true
end)
audio:destroy();root:Destroy()
assert(ok,tostring(err))
results.scope='Native muted Edit component check; no Play, listening or multiplayer validation.'
return results
