local template=Instance.new('Model');local body=Instance.new('Part');body.Parent=template;template.PrimaryPart=body;template.Parent=rs
realTime=100
DroneRoleEffects.Ability(1,{kind='scrapPose',expires=110,bots={{id=1,x=0,y=3,z=0,active=true,pulse=1}}},template)
scan();local source=workspace.DroneRoleState.ScrapSwarm.ScrapBot_1
local record=assert(bots[source]);assert(record.view.Scale==.18)
renderBots(1/60,100)
realTime=100.1
DroneRoleEffects.Ability(1,{kind='scrapPose',expires=110,bots={{id=1,x=1,y=3,z=0,active=true,pulse=2}}},template)
renderBots(1/60,100.1)
renderBots(1/60,100.15)
assert(math.abs(record.pos.X-.3)<.00001,'scrap bot chased a network point instead of interpolating')
assert(record.sparks.Emitted==2,'confirmed pulse did not emit local chips')
scan();assert(bots[source]==record,'scan cloned a duplicate bot')
DroneRoleEffects.ClearAbility(1);renderBots(1/60,100.2)
assert(bots[source]==nil and not record.view.Parent and not record.beam.Parent)
assert(record.core.Parent and not record.sparks.Enabled,'cleanup clipped existing particle tails')
visualRoot:Destroy();template:Destroy()
print('PASS production scrap observer, original miniature asset, buffered motion, confirmed chips and cleanup')
