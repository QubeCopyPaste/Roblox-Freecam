local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

--==================================================
-- SETTINGS
--==================================================

local TOGGLE_KEY = Enum.KeyCode.F

local SPEED = 50
local SLOW_SPEED = 12

-- Heavy movement / inertia
local MOVEMENT_ACCELERATION = 2.4
local MOVEMENT_DRAG = 1.1

-- Heavy camera rotation
local ROTATION_STIFFNESS = 7
local ROTATION_DAMPING = 4.5

local SENSITIVITY = 0.0025

--==================================================
-- STATE
--==================================================

local freecamEnabled = false

local savedCameraType
local savedCameraCFrame

local velocity = Vector3.zero

local yaw = 0
local pitch = 0

local targetYaw = 0
local targetPitch = 0

local yawVelocity = 0
local pitchVelocity = 0

local keys = {
W = false,
A = false,
S = false,
D = false,
E = false,
Q = false
}

local controls

--==================================================
-- STARTUP KEY DISPLAY
--==================================================

local function createKeyDisplay()
local playerGui = player:WaitForChild("PlayerGui")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "FreecamKeyDisplay"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

local container = Instance.new("Frame")
container.Name = "KeyContainer"
container.AnchorPoint = Vector2.new(0.5, 0.5)
container.Position = UDim2.fromScale(0.5, 0.5)
container.Size = UDim2.fromOffset(180, 70)
container.BackgroundTransparency = 1
container.Parent = screenGui

-- HORIZONTAL: [ Shift ]   [ F ]
local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.VerticalAlignment = Enum.VerticalAlignment.Center
layout.Padding = UDim.new(0, 12)
layout.Parent = container

local function createKey(text, width)
	local wrapper = Instance.new("Frame")
	wrapper.Name = text .. "Wrapper"
	wrapper.Size = UDim2.fromOffset(width + 30, 62)
	wrapper.BackgroundTransparency = 1
	wrapper.Parent = container

	-- Outer glow
	local glow = Instance.new("Frame")
	glow.Name = "Glow"
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.5)
	glow.Size = UDim2.fromOffset(width + 24, 50)
	glow.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
	glow.BackgroundTransparency = 0.72
	glow.BorderSizePixel = 0
	glow.ZIndex = 1
	glow.Parent = wrapper

	local glowCorner = Instance.new("UICorner")
	glowCorner.CornerRadius = UDim.new(0, 10)
	glowCorner.Parent = glow

	local glowStroke = Instance.new("UIStroke")
	glowStroke.Color = Color3.fromRGB(55, 55, 55)
	glowStroke.Thickness = 8
	glowStroke.Transparency = 0.45
	glowStroke.Parent = glow

	-- Key
	local key = Instance.new("TextLabel")
	key.Name = "Key"
	key.AnchorPoint = Vector2.new(0.5, 0.5)
	key.Position = UDim2.fromScale(0.5, 0.5)
	key.Size = UDim2.fromOffset(width, 44)
	key.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
	key.BackgroundTransparency = 0
	key.BorderSizePixel = 0
	key.Text = text
	key.TextColor3 = Color3.fromRGB(235, 235, 235)
	key.TextSize = 17
	key.Font = Enum.Font.GothamMedium
	key.ZIndex = 2
	key.Parent = wrapper

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 7)
	corner.Parent = key

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(25, 25, 25)
	stroke.Thickness = 2
	stroke.Transparency = 0
	stroke.Parent = key

	-- Glow pulse
	local pulseInfo = TweenInfo.new(
		0.9,
		Enum.EasingStyle.Sine,
		Enum.EasingDirection.InOut,
		-1,
		true
	)

	TweenService:Create(
		glow,
		pulseInfo,
		{
			Size = UDim2.fromOffset(width + 38, 64),
			BackgroundTransparency = 0.55
		}
	):Play()

	TweenService:Create(
		glowStroke,
		pulseInfo,
		{
			Thickness = 13,
			Transparency = 0.18
		}
	):Play()
end

-- EXACT ORDER:
-- [ Shift ]   [ F ]
createKey("Shift", 82)
createKey("F", 48)

-- Fade everything out after 5 seconds
task.delay(5, function()
	if not screenGui or not screenGui.Parent then
		return
	end

	local fadeInfo = TweenInfo.new(
		0.5,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out
	)

	for _, object in ipairs(container:GetDescendants()) do
		if object:IsA("TextLabel") then
			TweenService:Create(
				object,
				fadeInfo,
				{
					TextTransparency = 1,
					BackgroundTransparency = 1
				}
			):Play()

		elseif object:IsA("UIStroke") then
			TweenService:Create(
				object,
				fadeInfo,
				{
					Transparency = 1
				}
			):Play()

		elseif object:IsA("Frame") then
			TweenService:Create(
				object,
				fadeInfo,
				{
					BackgroundTransparency = 1
				}
			):Play()
		end
	end

	task.wait(0.5)

	if screenGui then
		screenGui:Destroy()
	end
end)

end

createKeyDisplay()

--==================================================
-- PLAYER CONTROLS
--==================================================

local function getControls()
if controls then
return controls
end

local playerScripts = player:WaitForChild("PlayerScripts")
local playerModule = playerScripts:WaitForChild("PlayerModule")

local module = require(playerModule)
controls = module:GetControls()

return controls

end

--==================================================
-- INPUT
--==================================================

UserInputService.InputBegan:Connect(function(input, gameProcessed)
if gameProcessed then
return
end

if input.KeyCode == TOGGLE_KEY
	and (
		UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
		or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
	) then

	if freecamEnabled then
		-- Disable
		freecamEnabled = false

		if controls then
			controls:Enable()
		end

		camera.CameraType = savedCameraType or Enum.CameraType.Custom
		camera.CFrame = savedCameraCFrame or camera.CFrame

		velocity = Vector3.zero
		yawVelocity = 0
		pitchVelocity = 0

		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true

	else
		-- Enable
		freecamEnabled = true

		savedCameraType = camera.CameraType
		savedCameraCFrame = camera.CFrame

		local lookVector = camera.CFrame.LookVector

		yaw = math.atan2(-lookVector.X, -lookVector.Z)
		pitch = math.asin(math.clamp(lookVector.Y, -1, 1))

		targetYaw = yaw
		targetPitch = pitch

		yawVelocity = 0
		pitchVelocity = 0
		velocity = Vector3.zero

		camera.CameraType = Enum.CameraType.Scriptable

		local playerControls = getControls()
		playerControls:Disable()

		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		UserInputService.MouseIconEnabled = false
	end

	return
end

if input.KeyCode == Enum.KeyCode.W then
	keys.W = true

elseif input.KeyCode == Enum.KeyCode.A then
	keys.A = true

elseif input.KeyCode == Enum.KeyCode.S then
	keys.S = true

elseif input.KeyCode == Enum.KeyCode.D then
	keys.D = true

elseif input.KeyCode == Enum.KeyCode.E then
	keys.E = true

elseif input.KeyCode == Enum.KeyCode.Q then
	keys.Q = true
end

end)

UserInputService.InputEnded:Connect(function(input)
if input.KeyCode == Enum.KeyCode.W then
keys.W = false

elseif input.KeyCode == Enum.KeyCode.A then
	keys.A = false

elseif input.KeyCode == Enum.KeyCode.S then
	keys.S = false

elseif input.KeyCode == Enum.KeyCode.D then
	keys.D = false

elseif input.KeyCode == Enum.KeyCode.E then
	keys.E = false

elseif input.KeyCode == Enum.KeyCode.Q then
	keys.Q = false
end

end)

--==================================================
-- ENABLE / DISABLE
--==================================================

local function enableFreecam()
if freecamEnabled then
return
end

freecamEnabled = true

savedCameraType = camera.CameraType
savedCameraCFrame = camera.CFrame

local lookVector = camera.CFrame.LookVector

yaw = math.atan2(-lookVector.X, -lookVector.Z)
pitch = math.asin(math.clamp(lookVector.Y, -1, 1))

targetYaw = yaw
targetPitch = pitch

yawVelocity = 0
pitchVelocity = 0
velocity = Vector3.zero

camera.CameraType = Enum.CameraType.Scriptable

local playerControls = getControls()
playerControls:Disable()

UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
UserInputService.MouseIconEnabled = false

end

local function disableFreecam()
if not freecamEnabled then
return
end

freecamEnabled = false

if controls then
	controls:Enable()
end

camera.CameraType = savedCameraType or Enum.CameraType.Custom
camera.CFrame = savedCameraCFrame or camera.CFrame

velocity = Vector3.zero
yawVelocity = 0
pitchVelocity = 0

UserInputService.MouseBehavior = Enum.MouseBehavior.Default
UserInputService.MouseIconEnabled = true

end

--==================================================
-- MOVEMENT
--==================================================

local function getMovementDirection()
local direction = Vector3.zero

if keys.W then
	direction += Vector3.new(0, 0, -1)
end

if keys.S then
	direction += Vector3.new(0, 0, 1)
end

if keys.A then
	direction += Vector3.new(-1, 0, 0)
end

if keys.D then
	direction += Vector3.new(1, 0, 0)
end

if keys.E then
	direction += Vector3.new(0, 1, 0)
end

if keys.Q then
	direction += Vector3.new(0, -1, 0)
end

if direction.Magnitude > 0 then
	direction = direction.Unit
end

return direction

end

--==================================================
-- FREECAM LOOP
--==================================================

RunService:BindToRenderStep(
"SmoothFreecam",
Enum.RenderPriority.Camera.Value + 1,
function(dt)

	if not freecamEnabled then
		return
	end

	--==============================================
	-- MOUSE ROTATION
	--==============================================

	local mouseDelta = UserInputService:GetMouseDelta()

	targetYaw -= mouseDelta.X * SENSITIVITY
	targetPitch -= mouseDelta.Y * SENSITIVITY

	-- No pitch clamp.
	-- Allows full vertical 360° rotation.

	local yawDifference = targetYaw - yaw
	local pitchDifference = targetPitch - pitch

	yawVelocity += yawDifference * ROTATION_STIFFNESS * dt
	pitchVelocity += pitchDifference * ROTATION_STIFFNESS * dt

	local rotationalDrag = math.exp(-ROTATION_DAMPING * dt)

	yawVelocity *= rotationalDrag
	pitchVelocity *= rotationalDrag

	yaw += yawVelocity * dt
	pitch += pitchVelocity * dt

	--==============================================
	-- CAMERA ROTATION
	--==============================================

	local rotation = CFrame.Angles(0, yaw, 0)
		* CFrame.Angles(pitch, 0, 0)

	--==============================================
	-- MOVEMENT
	--==============================================

	local movementDirection = getMovementDirection()

	local currentSpeed = SPEED

	if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
		or UserInputService:IsKeyDown(Enum.KeyCode.RightShift) then
		currentSpeed = SLOW_SPEED
	end

	local targetVelocity = rotation:VectorToWorldSpace(
		movementDirection * currentSpeed
	)

	-- Heavy acceleration / inertia
	if movementDirection.Magnitude > 0 then
		local accelerationAlpha =
			1 - math.exp(-MOVEMENT_ACCELERATION * dt)

		velocity = velocity:Lerp(
			targetVelocity,
			accelerationAlpha
		)
	else
		local drag = math.exp(-MOVEMENT_DRAG * dt)

		velocity *= drag

		if velocity.Magnitude < 0.01 then
			velocity = Vector3.zero
		end
	end

	--==============================================
	-- APPLY
	--==============================================

	local newPosition =
		camera.CFrame.Position + velocity * dt

	camera.CFrame =
		CFrame.new(newPosition) * rotation
end

)
