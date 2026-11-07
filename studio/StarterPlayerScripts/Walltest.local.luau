local folder = Instance.new("Folder")
local tw = game:GetService("TweenService")
folder.Parent = game.Workspace

local test = {}
local grid = {}

local rows, cols = 50,50


for i =1, rows do
	grid[i] = {}
	for j = 1, cols do
		grid[i][j] = false
	end
end
local height = 10
local offset = Vector3.new(5,height/2,5)




local function setTileOccupied(x,z) 
	if  grid[x][z] ~= nil then
		grid[x][z] = true
	end
end

local function isTileOccupied(x,z) 
	if grid[x] and grid[x][z] ~= nil then
		return grid[x][z]

	else
		return nil
	end
end


local function placeLargeWall (x, z) 
	local wall = {
		part = Instance.new("Part"),
		xPos = x * 2,
		zPos =z *2,
		size = 4,
		up = true,
		isTweeningUp = false,
		isTweeningDown = false

	}

	wall.part.Size = Vector3.new(4,height,4)
	wall.part.Anchored = true
	wall.part.Position = Vector3.new(x * 2,0,z *2) + offset
	wall.part.Parent = folder
	table.insert(test, wall)
end


local function setUpGrid () 

	for i = 1, 500  do
		local randX = math.random(1,rows)
		local randZ = math.random(1,cols)

		local randPoint = grid[randX][randZ]




		if isTileOccupied(randX, randZ) == false
			and isTileOccupied(randX +1, randZ) == false
			and isTileOccupied(randX, randZ + 1) == false
			and isTileOccupied(randX + 1, randZ + 1) == false
		then
			placeLargeWall(randX, randZ)

			setTileOccupied(randX, randZ)
			setTileOccupied(randX +1, randZ) 
			setTileOccupied(randX, randZ + 1) 
			setTileOccupied(randX + 1, randZ + 1)
		end

	end

	print(grid)




	for x= 1, rows do
		for z = 1, cols do
			if isTileOccupied(x,z) == false then
				local wall = {
					part = Instance.new("Part"),
					xPos = x * 2,
					zPos =z *2,
					size = 2,
					up = true,
					isTweeningUp = false,
					isTweeningDown = false

				}

				wall.part.Size = Vector3.new(2,height,2)
				wall.part.Anchored = true
				wall.part.Position = Vector3.new(x * 2, 0,z *2) + offset
				wall.part.Parent = folder
				table.insert(test, wall)
			end

		end

	end

end

setUpGrid()



wait(3)
game:GetService("RunService").Stepped:Connect(function()
	local plrPos = game.Players.LocalPlayer.Character.HumanoidRootPart.Position
	for i, v in pairs( test) do
		local anchorOffset
		if v.size == 4  then
			
			anchorOffset = 1
		elseif v.size == 2 then
			anchorOffset = 0
		end
		
		if (Vector2.new(v.xPos, v.zPos) - Vector2.new(plrPos.x,plrPos.z)).magnitude < 20 then
			if v.up == true and v.isTweeningUp ==  false  then
				v.isTweeningUp = true
				v.

				local tweenInfo1 = TweenInfo.new(2, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut)
				local goal1 = Vector3.new(v.xPos + anchorOffset,  -height + 1, v.zPos + anchorOffset) + offset
				local tween1 = tw:Create(v.part, tweenInfo1, {Position = goal1})
				tween1:Play()

				tween1.Completed:Connect(function(playbackState)
					v.up = false
					v.isTweeningUp = false
				end)

			end

		else

			if v.up == false and v.isTweeningDown == false  then
				v.isTweeningDown = true

				local tweenInfo2 = TweenInfo.new(2, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut)
				local goal2 = Vector3.new(v.xPos +anchorOffset ,0 ,v.zPos +anchorOffset ) + offset
				local tween2 = tw:Create(v.part, tweenInfo2, {Position = goal2})
				tween2:Play()

				tween2.Completed:Connect(function(playbackState)
					v.up = true
					v.isTweeningDown = false
				end)
			end


		end

	end
end)
