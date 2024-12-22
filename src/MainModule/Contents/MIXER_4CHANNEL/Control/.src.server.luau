math.randomseed(os.time())
local runService = game:GetService("RunService")

local Master = script.Parent
local DECK = Master.Parent

local Body = script.Parent.Body
local LEDS = script.Parent.LEDS
local INDICATORS = LEDS["VOLUME INDICATORS"]

local volumeMeter = script.Parent:WaitForChild("VolumeMeter")
local faderStatus = script.Parent:WaitForChild("FaderStatus")
local knobControl = script.Parent:WaitForChild("KnobControl")
local faderControl = script.Parent:WaitForChild("FaderControl")

local function mapNumber(l, inMin, inMax, outMin, outMax)
	if (inMax - inMin + outMin == 0) then return 0 end	
	return ((l - inMin) * (outMax - outMin)) / (inMax - inMin) + outMin
end

do
	local updateFPS = 1/20
	local updateCounter = 0
	local PeakHoldTime = 2

	local VUSize = 15
	local MaxSize = 100
	local LEVELTABS = {["CHANNEL1"] = {}, ["CHANNEL2"] = {}, ["CHANNEL3"] = {}, ["CHANNEL4"] = {}, ["MASTER1"] = {}, ["MASTER2"] = {}}

	local LEVELS = {0, 0, 0, 0}
	local PeakLevels = {0, 0, 0, 0, 0, 0}
	local PeakTimers = {0, 0, 0, 0, 0, 0}
	local masterDiv = {0, 0}

	local CHANNELS = {
		["CHANNEL1"] = INDICATORS["CHANNEL 1"],
		["CHANNEL2"] = INDICATORS["CHANNEL 2"],
		["CHANNEL3"] = INDICATORS["CHANNEL 3"],
		["CHANNEL4"] = INDICATORS["CHANNEL 4"],
		["MASTER1"] = INDICATORS["MASTER L"],
		["MASTER2"] = INDICATORS["MASTER R"]
	}

	for channelIndex = 1, 4 do
		for VUIndex = 1, VUSize do
			LEVELTABS[`CHANNEL{channelIndex}`][#LEVELTABS[`CHANNEL{channelIndex}`] + 1] = mapNumber(VUIndex, 1, VUSize, 0, MaxSize)
		end
	end		
	for channelIndex = 1, 2 do
		for VUIndex = 1, VUSize do
			LEVELTABS[`MASTER{channelIndex}`][#LEVELTABS[`MASTER{channelIndex}`] + 1] = mapNumber(VUIndex, 1, VUSize, 0, MaxSize)
		end
	end

	runService.Heartbeat:Connect(function(deltaTime)
		for channelIndex = 1, 4 do PeakTimers[channelIndex] += deltaTime end
		updateCounter += deltaTime

		if updateCounter >= updateFPS then
			updateCounter -= updateFPS

			local RANDOMS = {
				[1] = math.random(40, 90), [2] = math.random(40, 90),
				[3] = math.random(40, 90), [4] = math.random(40, 90)
			}

			for channelIndex = 1, 4 do
				local newLevel = RANDOMS[channelIndex]

				if (PeakTimers[channelIndex] >= PeakHoldTime) or (newLevel > PeakLevels[channelIndex]) then
					PeakLevels[channelIndex] = newLevel
					PeakTimers[channelIndex] = 0
				end

				for index = 1, VUSize do
					CHANNELS[`CHANNEL{channelIndex}`].LEDS[index].BackgroundTransparency = LEVELTABS[`CHANNEL{channelIndex}`][index] <= newLevel and 0 or 1		
					LEVELS[channelIndex] = CHANNELS[`CHANNEL{channelIndex}`].LEDS[index].Visible and newLevel or 0

					local correspondingIndex = math.floor(mapNumber(PeakLevels[channelIndex], 0, MaxSize, 1, VUSize))
					if index == correspondingIndex then
						CHANNELS[`CHANNEL{channelIndex}`].LEDS[index].BackgroundTransparency = 0
					end
				end
			end

			for channelIndex = 1, 2 do
				local newLevel = (LEVELS[1]+LEVELS[2]+LEVELS[3]+LEVELS[4]) / masterDiv[channelIndex]
				local masterIndex = channelIndex+4

				PeakTimers[masterIndex] += updateFPS
				if (PeakTimers[masterIndex] >= PeakHoldTime) or (newLevel > PeakLevels[masterIndex]) then
					PeakLevels[masterIndex] = newLevel
					PeakTimers[masterIndex] = 0
				end

				for index = 1, VUSize do
					CHANNELS[`MASTER{channelIndex}`].LEDS[index].BackgroundTransparency = LEVELTABS[`MASTER{channelIndex}`][index] < newLevel and 0 or 1

					local correspondingIndex = math.floor(mapNumber(PeakLevels[masterIndex], 0, MaxSize, 1, VUSize))
					if correspondingIndex == 1 then
						CHANNELS[`MASTER{channelIndex}`].LEDS[index].BackgroundTransparency = 1
					elseif index == correspondingIndex then
						CHANNELS[`MASTER{channelIndex}`].LEDS[index].BackgroundTransparency = 0
					end
				end
			end
		end
	end)

	task.spawn(function()
		while task.wait(.5) do
			for index = 1, #masterDiv do
				masterDiv[index] = math.random(30, 40) / 10
			end
		end
	end)

	volumeMeter.Event:Connect(function(channelNumber: number, isVisible: boolean)
		for index = 1, VUSize do
			CHANNELS[`CHANNEL{channelNumber}`].LEDS[index].Visible = isVisible
		end
	end)
end

do
	local loop
	local deb = false

	LEDS["BEAT FX INDICATOR"].ClickDetector.MouseClick:Connect(function()
		if not deb then
			loop = coroutine.wrap(function()
				while true do
					if not loop then break end
					LEDS["BEAT FX INDICATOR"].Color = Color3.fromRGB(60, 60, 60)
					task.wait(.25)
					LEDS["BEAT FX INDICATOR"].Color = Color3.fromRGB(74, 118, 166)
					task.wait(.25)
				end
			end) loop()
			deb = true
		elseif deb then
			loop = false
			deb = false
		end
	end)
end

do
	--weird debounce but its better than having debounce variables for each button
	LEDS["CUE CHANNEL 1"].ClickDetector.MouseClick:Connect(function()
		if LEDS["CUE CHANNEL 1"].Material == Enum.Material.SmoothPlastic then
			LEDS["CUE CHANNEL 1"].Material = Enum.Material.Neon
			LEDS["CUE CHANNEL 1"].Color = Color3.fromRGB(172, 125, 63)
		else
			LEDS["CUE CHANNEL 1"].Material = Enum.Material.SmoothPlastic
			LEDS["CUE CHANNEL 1"].Color = Color3.fromRGB(100, 100, 100)
		end
	end)
	LEDS["CUE CHANNEL 2"].ClickDetector.MouseClick:Connect(function()
		if LEDS["CUE CHANNEL 2"].Material == Enum.Material.SmoothPlastic then
			LEDS["CUE CHANNEL 2"].Material = Enum.Material.Neon
			LEDS["CUE CHANNEL 2"].Color = Color3.fromRGB(172, 125, 63)
		else
			LEDS["CUE CHANNEL 2"].Material = Enum.Material.SmoothPlastic
			LEDS["CUE CHANNEL 2"].Color = Color3.fromRGB(100, 100, 100)
		end
	end)
	LEDS["CUE CHANNEL 3"].ClickDetector.MouseClick:Connect(function()
		if LEDS["CUE CHANNEL 3"].Material == Enum.Material.SmoothPlastic then
			LEDS["CUE CHANNEL 3"].Material = Enum.Material.Neon
			LEDS["CUE CHANNEL 3"].Color = Color3.fromRGB(172, 125, 63)
		else
			LEDS["CUE CHANNEL 3"].Material = Enum.Material.SmoothPlastic
			LEDS["CUE CHANNEL 3"].Color = Color3.fromRGB(100, 100, 100)
		end
	end)
	LEDS["CUE CHANNEL 4"].ClickDetector.MouseClick:Connect(function()
		if LEDS["CUE CHANNEL 4"].Material == Enum.Material.SmoothPlastic then
			LEDS["CUE CHANNEL 4"].Material = Enum.Material.Neon
			LEDS["CUE CHANNEL 4"].Color = Color3.fromRGB(172, 125, 63)
		else
			LEDS["CUE CHANNEL 4"].Material = Enum.Material.SmoothPlastic
			LEDS["CUE CHANNEL 4"].Color = Color3.fromRGB(100, 100, 100)
		end
	end)

	LEDS["CUE MASTER"].ClickDetector.MouseClick:Connect(function()
		if LEDS["CUE MASTER"].Material == Enum.Material.SmoothPlastic then
			LEDS["CUE MASTER"].Material = Enum.Material.Neon
			LEDS["CUE MASTER"].Color = Color3.fromRGB(172, 125, 63)
		else
			LEDS["CUE MASTER"].Material = Enum.Material.SmoothPlastic
			LEDS["CUE MASTER"].Color = Color3.fromRGB(100, 100, 100)
		end
	end)
end

do
	LEDS["LOW"].ClickDetector.MouseClick:Connect(function()
		if LEDS["LOW"].Material == Enum.Material.SmoothPlastic then
			LEDS["LOW"].Material = Enum.Material.Neon
			LEDS["LOW"].Color = Color3.fromRGB(74, 118, 166)
		else
			LEDS["LOW"].Material = Enum.Material.SmoothPlastic
			LEDS["LOW"].Color = Color3.fromRGB(100, 100, 100)
		end
	end)
	LEDS["MID"].ClickDetector.MouseClick:Connect(function()
		if LEDS["MID"].Material == Enum.Material.SmoothPlastic then
			LEDS["MID"].Material = Enum.Material.Neon
			LEDS["MID"].Color = Color3.fromRGB(74, 118, 166)
		else
			LEDS["MID"].Material = Enum.Material.SmoothPlastic
			LEDS["MID"].Color = Color3.fromRGB(100, 100, 100)
		end
	end)
	LEDS["HI"].ClickDetector.MouseClick:Connect(function()
		if LEDS["HI"].Material == Enum.Material.SmoothPlastic then
			LEDS["HI"].Material = Enum.Material.Neon
			LEDS["HI"].Color = Color3.fromRGB(74, 118, 166)
		else
			LEDS["HI"].Material = Enum.Material.SmoothPlastic
			LEDS["HI"].Color = Color3.fromRGB(100, 100, 100)
		end
	end)
end

do
	local FXChannels = {[1]="BEAT FX CHANNEL 1",[2]="BEAT FX CHANNEL 2",[3]="BEAT FX CHANNEL 3",[4]="BEAT FX CHANNEL 4",[5]="BEAT FX MASTER"}
	local FXLabels = {[1]="DELAY",[2]="ECHO",[3]="PINGPONG",[4]="SPIRAL",[5]="REVERB",[6]="TRANS",[7]="FILTER",[8]="FLANGER",[9]="PHASER",[10]="PITCH",[11]="SLIPROLL",[12]="ROLL",[13]="VINYLBRAKE",[14]="HELIX"}

	knobControl.OnServerEvent:Connect(function(fromPlayer: Player, data: {index: number, knobType: number})
		if data.knobType == 1 then
			for _,buttonName in FXChannels do
				LEDS[buttonName].Material = Enum.Material.SmoothPlastic
				LEDS[buttonName].Color = Color3.fromRGB(100, 100, 100)
			end
			
			LEDS[FXChannels[data.index]].Material = Enum.Material.Neon
			LEDS[FXChannels[data.index]].Color = Color3.fromRGB(74, 118, 166)
		elseif data.knobType == 2 then
			local gui = LEDS["TOPSCREEN"].Screen.Background
			gui.CurrentFX.Text = FXLabels[data.index]
		end
	end)
end

do
	local faders = Body.faders

	faderControl.OnServerEvent:Connect(function(fromPlayer: Player, data: {fader: string, cframe: CFrame, canvasPos: number})
		local faderValue = 1000 - mapNumber(data.canvasPos, 0, 901, 0, 1000)
		local save = faders[data.fader].save
		local fader = faders[data.fader].fader

		fader.CFrame = save.CFrame * data.cframe
		local deckNumber = tonumber(string.match(data.fader, "%d+"))
		faderStatus:Fire(deckNumber-1, faderValue)
	end)
end

do
	local headphones = script.DJHeadphones
	script.Parent.Headphones.ClickDetector.MouseClick:Connect(function(player: Player)
		local character = player.Character

		if character:FindFirstChild(headphones.Name) then
			character[headphones.Name]:Destroy()
		else
			local clone = headphones:Clone()
			clone.Handle.Anchored = false
			character.Humanoid:AddAccessory(clone)
		end
	end)
end

do
	local CDJs = {}
	for _,model in DECK:GetChildren() do
		if model.Name:lower():find("cdj") then table.insert(CDJs, model) end
	end
		
	for _,CDJ in CDJs do
		if CDJ:GetAttribute("HasUSB") then
			CDJ.LEDS["LINK BUTTON"].Color = Color3.fromRGB(43, 89, 130)
			CDJ.LEDS["LINK BUTTON"].Material = Enum.Material.Neon
		end
	end
	
	task.spawn(function()
		while true do
			for _,CDJ in CDJs do
				if CDJ:GetAttribute("HasUSB") then
					CDJ.LEDS["USB LED"].Color = Color3.fromRGB(160, 160, 160)
					CDJ.LEDS["USB BUTTON"].Color = Color3.fromRGB(143, 170, 70)
					CDJ.LEDS["USB LED"].Material = Enum.Material.Neon
					CDJ.LEDS["USB BUTTON"].Material = Enum.Material.Neon
				end
			end
			task.wait(.5)
			for _,CDJ in CDJs do
				if CDJ:GetAttribute("HasUSB") then
					CDJ.LEDS["USB LED"].Color = Color3.fromRGB(100, 100, 100)
					CDJ.LEDS["USB BUTTON"].Color = Color3.fromRGB(100, 100, 100)
					CDJ.LEDS["USB LED"].Material = Enum.Material.SmoothPlastic
					CDJ.LEDS["USB BUTTON"].Material = Enum.Material.SmoothPlastic
				end
			end
			task.wait(.5)
		end
	end)
	
	task.spawn(function()
		while true do
			for _,CDJ in CDJs do
				if not CDJ:GetAttribute("HasUSB") then
					CDJ.LEDS["LINK BUTTON"].Color = Color3.fromRGB(57, 115, 170)
					CDJ.LEDS["LINK BUTTON"].Material = Enum.Material.Neon
				end
			end
			task.wait(.5)
			for _,CDJ in CDJs do
				if not CDJ:GetAttribute("HasUSB") then
					CDJ.LEDS["LINK BUTTON"].Color = Color3.fromRGB(100, 100, 100)
					CDJ.LEDS["LINK BUTTON"].Material = Enum.Material.SmoothPlastic
				end
			end
			task.wait(.5)
		end
	end)
end

task.spawn(function()
	while true do
		LEDS["COLOR FX FILTER"].Color = Color3.fromRGB(170, 170, 170)
		task.wait(.25)
		LEDS["COLOR FX FILTER"].Color = Color3.fromRGB(85, 85, 85)
		task.wait(.25)
	end
end)

print(`mixer init`)