-- Actual fragment creation/update code with API doubles, not engine physics.
local root=Instance.new('Folder');root.Parent=workspace
local view=Instance.new('Part');view.Size=Vector3.one;view.Parent=root
local checks=0
local function check(name,fn) fn();checks+=1;print('PASS fragment audio '..name) end
local function fixture(priority)
 local p=Presentation.new({parent=root});local heard={}
 function p:_sound(position,kind,now) table.insert(heard,{position=position,kind=kind,at=now}) end
 p:_fragment(view,CFrame.new(0,4,0),view.Color,0,.1,Vector3.new(2,1,0),Vector3.zero,0,100,.1,priority)
 return p,heard
end
check('short-lived stone chips survive until landing and sound only once',function()
 local p,heard=fixture(false);assert(p.fragments[1].duration>.8)
 for n=1,90 do p:update(1/60,100+n/60) end
 assert(#heard==1 and heard[1].kind=='rubble' and heard[1].position.Y<.1)
 p:destroy()
end)
check('drone debris uses the metal landing cue',function()
 local p,heard=fixture(true)
 for n=1,90 do p:update(1/60,100+n/60) end
 assert(#heard==1 and heard[1].kind=='metal_land');p:destroy()
end)
check('a stalled renderer does not replay historical landings',function()
 local p,heard=fixture(false);p:update(1,101);p:update(.01,101.01)
 assert(#heard==0);p:destroy()
end)
print(checks..' actual cosmetic fragment checks with API doubles; listening/visuals not verified')
