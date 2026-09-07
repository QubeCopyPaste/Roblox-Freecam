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
	container.Size = UDim2.fromOffset(150, 58)
	container.BackgroundTransparency = 1
	container.Parent = screenGui

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 8)
	layout.Parent = container

	local function createKey(text, width)
		local key = Instance.new("TextLabel")
		key.Name = text .. "Key"
		key.Size = UDim2.fromOffset(width, 50)
		key.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
		key.BackgroundTransparency = 0
		key.BorderSizePixel = 0
		key.Text = text
		key.TextColor3 = Color3.fromRGB(235, 235, 235)
		key.TextSize = 18
		key.Font = Enum.Font.GothamMedium
		key.ZIndex = 2
		key.Parent = container

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = key

		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(25, 25, 25)
		stroke.Thickness = 2
		stroke.Transparency = 0
		stroke.Parent = key

		-- Dark gray glow
		local glow = Instance.new("ImageLabel")
		glow.Name = "Glow"
		glow.AnchorPoint = Vector2.new(0.5, 0.5)
		glow.Position = UDim2.fromScale(0.5, 0.5)
		glow.Size = UDim2.new(1, 28, 1, 28)
		glow.BackgroundTransparency = 1
		glow.Image = "rbxassetid://5028857084"
		glow.ImageColor3 = Color3.fromRGB(55, 55, 55)
		glow.ImageTransparency = 0.45
		glow.ZIndex = 1
		glow.Parent = key

		--==================================================
		-- PULSE
		--==================================================

		task.spawn(function()
			local pulseInfo = TweenInfo.new(
				0.8,
				Enum.EasingStyle.Sine,
				Enum.EasingDirection.InOut,
				-1,
				true
			)

			TweenService:Create(
				key,
				pulseInfo,
				{
					BackgroundColor3 = Color3.fromRGB(65, 65, 65)
				}
			):Play()

			TweenService:Create(
				glow,
				pulseInfo,
				{
					ImageTransparency = 0.15,
					Size = UDim2.new(1, 38, 1, 38)
				}
			):Play()
		end)

		return key
	end

	createKey("Shift", 82)
	createKey("F", 50)

	--==================================================
	-- DISAPPEAR AFTER 5 SECONDS
	--==================================================

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

			elseif object:IsA("ImageLabel") then
				TweenService:Create(
					object,
					fadeInfo,
					{
						ImageTransparency = 1
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
		-- This allows full vertical 360° rotation.

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
