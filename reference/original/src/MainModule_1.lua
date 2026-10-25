local MainModule = {}





local rs = game:GetService("ReplicatedStorage")
local ts = game:GetService("TweenService")

local Crystal = {} -- put outside of function later
Crystal.__index = Crystal

function Crystal.new(patch) 
	
	local self = setmetatable({}, Crystal)

	self.mesh = rs.Crystal.Mesh:Clone()

	self.mesh.Parent = game.Workspace

	self.id = patch.availableIDs[1]
	
	self.patch = patch.name


	self.maxHealth = math.random(50,100)

	self.health = self.maxHealth
	
	self.healthPeriod = 1

	self.canBeMined = false

	self.position = nil

	-- setting up position

	local patchSize = patch.mesh.Size

	self.mesh.Size = Vector3.new(0,0,0)

	self.mesh.Attachment.Position = Vector3.new(0,self.mesh.Size.Y/2 ,0) 
	
	self.mesh.Position =  Vector3.new(
		math.random(-patchSize.X / 2,patchSize.X / 2) + patch.mesh.Position.X, 
		self.mesh.Size.Y/2 + ( patch.mesh.Position.Y),
		math.random(-patchSize.Z / 2, patchSize.Z / 2) + patch.mesh.Position.Z)


	
	ts:Create(self.mesh, TweenInfo.new(2), {Size = Vector3.new(1,1,1) * self.maxHealth/25}):Play()

	ts:Create(self.mesh, TweenInfo.new(2), {Position = Vector3.new(
		self.mesh.Position.X,
		(self.maxHealth/25)/2 + (2 + patch.mesh.Position.Y),
		self.mesh.Position.Z
		)}):Play()

		

	self.mesh.BillboardGui.Frame.TextLabel.Text = self.id

	
	--	print(#patchDict.rubyPatch.availableIDs)
	local spawnDelay = spawn(function()
		wait(2)
		self.canBeMined = true
	end)
	

	return self
end





MainModule.CreateBeam = function(drone)
	-- Function to handle the raycast result

	

	local attachment = Instance.new("Attachment") -- make this drone.attachment when models are complete
	attachment.Parent = drone.Mesh
	attachment.Position = drone.Mesh.Emmiter.Position

	

	local beam = game.ReplicatedStorage.MiningFX.Beam:Clone()
	


	local miningEffect = game.ReplicatedStorage.MiningFX.MiningEffect:Clone()
	
	miningEffect.Parent = beam
	

	
	beam.Parent = game.Workspace
	beam.InnerBeam.Attachment0 = attachment
	beam.OuterBeam.Attachment0 = attachment
	

	

	return beam




end



MainModule.ShowBeam = function(beam, attachment) 


	beam.InnerBeam.Attachment1 = attachment
	beam.OuterBeam.Attachment1 = attachment

	local tweenInfo = TweenInfo.new(2)

	local tween1 = game:GetService("TweenService"):Create(beam.InnerBeam, tweenInfo, { Width0 = 0.3}):Play()
	local tween2 = game:GetService("TweenService"):Create(beam.InnerBeam, tweenInfo, { Width1 = 0.3}):Play()
	
	beam.MiningEffect.Transparency = .8
	beam.MiningEffect.InnerMiningEffect.Transparency = 0

end




MainModule.HideBeam = function(beam)
	-- Function to handle the raycast result
	local transparencySequence = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), -- Time = 0, Transparency = 1 (completely opaque)
		NumberSequenceKeypoint.new(1, 1)  -- Time = 1, Transparency = 0 (completely transparent)
	})
	local tweenInfo = TweenInfo.new(.2)
	

	local tween1 = game:GetService("TweenService"):Create(beam.InnerBeam, tweenInfo, { Width0 = 0}):Play()
	local tween2 = game:GetService("TweenService"):Create(beam.InnerBeam, tweenInfo, { Width1 = 0}):Play()
	
	
	local tween3 = game:GetService("TweenService"):Create(beam.OuterBeam, tweenInfo, { Width0 = 0}):Play()
	local tween4 = game:GetService("TweenService"):Create(beam.OuterBeam, tweenInfo, { Width1 = 0}):Play()


	local hi = spawn(function()
		beam.MiningEffect.Transparency = 1
		beam.MiningEffect.InnerMiningEffect.Transparency = 1

		
		
	

		
	end)



end

MainModule.SpawnCrystals = function(patch, amount) -- patchDict refers to the individual patch
	
	
	
	for i = 1, amount do
		if #patch.availableIDs > 0 then
			local newId = patch.availableIDs[1]

			patch.crystalDict[newId] =   Crystal.new(patch)
			
			table.remove(patch.availableIDs, 1)

		end
	end
	
	return patch.crystalDict
end







return MainModule
