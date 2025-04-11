math.randomseed(os.time())
local runService = game:GetService("RunService")

local Master = script.Parent
local DECK = Master.Parent

local isRMX = Master:GetAttribute("isRMX")
local Body = script.Parent.Body
local LEDS = script.Parent.LEDS
local INDICATORS = LEDS["VOLUME INDICATORS"]

local volumeMeter = script.Parent:WaitForChild("VolumeMeter")
local faderStatus = script.Parent:WaitForChild("FaderStatus")
local knobControl = script.Parent:WaitForChild("KnobControl")
local faderControl = script.Parent:WaitForChild("FaderControl")

local RMX, LEDS_RMX, INDICATORS_RMX
if isRMX then
	RMX = DECK:FindFirstChild("rmx").Machine
	LEDS_RMX = RMX.LEDS
	INDICATORS_RMX = LEDS_RMX["VOLUME INDICATORS"]
end

local function mapNumber(l, inMin, inMax, outMin, outMax)
	if (inMax - inMin + outMin == 0) then return 0 end	
	return ((l - inMin) * (outMax - outMin)) / (inMax - inMin) + outMin
end

local function getRandomAudioPeak(minDb, maxDb)
	local db = minDb + math.random() * (maxDb - minDb)
	return math.floor(100 * 10^(db / 20))
end

do
	local updateFPS = 1/20
	local updateCounter = 0
	local PeakHoldTime = 2
	local DecayRate, ExpFactor = 5, 1

	local VUSize, MaxSize = 15, 100
	local LEVELTABS = {["CHANNEL1"] = {}, ["CHANNEL2"] = {}, ["CHANNEL3"] = {}, ["CHANNEL4"] = {}, ["CHANNEL5"] = {}, ["CHANNEL6"] = {}, ["MASTER1"] = {}, ["MASTER2"] = {}}
	
	local LEVELS = {0, 0, 0, 0, 0, 0}
	local ChannelActive = {false, false, false, false}
	local PeakLevels = {0, 0, 0, 0, 0, 0, 0, 0}
	local PeakTimers = {0, 0, 0, 0, 0, 0, 0, 0}
	local masterDiv = {0, 0}
	
	local CHANNELS = {
		["CHANNEL1"] = INDICATORS["CHANNEL 1"],
		["CHANNEL2"] = INDICATORS["CHANNEL 2"],
		["CHANNEL3"] = INDICATORS["CHANNEL 3"],
		["CHANNEL4"] = INDICATORS["CHANNEL 4"],
		["CHANNEL5"] = INDICATORS["CHANNEL 5"],
		["CHANNEL6"] = INDICATORS["CHANNEL 6"],
		["MASTER1"] = INDICATORS["MASTER L"],
		["MASTER2"] = INDICATORS["MASTER R"]
	}

	local LEVELTABS_RMX, CHANNELS_RMX
	local PeakLevel_RMX = 0
	local PeakTimer_RMX = 0

	if isRMX then
		LEVELTABS_RMX = {["INPUT"] = {}, ["OUTPUT"] = {}}
		CHANNELS_RMX = {["INPUT"] = INDICATORS_RMX["INPUT"], ["OUTPUT"] = INDICATORS_RMX["OUTPUT"]}

		for _,lvlTab in LEVELTABS_RMX do
			for VUIndex = 1, 11 do
				table.insert(lvlTab, mapNumber(VUIndex, 1, 11, 0, MaxSize))
			end
		end
	end

	local function fillLevelTabs(t)
		for _,channel in t do
			for vuIndex = 1, VUSize do
				table.insert(LEVELTABS[channel], mapNumber(vuIndex, 1, VUSize, 0, MaxSize))
			end
		end
	end
	
	fillLevelTabs({"CHANNEL1", "CHANNEL2", "CHANNEL3", "CHANNEL4", "CHANNEL5", "CHANNEL6"})
	fillLevelTabs({"MASTER1", "MASTER2"})
	
	for _,channel in CHANNELS do
		for _,led in channel.LEDS:GetChildren() do led.Visible = true end
	end

	runService.Heartbeat:Connect(function(deltaTime)
		for index = 1, 8 do PeakTimers[index] += deltaTime end
		updateCounter += deltaTime
		
		if updateCounter >= updateFPS then
			updateCounter -= updateFPS
			
			local RANDOMS = {}
			for index = 1, 6 do RANDOMS[index] = ChannelActive[index] and getRandomAudioPeak(-6, -1) or 0 end

			for channel = 1, 6 do
				local newLevel = RANDOMS[channel]

				PeakTimers[channel] += updateFPS
				if (PeakTimers[channel] >= PeakHoldTime) or (newLevel > PeakLevels[channel]) then
					PeakLevels[channel], PeakTimers[channel] = newLevel, 0
				end

				if newLevel < 5 then
					local currentDecay = DecayRate * (PeakLevels[channel] ^ ExpFactor)
					PeakLevels[channel] = math.max(PeakLevels[channel] - (currentDecay*deltaTime), 0)
				end
				
				local peakIndex = math.floor(mapNumber(PeakLevels[channel], 0, MaxSize, 1, VUSize))
				for vuIndex = 1, VUSize do
					CHANNELS["CHANNEL"..channel].LEDS[vuIndex].BackgroundTransparency = 
						(LEVELTABS["CHANNEL"..channel][vuIndex] < newLevel
						or (peakIndex > 1 and vuIndex == peakIndex)) and 0 or 1

					LEVELS[channel] = ChannelActive[channel] and newLevel or 0
				end
			end

			for channel = 1, 2 do
				local newLevel = (LEVELS[1] + LEVELS[2] + LEVELS[3] + LEVELS[4] + LEVELS[5] + LEVELS[6]) / masterDiv[channel]
				local masterIndex = channel + 6

				PeakTimers[masterIndex] += updateFPS
				if (PeakTimers[masterIndex] >= PeakHoldTime) or (newLevel > PeakLevels[masterIndex]) then
					PeakLevels[masterIndex], PeakTimers[masterIndex] = newLevel, 0		
				end

				if newLevel < 5 then
					local currentDecay = DecayRate * (PeakLevels[masterIndex] ^ ExpFactor)
					PeakLevels[masterIndex] = math.max(PeakLevels[masterIndex] - (currentDecay*deltaTime), 0)
				end

				local peakIndex = math.floor(mapNumber(PeakLevels[masterIndex], 0, MaxSize, 1, VUSize))
				for vuIndex = 1, VUSize do
					CHANNELS["MASTER"..channel].LEDS[vuIndex].BackgroundTransparency = 
        			(LEVELTABS["MASTER"..channel][vuIndex] < newLevel
					or (peakIndex > 1 and vuIndex == peakIndex)) and 0 or 1
				end
			end

			if not isRMX then return end
			for name, channel in CHANNELS_RMX do
				local newLevel = (LEVELS[1] + LEVELS[2] + LEVELS[3] + LEVELS[4] + LEVELS[5] + LEVELS[6]) / 2

				PeakTimer_RMX += updateFPS
				if (PeakTimer_RMX >= PeakHoldTime) or (newLevel > PeakLevel_RMX) then
					PeakLevel_RMX, PeakTimer_RMX = newLevel, 0	
				end

				if newLevel < 5 then
					local currentDecay = DecayRate * (PeakLevel_RMX ^ ExpFactor)
					PeakLevel_RMX = math.max(PeakLevel_RMX - (currentDecay*deltaTime), 0)
				end

				local peakIndex = math.floor(mapNumber(PeakLevel_RMX, 0, MaxSize, 1, 11))
				for vuIndex = 1, 11 do
					channel.LEDS[vuIndex].ImageTransparency =
						(LEVELTABS_RMX[name][vuIndex] < newLevel
						or (peakIndex > 1 and vuIndex == peakIndex)) and 0 or 1
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
		ChannelActive[channelNumber] = isVisible
	end)
end

do
	local loop
	local deb = false
	local beatFXbutton = nil
	
	local blacklistedButtons = {
		["BEAT FX INDICATOR"] = true,
		["BEAT FX MIC"] = true
	}
	
	local function turnOffAllButtons()
		for _,button in LEDS:GetChildren() do
			if button.Name:find("BEAT FX") and not blacklistedButtons[button.Name] then
				button.Color = Color3.fromRGB(100, 100, 100)
				button.Material = Enum.Material.Plastic
			end
		end
	end
	
	LEDS["BEAT FX CHANNEL 1"].ClickDetector.MouseClick:Connect(function()
		turnOffAllButtons()
		beatFXbutton = LEDS["BEAT FX CHANNEL 1"]
		beatFXbutton.Color = Color3.fromRGB(155, 82, 82)
		beatFXbutton.Material = Enum.Material.Neon
	end)
	LEDS["BEAT FX CHANNEL 2"].ClickDetector.MouseClick:Connect(function()
		turnOffAllButtons()
		beatFXbutton = LEDS["BEAT FX CHANNEL 2"]
		beatFXbutton.Color = Color3.fromRGB(155, 82, 82)
		beatFXbutton.Material = Enum.Material.Neon
	end)
	LEDS["BEAT FX CHANNEL 3"].ClickDetector.MouseClick:Connect(function()
		turnOffAllButtons()
		beatFXbutton = LEDS["BEAT FX CHANNEL 3"]
		beatFXbutton.Color = Color3.fromRGB(155, 82, 82)
		beatFXbutton.Material = Enum.Material.Neon
	end)
	LEDS["BEAT FX CHANNEL 4"].ClickDetector.MouseClick:Connect(function()
		turnOffAllButtons()
		beatFXbutton = LEDS["BEAT FX CHANNEL 4"]
		beatFXbutton.Color = Color3.fromRGB(155, 82, 82)
		beatFXbutton.Material = Enum.Material.Neon
	end)
	LEDS["BEAT FX CHANNEL 5"].ClickDetector.MouseClick:Connect(function()
		turnOffAllButtons()
		beatFXbutton = LEDS["BEAT FX CHANNEL 5"]
		beatFXbutton.Color = Color3.fromRGB(155, 82, 82)
		beatFXbutton.Material = Enum.Material.Neon
	end)
	LEDS["BEAT FX CHANNEL 6"].ClickDetector.MouseClick:Connect(function()
		turnOffAllButtons()
		beatFXbutton = LEDS["BEAT FX CHANNEL 6"]
		beatFXbutton.Color = Color3.fromRGB(155, 82, 82)
		beatFXbutton.Material = Enum.Material.Neon
	end)
	LEDS["BEAT FX MASTER"].ClickDetector.MouseClick:Connect(function()
		turnOffAllButtons()
		beatFXbutton = LEDS["BEAT FX MASTER"]
		beatFXbutton.Color = Color3.fromRGB(155, 82, 82)
		beatFXbutton.Material = Enum.Material.Neon
	end)

	LEDS["BEAT FX INDICATOR"].ClickDetector.MouseClick:Connect(function()		
		if not deb then
			loop = coroutine.wrap(function()
				while true do
					if not loop then break end
					LEDS["BEAT FX INDICATOR"].Color = Color3.fromRGB(100, 100, 100)
					LEDS["BEAT FX INDICATOR"].Material = Enum.Material.Plastic
					beatFXbutton.Color = Color3.fromRGB(100, 100, 100)
					beatFXbutton.Material = Enum.Material.Plastic
					task.wait(.25)
					LEDS["BEAT FX INDICATOR"].Color = Color3.fromRGB(155, 82, 82)
					LEDS["BEAT FX INDICATOR"].Material = Enum.Material.Neon
					beatFXbutton.Color = Color3.fromRGB(155, 82, 82)
					beatFXbutton.Material = Enum.Material.Neon
					task.wait(.25)
				end
			end); loop()
			deb = true
		elseif deb then
			loop = false
			deb = false
		end
	end)
end

do
	--weird debounce but its better than having debounce variables for each button
	LEDS["CUE A CHANNEL 1"].ClickDetector.MouseClick:Connect(function()
		if LEDS["CUE A CHANNEL 1"].Material == Enum.Material.Plastic then
			LEDS["CUE A CHANNEL 1"].Material = Enum.Material.Neon
			LEDS["CUE A CHANNEL 1"].Color = Color3.fromRGB(172, 125, 63)
		else
			LEDS["CUE A CHANNEL 1"].Material = Enum.Material.Plastic
			LEDS["CUE A CHANNEL 1"].Color = Color3.fromRGB(100, 100, 100)
		end
	end)
	LEDS["CUE A CHANNEL 2"].ClickDetector.MouseClick:Connect(function()
		if LEDS["CUE A CHANNEL 2"].Material == Enum.Material.Plastic then
			LEDS["CUE A CHANNEL 2"].Material = Enum.Material.Neon
			LEDS["CUE A CHANNEL 2"].Color = Color3.fromRGB(172, 125, 63)
		else
			LEDS["CUE A CHANNEL 2"].Material = Enum.Material.Plastic
			LEDS["CUE A CHANNEL 2"].Color = Color3.fromRGB(100, 100, 100)
		end
	end)
	LEDS["CUE A CHANNEL 3"].ClickDetector.MouseClick:Connect(function()
		if LEDS["CUE A CHANNEL 3"].Material == Enum.Material.Plastic then
			LEDS["CUE A CHANNEL 3"].Material = Enum.Material.Neon
			LEDS["CUE A CHANNEL 3"].Color = Color3.fromRGB(172, 125, 63)
		else
			LEDS["CUE A CHANNEL 3"].Material = Enum.Material.Plastic
			LEDS["CUE A CHANNEL 3"].Color = Color3.fromRGB(100, 100, 100)
		end
	end)
	LEDS["CUE A CHANNEL 4"].ClickDetector.MouseClick:Connect(function()
		if LEDS["CUE A CHANNEL 4"].Material == Enum.Material.Plastic then
			LEDS["CUE A CHANNEL 4"].Material = Enum.Material.Neon
			LEDS["CUE A CHANNEL 4"].Color = Color3.fromRGB(172, 125, 63)
		else
			LEDS["CUE A CHANNEL 4"].Material = Enum.Material.Plastic
			LEDS["CUE A CHANNEL 4"].Color = Color3.fromRGB(100, 100, 100)
		end
	end)
	LEDS["CUE A CHANNEL 5"].ClickDetector.MouseClick:Connect(function()
		if LEDS["CUE A CHANNEL 5"].Material == Enum.Material.Plastic then
			LEDS["CUE A CHANNEL 5"].Material = Enum.Material.Neon
			LEDS["CUE A CHANNEL 5"].Color = Color3.fromRGB(172, 125, 63)
		else
			LEDS["CUE A CHANNEL 5"].Material = Enum.Material.Plastic
			LEDS["CUE A CHANNEL 5"].Color = Color3.fromRGB(100, 100, 100)
		end
	end)
	LEDS["CUE A CHANNEL 6"].ClickDetector.MouseClick:Connect(function()
		if LEDS["CUE A CHANNEL 6"].Material == Enum.Material.Plastic then
			LEDS["CUE A CHANNEL 6"].Material = Enum.Material.Neon
			LEDS["CUE A CHANNEL 6"].Color = Color3.fromRGB(172, 125, 63)
		else
			LEDS["CUE A CHANNEL 6"].Material = Enum.Material.Plastic
			LEDS["CUE A CHANNEL 6"].Color = Color3.fromRGB(100, 100, 100)
		end
	end)

	LEDS["CUE A MASTER"].ClickDetector.MouseClick:Connect(function()
		if LEDS["CUE A MASTER"].Material == Enum.Material.Plastic then
			LEDS["CUE A MASTER"].Material = Enum.Material.Neon
			LEDS["CUE A MASTER"].Color = Color3.fromRGB(172, 125, 63)
		else
			LEDS["CUE A MASTER"].Material = Enum.Material.Plastic
			LEDS["CUE A MASTER"].Color = Color3.fromRGB(100, 100, 100)
		end
	end)
end

do
	LEDS["DOT B CHANNEL 1"].ClickDetector.MouseClick:Connect(function()
		if LEDS["DOT B CHANNEL 1"].Material == Enum.Material.Plastic then
			LEDS["DOT B CHANNEL 1"].Material = Enum.Material.Neon
			LEDS["DOT B CHANNEL 1"].Color = Color3.fromRGB(172, 125, 63)
		else
			LEDS["DOT B CHANNEL 1"].Material = Enum.Material.Plastic
			LEDS["DOT B CHANNEL 1"].Color = Color3.fromRGB(100, 100, 100)
		end
	end)
	LEDS["DOT B CHANNEL 2"].ClickDetector.MouseClick:Connect(function()
		if LEDS["DOT B CHANNEL 2"].Material == Enum.Material.Plastic then
			LEDS["DOT B CHANNEL 2"].Material = Enum.Material.Neon
			LEDS["DOT B CHANNEL 2"].Color = Color3.fromRGB(172, 125, 63)
		else
			LEDS["DOT B CHANNEL 2"].Material = Enum.Material.Plastic
			LEDS["DOT B CHANNEL 2"].Color = Color3.fromRGB(100, 100, 100)
		end
	end)
	LEDS["DOT B CHANNEL 3"].ClickDetector.MouseClick:Connect(function()
		if LEDS["DOT B CHANNEL 3"].Material == Enum.Material.Plastic then
			LEDS["DOT B CHANNEL 3"].Material = Enum.Material.Neon
			LEDS["DOT B CHANNEL 3"].Color = Color3.fromRGB(172, 125, 63)
		else
			LEDS["DOT B CHANNEL 3"].Material = Enum.Material.Plastic
			LEDS["DOT B CHANNEL 3"].Color = Color3.fromRGB(100, 100, 100)
		end
	end)
	LEDS["DOT B CHANNEL 4"].ClickDetector.MouseClick:Connect(function()
		if LEDS["DOT B CHANNEL 4"].Material == Enum.Material.Plastic then
			LEDS["DOT B CHANNEL 4"].Material = Enum.Material.Neon
			LEDS["DOT B CHANNEL 4"].Color = Color3.fromRGB(172, 125, 63)
		else
			LEDS["DOT B CHANNEL 4"].Material = Enum.Material.Plastic
			LEDS["DOT B CHANNEL 4"].Color = Color3.fromRGB(100, 100, 100)
		end
	end)
	LEDS["DOT B CHANNEL 5"].ClickDetector.MouseClick:Connect(function()
		if LEDS["DOT B CHANNEL 5"].Material == Enum.Material.Plastic then
			LEDS["DOT B CHANNEL 5"].Material = Enum.Material.Neon
			LEDS["DOT B CHANNEL 5"].Color = Color3.fromRGB(172, 125, 63)
		else
			LEDS["DOT B CHANNEL 5"].Material = Enum.Material.Plastic
			LEDS["DOT B CHANNEL 5"].Color = Color3.fromRGB(100, 100, 100)
		end
	end)
	LEDS["DOT B CHANNEL 6"].ClickDetector.MouseClick:Connect(function()
		if LEDS["DOT B CHANNEL 6"].Material == Enum.Material.Plastic then
			LEDS["DOT B CHANNEL 6"].Material = Enum.Material.Neon
			LEDS["DOT B CHANNEL 6"].Color = Color3.fromRGB(172, 125, 63)
		else
			LEDS["DOT B CHANNEL 6"].Material = Enum.Material.Plastic
			LEDS["DOT B CHANNEL 6"].Color = Color3.fromRGB(100, 100, 100)
		end
	end)

	LEDS["DOT B MASTER"].ClickDetector.MouseClick:Connect(function()
		if LEDS["DOT B MASTER"].Material == Enum.Material.Plastic then
			LEDS["DOT B MASTER"].Material = Enum.Material.Neon
			LEDS["DOT B MASTER"].Color = Color3.fromRGB(172, 125, 63)
		else
			LEDS["DOT B MASTER"].Material = Enum.Material.Plastic
			LEDS["DOT B MASTER"].Color = Color3.fromRGB(100, 100, 100)
		end
	end)
end

do
	LEDS["HEADPHONES A LINK CUE"].ClickDetector.MouseClick:Connect(function()
		if LEDS["HEADPHONES A LINK CUE"].Material == Enum.Material.Plastic then
			LEDS["HEADPHONES A LINK CUE"].Material = Enum.Material.Neon
			LEDS["HEADPHONES A LINK CUE"].Color = Color3.fromRGB(172, 125, 63)
		else
			LEDS["HEADPHONES A LINK CUE"].Material = Enum.Material.Plastic
			LEDS["HEADPHONES A LINK CUE"].Color = Color3.fromRGB(100, 100, 100)
		end
	end)
	LEDS["HEADPHONES A MONO SPLIT"].ClickDetector.MouseClick:Connect(function()
		if LEDS["HEADPHONES A MONO SPLIT"].Material == Enum.Material.Plastic then
			LEDS["HEADPHONES A MONO SPLIT"].Material = Enum.Material.Neon
			LEDS["HEADPHONES A MONO SPLIT"].Color = Color3.fromRGB(172, 125, 63)
		else
			LEDS["HEADPHONES A MONO SPLIT"].Material = Enum.Material.Plastic
			LEDS["HEADPHONES A MONO SPLIT"].Color = Color3.fromRGB(100, 100, 100)
		end
	end)
	LEDS["HEADPHONES A PRE EQ"].ClickDetector.MouseClick:Connect(function()
		if LEDS["HEADPHONES A PRE EQ"].Material == Enum.Material.Plastic then
			LEDS["HEADPHONES A PRE EQ"].Material = Enum.Material.Neon
			LEDS["HEADPHONES A PRE EQ"].Color = Color3.fromRGB(172, 125, 63)
		else
			LEDS["HEADPHONES A PRE EQ"].Material = Enum.Material.Plastic
			LEDS["HEADPHONES A PRE EQ"].Color = Color3.fromRGB(100, 100, 100)
		end
	end)
	LEDS["HEADPHONES B LINK CUE"].ClickDetector.MouseClick:Connect(function()
		if LEDS["HEADPHONES B LINK CUE"].Material == Enum.Material.Plastic then
			LEDS["HEADPHONES B LINK CUE"].Material = Enum.Material.Neon
			LEDS["HEADPHONES B LINK CUE"].Color = Color3.fromRGB(172, 125, 63)
		else
			LEDS["HEADPHONES B LINK CUE"].Material = Enum.Material.Plastic
			LEDS["HEADPHONES B LINK CUE"].Color = Color3.fromRGB(100, 100, 100)
		end
	end)
end

do
	LEDS["LOW"].ClickDetector.MouseClick:Connect(function()
		if LEDS["LOW"].Material == Enum.Material.Plastic then
			LEDS["LOW"].Material = Enum.Material.Neon
			LEDS["LOW"].Color = Color3.fromRGB(155, 82, 82)
		else
			LEDS["LOW"].Material = Enum.Material.Plastic
			LEDS["LOW"].Color = Color3.fromRGB(100, 100, 100)
		end
	end)
	LEDS["MID"].ClickDetector.MouseClick:Connect(function()
		if LEDS["MID"].Material == Enum.Material.Plastic then
			LEDS["MID"].Material = Enum.Material.Neon
			LEDS["MID"].Color = Color3.fromRGB(155, 82, 82)
		else
			LEDS["MID"].Material = Enum.Material.Plastic
			LEDS["MID"].Color = Color3.fromRGB(100, 100, 100)
		end
	end)
	LEDS["HI"].ClickDetector.MouseClick:Connect(function()
		if LEDS["HI"].Material == Enum.Material.Plastic then
			LEDS["HI"].Material = Enum.Material.Neon
			LEDS["HI"].Color = Color3.fromRGB(155, 82, 82)
		else
			LEDS["HI"].Material = Enum.Material.Plastic
			LEDS["HI"].Color = Color3.fromRGB(100, 100, 100)
		end
	end)
end

do
	local passFilterButton = nil
	
	task.spawn(function()
		while true do
			if passFilterButton then
				passFilterButton.Color = Color3.fromRGB(100, 100, 100)
				passFilterButton.Material = Enum.Material.Plastic
			end
			task.wait(.25)
			if passFilterButton then
				passFilterButton.Color = Color3.fromRGB(160, 160, 160)
				passFilterButton.Material = Enum.Material.Neon
			end
			task.wait(.25)
		end
	end)
	
	LEDS["LOW PASS FILTER"].ClickDetector.MouseClick:Connect(function()
		if passFilterButton == LEDS["LOW PASS FILTER"] then
			local saved = passFilterButton
			passFilterButton = nil
			saved.Color = Color3.fromRGB(160, 160, 160)
			saved.Material = Enum.Material.Neon
		else
			passFilterButton = LEDS["LOW PASS FILTER"]
			LEDS["HIGH PASS FILTER"].Color = Color3.fromRGB(160, 160, 160)
			LEDS["HIGH PASS FILTER"].Material = Enum.Material.Neon
		end	
	end)

	LEDS["HIGH PASS FILTER"].ClickDetector.MouseClick:Connect(function()
		if passFilterButton == LEDS["HIGH PASS FILTER"] then
			local saved = passFilterButton
			passFilterButton = nil
			saved.Color = Color3.fromRGB(160, 160, 160)
			saved.Material = Enum.Material.Neon
		else
			passFilterButton = LEDS["HIGH PASS FILTER"]
			LEDS["LOW PASS FILTER"].Color = Color3.fromRGB(160, 160, 160)
			LEDS["LOW PASS FILTER"].Material = Enum.Material.Neon
		end	
	end)
end

do
	local extButton = nil
	local sendButton = nil
	local whitelistedButtons = {
		["SEND SHORT DELAY"] = true,
		["SEND LONG DELAY"] = true,
		["SEND DUB ECHO"] = true,
		["SEND REVERB"] = true,
	}
	
	local function turnOnAllButtons(fromButton: string)
		for _,button in LEDS:GetChildren() do
			if button.Name ~= fromButton and whitelistedButtons[button.Name] then
				button.Color = Color3.fromRGB(160, 160, 160)
				button.Material = Enum.Material.Neon
			end
		end
	end
	
	task.spawn(function()
		while true do
			if sendButton then
				sendButton.Color = Color3.fromRGB(100, 100, 100)
				sendButton.Material = Enum.Material.Plastic
			end
			if extButton then
				extButton.Color = Color3.fromRGB(100, 100, 100)
				extButton.Material = Enum.Material.Plastic
			end
			task.wait(.25)
			if sendButton then
				sendButton.Color = Color3.fromRGB(160, 160, 160)
				sendButton.Material = Enum.Material.Neon
			end
			if extButton then
				extButton.Color = Color3.fromRGB(160, 160, 160)
				extButton.Material = Enum.Material.Neon
			end
			task.wait(.25)
		end
	end)
	
	LEDS["SEND EXT 1"].ClickDetector.MouseClick:Connect(function()
		if extButton == LEDS["SEND EXT 1"] then
			local saved = extButton
			extButton = nil
			saved.Color = Color3.fromRGB(160, 160, 160)
			saved.Material = Enum.Material.Neon
		else
			extButton = LEDS["SEND EXT 1"]
			LEDS["SEND EXT 2"].Color = Color3.fromRGB(160, 160, 160)
			LEDS["SEND EXT 2"].Material = Enum.Material.Neon
		end	
	end)
	
	LEDS["SEND EXT 2"].ClickDetector.MouseClick:Connect(function()
		if extButton == LEDS["SEND EXT 2"] then
			local saved = extButton
			extButton = nil
			saved.Color = Color3.fromRGB(160, 160, 160)
			saved.Material = Enum.Material.Neon
		else
			extButton = LEDS["SEND EXT 2"]
			LEDS["SEND EXT 1"].Color = Color3.fromRGB(160, 160, 160)
			LEDS["SEND EXT 1"].Material = Enum.Material.Neon
		end	
	end)

	for sendFx,_ in whitelistedButtons do
		LEDS[sendFx].ClickDetector.MouseClick:Connect(function()
			if sendButton == LEDS[sendFx] then
				local saved = sendButton
				sendButton = nil
				saved.Color = Color3.fromRGB(170, 170, 170)
			else
				sendButton = LEDS[sendFx]
				turnOnAllButtons(sendButton.Name)
			end
		end)
	end
end

do
	local FXLabels = {[1]="DELAY",[2]="ECHO",[3]="PINGPONG",[4]="SPIRAL",[5]="HELIX",[6]="REVERB",[7]="SHIMMER",[8]="FLANGER",[9]="PHASER",[10]="FILTER",[11]="TRANS",[12]="ROLL",[13]="PITCH",[14]="VINYLBRAKE"}

	knobControl.OnServerEvent:Connect(function(fromPlayer: Player, data: {index: number, knobType: number})
		if data.knobType == 1 then
			local gui = LEDS["SCREEN"].Screen
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

do
	if not isRMX then return end
	task.spawn(function()
		while true do
			LEDS_RMX["BPM"].Transparency = 1
			task.wait(.25)
			LEDS_RMX["BPM"].Transparency = 0
			task.wait(.25)
		end
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


print(`mixer init ({Master:GetAttribute("ChannelCount")} channel ver)`)