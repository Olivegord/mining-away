-- Actual production renderResource against API doubles, not native profiling.
local source=Instance.new('UnionOperation');source.Parent=workspace
for key,value in pairs({FullSize=Vector3.one*3,FullPosition=Vector3.new(0,1.5,0),StartPosition=Vector3.zero,SpawnAt=0,ReadyAt=2,HP=300,MaxHP=300,Stage=0,StageCount=3,StageSeed=1,GroundY=0,Kind='Crystal',CubicRock=false}) do source:SetAttribute(key,value) end
local record={source=source,view=source:Clone(),baseColor=source.Color,dirty=true,visual=Feel.newStagePresentation(0,false,0,3)}
record.view.Parent=workspace
local reads=0;local original=IM.GetAttribute
function IM:GetAttribute(key) if self==source then reads+=1 end;return original(self,key) end
source:GetAttributeChangedSignal('HP'):Connect(function()record.dirty=true end)
renderResource(record,0);assert(not record.settled)
renderResource(record,1);assert(not record.settled)
renderResource(record,2.1);assert(record.settled)
local before=reads
for frame=1,3600 do renderResource(record,2.1+frame/60) end
assert(reads==before,'mature unchanged rocks repeatedly read replicated attributes')
source:SetAttribute('HP',100);source:SetAttribute('Stage',2)
local initial=record.view.Size.X
local orientation=record.view.CFrame.LookVector
renderResource(record,63)
assert(record.settled and record.view.Size.X==initial*.5,'layer loss did not snap immediately')
assert((record.view.CFrame.LookVector-orientation).Magnitude>.2,'crystal did not change facing')
local snapped=record.view.CFrame.LookVector
local late={source=source,view=source:Clone(),baseColor=source.Color,dirty=true,visual=Feel.newStagePresentation(2,false,63,3)}
renderResource(late,63.101);assert((late.view.CFrame.LookVector-snapped).Magnitude<1e-8,'late observer got a different facing')
renderResource(record,63.135);assert(record.view.Size.X==initial*.5 and (record.view.CFrame.LookVector-snapped).Magnitude<1e-8,'rock changed between damage stages')
for frame=1,30 do renderResource(record,63.101+frame/60) end
assert(record.settled and record.visual.stage==2 and #cues==1,'one observed fracture replayed extra animations')
source:SetAttribute('HP',0);source:SetAttribute('BreakSerial',1)
for frame=1,60 do renderResource(record,64+frame/60) end
assert(record.settled and record.visual.broken and record.view.Transparency==1)
assert(#cues==1,'final break must be silent')
before=reads;for frame=1,3600 do renderResource(record,66+frame/60) end
assert(reads==before and #cues==1)
-- Damage stays darker across a stage seam and reconstructs on late join.
local fixed=source:Clone()
fixed:SetAttribute('ReferenceCrystal',true)
fixed.Color=Color3.fromRGB(255,0,0)
fixed:SetAttribute('MaxHP',100);fixed:SetAttribute('HP',100);fixed:SetAttribute('Stage',0);fixed:SetAttribute('BreakSerial',0)
fixed:SetAttribute('SpawnAt',70);fixed:SetAttribute('ReadyAt',72)
local fixedRecord={source=fixed,view=fixed:Clone(),baseColor=fixed.Color,dirty=true,visual=Feel.newStagePresentation(0,false,70,3)}
renderResource(fixedRecord,70)
local originalSize=fixedRecord.view.Size
assert(originalSize.X==3 and fixedRecord.view.Color.R==1 and not fixedRecord.settled)
local previous=fixedRecord.view.Color.R
for stage,hp in ipairs({75,50,25}) do
 local at=72+stage
 local oldDirection=fixedRecord.view.CFrame.LookVector
 fixed:SetAttribute('HP',hp+1);fixedRecord.dirty=true
 renderResource(fixedRecord,at-.1)
 assert(fixedRecord.view.Size.X==originalSize.X*(1-(stage-1)*.25))
 assert(fixedRecord.view.Color.R<previous)
 local beforeCrack=fixedRecord.view.Color.R
 fixed:SetAttribute('HP',hp);fixed:SetAttribute('Stage',stage);fixedRecord.dirty=true
 renderResource(fixedRecord,at)
 assert(fixedRecord.view.Color.R<beforeCrack and beforeCrack-fixedRecord.view.Color.R<.03)
 assert(fixedRecord.view.Size.X==originalSize.X*(1-stage*.25))
 assert((fixedRecord.view.CFrame.LookVector-oldDirection).Magnitude>.2)
 local afterCrack=fixedRecord.view.Color.R
 fixed:SetAttribute('HP',hp-1);fixedRecord.dirty=true
 renderResource(fixedRecord,at+.05)
 assert(fixedRecord.view.Color.R<afterCrack)
 previous=fixedRecord.view.Color.R
end
local lateFixed={source=fixed,view=fixed:Clone(),baseColor=fixed.Color,dirty=true,visual=Feel.newStagePresentation(3,false,76,3)}
renderResource(lateFixed,76)
assert(lateFixed.view.Color.R==fixedRecord.view.Color.R and lateFixed.view.Size.X==fixedRecord.view.Size.X)
fixed:SetAttribute('FieldId',8)
fixedRecord.dirty=true
renderResource(fixedRecord,79)
local rockColor=fixedRecord.view.Color
renderResource(fixedRecord,80,Vector3.new(-15,0,0),30,8)
local outline=assert(fixedRecord.rockOutline)
assert(outline.Enabled and outline.Adornee==fixedRecord.view and outline.FillTransparency==1
 and outline.DepthMode==Enum.HighlightDepthMode.Occluded,'a rock centered on the preview edge needs an occluded outline')
assert(fixedRecord.view.Color==rockColor,'preview changed the rock color')
renderResource(fixedRecord,81,Vector3.new(-15.01,0,0),30,8)
assert(not outline.Parent and not fixedRecord.rockOutline and fixedRecord.view.Color==rockColor,'moving the preview should clear the outline')
renderResource(fixedRecord,82,Vector3.zero,30,9)
assert(not fixedRecord.rockOutline,'another field must not get the preview highlight')
renderResource(fixedRecord,83,Vector3.zero,30,8)
assert(fixedRecord.rockOutline.Enabled and fixedRecord.view.Color==rockColor)
renderResource(fixedRecord,84)
assert(not fixedRecord.rockOutline and fixedRecord.view.Color==rockColor,'clearing the preview left a highlight or changed the color')
fixed:SetAttribute('RockModifiers',Mining.ROCK_MODIFIERS.Frosted);fixedRecord.dirty=true
local material=fixedRecord.view.Material
renderResource(fixedRecord,85)
assert(not fixedRecord.rockOutline,'a modifier restored the removed silhouette outline')
assert(fixedRecord.view.Color.R==rockColor.R and fixedRecord.view.Color.G==rockColor.G and fixedRecord.view.Material==material,'Frosted changed the red mineral')
renderResource(fixedRecord,86,Vector3.zero,30,8)
outline=assert(fixedRecord.rockOutline)
assert(outline.Enabled and outline.OutlineColor.R>.9)
renderResource(fixedRecord,87)
assert(not fixedRecord.rockOutline,'clearing the preview should remove the outline even on modified rocks')
print('PASS production resource renderer: immediate size snaps, replicated stage turns, idle fast path and no duplicate effects over 7200 stable frames')
