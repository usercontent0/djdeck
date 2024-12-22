local runService = game:GetService("RunService")
local httpService = game:GetService("HttpService")

local Master = script:FindFirstAncestor("DJDECK")
local mixer = Master:WaitForChild("mixer")
local LEDS = script.Parent.LEDS
local PlayerNumber = script.Parent:GetAttribute("PlayerNumber")
local TrackList = require(script:WaitForChild("TrackList"))

do
	LEDS["JOGWHEEL RING LED"].Color = Color3.fromRGB(220, 0, 0)
	
	local images = {}
	local isPlaying = false
	local onAirLoop = nil
	local faderThreshold = 275
	local waveformLoop
	local playbuttonLoop
	local cuebuttonLoop
	
	local countdownEvent = Instance.new("BindableEvent")
	local countdown = nil
	
	local SCREEN = LEDS.SCREEN.Screen.Background
	SCREEN.Changable.PlayerNumber.PlayerNumber.Text = PlayerNumber
	
	local bigRemaining, smallRemaining = SCREEN.Changable.TimeRemaining.BigNum, SCREEN.Changable.TimeRemaining.SmallNum
	
	local function changeTrackName()
		local SongName = SCREEN.Changable.SongInfo.SongName
		SongName.Text = `♪ {TrackList[math.random(1, #TrackList)]}`
	end
	local function changeTrackNumber()
		local TrackNumber = SCREEN.Labels.TrackNumber
		TrackNumber.Text = string.format("%0.2i", math.random(1, 20))
	end
	local function changeBPM(bpm: number)
		local BPM = SCREEN.Changable.BPM
		local BPMMaster = SCREEN.Changable.BPMMaster
		
		BPM.BigNum.Text = `{bpm}.`
		BPMMaster.BigNum.Text = `{bpm}.`
	end
	local function startCountdown(countdownTime: {minutes: number, seconds: number})
		local minutes, seconds = countdownTime.minutes, countdownTime.seconds
		local remainingTime = (minutes*60 + seconds) * 1000

		local function updateTime()
			local millisec = remainingTime % 1000
			local secs = remainingTime // 1000
			local mins = secs // 60
			secs %= 60

			return millisec, secs, mins
		end

		local connection
		local counter = 0
		local rate = 1/30

		connection = runService.Heartbeat:Connect(function(deltaTime)
			if not isPlaying then return end
			remainingTime -= deltaTime*1000
			counter += deltaTime

			if remainingTime <= 0 then
				remainingTime = 0
				
				connection:Disconnect()
				countdownEvent:Fire()
				connection = nil		
			end

			if counter >= rate then
				counter -= rate

				local millisec, secs, mins = updateTime()
				bigRemaining.Text = string.format("%0.2i:%0.2i.", mins, secs)
				smallRemaining.Text = string.format("%0.3i", millisec)
			end
		end)
		
		return countdownEvent.Event
	end
	
	if not onAirLoop then	
		onAirLoop = coroutine.wrap(function()
			while true do
				if not onAirLoop then break end
				local onAirLabel = SCREEN.Changable.PlayerNumber.OnAir

				onAirLabel.ImageTransparency = 0
				task.wait(.25)
				onAirLabel.ImageTransparency = 1
				task.wait(.25)
			end
		end); onAirLoop()
	end
	
	countdown = startCountdown({minutes = math.random(1, 4), seconds = math.random(0, 59)})
	countdown:Connect(function()
		countdown = startCountdown({minutes = math.random(1, 4), seconds = math.random(0, 59)})
		
		changeTrackName()
		changeTrackNumber()
		changeBPM(math.random(115, 140))
	end)
	
	changeTrackName()
	changeTrackNumber()
	changeBPM(math.random(115, 140))
	
	local Waveform = SCREEN.Waveform.MainWaveform
	local frameHeight, imageWidth = Waveform.AbsoluteSize.Y, 109
	local waveformSpeed = 6

	local xPos = 0
	local currentImage = 1
	local numVisibleImages = 15
	local waveformParts = {
		"rbxassetid://12553976372",
		"rbxassetid://12553976133",
		"rbxassetid://12553975878",
		"rbxassetid://12553975627",
		"rbxassetid://12553975344",
		"rbxassetid://12553975030",
		"rbxassetid://12553974770",
		"rbxassetid://12553974547",
		"rbxassetid://12553974280",
		"rbxassetid://12553976133",
		"rbxassetid://12553975627",
		"rbxassetid://12553975030",
		"rbxassetid://12553974547",
		"rbxassetid://12553976133",
		"rbxassetid://12553974770",
	}

	for ID = 1, #waveformParts do
		local newImage = Instance.new("ImageLabel")
		newImage.Image = waveformParts[ID]
		newImage.Parent = Waveform
		newImage.Name = ID
		newImage.BackgroundTransparency = 1
		newImage.AnchorPoint = Vector2.new(0, .5)
		newImage.Size = UDim2.fromOffset(imageWidth, frameHeight)
		newImage.Position = UDim2.fromScale(2, 2)

		images[ID] = newImage
	end

	LEDS["play button"].ClickDetector.MouseClick:Connect(function()
		if not isPlaying then
			waveformLoop = coroutine.wrap(function()
				while true do
					if not waveformLoop then break end
					xPos -= waveformSpeed
					
					if xPos <= -imageWidth then
						xPos = 0; currentImage += 1
						if currentImage > #waveformParts then currentImage = 1 end
					end

					for index = 0, numVisibleImages - 1 do
						local imageIndex = currentImage + index
						if imageIndex > #waveformParts then imageIndex = imageIndex - #waveformParts end

						local image = images[imageIndex]
						image.Position = UDim2.new(0, xPos + index*imageWidth, .5, 0)
					end

					LEDS["JOGWHEEL LED"].LED.Rotate.Rotation += 6.5988
					task.wait(.03)
				end
			end)
			
			waveformLoop()
			mixer.VolumeMeter:Fire(PlayerNumber, true)
			
			SCREEN.Changable.PlayerNumber.OnAir.Visible = true
			playbuttonLoop = false; cuebuttonLoop = false
			isPlaying = true
			
		elseif isPlaying then
			playbuttonLoop = coroutine.wrap(function()
				while true do
					if not playbuttonLoop then break end
					LEDS["PLAY RING"].Material = Enum.Material.SmoothPlastic
					LEDS["PLAY RING"].Color = Color3.fromRGB(100, 100, 100)
					task.wait(.5)
					LEDS["PLAY RING"].Material = Enum.Material.Neon
					LEDS["PLAY RING"].Color = Color3.fromRGB(15, 160, 25)
					task.wait(.5)
				end
			end)
			
			cuebuttonLoop = coroutine.wrap(function()
				while true do
					if not cuebuttonLoop then break end
					LEDS["CUE RING"].Material = Enum.Material.SmoothPlastic
					LEDS["CUE RING"].Color = Color3.fromRGB(100, 100, 100)
					task.wait(.25)
					LEDS["CUE RING"].Material = Enum.Material.Neon
					LEDS["CUE RING"].Color = Color3.fromRGB(161, 83, 47)
					task.wait(.25)
				end
			end)

			playbuttonLoop(); cuebuttonLoop()	
			mixer.VolumeMeter:Fire(PlayerNumber, false)
			
			SCREEN.Changable.PlayerNumber.OnAir.Visible = false
			waveformLoop = false
			isPlaying = false
		end
	end)
	
	mixer.FaderStatus.Event:Connect(function(deckNumber: number, faderValue: number)
		if deckNumber ~= PlayerNumber then return end
		local jogwheelLightColor = faderValue >= faderThreshold and Color3.fromRGB(220, 0, 0) or Color3.fromRGB(200, 200, 200)
		
		LEDS["JOGWHEEL RING LED"].Color = jogwheelLightColor
		
		if faderValue >= faderThreshold then
			if not onAirLoop then	
				onAirLoop = coroutine.wrap(function()
					while true do
						if not onAirLoop then break end
						local onAirLabel = SCREEN.Changable.PlayerNumber.OnAir
						
						onAirLabel.ImageTransparency = 0
						task.wait(.25)
						onAirLabel.ImageTransparency = 1
						task.wait(.25)
					end
				end); onAirLoop()
			end
		else
			onAirLoop = false; onAirLoop = nil
		end
	end)
	
	LEDS["MASTER"].ClickDetector.MouseClick:Connect(function()
		local BPM = SCREEN.Changable.BPM
		local BPMMaster = SCREEN.Changable.BPMMaster
		
		if LEDS["MASTER"].Color == Color3.fromRGB(100, 72, 36) then
			local MasterSettings = {
				MasterDeck = PlayerNumber,
				MasterBPM = tonumber(BPM.BigNum.Text)
			}
			Master:SetAttribute("MasterSettings", httpService:JSONEncode(MasterSettings))

			BPM.Visible = false
			BPMMaster.Visible = true
			LEDS["MASTER"].Color = Color3.fromRGB(172, 125, 63)
			LEDS["SYNC"].Color = Color3.fromRGB(100, 100, 100)
		else
			Master:SetAttribute("MasterSettings", "")
			BPM.Visible = true
			BPMMaster.Visible = false
			LEDS["MASTER"].Color = Color3.fromRGB(100, 72, 36)
		end
	end)
	
	Master:GetAttributeChangedSignal("MasterSettings"):Connect(function()
		if Master:GetAttribute("MasterSettings") == "" then return end
		
		local MasterSettings = httpService:JSONDecode(Master:GetAttribute("MasterSettings"))
		if MasterSettings.MasterDeck == PlayerNumber then return end
		
		local BPM = SCREEN.Changable.BPM
		local BPMMaster = SCREEN.Changable.BPMMaster
		
		BPM.Visible = true
		BPMMaster.Visible = false
		LEDS["MASTER"].Color = Color3.fromRGB(100, 72, 36)
	end)
	
	LEDS["SYNC"].ClickDetector.MouseClick:Connect(function()
		if Master:GetAttribute("MasterSettings") == "" then return end
		
		local MasterSettings = httpService:JSONDecode(Master:GetAttribute("MasterSettings"))
		if MasterSettings.MasterDeck == PlayerNumber then return end
		
		local BPM = SCREEN.Changable.BPM
		local BPMMaster = SCREEN.Changable.BPMMaster
		
		if LEDS["SYNC"].Color == Color3.fromRGB(100, 100, 100) then
			changeBPM(MasterSettings.MasterBPM)

			BPM.Visible = true
			BPMMaster.Visible = false
			
			LEDS["MASTER"].Color = Color3.fromRGB(100, 72, 36)
			LEDS["SYNC"].Color = Color3.fromRGB(160, 160, 160)			
		else
			LEDS["SYNC"].Color = Color3.fromRGB(100, 100, 100)
		end
	end)
end

print(`player{PlayerNumber} init`)