--!strict
-- Original Mining Away sounds, played only on replicated stage/break events.
local ContentProvider = game:GetService('ContentProvider')
local Debris = game:GetService('Debris')

local CrystalAudio = {}
CrystalAudio.__index = CrystalAudio
local MAX_VOICES, STAGE_VOICES, MAX_DISTANCE = 10, 6, 85
local CRACK, BREAK = 'rbxassetid://9119050085', 'rbxassetid://7158347304'

function CrystalAudio.new(parent: Instance, soundGroup: SoundGroup?)
 local folder = Instance.new('Folder')
 folder.Name = 'CrystalAudio'; folder.Parent = parent
 task.spawn(function() pcall(function() ContentProvider:PreloadAsync({CRACK,BREAK}) end) end)
 return setmetatable({folder=folder,soundGroup=soundGroup,voices=0,closed=false},CrystalAudio)
end

function CrystalAudio:play(position: Vector3, event: string)
 local breaking = event == 'break'
 if self.closed or (not breaking and event ~= 'stage') or self.voices >= (breaking and MAX_VOICES or STAGE_VOICES) then return end
 local camera = workspace.CurrentCamera
 if camera and (position-camera.CFrame.Position).Magnitude > MAX_DISTANCE then return end

 local anchor = Instance.new('Part')
 anchor.Name = 'CrystalSoundOrigin'; anchor.Size = Vector3.one * .05; anchor.Transparency = 1
 anchor.Anchored = true; anchor.CanCollide = false; anchor.CanQuery = false; anchor.CanTouch = false; anchor.CastShadow = false
 anchor.Position = position; anchor.Parent = self.folder
 local sound = Instance.new('Sound')
 sound.Name = breaking and 'RockBreak' or 'RockCrack'
 sound.SoundId = breaking and BREAK or CRACK
 sound.Volume = breaking and .3 or .05
 sound.PlaybackSpeed = 1
 sound.RollOffMode = Enum.RollOffMode.Inverse
 sound.RollOffMinDistance = 10; sound.RollOffMaxDistance = MAX_DISTANCE
 sound.SoundGroup = self.soundGroup; sound.Parent = anchor
 self.voices += 1
 anchor.Destroying:Once(function() self.voices = math.max(0,self.voices-1) end)
 sound.Ended:Once(function() anchor:Destroy() end)
 Debris:AddItem(anchor,8)
 sound:Play()
end

function CrystalAudio:destroy()
 self.closed = true
 self.folder:Destroy()
end

return CrystalAudio
