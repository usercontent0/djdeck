math.randomseed(os.time())
local runService = game:GetService("RunService")

local Master = script.Parent
local DECK = Master.Parent

local Body = script.Parent.Body
local LEDS = script.Parent.LEDS
local INDICATORS = LEDS["VOLUME INDICATORS"]

local volumeMeter = script.Parent:WaitForChild("VolumeMeter")
local faderStatus = script.Parent:WaitForChild("FaderStatus")
local faderControl = script.Parent:WaitForChild("FaderControl")

local function mapNumber(l, inMin, inMax, outMin, outMax)
	if (inMax - inMin + outMin == 0) then return 0 end	
	return ((l - inMin) * (outMax - outMin)) / (inMax - inMin) + outMin
end

local vuColors = {
	standard = {
		[1] = Color3.fromRGB(58, 160, 92),
		[2] = Color3.fromRGB(58, 160, 92),
		[3] = Color3.fromRGB(58, 160, 92),
		[4] = Color3.fromRGB(58, 160, 92),
		[5] = Color3.fromRGB(58, 160, 92),
		[6] = Color3.fromRGB(80, 116, 165),
		[7] = Color3.fromRGB(80, 116, 165),
		[8] = Color3.fromRGB(80, 116, 165),
		[9] = Color3.fromRGB(165, 0, 74),
	},
	master = {
		[1] = Color3.fromRGB(58, 160, 92),
		[2] = Color3.fromRGB(58, 160, 92),
		[3] = Color3.fromRGB(58, 160, 92),
		[4] = Color3.fromRGB(58, 160, 92),
		[5] = Color3.fromRGB(58, 160, 92),
		[6] = Color3.fromRGB(58, 160, 92),
		[7] = Color3.fromRGB(58, 160, 92),
		[8] = Color3.fromRGB(80, 116, 165),
		[9] = Color3.fromRGB(80, 116, 165),
		[10] = Color3.fromRGB(80, 116, 165),
		[11] = Color3.fromRGB(165, 0, 74),
	}
}

do
	local updateFPS = 1/20
	local updateCounter = 0
	local PeakHoldTime = 2

	local VUSize = 9
	local VUSizeMaster = 11
	local MaxSize = 100
	local LEVELTABS = {["CHANNEL1"] = {}, ["CHANNEL2"] = {}, ["CHANNEL3"] = {}, ["CHANNEL4"] = {}, ["MASTER1"] = {}, ["MASTER2"] = {}}

	local LEVELS = {0, 0, 0, 0}
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
		for VUIndex = 1, VUSizeMaster do
			LEVELTABS[`MASTER{channelIndex}`][#LEVELTABS[`MASTER{channelIndex}`] + 1] = mapNumber(VUIndex, 1, VUSizeMaster, 0, MaxSize)
		end
	end
	
	runService.Heartbeat:Connect(function(deltaTime)
		updateCounter += deltaTime

		if updateCounter >= updateFPS then
			updateCounter -= updateFPS

			local RANDOMS = {
				[1] = math.random(40, 90), [2] = math.random(40, 90),
				[3] = math.random(40, 90), [4] = math.random(40, 90)
			}

			for channelIndex = 1, 4 do
				local newLevel = RANDOMS[channelIndex]

				for index = 1, VUSize do
					CHANNELS[`CHANNEL{channelIndex}`][index].Color = LEVELTABS[`CHANNEL{channelIndex}`][index] <= newLevel and vuColors.standard[index] or Color3.new(0, 0, 0)	
					LEVELS[channelIndex] = CHANNELS[`CHANNEL{channelIndex}`][index].Transparency == 0 and newLevel or 0
				end
			end

			for channelIndex = 1, 2 do
				local newLevel = (LEVELS[1]+LEVELS[2]+LEVELS[3]+LEVELS[4]) / masterDiv[channelIndex]
				local masterIndex = channelIndex+4

				for index = 1, VUSizeMaster do
					CHANNELS[`MASTER{channelIndex}`][index].Color = LEVELTABS[`MASTER{channelIndex}`][index] < newLevel and vuColors.master[index] or Color3.new(0, 0, 0)
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
			CHANNELS[`CHANNEL{channelNumber}`][index].Transparency = isVisible and 0 or 1
		end
	end)
end

do
	LEDS["FILTER 1"].ClickDetector.MouseClick:Connect(function()
		if LEDS["FILTER TOGGLE LED RINGS"]["1"].Color == Color3.fromRGB(0, 0, 0) then
			LEDS["FILTER TOGGLE LED RINGS"]["1"].Color = Color3.fromRGB(13, 105, 172)
		else
			LEDS["FILTER TOGGLE LED RINGS"]["1"].Color = Color3.fromRGB(0, 0, 0)
		end
	end)
	LEDS["FILTER 2"].ClickDetector.MouseClick:Connect(function()
		if LEDS["FILTER TOGGLE LED RINGS"]["2"].Color == Color3.fromRGB(0, 0, 0) then
			LEDS["FILTER TOGGLE LED RINGS"]["2"].Color = Color3.fromRGB(13, 105, 172)
		else
			LEDS["FILTER TOGGLE LED RINGS"]["2"].Color = Color3.fromRGB(0, 0, 0)
		end
	end)
end

do
	LEDS["FILTER 1 HPF"].ClickDetector.MouseClick:Connect(function()
		LEDS["FILTER LED RINGS"]["1 HPF"].Color = Color3.fromRGB(170, 110, 80)
		LEDS["FILTER LED RINGS"]["1 BPF"].Color = Color3.fromRGB(0, 0, 0)
		LEDS["FILTER LED RINGS"]["1 LPF"].Color = Color3.fromRGB(0, 0, 0)
	end)
	LEDS["FILTER 1 BPF"].ClickDetector.MouseClick:Connect(function()
		LEDS["FILTER LED RINGS"]["1 HPF"].Color = Color3.fromRGB(0, 0, 0)
		LEDS["FILTER LED RINGS"]["1 BPF"].Color = Color3.fromRGB(170, 110, 80)
		LEDS["FILTER LED RINGS"]["1 LPF"].Color = Color3.fromRGB(0, 0, 0)
	end)

	LEDS["FILTER 1 LPF"].ClickDetector.MouseClick:Connect(function()
		LEDS["FILTER LED RINGS"]["1 HPF"].Color = Color3.fromRGB(0, 0, 0)
		LEDS["FILTER LED RINGS"]["1 BPF"].Color = Color3.fromRGB(0, 0, 0)
		LEDS["FILTER LED RINGS"]["1 LPF"].Color = Color3.fromRGB(170, 110, 80)
	end)
	
	LEDS["FILTER 2 HPF"].ClickDetector.MouseClick:Connect(function()
		LEDS["FILTER LED RINGS"]["2 HPF"].Color = Color3.fromRGB(170, 110, 80)
		LEDS["FILTER LED RINGS"]["2 BPF"].Color = Color3.fromRGB(0, 0, 0)
		LEDS["FILTER LED RINGS"]["2 LPF"].Color = Color3.fromRGB(0, 0, 0)
	end)
	LEDS["FILTER 2 BPF"].ClickDetector.MouseClick:Connect(function()
		LEDS["FILTER LED RINGS"]["2 HPF"].Color = Color3.fromRGB(0, 0, 0)
		LEDS["FILTER LED RINGS"]["2 BPF"].Color = Color3.fromRGB(170, 110, 80)
		LEDS["FILTER LED RINGS"]["2 LPF"].Color = Color3.fromRGB(0, 0, 0)
	end)
	LEDS["FILTER 2 LPF"].ClickDetector.MouseClick:Connect(function()
		LEDS["FILTER LED RINGS"]["2 HPF"].Color = Color3.fromRGB(0, 0, 0)
		LEDS["FILTER LED RINGS"]["2 BPF"].Color = Color3.fromRGB(0, 0, 0)
		LEDS["FILTER LED RINGS"]["2 LPF"].Color = Color3.fromRGB(170, 110, 80)
	end)
	
	LEDS["CUE CHANNEL 1"].ClickDetector.MouseClick:Connect(function()
		if LEDS["CUE LED RINGS"]["CHANNEL 1"].Color == Color3.fromRGB(0, 0, 0) then
			LEDS["CUE LED RINGS"]["CHANNEL 1"].Color = Color3.fromRGB(165, 0, 74)
		else
			LEDS["CUE LED RINGS"]["CHANNEL 1"].Color = Color3.fromRGB(0, 0, 0)
		end
	end)
	LEDS["CUE CHANNEL 2"].ClickDetector.MouseClick:Connect(function()
		if LEDS["CUE LED RINGS"]["CHANNEL 2"].Color == Color3.fromRGB(0, 0, 0) then
			LEDS["CUE LED RINGS"]["CHANNEL 2"].Color = Color3.fromRGB(165, 0, 74)
		else
			LEDS["CUE LED RINGS"]["CHANNEL 2"].Color = Color3.fromRGB(0, 0, 0)
		end
	end)
	LEDS["CUE CHANNEL 3"].ClickDetector.MouseClick:Connect(function()
		if LEDS["CUE LED RINGS"]["CHANNEL 3"].Color == Color3.fromRGB(0, 0, 0) then
			LEDS["CUE LED RINGS"]["CHANNEL 3"].Color = Color3.fromRGB(165, 0, 74)
		else
			LEDS["CUE LED RINGS"]["CHANNEL 3"].Color = Color3.fromRGB(0, 0, 0)
		end
	end)
	LEDS["CUE CHANNEL 4"].ClickDetector.MouseClick:Connect(function()
		if LEDS["CUE LED RINGS"]["CHANNEL 4"].Color == Color3.fromRGB(0, 0, 0) then
			LEDS["CUE LED RINGS"]["CHANNEL 4"].Color = Color3.fromRGB(165, 0, 74)
		else
			LEDS["CUE LED RINGS"]["CHANNEL 4"].Color = Color3.fromRGB(0, 0, 0)
		end
	end)
	
	LEDS["CUE A"].ClickDetector.MouseClick:Connect(function()
		if LEDS["CUE LED RINGS"]["A"].Color == Color3.fromRGB(0, 0, 0) then
			LEDS["CUE LED RINGS"]["A"].Color = Color3.fromRGB(165, 0, 74)
		else
			LEDS["CUE LED RINGS"]["A"].Color = Color3.fromRGB(0, 0, 0)
		end
	end)
	LEDS["CUE B"].ClickDetector.MouseClick:Connect(function()
		if LEDS["CUE LED RINGS"]["B"].Color == Color3.fromRGB(0, 0, 0) then
			LEDS["CUE LED RINGS"]["B"].Color = Color3.fromRGB(165, 0, 74)
		else
			LEDS["CUE LED RINGS"]["B"].Color = Color3.fromRGB(0, 0, 0)
		end
	end)
	LEDS["CUE C"].ClickDetector.MouseClick:Connect(function()
		if LEDS["CUE LED RINGS"]["C"].Color == Color3.fromRGB(0, 0, 0) then
			LEDS["CUE LED RINGS"]["C"].Color = Color3.fromRGB(165, 0, 74)
		else
			LEDS["CUE LED RINGS"]["C"].Color = Color3.fromRGB(0, 0, 0)
		end
	end)
	LEDS["CUE D"].ClickDetector.MouseClick:Connect(function()
		if LEDS["CUE LED RINGS"]["D"].Color == Color3.fromRGB(0, 0, 0) then
			LEDS["CUE LED RINGS"]["D"].Color = Color3.fromRGB(165, 0, 74)
		else
			LEDS["CUE LED RINGS"]["D"].Color = Color3.fromRGB(0, 0, 0)
		end
	end)
	
	local cueStates = {}
	
	for _,cueButton in LEDS:GetChildren() do
		if cueButton.Name:find("CUE") and cueButton:IsA("MeshPart") then
			cueStates[cueButton.Name] = false
			
			cueButton.ClickDetector.MouseClick:Connect(function()
				cueStates[cueButton.Name] = not cueStates[cueButton.Name]
				
				for buttonName, state in cueStates do
					if state then
						LEDS["CUE STATUS INDICATOR"].Color = Color3.fromRGB(165, 0, 74); return
					else
						LEDS["CUE STATUS INDICATOR"].Color = Color3.fromRGB(0, 0, 0)
					end
				end
			end)
		end
	end
end

do
	local faders = Body.faders

	faderControl.OnServerEvent:Connect(function(fromPlayer: Player, data: {fader: string, cframe: CFrame, canvasPos: number})
		local faderValue = 1000 - data.canvasPos
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

print(`xone mixer init`)