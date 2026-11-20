-- Every hit is server-owned. Safe home, spawn shields and cover are respected.
local H={};H.__index=H
function H.new(ctx) return setmetatable({ctx=ctx},H) end
function H:hit(p,amount,from,key,interval,impulse)
 local ctx=self.ctx;local hr=ctx.root(p);if not hr then return end
 local humanoid=p.player.Character:FindFirstChildOfClass('Humanoid')
 if not humanoid or humanoid.Health<=0 or (hr.Position-ctx.home).Magnitude<23
  or p.player.Character:FindFirstChildOfClass('ForceField') then return end
 p.hazardAt=p.hazardAt or {};local now=ctx.now()
 if now<(p.hazardAt[key] or 0) then return end
 if not ctx.clear(from,hr.Position,p.player.Character) then return end
 p.hazardAt[key]=now+(interval or .25)
 -- Bounded categories keep a long server from accumulating per-projectile keys.
 humanoid:TakeDamage(math.clamp(amount,0,65))
 p.player:SetAttribute('MA_HurtAt',now)
 if impulse then
  local away=hr.Position-from;away=Vector3.new(away.X,0,away.Z)
  if away.Magnitude>.01 then away=away.Unit else away=Vector3.new(1,0,0) end
  hr:ApplyImpulse((away*impulse+Vector3.new(0,impulse*.45,0))*hr.AssemblyMass)
 end
end
function H:beam(from,to,amount,key)
 for _,p in pairs(self.ctx.players) do
  local hr=self.ctx.root(p)
  if hr and ToolRules.segmentDistance(hr.Position,from,to)<1.8 then self:hit(p,amount,from,key or 'laser',.24) end
 end
end
function H:blast(position,radius,amount,key)
 for _,p in pairs(self.ctx.players) do
  local hr=self.ctx.root(p);local distance=hr and (hr.Position-position).Magnitude or math.huge
  if distance<radius then self:hit(p,amount*(1-.65*distance/radius),position,key or 'explosion',.35,18*(1-distance/radius)) end
 end
end
return H
