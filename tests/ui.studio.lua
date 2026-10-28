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
 local function inside(object,container)
  local p,s=object.AbsolutePosition,object.AbsoluteSize
  local q,t=container.AbsolutePosition,container.AbsoluteSize
  return s.X>0 and s.Y>0 and p.X>=q.X-.5 and p.Y>=q.Y-.5 and p.X+s.X<=q.X+t.X+.5 and p.Y+s.Y<=q.Y+t.Y+.5
 end
 local controls=0
 local function inspect(surface)
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
 end
 local surface=mode=='hud' and root or sheet
 inspect(surface)
 -- Offer status is a SafeContent sibling, not a sheet child. When present
 -- inspect its actual rendered font bounds and ensure it lies on screen.
 local feedback=root:FindFirstChild('Feedback')
 if mode~='hud' and feedback and feedback.Visible then
  inspect(feedback);check(inside(feedback,root),'visible feedback is outside safe content')
 end
 if options.expectFeedback then
  check(feedback~=nil and feedback.Visible,'expected visible production feedback/error')
 end
 if mode=='hud' then
  local context=root:FindFirstChild('ContextAction')
  if options.expectContext then check(context~=nil and context.Visible,'expected a visible context dock') end
  if context and context.Visible then
   local title=context:FindFirstChild('ContextTitle');local detail=context:FindFirstChild('ContextDetail');local action=context:FindFirstChild('UseContext')
   check(title~=nil and detail~=nil and action~=nil,'context controls missing')
   if title and action then check(inside(title,context) and title.AbsolutePosition.X+title.AbsoluteSize.X<=action.AbsolutePosition.X+.5,'context title overlaps its action or escapes dock') end
   if detail and detail.Visible and title and action then
    check(inside(detail,context) and detail.AbsolutePosition.X+detail.AbsoluteSize.X<=action.AbsolutePosition.X+.5,'context detail overlaps its action or escapes dock')
    check(title.AbsolutePosition.Y+title.AbsoluteSize.Y<=detail.AbsolutePosition.Y+.5,'context title overlaps its detail')
   end
  end
 end
 check(controls>0,'production text controls present')
 local expected=({fleet={'FleetTab','RunTab','NextDrone'},run={'FleetTab','RunTab'},pack={'BuyPack'},prestige={'PrestigeKeep','PrestigeReset','ConfirmPrestige'},offer={'ConfirmCard','CloseOffer'},hud={'Resources','Cargo','SaveStatus'}})[mode]
 local searchRoot=(mode=='hud' and root) or (mode=='offer' and sheet) or body
 for _,name in ipairs(expected) do
  local control=searchRoot:FindFirstChild(name,true)
  check(control~=nil,'missing production control '..name)
  if mode=='offer' and control and control:IsA('TextButton') then
   check(control.AbsoluteSize.X>=44 and control.AbsoluteSize.Y>=44,name..' target under 44px')
   check(inside(control,root),name..' action outside safe content')
   check(inside(control,sheet),name..' action outside offer sheet')
  end
 end
 if mode=='offer' then
  local detail=sheet:FindFirstChild('FocusedCardDetail',true)
  check(detail~=nil and inside(detail,root),'focused card detail missing or offscreen')
  for index=1,3 do
   local slot=body:FindFirstChild('OfferSlot'..index)
   local card=slot and slot:FindFirstChild('CardChoice'..index,true)
   local focus=card and card:FindFirstChild('FocusCard',true)
   check(focus~=nil,'missing focus card '..index)
   if focus then
    check(focus.AbsoluteSize.X>=44 and focus.AbsoluteSize.Y>=44,'focus card '..index..' target under 44px')
    check(inside(focus,root) and inside(focus,body),'focus card '..index..' is clipped or offscreen')
   end
  end
 end
 result.manualInteraction='Manually exercise tab transitions, offer focus and errors, touch, scroll, assignment, pack reopen/confirm, and prestige disclosure on real desktop and phone; this inspection does not trigger transactions. Open offer with each choice focused and again while a server confirmation/error is pending.'
 result.passed=#result.failures==0
 return result
end
