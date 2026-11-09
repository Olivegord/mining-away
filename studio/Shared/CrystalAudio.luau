--!strict
-- Original Mining Away crack on a replicated intermediate fracture.
local ContentProvider = game:GetService('ContentProvider')
local Debris = game:GetService('Debris')

local CrystalAudio = {}
CrystalAudio.__index = CrystalAudio
local MAX_VOICES, MAX_DISTANCE = 6, 85
local CRACK = 'rbxassetid://9119050085'

function CrystalAudio.new(parent: Instance, soundGroup: SoundGroup?)
 local folder = Instance.new('Folder')
 folder.Name = 'CrystalAudio'; folder.Parent = parent
 task.spawn(function() pcall(function() ContentProvider:PreloadAsync({CRACK}) end) end)
 return setmetatable({folder=folder,soundGroup=soundGroup,voices=0,closed=false},CrystalAudio)
end

function CrystalAudio:playCrack(position: Vector3)
 if self.closed or self.voices >= MAX_VOICES then return end
 local camera = workspace.CurrentCamera
 if camera and (position-camera.CFrame.Position).Magnitude > MAX_DISTANCE then return end

 local anchor = Instance.new('Part')
 anchor.Name = 'CrystalSoundOrigin'; anchor.Size = Vector3.one * .05; anchor.Transparency = 1
 anchor.Anchored = true; anchor.CanCollide = false; anchor.CanQuery = false; anchor.CanTouch = false; anchor.CastShadow = false
 anchor.Position = position; anchor.Parent = self.folder
 local sound = Instance.new('Sound')
 sound.Name = 'RockCrack'
 sound.SoundId = CRACK
 sound.Volume = .05
 sound.PlaybackSpeed = 1
 sound.RollOffMode = Enum.RollOffMode.Inverse
 -- Match the captured Sound itself; the local voice/distance budget above
 -- limits instances without changing their falloff curve.
 sound.RollOffMinDistance = 10; sound.RollOffMaxDistance = 10000
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
