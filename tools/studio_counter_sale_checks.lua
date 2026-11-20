-- Native Edit component check for the counter sale; no Play, gameplay commands, or profile edits.
-- Set shared.CounterSaleCapture=<seconds> first to leave the scene frozen at that moment for a
-- screenshot, then call shared.CounterSaleCheck.close().
assert(not game:GetService('RunService'):IsRunning() and game.PlaceId==124078027733625 and game.GameId==10774898335)
if shared.CounterSaleCheck then shared.CounterSaleCheck.close() end
local source=game.ScriptEditorService:GetEditorSource(game.StarterPlayer.StarterPlayerScripts.ClientDroneControl)
local function module(name,nextName)
 local start=assert(source:find('local '..name..' = (function()',1,true))
 local finish=assert(source:find('\nlocal '..nextName..' = (function()',start,true))
 return source:sub(start,finish-1)
end
local W,M,Finish,Sale=assert(loadstring(
 module('EnergyDisc','Workshop')..module('Workshop','Shops')..module('Shops','Feel')..module('Mining','Feedback')..module('RockFinish','WorkEffects')
 ..'\nlocal BeamVFX={reduced=function() return false end,near=function() return true end}\n'
 ..module('RoleVisuals','NomadView')..module('RockModifierView','PickupDisplay')
 ..module('SaleView','CommandView')..'\nreturn Workshop,Mining,RockFinish,SaleView'))()
Finish.Gems.prepare()

-- The SELL ORE counter in the authored map.
local counter
for _,node in ipairs(workspace:GetDescendants()) do
 if node:IsA('TextLabel') and node.Text=='SELL ORE' then
  local gui=node:FindFirstAncestorWhichIsA('SurfaceGui') or node:FindFirstAncestorWhichIsA('BillboardGui')
  local part=gui and (gui.Adornee or gui.Parent)
  if part and part:IsA('BasePart') then counter=part;break end
 end
end
assert(counter,'SELL ORE counter not found')
local top=counter.Position+Vector3.yAxis*(counter.Size.Y*.5+.3)

local fx=Instance.new('Folder');fx.Name='TemporaryCounterSaleCheck';fx.Parent=workspace
local world=Instance.new('Folder');world.Parent=fx
local resources=Instance.new('Folder');resources.Name='Resources';resources.Parent=world
local template=game.ServerStorage:FindFirstChild('MiningAwayCrystal')
if template then local rock=template:Clone();rock.Parent=resources;rock.Transparency=1 end
local character=Instance.new('Model');character.Name='SaleCheckAvatar';character.Parent=fx
local away=counter.CFrame.LookVector;away=Vector3.new(away.X,0,away.Z).Unit
local root=Instance.new('Part');root.Name='HumanoidRootPart';root.Anchored=true;root.Transparency=1;root.CanCollide=false
root.Size=Vector3.new(2,2,1);root.Position=top+away*9;root.Parent=character
local gui=Instance.new('ScreenGui');gui.Name='TemporaryCounterSaleHUD';gui.Parent=game:GetService('CoreGui')
local camera=workspace.CurrentCamera;local oldCamera=camera.CFrame
camera.CFrame=CFrame.lookAt(root.Position+away*9+Vector3.yAxis*6,top+Vector3.yAxis*1.5)

local credits,cues,beats={},{},0
local view=Sale.new({player={Character=character},world=world,parent=fx,gui=gui,
 reducedMotion=function() return false end,hidden=function() return false end,onCommitted=function() end,
 presentation={cameraBeat=function() beats+=1 end},
 audio={play=function(_,name) cues[name]=(cues[name] or 0)+1 end},
 hud={beginSale=function() end,currencyHit=function(_,_,key,amount) table.insert(credits,{key=key,amount=amount}) end}})

local closed=false
local function close()
 if closed then return end;closed=true
 view:destroy();gui:Destroy();fx:Destroy();camera.CFrame=oldCamera;shared.CounterSaleCheck=nil
end
shared.CounterSaleCheck={close=close,view=view}

local report={counter=counter:GetFullName()}
local ok,err=xpcall(function()
 local bits=M.ROCK_MODIFIERS
 local bag,cash={},0
 local function add(material,value,stone,mask,count)
  local key=W.saleCargo(material,value,stone,stone and 7 or 100,stone and 100 or 0,mask,'Crown')
  bag[key]=(bag[key] or 0)+count
  cash+=W.saleItem(key).cash*count
 end
 add('Amber',2,true,0,4)
 add('Amber',2,true,bits.Charged,2)
 add('RunRuby',4,true,bits.Frosted,1)
 add('RunRuby',4,true,bits.Titan+bits.Charged,1)
 add('Diamond',120,false,0,1)
 add('Amber',2,true,bits.Big,3)
 add('Amber',2,true,bits.Massive+bits.Frosted,1)
 local receipt={id='counter-sale-check',runId='check',revision=1,full=true,cargo=bag,cash=cash,
  resources={Stone=1300,Amber=40,Ruby=14,Diamond=100},counter={top.X,top.Y,top.Z}}
 view:receiveProfile({run={id='check'},recentSales={}})
 view:receive(receipt)
 local batch=assert(view.batch)
 assert(#batch.rocks==5 and batch.rest.count>0,'five stacks shown, the rest summed')
 for i=2,#batch.rocks do assert(batch.groups[i-1].cash<=batch.groups[i].cash,'cheapest to best') end
 local start=batch.start
 local function step(to)
  local t=(batch.frame or start)-start
  while t<to do t=math.min(to,t+1/60);view:update(start+t) end
 end
 step(.3)
 assert(batch.total.Text=='+$0' and not batch.rocks[1].gui.Enabled,'nothing priced before the first beat')
 local last=batch.rocks[#batch.rocks]
 local beforeBoost
 local bonus
 for _,rock in ipairs(batch.rocks) do if rock.group.bonus>0 then bonus=rock;break end end
 assert(bonus,'a cash modifier stack is on display')
 step(bonus.beat+.05)
 beforeBoost=bonus.value.Text
 assert(bonus.gui.Enabled and not bonus.row.Visible,'base price shows before the modifier')
 step(bonus.beat+.6)
 assert(bonus.row.Visible and bonus.value.Text~=beforeBoost,'modifier lifts the shown price')
 report.modifierBeat=beforeBoost..' -> '..bonus.value.Text
 report.chip=bonus.row:FindFirstChildWhichIsA('TextLabel').Text
 step(last.beat+.4)
 -- Legibility on the default camera at this distance.
 local function pixels(part)
  local a=camera:WorldToViewportPoint(part.Position)
  local b=camera:WorldToViewportPoint(part.Position+camera.CFrame.RightVector*part.Size.X)
  return math.floor(math.abs(b.X-a.X))
 end
 report.rockPixels=pixels(last.ore)
 report.labelPixels=math.floor(last.value.AbsoluteSize.Y)
 report.totalPixels=math.floor(batch.total.TextBounds.Y)
 report.totalBeforeBreak=batch.total.Text
 assert(#credits==0,'no wallet credit before the break')
 if shared.CounterSaleCapture then step(shared.CounterSaleCapture);return end
 step(batch.shatterAt+.05)
 assert(batch.rocks==nil and fx:FindFirstChild('Selling_'..last.group.item.name)==nil,'rocks break')
 local money=0;for _,c in ipairs(credits) do if c.key=='Money' then money+=c.amount end end
 assert(money==cash,'one exact cash credit')
 assert(batch.total.Text=='+'..Sale.Ledger.money(cash))
 report.total=batch.total.Text;report.summary=batch.summary.Text;report.materials=batch.materials.Text
 report.cameraBeats=beats;report.cues=cues
 step(batch.endAt-.01);assert(view.batch==batch)
 view:update(start+batch.endAt+.01)
 assert(view.batch==nil and not gui:FindFirstChild('OreSaleTotal'),'sale clears itself')
 report.duration=math.floor(batch.endAt*100)/100
 report.scope='Native Edit component check'
end,debug.traceback)
if not shared.CounterSaleCapture or not ok then close() end
if not ok then error(err) end
return game:GetService('HttpService'):JSONEncode(report)
