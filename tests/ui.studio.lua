-- Real Studio CLIENT test. Inject the production Interface and CardView modules,
-- then call the returned function: run(Interface, CardView, {safeRoot=...}).
-- This renders temporary native controls and reads their engine font/layout
-- metrics. It never sends commands, changes a profile or clicks a game button.
return function(Interface,CardView,options)
 options=options or {}
 local Players=game:GetService('Players')
 local RunService=game:GetService('RunService')
 assert(RunService:IsStudio() and RunService:IsClient(),'Run this test on a Studio Play client')
 local player=assert(Players.LocalPlayer,'Studio client player is missing')
 local playerGui=assert(player:FindFirstChildOfClass('PlayerGui'),'PlayerGui is missing')
 local gui=Instance.new('ScreenGui')
 local result={kind='real Studio client native card geometry and rendered font metrics',cases=0,checks=0,failureCount=0,failures={}}
 local currentCase='setup'
 local function check(condition,name,detail)
  result.checks+=1
  if not condition then
   result.failureCount+=1
   if #result.failures<60 then table.insert(result.failures,{case=currentCase,check=name,detail=detail}) end
  end
 end
 local function rect(object)
  local p,s=object.AbsolutePosition,object.AbsoluteSize
  return {x=p.X,y=p.Y,w=s.X,h=s.Y}
 end
 local function inside(a,b)
  return a.w>0 and a.h>0 and a.x>=b.x-.5 and a.y>=b.y-.5 and a.x+a.w<=b.x+b.w+.5 and a.y+a.h<=b.y+b.h+.5
 end
 local function separate(a,b)
  return a.x+a.w<=b.x+.5 or b.x+b.w<=a.x+.5 or a.y+a.h<=b.y+.5 or b.y+b.h<=a.y+.5
 end
 local function textObject(object)
  return object:IsA('TextLabel') or object:IsA('TextButton')
 end
 local function findText(root,text)
  for _,object in ipairs(root:GetDescendants()) do if textObject(object) and object.Text==text then return object end end
 end
 local function rendered(root)
  -- TextBounds is populated by Roblox's renderer after parenting/layout.
  for _=1,12 do
   RunService.RenderStepped:Wait()
   local ready=root.AbsoluteSize.X>0
   for _,object in ipairs(root:GetDescendants()) do
    if textObject(object) and object.Text~='' and object.TextBounds.Y<=0 then ready=false end
   end
   if ready then RunService.RenderStepped:Wait();return end
  end
 end
 -- Actual catalog copy: longest description, four changed stat rows, longest
 -- title and longest penalty wording are exercised independently.
 local fixtures={
  {id='D17 longest description',choice={title='Siege Focus',description='+45% shot damage; +50% finishing damage below 35% sentry hull; −15% flight speed',headline='SPECIALIZE FOR SIEGES',tradeoff='15% less flight speed',previewTargetName='Green 12'},
   rows={'Combat / sec  12 → 17.4','Flight speed  18 → 15.3 studs/s','Finishing damage  1× → 1.5×'},target='ONE DRONE / Green 12',stack='Unique for this target · this run'},
  {id='D20 four stat rows',choice={title='Shard Harvester',description='Split 20% mining damage within 12 studs; +25% mining output; −15% hull',headline='HARVEST THE WHOLE CLUSTER',tradeoff='15% less maximum hull',previewTargetName='Green 12'},
   rows={'Mining / sec  32.5 → 40.6','Hull  93.5 → 79.5','Split damage  0 → 20%','Split reach  6 → 12 studs'},target='ONE DRONE / Green 12',stack='Unique for this target · this run'},
  {id='F03 longest title',choice={title='Combat Calibration',description='+30% combat shot damage across your fleet',headline='COMBAT UPGRADE',tradeoff='No stat penalty',previewTargetName='Green 12'},
   rows={'Combat / sec  12 → 15.6'},target='ENTIRE FLEET',stack='Copy 2 of 2 · adds to base · this run'},
  {id='T02 longest penalty',choice={title='Battle Formation',description='+60% fleet combat shot damage; −20% mining output',headline='COMBAT UPGRADE',tradeoff='20% less mining output',previewTargetName='Green 12'},
   rows={'Mining / sec  32.5 → 26','Combat / sec  12 → 19.2'},target='ENTIRE FLEET',stack='Unique for this target · this run'},
 }
 local callbackCount=0
 local ok,err=xpcall(function()
  gui.Name='MiningAwayUIReviewHarness'
  gui.ResetOnSpawn=false
  gui.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets
  gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
  gui.DisplayOrder=1000
  gui.Enabled=true
  gui.Parent=playerGui
  local host=Interface.frame(gui,UDim2.fromOffset(6,6),UDim2.fromOffset(284,520),Interface.palette.paper)
  host.BackgroundTransparency=1
  for _,height in ipairs({430,437,499,500,510,519,520}) do
   for _,width in ipairs({240,284}) do
    for _,fixture in ipairs(fixtures) do
     currentCase=string.format('%dx%d %s',width,height,fixture.id)
     result.cases+=1
     host.Size=UDim2.fromOffset(width,height)
     local view=CardView.create(Interface,host,fixture.choice,1,width,height,{
      category='COMBAT',target=fixture.target,previewRows=fixture.rows,stackText=fixture.stack,
      onChoose=function() callbackCount+=1 end,
     })
     local card,button=view.root,view.button
     rendered(card)
     local cardRect=rect(card)
     check(math.abs(cardRect.w-width)<.5 and math.abs(cardRect.h-height)<.5,'requested native card dimensions',string.format('actual %.1fx%.1f',cardRect.w,cardRect.h))
     check(button.AbsoluteSize.Y>=44 and button.AbsoluteSize.X>=44,'choose target is at least 44px')
     check(inside(rect(button),cardRect),'choose target is fully inside card')
     local stack=card:FindFirstChild('CardStacking')
     local expiry=findText(card,'THIS RUN · RESETS AT PRESTIGE')
     check(stack~=nil,'stacking copy exists')
     check(expiry~=nil,'prestige expiry exists')
     if stack then check(separate(rect(stack),rect(button)),'stacking never intersects choose button') end
     if expiry then check(separate(rect(expiry),rect(button)),'expiry never intersects choose button') end
     local description=findText(card,fixture.choice.description)
     check(description~=nil,'full precise effect description exists')
     if description then check(description.Font==Enum.Font.GothamMedium and not description.TextScaled,'body uses regular native Gotham metrics') end
     local title=card:FindFirstChild('CardTitle')
     check(title~=nil and title.Font==Enum.Font.FredokaOne and not title.TextScaled,'title uses native Fredoka metrics')
     check(findText(card,fixture.target)~=nil,'exact target copy exists')
     for index,row in ipairs(fixture.rows) do
      local stat=card:FindFirstChild('StatRow'..index)
      check(stat~=nil and findText(stat,row)~=nil,'exact stat row '..index..' exists')
      if stat and stack then check(separate(rect(stat),rect(stack)),'stat row '..index..' stays above stacking') end
     end
     local penalty=card:FindFirstChild('CardTradeoff')
     check(penalty~=nil and string.find(penalty.Text,fixture.choice.tradeoff,1,true)~=nil,'complete penalty wording exists')
     if description and penalty then check(separate(rect(description),rect(penalty)),'description and penalty do not overlap') end
     for _,object in ipairs(card:GetDescendants()) do
      if textObject(object) and object.Text~='' and object.Visible then
       local bounds,size=object.TextBounds,object.AbsoluteSize
       local detail=string.format('%s: bounds %.1fx%.1f / box %.1fx%.1f',object.Text,bounds.X,bounds.Y,size.X,size.Y)
       check(bounds.X>0 and bounds.Y>0,'renderer populated text bounds',detail)
       check(object.TextFits and bounds.X<=size.X+.5 and bounds.Y<=size.Y+.5,'rendered text fits its actual native box',detail)
       check(inside(rect(object),cardRect),'text box remains inside card',object.Text)
      end
     end
     card:Destroy()
    end
   end
  end
  currentCase='compact portrait focus dispatch'
  local focusCount,lastFocus=0,nil
  local compact=CardView.create(Interface,host,fixtures[1].choice,2,150,200,{offerCompact=true,category='COMBAT',target=fixtures[1].target,previewRows=fixtures[1].rows,onFocus=function(index) focusCount+=1;lastFocus=index end})
  rendered(compact.root)
  check(compact.button.AbsoluteSize.X>=44 and compact.button.AbsoluteSize.Y>=44,'portrait focus target meets touch minimum')
  compact.select();check(focusCount==1 and lastFocus==2,'shared activated handler selects correct saved index')
  compact.setFocus(true,true);check(compact.root.Position.Y.Offset==0,'reduced motion focus lift resolves immediately')
  compact.setFocus(false,true);check(compact.root.Position.Y.Offset==6,'focus clears without replay')
  compact.root:Destroy()
  currentCase='optional production safe bounds'
  local safeRoot=options.safeRoot
  if safeRoot then
   check(safeRoot:IsA('GuiObject') and safeRoot:IsDescendantOf(playerGui),'production safe root belongs to local PlayerGui')
   for _,name in ipairs({'Resources','NextStep','Recall','ContextAction','SentryHealth'}) do
    local control=safeRoot:FindFirstChild(name)
    if control and control:IsA('GuiObject') and control.Visible then check(inside(rect(control),rect(safeRoot)),name..' stays inside actual native safe content') end
   end
   local layer=safeRoot:FindFirstChild('MenuLayer')
   local sheet=layer and layer:FindFirstChild('MenuSheet')
   if layer and layer.Visible and sheet then check(inside(rect(sheet),rect(safeRoot)),'open production menu stays inside actual native safe content') end
  end
  check(callbackCount==0,'harness never invokes choose callbacks')
 end,debug.traceback)
 -- The temporary tree is destroyed even if construction or a native API fails.
 local cleaned,cleanupError=pcall(function() gui:Destroy() end)
 assert(cleaned and gui.Parent==nil,'UI harness cleanup failed: '..tostring(cleanupError))
 result.cleaned=true
 if not ok then check(false,'harness execution error',tostring(err)) end
 result.passed=result.failureCount==0
 return result
end
