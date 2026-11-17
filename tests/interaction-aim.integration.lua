local originalGet=game.GetService
local cursor=Vector3.new(100,100,0)
local input={GetMouseLocation=function() return cursor end,GetLastInputType=function() return {Name='MouseMovement'} end}
local inset={GetGuiInset=function() return Vector3.zero end}
function game:GetService(name) if name=='UserInputService' then return input elseif name=='GuiService' then return inset end;return originalGet(self,name) end
workspace.CurrentCamera={ViewportSize=Vector3.new(400,400,0),WorldToViewportPoint=function(_,point) return Vector3.new(point.X*10+100,100-point.Y*10,1),point.Z>=0 end}
local pl={UserId=5,Character=Instance.new('Model')}
local hr=Instance.new('Part');hr.Name='HumanoidRootPart';hr.Position=Vector3.zero;hr.Parent=pl.Character
local fx=Instance.new('Folder');fx.Parent=workspace
local selector=SelectorView.new({player=pl,parent=fx})
local function record(id,pos)
 local s=Instance.new('Part');s.Position=pos;s.Size=Vector3.one;s.Parent=workspace
 s:SetAttribute('OpenReady',true);s:SetAttribute('ReadyAt',0);s:SetAttribute('OpenOwner',5)
 return {source=s,view=s,id=id}
end
local aimed=record('b',Vector3.new(0,0,10));local nearby=record('a',Vector3.new(8,0,1))
assert(selector:readyRock({nearby,aimed})==aimed,'nearest player distance overrode aim')
cursor=Vector3.new(180,100,0);assert(selector:readyRock({aimed,nearby})==nearby,'aim did not switch targets')
cursor=Vector3.new(300,100,0);assert(not selector:readyRock({aimed,nearby}),'looking away still selected a reward')
cursor=Vector3.new(100,100,0);aimed.source:SetAttribute('ReadyAt',realTime+2)
assert(not selector:readyRock({aimed}),'prompt offered flying geode')
aimed.source:SetAttribute('ReadyAt',0);workspace.Raycast=function() return {Instance=nearby.source} end
assert(not selector:readyRock({aimed}),'prompt offered obscured geode')
workspace.Raycast=function() return nil end
assert(selector:readyRock({aimed})==aimed)
cursor=Vector3.new(100,88,0);assert(selector:readyRock({aimed})==aimed,'moving onto button lost its target')
print('PASS aim beats proximity, cursor changes target, looking away clears it, landing and obstruction gates, button retention')
