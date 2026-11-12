local function checkNomadView()
 local node=Instance.new('Folder')
 local from,target=Vector3.new(0,420,0),Vector3.zero
 local side=from+Vector3.new(53,0,0)
 local windup,flight=Feel.nomadWindup((side-from).Magnitude,9,6.4),1.44
 local beamOff=windup-1.8
 local _,scanClock=Feel.nomadScanProgress(0,windup)
 node:SetAttribute('ScanFrom',side)
 node:SetAttribute('BlastRadius',32)
 local record={}
 local loop,flashes=nil,0
 local impactBeats,played={},{}
 local audio={
  setLoop=function(_,_,name,point,level,pitch) loop={name=name,point=point,level=level,pitch=pitch} end,
  play=function(_,cue) played[#played+1]=cue end,
  stopLoop=function() loop=nil end,
 }
 local function at(age)
  NomadView.step(record,node,age,from,target,age,windup,(age-windup)/flight,audio,
   function(_,strength) impactBeats[#impactBeats+1]=strength end,function() flashes+=1 end)
 end
 local function filaments(scan)
  local count=0
  for _,pane in ipairs(scan.panes) do
   for _,edge in ipairs(pane.edges) do if edge.main.Enabled then count+=1 end end
  end
  return count
 end
 local function straight(line)
  local top,bottom=line.b.WorldCFrame.Position,line.a.WorldCFrame.Position
  assert(top.Y>37 and top.Y<38 and bottom.Y<.10 and top.X==bottom.X and top.Z==bottom.Z)
 end
 local forward=(from-side).Unit
 local function oldPort(line,age,x,y,z)
  local center=Feel.nomadPass(side,from,Feel.nomadScanProgress(age,windup))
  local origin=Vector3.new(center.X,38,center.Z)-forward*1.4290527
  local frame=CFrame.lookAt(origin,origin+forward)
  local actual=frame:PointToObjectSpace(line.b.WorldCFrame.Position)
  assert((actual-Vector3.new(x,y,z)).Magnitude<.001,'projection differs from the pre-teeth hull aperture')
  straight(line)
 end
 at(.01)
 local scan=assert(record.scan)
 local first=scan.panes[1]
 local width=first.sheet.main.Width0
 local originalWidth=4.8066006 -- Measured on the fitted hull at 44f061c.
 assert(first.sheet.main.Enabled and math.abs(width-originalWidth)<.001 and width==first.sheet.main.Width1)
 assert(filaments(scan)==6 and not scan.panes[3].sheet.main.Enabled)
 assert(played[1]=='nomad_scan_cut' and loop.name=='nomad_scan' and loop.point.X>52)
 oldPort(first.edges[1],.01,-1.830974,-.279856,.163746)
 oldPort(first.edges[3],.01,-6.498919,-.279856,1.422769)
 oldPort(scan.panes[2].edges[3],.01,6.660275,-.279856,.393320)
 at(.268*scanClock);assert(first.sheet.main.Width0==width)
 local before=first.edges[1].b.WorldCFrame.Position
 at(.270*scanClock)
 assert((first.edges[1].b.WorldCFrame.Position-before).Magnitude>2.5 and played[2]=='nomad_scan_cut' and loop.pitch>.78)
 oldPort(first.edges[1],.270*scanClock,-5.731097,-.324514,.357263)
 oldPort(scan.panes[2].edges[3],.270*scanClock,1.816088,-.339400,1.339737)
 assert(filaments(scan)==9 and scan.seams[1].core.Transparency==1)
 before=first.edges[1].b.WorldCFrame.Position
 at(.336*scanClock)
 assert((first.edges[1].b.WorldCFrame.Position-before).Magnitude>1.6 and first.sheet.main.Width0<width and played[3]=='nomad_scan_cut')
 oldPort(first.edges[1],.336*scanClock,-5.731097,-.324514,1.042018)
 at(.471*scanClock);assert(scan.seams[1].core.Transparency<1 and played[4]=='nomad_scan_cut')
 oldPort(scan.panes[3].edges[1],.471*scanClock,1.830974,-.279856,.163746)
 at(.593*scanClock);assert(filaments(scan)==4 and not scan.panes[3].sheet.main.Enabled and played[5]=='nomad_scan_cut')
 oldPort(first.edges[2],.593*scanClock,-.282833,-.711549,-1.429053)
 at(.728*scanClock);assert(first.sheet.main.Enabled and first.feet[1].core.Transparency<1)
 at(.730*scanClock);assert(not first.sheet.main.Enabled and filaments(scan)==2 and first.feet[1].core.Transparency==1)
 oldPort(scan.panes[2].edges[2],.730*scanClock,.282833,-.711549,-1.429053)
 assert(played[6]=='nomad_scan_cut')
 at(beamOff-.001);assert(record.scan and filaments(scan)==2)
 at(beamOff);assert(not record.scan and not loop and played[7]=='nomad_scan_off')
 at(windup-.001);assert(not record.scan and not record.rocket and #played==7)
 at(windup);assert(not record.scan and record.rocket and loop.name=='nomad_descent' and played[8]=='nomad_release')
 assert(record.rocket.body.CFrame.Position.Y==34,'the payload started out of sight at patrol altitude')
 local altitude=loop.point.Y
 at(windup+.16);assert(played[9]=='nomad_screech')
 at(windup+.8);assert(loop.point.Y<altitude and #played==9)
 local impactAt=windup+flight
 node:SetAttribute('ContactAt',impactAt);node:SetAttribute('BlastGround',target)
 at(impactAt+.02)
 local blast=assert(record.blast)
 assert(not loop and flashes==1 and #impactBeats==1 and played[10]=='nomad_impact' and RoleVisuals.pulses==1)
 assert(blast.stem.Emitted==18 and not blast.cap[1].Emitted and blast.fire.Emitted==14)
 at(impactAt+.28)
 assert(blast.cap[1].Emitted==5 and blast.stem.Emitted==26 and not record.rocket)
 assert(blast.cap[1].Size[2].Value>22 and blast.cap[1].Lifetime.Max>3)
 assert(blast.root:GetChildren()[1].Transparency==1,'the plume used visible geometry')
 at(impactAt+.49)
 assert(#impactBeats==1 and not record.shattered and RoleVisuals.craters==0)
 node:SetAttribute('ShatterAt',impactAt+.50)
 at(impactAt+.51)
 assert(impactBeats[2]>impactBeats[1] and RoleVisuals.pulses==2 and played[11]=='nomad_shatter')
 at(impactAt+.52)
 assert(#impactBeats==2 and flashes==1 and RoleVisuals.craters==1 and not NomadView.detach(record,impactAt+2))
 assert(RoleVisuals.craterAt==impactAt+.50)
 assert(NomadView.detach(record,impactAt+5) and not blast.root.Parent)
 NomadView.clear(record)
 print('PASS Nomad pre-teeth apertures, original bank widths, stage-synced audio and 1.8-second blackout')
end
checkNomadView()
