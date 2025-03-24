--!strict
local DraggableUI = {}

local UIS = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer::Player
local playerGui = player.PlayerGui


export type Draggable = {
	ID: number,
	OnDragStart: (() -> ())?,
	OnDragMove: ((mousePos: Vector2) -> ())?,
	OnDragEnd: ((mousePos: Vector2, guisAtPos: { GuiObject }, wasDragged: boolean) -> ())?
}

type _Draggable = {
	_instance: GuiObject,
	_mouse1Down: boolean,
	_dragging: boolean,
	_parent: any,
	_size: Vector2,
	_pos: Vector2,
	_dragParent: ScreenGui,
	_parentSize: UDim2,
	_parentPos: UDim2,
	_moveCon: RBXScriptConnection?,
	_inputBegan: RBXScriptConnection?,
	_inputEnded: RBXScriptConnection?,
	_guiInsetIgnored: boolean,
}


local _objs: { [number]: _Draggable } = {}


local function disconnectCon(con: RBXScriptConnection?)
	if con and con.Connected then
		con:Disconnect()
	end
end

local function revertToParentProps(_props: _Draggable)
	local guiObj =_props._instance
	guiObj.Parent = _props._parent
	guiObj.Size = _props._parentSize
	guiObj.Position = _props._parentPos
	guiObj.ZIndex -= 10
end

local function saveParentProps(_props: _Draggable)
	local guiObj =_props._instance
	_props._size = guiObj.AbsoluteSize
	_props._pos = guiObj.AbsolutePosition
	_props._parent = guiObj.Parent
	_props._parentPos = guiObj.Position
	_props._parentSize = guiObj.Size
end


function DraggableUI.new(guiObj: GuiObject): Draggable
	local screenGui = guiObj:FindFirstAncestorWhichIsA("ScreenGui") -- used as the parent to guiObj when dragging 
	if not screenGui then error("Could not find an ancestor screenGui to anchor the draggable object", 0) end
	
	local _props = {
		_instance = guiObj,
		_mouse1Down = false,
		_dragging = false,
		_parent = nil,
		_size = Vector2.zero,
		_pos = Vector2.zero,
		_dragParent = screenGui,
		_parentSize = UDim2.new(),
		_parentPos = UDim2.new(),
		_guiInsetIgnored = screenGui.IgnoreGuiInset::boolean
	}::_Draggable
	
	table.insert(_objs, _props)
	
	local props = {
		ID = #_objs
	}::Draggable
	
	return props
end

function DraggableUI.Enable(draggableObj: Draggable)
	local _props = _objs[draggableObj.ID]
	local guiObj = _props._instance
	

	_props._inputBegan = guiObj.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			_props._mouse1Down = true
			
			saveParentProps(_props)
			local guiInset = _props._guiInsetIgnored and GuiService:GetGuiInset() or Vector2.zero

			guiObj.Parent = _props._dragParent
			guiObj.Size = UDim2.new(0, _props._size.X, 0, _props._size.Y)
			guiObj.Position = UDim2.new(0, math.ceil(_props._pos.X), 0, _props._pos.Y+guiInset.Y)
			guiObj.ZIndex += 10
			
			local initialMousePos = UIS:GetMouseLocation()
			local offset = _props._pos - initialMousePos + guiInset

			_props._moveCon = UIS.InputChanged:Connect(function(uisInput: InputObject)
				if uisInput.UserInputType == Enum.UserInputType.MouseMovement and _props._mouse1Down then
					if not _props._dragging then
						if draggableObj.OnDragStart then task.spawn(draggableObj.OnDragStart) end
					end
					_props._dragging = true
					local mouse = UIS:GetMouseLocation()
					guiObj.Position = UDim2.new(0, mouse.X + offset.X, 0, mouse.Y + offset.Y)
					if draggableObj.OnDragMove then task.spawn(draggableObj.OnDragMove, mouse) end
				end
			end)
		end
	end)
	
	_props._inputEnded = guiObj.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			_props._mouse1Down = false
			revertToParentProps(_props)
			disconnectCon(_props._moveCon)
			
			if draggableObj.OnDragEnd then 
				local mousePos = UIS:GetMouseLocation()
				local guisAtPos = playerGui:GetGuiObjectsAtPosition(mousePos.X, mousePos.Y - GuiService:GetGuiInset().Y)
				task.spawn(draggableObj.OnDragEnd, mousePos, guisAtPos, _props._dragging) 
			end
			
			_props._dragging = false
		end
	end)
end

function DraggableUI.Disable(draggableObj: Draggable)
	local _props = _objs[draggableObj.ID]
	
	_props._mouse1Down = false
	revertToParentProps(_props)
	disconnectCon(_props._inputBegan)
	disconnectCon(_props._inputEnded)
	disconnectCon(_props._moveCon)
end

function DraggableUI.Destroy(draggableObj: Draggable)
	if _objs[draggableObj.ID] == nil then error("[DragagbleUI]: Attempt to call DraggableUI.Destroy on nil;", 0) end
	
	DraggableUI.Disable(draggableObj)
	table.remove(_objs, draggableObj.ID)
end





return DraggableUI
