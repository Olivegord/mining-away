-- Run on a real Studio Play CLIENT against the production UI, once per screen.
-- First manually open Fleet, Run, Pack or Prestige, then call
-- run(Interface, CardView, {safeRoot=player.PlayerGui.MiningAwayHUD.SafeContent,
--                           expectedMode='fleet'}) with the matching expectedMode.
-- This inspects the actual production tree; it does not fake player input or
-- claim the open/choose/reopen network lifecycle passed.
return function(_Interface,_CardView,options)
 options=options or {}
 local RunService=game:GetService('RunService')
 assert(RunService:IsStudio() and RunService:IsClient(),'Run in a Studio Play client')
 local root=assert(options.safeRoot,'Supply production SafeContent')
 local mode=assert(options.expectedMode,'Open a production screen and supply expectedMode')
 assert(mode=='fleet' or mode=='run' or mode=='pack' or mode=='prestige' or mode=='offer' or mode=='hud','Use fleet, run, pack, prestige, offer or hud')
 local layer=assert(root:FindFirstChild('MenuLayer'),'production menu missing')
 local sheet=assert(layer:FindFirstChild('MenuSheet'),'production sheet missing')
 if mode=='hud' then assert(not layer.Visible,'Close the production menu first') else assert(layer.Visible and sheet:GetAttribute('MenuMode')==mode,'Open the matching production screen first') end
 local body=assert(sheet:FindFirstChild('MenuContent'),'production scrolling body missing')
 for _=1,4 do RunService.RenderStepped:Wait() end
 local result={kind='production Studio UI inspection',mode=mode,checks=0,failures={},passed=false}
 local function check(ok,name)
  result.checks+=1;if not ok then table.insert(result.failures,name) end
 end
 local function visible(object,ancestor)
  local node=object
  while node and node~=ancestor do
   if node:IsA('GuiObject') and not node.Visible then return false end
   node=node.Parent
  end
  return true
 end
 local controls=0
 local surface=mode=='hud' and root or sheet
 for _,object in ipairs(surface:GetDescendants()) do
  if visible(object,surface) and (object:IsA('TextLabel') or object:IsA('TextButton')) and object.Text~='' then
   controls+=1
   local prefix=object:GetFullName()..' ['..object.Text..'] '
   check(object.TextSize>=16,prefix..'text below 16 px')
   check(not object.TextScaled,prefix..'unexpected text scaling')
   check(object.TextBounds.X>0 and object.TextBounds.Y>0,prefix..'no rendered text bounds')
   check(object.TextFits and object.TextBounds.X<=object.AbsoluteSize.X+.5 and object.TextBounds.Y<=object.AbsoluteSize.Y+.5,prefix..'text clips its native box')
   if object:IsA('TextButton') then check(object.AbsoluteSize.X>=44 and object.AbsoluteSize.Y>=44,prefix..'target under 44 px') end
  end
 end
 check(controls>0,'production text controls present')
 local expected=({fleet={'FleetTab','RunTab','NextDrone'},run={'FleetTab','RunTab'},pack={'BuyPack'},prestige={'PrestigeKeep','PrestigeReset','ConfirmPrestige'},offer={'ConfirmCard','CloseOffer'},hud={'Resources','Cargo','SaveStatus'}})[mode]
 local searchRoot=(mode=='hud' and root) or (mode=='offer' and sheet) or body
 for _,name in ipairs(expected) do check(searchRoot:FindFirstChild(name,true)~=nil,'missing production control '..name) end
 result.manualInteraction='Manually exercise tab transitions, offer focus and errors, touch, scroll, assignment, pack reopen/confirm, and prestige disclosure on real desktop and phone; this inspection does not trigger transactions. Open offer with each choice focused and again while a server confirmation/error is pending.'
 result.passed=#result.failures==0
 return result
end
