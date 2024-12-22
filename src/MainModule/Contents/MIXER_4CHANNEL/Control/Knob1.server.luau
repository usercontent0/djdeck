local uis = game:GetService("UserInputService")
local master = script:FindFirstAncestor("mixer")
local knob = master.LEDS["BEATFX CHANNEL SELECTION KNOB"]
local gui = knob.Screen

local knobControl = master:WaitForChild("KnobControl")
local camera = workspace.CurrentCamera

local angles = {-151, -172, 167, 147, 124}
local angleIndex = 1
local range = 2

local dragging = false

local function onMouseMove(input: InputObject)
	local knobPosition = camera:WorldToScreenPoint(knob.CFrame.Position)
	local distance = (knobPosition.Y - input.Position.Y) / #angles
	angleIndex = math.floor(distance / range) + #angles
	
	knob.Orientation = Vector3.new(0, angles[math.clamp(angleIndex, 1, #angles)], 0)
end

uis.InputChanged:Connect(function(input)
	if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
		onMouseMove(input)
	end
end)

gui.Frame.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = true
		
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				dragging = false
				knobControl:FireServer({
					index = math.clamp(angleIndex, 1, #angles),
					knobType = 1
				})
			end
		end)
	end
end)