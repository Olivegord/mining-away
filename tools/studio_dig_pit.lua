-- Dig pit (November 22): the owner wants the Dig Cube sunk INTO the ground so
-- players mine down. The cube (runtime rock, src/DigCube.lua) is now 44 studs
-- deep with its top flush with the ground at Y 3.8, filling x 96..184,
-- z -24..64. This cuts that hole in the ground plate: the 2048-stud
-- Baseplate becomes its west part, three clones make the rest, and a shaft
-- lining plus a floor close the hole under and around the rock, so a crater
-- dug to the cube's edge or bottom shows earth, not the void.
-- Run once in shared Edit. Stages exact edits for tools/refresh_dig_pit.py:
-- returns JSON {edits, scenery} (scenery = zstd+base64 native model).
assert(game.PlaceId==124078027733625 and game.GameId==10774898335)
assert(game:GetService('RunService'):IsEdit())
local map=workspace.MiningAway
assert(not map:FindFirstChild('DigPit'),'DigPit already exists')
local base=map.Fields.Baseplate
local G=3.8
local X0,X1,Z0,Z1=96,184,-24,64
local BOTTOM=G-44
local function v(x) return {x.X,x.Y,x.Z} end
assert((base.Position-Vector3.new(0,-4.2,0)).Magnitude<.01 and (base.Size-Vector3.new(2048,16,2048)).Magnitude<.01)
local before={position=v(base.Position),size=v(base.Size)}
local y,h=base.Position.Y,base.Size.Y
local pit=Instance.new('Folder');pit.Name='DigPit'
local function ground(name,x0,x1,z0,z1)
 local p=base:Clone();p.Name=name
 p.Size=Vector3.new(x1-x0,h,z1-z0);p.CFrame=CFrame.new((x0+x1)*.5,y,(z0+z1)*.5)
 p.Parent=pit
end
local function block(name,size,center,color,material)
 local p=Instance.new('Part');p.Name=name;p.Anchored=true;p.Size=size;p.CFrame=CFrame.new(center)
 p.Color=color;p.Material=material;p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth
 p.Parent=pit
end
ground('GroundEast',X1,1024,-1024,1024)
ground('GroundNorth',X0,X1,Z1,1024)
ground('GroundSouth',X0,X1,-1024,Z0)
-- Lining from the plate's underside down past the rock's bottom, and the floor.
local under=y-h*.5
local wallH=under-(BOTTOM-4)
local wallY=(under+BOTTOM-4)*.5
local earth=Color3.fromRGB(104,96,90)
local slate=Color3.fromRGB(84,83,92)
block('ShaftNorth',Vector3.new(X1-X0+4,wallH,2),Vector3.new((X0+X1)*.5,wallY,Z1+1),earth,Enum.Material.Plastic)
block('ShaftSouth',Vector3.new(X1-X0+4,wallH,2),Vector3.new((X0+X1)*.5,wallY,Z0-1),earth,Enum.Material.Plastic)
block('ShaftEast',Vector3.new(2,wallH,Z1-Z0),Vector3.new(X1+1,wallY,(Z0+Z1)*.5),earth,Enum.Material.Plastic)
block('ShaftWest',Vector3.new(2,wallH,Z1-Z0),Vector3.new(X0-1,wallY,(Z0+Z1)*.5),earth,Enum.Material.Plastic)
block('ShaftFloor',Vector3.new(X1-X0+4,4,Z1-Z0+4),Vector3.new((X0+X1)*.5,BOTTOM-2,(Z0+Z1)*.5),slate,Enum.Material.Plastic)
-- The Baseplate keeps its name and place in the tree and becomes the west part.
base.Size=Vector3.new(X0+1024,h,2048);base.CFrame=CFrame.new((X0-1024)*.5,y,0)
pit.Parent=map
local after={position=v(base.Position),size=v(base.Size)}
local encoding=game:GetService('EncodingService')
local binary=game:GetService('SerializationService'):SerializeInstancesAsync({pit})
local scenery=buffer.tostring(encoding:Base64Encode(encoding:CompressBuffer(binary,Enum.CompressionAlgorithm.Zstd)))
return game:GetService('HttpService'):JSONEncode({edits={{path=base:GetFullName(),class='Part',anchor=before.position,before=before,after=after}},scenery=scenery})
