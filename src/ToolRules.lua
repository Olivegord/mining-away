-- Shared throw equations and temporary durability. Clients only preview them.
local T={SLOTS=8,WORLD_LIFETIME=75,MAX_DROPS=36,MAX_OWNER_DROPS=6,MAX_DRY=6}
T.ORDER={'BowlingBall','Crowbar','JellyGrenade','Greatsword','Scrap','Orbital','Sledgehammer','MoltenTongs'}
T.SAVED={[5]='Scrap',[6]='Orbital'}
T.ITEMS={
 BowlingBall={name='Bowling ball',short='Bowling',uses=4,gravity=420,speed=58,range=42,radius=1.05,color={95,109,222},cooldown=.82,windup=.44},
 Crowbar={name='Crowbar',short='Crowbar',uses=12,range=8,color={239,136,82},cooldown=.56,windup=.29,melee=true},
 JellyGrenade={name='Jelly grenade',short='Jelly',uses=1,gravity=280,speed=52,range=38,radius=.5,color={144,225,99},cooldown=.62,windup=.16,fuse=.42},
 Greatsword={name='Giant sword',short='Sword',uses=3,range=13,radius=.65,color={137,205,255},cooldown=.95,windup=.56,melee=true},
 Sledgehammer={name='Sledgehammer',short='Hammer',uses=3,range=10,radius=.65,color={255,192,84},cooldown=.9,windup=.50,melee=true},
 MoltenTongs={name='Molten steel tongs',short='Molten',uses=1,range=9,radius=.62,color={255,105,42},cooldown=.8,windup=.48,gravity=370,speed=50,molten=true},
 Scrap={name='Scrap capsule',short='Scrap',uses=1,range=45,radius=.6,color={190,149,255},cooldown=.58,windup=.26,gadget=true},
 Orbital={name='Orbital laser',short='Orbital',uses=1,range=45,radius=.6,color={255,125,81},cooldown=.58,windup=.26,gadget=true},
}
function T.finite(n) return type(n)=='number' and n==n and n>-math.huge and n<math.huge end
function T.vector(v) return typeof(v)=='Vector3' and math.abs(v.X)<=100000 and math.abs(v.Y)<=100000 and math.abs(v.Z)<=100000 end
function T.origin(position,look) return position+Vector3.new(0,1.3,0)+look*1.6 end
function T.launch(kind,from,aim)
 local item=T.ITEMS[kind]
 if not item or not item.gravity or not T.vector(from) or not T.vector(aim) then return nil end
 local delta=aim-from;local flat=Vector3.new(delta.X,0,delta.Z)
 if flat.Magnitude>item.range then flat=flat.Unit*item.range end
 delta=flat+Vector3.new(0,math.clamp(delta.Y,-16,10),0)
 local duration=math.clamp(flat.Magnitude/item.speed,.22,.78)
 return delta/duration+Vector3.new(0,item.gravity*duration*.5,0),duration
end
function T.position(from,velocity,gravity,t) return from+velocity*t-Vector3.new(0,gravity*t*t*.5,0) end
function T.segmentDistance(point,from,to)
 local delta=to-from;local length=delta:Dot(delta)
 local q=length>1e-8 and math.clamp((point-from):Dot(delta)/length,0,1) or 0
 return (point-(from+delta*q)).Magnitude
end
-- Work in box-local units so a click at a corner or the visible edge
-- produces a real surface contact at any stage of a rock's life.
function T.surface(part,point,from)
 local half=part.Size*.5
 local v=part.CFrame:PointToObjectSpace(point)
 local q=Vector3.new(math.clamp(v.X,-half.X,half.X),math.clamp(v.Y,-half.Y,half.Y),math.clamp(v.Z,-half.Z,half.Z))
 if (q-v).Magnitude<1e-5 then
  local relative=q/half
  local direction=relative.Magnitude>.01 and relative or part.CFrame:PointToObjectSpace(from)/half
  local axis='X'
  if math.abs(direction.Y)>math.abs(direction[axis]) then axis='Y' end
  if math.abs(direction.Z)>math.abs(direction[axis]) then axis='Z' end
  local edge=half[axis]*(direction[axis]<0 and -1 or 1)
  q=Vector3.new(axis=='X' and edge or q.X,axis=='Y' and edge or q.Y,axis=='Z' and edge or q.Z)
 end
 return part.CFrame:PointToWorldSpace(q),q/part.Size
end
-- Keep old impacts for the life of the rock. Closely spaced hits on
-- the same face deepen the same mark, keeping CSG work bounded.
function T.addScar(history,point,width,depth,heat)
 local axis='Y'
 if not heat then
  if math.abs(point.X)>math.abs(point[axis]) then axis='X' end
  if math.abs(point.Z)>math.abs(point[axis]) then axis='Z' end
 end
 local face=(heat or point[axis]>=0) and .5 or -.5
 local x=axis=='X' and face or math.clamp(point.X,-.49,.49)
 local y=axis=='Y' and face or math.clamp(point.Y,-.49,.49)
 local z=axis=='Z' and face or math.clamp(point.Z,-.49,.49)
 local center=Vector3.new(x,y,z)
 local faceIndex=axis=='X' and 1 or axis=='Y' and 2 or 3
 for _,mark in ipairs(history) do
  if mark[6]==axis and mark[7]==heat and mark[faceIndex]==face
   and (Vector3.new(mark[1],mark[2],mark[3])-center).Magnitude<=.16 then
   local growth=heat and 0 or .025
   local wider=math.min(.96,math.max(width,mark[4]+growth))
   local deeper=math.min(.75,math.max(depth,mark[5]+growth))
   if wider==mark[4] and deeper==mark[5] then return false end
   mark[4],mark[5]=wider,deeper
   return true
  end
 end
 if #history>=8 then return false end
 table.insert(history,{x,y,z,width,depth,axis,heat})
 return true
end
function T.drop(progress,roll,choice)
 progress.breaks=(progress.breaks or 0)+1;progress.dry=math.min(T.MAX_DRY,(progress.dry or 0)+1)
 if (progress.found or 0)==0 then return progress.dry>=2 and 'BowlingBall' or nil end
 if progress.dry<T.MAX_DRY and roll>=.24 then return nil end
 -- Introduce each tool, then vary the tool rather than handing out multipliers.
 if progress.found<#T.ORDER then return T.ORDER[progress.found+1] end
 return T.ORDER[1+math.floor(math.clamp(choice,0,.99999)*#T.ORDER)]
end
return T
