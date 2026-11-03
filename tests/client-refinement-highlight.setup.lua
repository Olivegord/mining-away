local localPlayer=player(7);players.LocalPlayer=localPlayer
local UIS={MouseEnabled=true,GamepadEnabled=false}
function UIS:GetFocusedTextBox() return nil end
function UIS:GetMouseLocation() return Vector2.new(100,100) end
local oldGetService=game.GetService
function game:GetService(name) if name=='UserInputService' then return UIS end;return oldGetService(self,name) end
local camera={}
function camera:ScreenPointToRay() return {Origin=Vector3.zero,Direction=Vector3.new(0,-1,0)} end
workspace.CurrentCamera=camera
local world=Instance.new('Folder');world.Parent=workspace
local fields=Instance.new('Folder');fields.Name='Fields';fields.Parent=world
local field=Instance.new('Model');field.Name='Quartz';field:SetAttribute('FieldId',1);field.Parent=fields
local floor=Instance.new('Part');floor.Name='Field';floor.Parent=field
local rock=Instance.new('Part');rock:SetAttribute('ResourceId','rock');rock:SetAttribute('FieldId',1);rock:SetAttribute('HP',100);rock.Parent=field
local hit=rock
function workspace:Raycast() return {Instance=hit} end
local fx=Instance.new('Folder');fx.Parent=workspace
local view=Instance.new('Part');view.Parent=fx
