local function checkNomadView()
 local hull=Instance.new('Model');hull.Parent=workspace
 local ports=Instance.new('Folder');ports.Parent=hull
 local function slit(name,x,z,width,returned)
  local part=Instance.new('Part');part.Name=name;part.Size=Vector3.new(.1,.1,width);part.Parent=ports
  local function mount(name,offset)
   local a=Instance.new('Attachment');a.Name=name;a.WorldPosition=Vector3.new(x,38,z)+offset;a.Parent=part;return a
  end
  local a=mount('A',Vector3.zero);local b=mount('B',Vector3.new(width,0,0))
  if returned then mount('C',Vector3.new(width,0,1)) end
  return a,b
 end
 local outer=slit('OuterLeft',-6,0,4,true)
 slit('OuterRight',2,0,4,true)
 local middle=slit('MidLeft',-5,-1,3,true)
 local rear=slit('RearLeft',-5,1,3,true)
 slit('Bridge',-2,0,4,true)
 slit('MidRight',2,-1,3,true)
 slit('RearRight',2,1,3,true)
 local keelA,keelB=slit('KeelLeft',-1.25,-1,1)
 local _,keelRight=slit('KeelRight',.25,-1,1)
 local muzzle=Instance.new('Attachment');muzzle.WorldPosition=Vector3.new(2.65,37.15,.17);muzzle.Parent=hull
 local drone={nomadProjectors=ports,shotMuzzle=muzzle,view=hull,source=hull}
 local node=Instance.new('Folder');node:SetAttribute('ScanGround',0)
 local record={}
 local windup=4.05
 local launches,cutAudio,flashes=0,0,0
 local impactBeats,played={},{}
 local audio={setLoop=function() end,play=function(_,cue)
  if cue=='coil_fire' then launches+=1 else played[#played+1]=cue end
 end,
  stopLoop=function(_,_,immediate) if immediate then cutAudio+=1 end end}
 local target=Vector3.new(0,2,0)
 local function at(q)
  local age=q*windup
  NomadView.step(record,node,age,muzzle.WorldPosition,target,age,windup,(age-windup)/.95,drone,nil,audio,
   function(_,strength) impactBeats[#impactBeats+1]=strength end,function() flashes+=1 end)
 end
 local function filaments(scan)
  local count=0
  for _,pane in ipairs(scan.panes) do
   for _,edge in ipairs(pane.edges) do if edge.main.Enabled then count+=1 end end
  end
  return count
 end
 local function straight(line,port)
  local top,bottom=line.b.WorldCFrame.Position,line.a.WorldCFrame.Position
  assert((top-port.WorldPosition).Magnitude<1e-5 and top.X==bottom.X and top.Z==bottom.Z)
 end
 for i=1,240 do
  NomadView.cruise(drone,i/60,workspace)
  assert(filaments(drone.nomadCruise)>0,'the cruise pattern blacked out')
 end
 at(.10)
 assert(not drone.nomadCruise)
 local scan=record.scan
 local first=scan.panes[1]
 assert(first.sheet.main.Enabled and first.sheet.main.Width0==4 and first.sheet.main.Width1==4)
 assert(filaments(scan)==6 and not scan.panes[3].sheet.main.Enabled)
 straight(first.edges[1],outer)
 at(.268);straight(first.edges[1],outer);assert(first.sheet.main.Width0==4)
 at(.270);straight(first.edges[1],middle);assert(first.sheet.main.Width0==3 and filaments(scan)==9)
 at(.334);straight(first.edges[1],middle)
 at(.336);straight(first.edges[1],rear);assert(first.sheet.main.Width0==3)
 at(.471);straight(first.edges[1],outer);assert(scan.seams[1].core.Transparency<1)
 at(.593);straight(first.edges[1],keelA);assert(first.sheet.main.Width0==1 and filaments(scan)==4)
 at(.728);assert(first.sheet.main.Enabled and first.feet[1].core.Transparency<1)
 at(.730)
 assert(not first.sheet.main.Enabled and filaments(scan)==2 and first.feet[1].core.Transparency==1)
 straight(first.edges[2],keelB);straight(scan.panes[2].edges[2],keelRight)
 at(.772);assert(filaments(scan)==2 and scan.glint.Transparency==1)
 at(.774);assert(filaments(scan)==0 and scan.glint.Transparency==1 and cutAudio==1)
 at(.900);assert(filaments(scan)==0 and scan.glint.Transparency==1 and not record.rocket)
 at(.946);assert(filaments(scan)==0 and scan.glint.Position==muzzle.WorldPosition and scan.glint.Transparency<1 and not record.rocket)
 at(1)
 assert(not record.scan and record.rocket and launches==1 and (record.launchFrom-muzzle.WorldPosition).Magnitude<1e-5)
 node:SetAttribute('ContactAt',5);node:SetAttribute('BlastGround',Vector3.zero);node:SetAttribute('BlastRadius',13)
 at(5.02/windup)
 local blast=assert(record.blast)
 assert(flashes==1 and #impactBeats==1 and played[1]=='nomad_impact' and RoleVisuals.pulses==1)
 assert(blast.stem.Emitted==18 and not blast.cap[1].Emitted and blast.fire.Emitted==14)
 at(5.28/windup)
 assert(blast.cap[1].Emitted==5 and blast.stem.Emitted==26 and not record.rocket)
 assert(blast.cap[1].Size[2].Value>12 and blast.cap[1].Lifetime.Max>3)
 assert(blast.root:GetChildren()[1].Transparency==1,'the plume used visible geometry')
 at(5.49/windup)
 assert(#impactBeats==1 and not record.shattered and RoleVisuals.craters==0)
 node:SetAttribute('ShatterAt',5.50)
 at(5.51/windup)
 assert(impactBeats[2]>impactBeats[1] and RoleVisuals.pulses==2 and played[2]=='nomad_shatter')
 at(5.52/windup)
 assert(#impactBeats==2 and flashes==1 and RoleVisuals.craters==1 and not NomadView.detach(record,7))
 assert(NomadView.detach(record,10) and not blast.root.Parent)
 NomadView.clear(record)
 print('PASS Nomad continuous cruise scan, launch cutoff, particle plume, one white flash and confirmed shatter beat')
end
checkNomadView()
