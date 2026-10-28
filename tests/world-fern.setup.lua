-- Two-part synthetic copies exercise original-model identity matching. This is
-- an API double, not a reconstruction of the real source asset or a Studio walk.
local fernTree=Instance.new('Model');fernTree.Name='Model';fernTree.Parent=workspace
local fernPart=fixturePart(fernTree,'Part',Vector3.new(56.4000168,29.4873676,104.3143997),Vector3.new(4.7368422,7.1052628,5.210526))
local fernTrunk=fixturePart(fernTree,'Part',Vector3.new(56.4000168,29.4873676,104.3143997),Vector3.new(1,10,1))
local unrelated=Instance.new('Model');unrelated.Name='Model';unrelated.Parent=workspace
local otherPart=fixturePart(unrelated,'Part',Vector3.new(22,2,51),Vector3.new(3,4,5))
local otherTrunk=fixturePart(unrelated,'Part',Vector3.new(22,2,51),Vector3.new(1,8,1))
