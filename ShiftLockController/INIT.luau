--!strict

--[[
	-- LUAU TYPECHECKING IS BUGGY, so ignore the red-underlined errors
]]


type ShiftLockLerpInfoType = {
	ToDurationSeconds: number,															-- time to animate camOffset when shiftlock is on
	FromDurationSeconds: number,														-- time to animate camOffset to default offset when shiftlock is off
	EasingInFunc: (startPos: Vector3, targetPos: Vector3, t: number) -> Vector3,		-- function for animation curve from default to camera offset
	EasingOutFunc: (startPos: Vector3, targetPos: Vector3, t: number) -> Vector3		-- function for animation curve from camera offset to default
}


local EasingFuncs = require(script.EasingFuncs)
local ShiftLockIcons = require(script.ShiftLockIcons)

--[[ DEFAULT CONFIGS ]]--
local ShiftLockController = {
	SmoothShiftLockEnabled = true,
	ShiftLockIcon = "rbxasset://textures/MouseLockedCursor.png",
	CameraOffset = Vector3.new(1.75, .25, 0),
	ZoomInThreshold = 2,											-- play around with this value to ensure zooming in and out in shift lock is apprioriate; if your camera offset has a higher magnitude, then make this value higher.
	CharRotateLerpSpeed = 20,
	ShiftLockLerpInfo = {
		ToDurationSeconds = .2,
		FromDurationSeconds = .2,
		EasingInFunc = EasingFuncs.Lerp,
		EasingOutFunc = EasingFuncs.Lerp,
	}:: ShiftLockLerpInfoType,
	EasingFuncs = EasingFuncs,
	ShiftLockIcons = ShiftLockIcons
}


local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")


local _DEFAULT_MOUSE_ICON: string = ""
local _shiftLockOn = false
local _camera = workspace.CurrentCamera::Camera
local _character = nil
local _humanoid = nil
local _HRP = nil
local _mouse = nil
local _shiftLockCon: RBXScriptConnection? = nil
local _currCameraOffset: Vector3 = Vector3.zero

local _initialized = false
local _characterDead = false

local function disconnectLerpCon(c: RBXScriptConnection)
	if c.Connected then
		c:Disconnect()
	end
end

local function enableShiftLock()
	local charLerpSpeed = ShiftLockController.CharRotateLerpSpeed
	local zoomInThreshold = ShiftLockController.ZoomInThreshold
	local smoothShiftLockEnabled = ShiftLockController.SmoothShiftLockEnabled
	local easingFunc = ShiftLockController.ShiftLockLerpInfo.EasingInFunc
	local targetOffset = ShiftLockController.CameraOffset
	
	-- initial lerp for camera offset 
	if smoothShiftLockEnabled then
		local startOffset = _currCameraOffset
		
		local lerpDuration = ShiftLockController.ShiftLockLerpInfo.ToDurationSeconds
		local currLerpTime = 0

		local con: RBXScriptConnection
		con = RunService.PreRender:Connect(function(dt: number)
			if not _shiftLockOn then disconnectLerpCon(con) return end
			if currLerpTime >= lerpDuration then disconnectLerpCon(con) return end
			
			local camCF = _camera.CFrame
			local distance = (_character.Head.Position - camCF.Position).magnitude
			
			if distance > 1 then -- start shift lock animation when zoomed out
				if UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter then
					UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
				end
				currLerpTime += dt
				local t = math.clamp(currLerpTime/lerpDuration, 0, 1)
				_currCameraOffset = easingFunc(startOffset, targetOffset, t)
			end
		end)
	else
		_currCameraOffset = targetOffset
	end
	
	local lerpDuration = ShiftLockController.ShiftLockLerpInfo.ToDurationSeconds
	local currLerpTime = 0
	local zoomedIn = false
	
	_shiftLockCon = RunService.PreRender:Connect(function(dt: number)
		(_humanoid::Humanoid).AutoRotate = false
			
		local _, y, _ = _camera.CFrame:ToEulerAnglesYXZ()
		;(_HRP::Part).CFrame = (_HRP::Part).CFrame:Lerp(CFrame.new((_HRP::Part).Position) * CFrame.Angles(0, y, 0), dt * charLerpSpeed)
		_camera.CFrame = _camera.CFrame * CFrame.new(_currCameraOffset)
		
		
		
		--[[ code below is to handle easing back out from being zoomed in ]]--
		
		local camCF = _camera.CFrame
		local distance = (_character.Head.Position - camCF.Position).magnitude
		

		if distance < zoomInThreshold and not zoomedIn then
			_camera.CFrame = CFrame.new(_character.Head.Position) * _camera.CFrame.Rotation
			_currCameraOffset = Vector3.zero
			currLerpTime = 0
			zoomedIn = true
			zoomInThreshold = 1
		elseif distance > zoomInThreshold and zoomedIn then
			if smoothShiftLockEnabled then
				if currLerpTime < lerpDuration then
					currLerpTime += dt
					local t = math.clamp(currLerpTime/lerpDuration, 0, 1)
					_currCameraOffset = easingFunc(Vector3.zero, targetOffset, t)
					if currLerpTime >= lerpDuration then
						zoomedIn = false
						zoomInThreshold = ShiftLockController.ZoomInThreshold
					end
				end
			else
				zoomedIn = false
				if UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter then
					UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
				end
				zoomInThreshold = ShiftLockController.ZoomInThreshold
				_currCameraOffset = targetOffset
			end
		end
		
	end)
end

local function disableShiftLock()
	if _shiftLockCon and _shiftLockCon.Connected then
		_shiftLockCon:Disconnect()
		_shiftLockCon = nil
	end
	(_humanoid::Humanoid).AutoRotate = true
	
	-- lerp camera offset back to 0 when shift lock is disabled
	if ShiftLockController.SmoothShiftLockEnabled then
		local startOffset = _currCameraOffset
		local easingFunc = ShiftLockController.ShiftLockLerpInfo.EasingOutFunc
		
		local lerpDuration = ShiftLockController.ShiftLockLerpInfo.FromDurationSeconds
		local currLerpTime = 0

		local con: RBXScriptConnection
		con = RunService.PreRender:Connect(function(dt: number)
			if _shiftLockOn then disconnectLerpCon(con) return end
			if currLerpTime >= lerpDuration then disconnectLerpCon(con) return end

			currLerpTime += dt
			local t = math.clamp(currLerpTime/lerpDuration, 0, 1)
			_currCameraOffset = easingFunc(startOffset, Vector3.zero, t)
			
			_camera.CFrame = _camera.CFrame * CFrame.new(_currCameraOffset)
		end)
	end
end



function ShiftLockController.Init(player: Player, character: Model)
	_character = character
		
	local hrp = _character:WaitForChild("HumanoidRootPart", 2)
	if hrp then
		_HRP = hrp
	end
	
	local humanoid = _character:WaitForChild("Humanoid", 2)
	if humanoid then
		_humanoid = humanoid::Humanoid

		_humanoid.Died:Once(function()
			if _shiftLockOn then ShiftLockController.Toggle() end
			_characterDead = true
		end)
	end	
	
	_mouse = player:GetMouse()
	_DEFAULT_MOUSE_ICON = _mouse.Icon
	_initialized = true
	_characterDead = false
end

function ShiftLockController.Toggle() 
	assert(_initialized, debug.traceback("Must be initalized with .Init() whenever the character spawns"))
	
	if _characterDead then return end
	
	_shiftLockOn = not _shiftLockOn::boolean
	UserInputService.MouseBehavior = _shiftLockOn and Enum.MouseBehavior.LockCenter or Enum.MouseBehavior.Default
	UserInputService.MouseIcon = _shiftLockOn and ShiftLockController.ShiftLockIcon or _DEFAULT_MOUSE_ICON
	
	if _shiftLockOn then
		enableShiftLock()
	else
		disableShiftLock()
	end
end





return ShiftLockController
