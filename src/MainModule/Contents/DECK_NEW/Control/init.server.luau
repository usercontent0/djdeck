local runService = game:GetService("RunService")
local httpService = game:GetService("HttpService")

local Master = script:FindFirstAncestor("DJDECK")
local mixer = Master:WaitForChild("mixer")
local LEDS = script.Parent.LEDS

local faderControl = script.Parent:WaitForChild("FaderControl")
local PlayerNumber = script.Parent:GetAttribute("PlayerNumber")
local TrackList = require(script:WaitForChild("TrackList"))

local hotCueColors = {
	Color3.fromRGB(150, 74, 74),
	Color3.fromRGB(50, 127, 160),
	Color3.fromRGB(105, 160, 51),
	Color3.fromRGB(124, 104, 160),
	Color3.fromRGB(36, 160, 82),
	Color3.fromRGB(160, 103, 72),
	Color3.fromRGB(77, 99, 170),
	Color3.fromRGB(160, 142, 3),
}

local tempoColors = {
	Color3.fromRGB(0, 255, 48),
	Color3.fromRGB(255, 70, 25),
	Color3.fromRGB(255, 255, 255),
	Color3.fromRGB(255, 0, 0)
}

local tempoLabel = {"± 6", "± 10", "± 16", "WIDE"}
local tempoPercentages = {[1] = 6, [2] = 10, [3] = 16, [4] = 100}

local SCREEN = LEDS.SCREEN.Screen.Background
local bigRemaining, smallRemaining = SCREEN.Changable.TimeRemaining.BigNum, SCREEN.Changable.TimeRemaining.SmallNum
local Waveform = SCREEN.Waveform.MainWaveform

local images = {}
local isPlaying = false
local currentSong = nil
local isSlip = false

local refreshRate = 30
local jogwheelRpm = 33
local rpmPerSecond = jogwheelRpm / 60
local rpmPerUpdate = rpmPerSecond / refreshRate
local degPerUpdate = rpmPerUpdate * 360

local currentBPM = 0
local currentTempo = 2
local currentTempoPercentage = 10
local tempoMultiplier = 0
local bypassTempo = false

local resumeScrubDelay = .1
local scrubSeq = 0
local wasPlaying = false
local canSetWasPlaying = true
local setRemainingMs

local bLoopStates = {
	inMs = nil,
	outMs = nil,
	active = false
}
local bLoopLed = nil
local onAirLoop = nil
local waveformLoop = nil
local playButtonLoop = nil
local cueButtonLoop = nil 
local jogwheelLoop = nil

local countdownEvent = Instance.new("BindableEvent")
local countdown = nil
local awaitUpdate = false

local originalImageWidth = 146
local imageWidth = originalImageWidth

local waveformSpeed = 2.5
local numVisibleImages = 12
local currentImage = 1
local xPos = 0

local waveformParts = {
	"rbxassetid://133642711259129",
	"rbxassetid://139035811679728",
	"rbxassetid://81973356245482",
	"rbxassetid://114056515926896",
	"rbxassetid://99358029680417",
	"rbxassetid://102911029991151",
	"rbxassetid://133642711259129",
	"rbxassetid://139035811679728",
	"rbxassetid://81973356245482",
	"rbxassetid://114056515926896",
	"rbxassetid://99358029680417",
	"rbxassetid://102911029991151",
}
local numWaveformParts = #waveformParts

SCREEN.Changable.PlayerNumber.PlayerNumber.Text = PlayerNumber
LEDS["JOGWHEEL RING LED"].Color = Color3.fromRGB(220, 0, 0)

local function resetWaveformPosition()
	local waveformCenter = Waveform.AbsoluteSize.X/2
	for wIndex = 1, #images do
		images[wIndex].Position = UDim2.new(0, waveformCenter + (wIndex-1) * imageWidth, .5, 0)
	end
	xPos = waveformCenter; currentImage = 1
end

local function getTotalMs(): number
	return (currentSong.length.minutes*60 + currentSong.length.seconds) * 1000
end

local function setCurrentMs(ms: number)
    local total = getTotalMs()
    ms = math.clamp(ms, 0, total)
    local remainingMs = total - ms

    if setRemainingMs then setRemainingMs(remainingMs) end

    local remMs = remainingMs % 1000
    local remSecs = (remainingMs // 1000) % 60
    local remMins = remainingMs // 60000

    bigRemaining.Text = string.format("%.2i:%.2i.", remMins, remSecs)
    smallRemaining.Text = string.format("%.3i", remMs)
end

local function getCurrentMs(): number
    local mins = tonumber(bigRemaining.Text:sub(1, 2)) or 0
    local secs = tonumber(bigRemaining.Text:sub(4, 5)) or 0
    local ms = tonumber(smallRemaining.Text) or 0

    local remainingMs = (mins*60 + secs) * 1000 + ms
    return getTotalMs() - remainingMs
end

local function jumpWaveformToMs(targetMs: number)
    local ppm = (waveformSpeed * refreshRate) / 1000 --pixels per millisecond
    local center = Waveform.AbsoluteSize.X / 2

    local rawX = center - (targetMs * ppm)
    local wraps = math.max(0, math.floor((-rawX) / imageWidth))

    xPos = rawX + wraps*imageWidth
    currentImage = (wraps % numWaveformParts) + 1

    for index = 0, numVisibleImages - 1 do
        local imageIndex = currentImage + index
        if imageIndex > numWaveformParts then imageIndex -= numWaveformParts end
        images[imageIndex].Position = UDim2.new(0, xPos + index*imageWidth, .5, 0)
    end
end

local function rotateJogwheelByMs(deltaMs: number)
	local degPerSec = rpmPerSecond * 360 * (1+tempoMultiplier)
	local deltaDeg = degPerSec * (deltaMs/1000)

	LEDS["JOGWHEEL LED"].LED.ROTATE.Rotation += deltaDeg
    LEDS["JOGWHEEL LED"].LED.SLIPROTATE.Rotation += deltaDeg
end

local function createLoopOverlay()
    local overlay = Waveform:FindFirstChild("LoopOverlay") :: Frame?
    if not overlay then
        overlay = Instance.new("Frame")
        overlay.Name = "LoopOverlay"
        overlay.Parent = Waveform
        overlay.BackgroundColor3 = Color3.fromRGB(238, 156, 113)
        overlay.BackgroundTransparency = .75
        overlay.BorderSizePixel = 0
        overlay.ZIndex = 10
    end
    return overlay
end

local function updateLoopOverlay()
    local overlay = createLoopOverlay()
    if not bLoopStates.inMs or not bLoopStates.outMs or not bLoopStates.active then
        overlay.Visible = false; return
    end

    local ppm = (waveformSpeed * refreshRate) / 1000
    local widthPx = math.max(2, math.floor((bLoopStates.outMs - bLoopStates.inMs) * ppm + .5))

    local currentMs = getCurrentMs()
    local center = Waveform.AbsoluteSize.X/2
    local xStart = center + (bLoopStates.inMs - currentMs) * ppm

    overlay.Visible = true
    overlay.Position = UDim2.fromOffset(xStart, 0)
	overlay.Size = UDim2.new(0, widthPx, 1, 0)
end

local function toggleLoopUi(state: boolean)
	SCREEN.Changable.SongInfo.ActivationIndicator.Visible = state
	SCREEN.LoopButtons.Visible = state
	SCREEN.Waveform.MainWaveform.Size = UDim2.fromOffset(1280, state and 96 or 191)
	SCREEN.Waveform.WaveformCenter1.Size = UDim2.fromOffset(5, state and 144 or 237)
	SCREEN.Waveform.BottomLines.Position = UDim2.fromOffset(0, state and 325 or 418)
end

local function clearLoop()
	toggleLoopUi(false)
    bLoopStates.inMs = nil
    bLoopStates.outMs = nil
    bLoopStates.active = false

    LEDS["LOOP IN"].Material = Enum.Material.Neon
    LEDS["LOOP OUT"].Material = Enum.Material.Neon
    LEDS["LOOP IN"].Color = Color3.fromRGB(172, 125, 63)
    LEDS["LOOP OUT"].Color = Color3.fromRGB(172, 125, 63)
	LEDS["RELOOP LED"].Color = Color3.fromRGB(25, 25, 25)

    local overlay = SCREEN.Waveform:FindFirstChild("LoopOverlay")
    if overlay then overlay:Destroy() end
end

local function changeTrackName()
	local SongInfo = SCREEN.Changable.SongInfo
	currentSong = TrackList[math.random(1, #TrackList)]

	SongInfo.SongName.Text = currentSong.title
	SongInfo.SongKey.Text = currentSong.key
	SongInfo.SongBPM.Text = string.format("%.1f", currentSong.bpm)
	SongInfo.SongLength.Text = `{string.format("%.2i", currentSong.length.minutes)}:{string.format("%.2i", currentSong.length.seconds)}`
	SCREEN.Changable.SongKey.Text = currentSong.key

	SongInfo.SongCover.Image = currentSong.cover
	LEDS["JOGWHEEL LED"].LED.COVER.Image = currentSong.cover
	currentBPM = currentSong.bpm
end

local function changeTrackNumber()
	local TrackNumber = SCREEN.Changable.TrackNumber.TrackNumber
	TrackNumber.Text = string.format("%.2i", math.random(1, 20))
end

local function changeBPM(bpm: number)
	local BPM = SCREEN.Changable.BPM
	local BPMMaster = SCREEN.Changable.BPMMaster

	local whole = math.floor(bpm)
	local tenth = math.floor((bpm - whole) * 10 + .0001)
	whole = math.clamp(whole, 0, 1000)

	BPM.BigNum.Text = `{whole}.`
	BPMMaster.BigNum.Text = `{whole}.`

	BPM.SmallNum.Text = tenth
	BPMMaster.SmallNum.Text = tenth
end

local function changeTempo(percentage: number)
	if bypassTempo then return end
	local Tempo = SCREEN.Changable.Tempo

	tempoMultiplier = percentage/100
	imageWidth = originalImageWidth * (1-tempoMultiplier)
	changeBPM(currentBPM * (1+tempoMultiplier))

	for wIndex = 1, #images do
		images[wIndex].Size = UDim2.new(0, imageWidth, 1, 0)
	end
	
	Tempo.BigNum.Text = string.format("%.2f", math.abs(percentage))
	Tempo.Sign.Text = percentage ~= 0 and (percentage < 0 and "-" or percentage > 0 and "+") or ""
end

local function blinkEncoder()
	task.spawn(function()
		for index = 1, 4 do
			LEDS["ENCODER LED"].Material = Enum.Material.SmoothPlastic
			LEDS["ENCODER LED"].Color = Color3.fromRGB(100, 100, 100)
			task.wait(.125)
			LEDS["ENCODER LED"].Material = Enum.Material.Neon
			LEDS["ENCODER LED"].Color = Color3.fromRGB(160, 160, 160)
			task.wait(.125)
		end
	end)
end

local function blinkJogwheel()
	if jogwheelLoop then return end

	jogwheelLoop = coroutine.wrap(function()
		while jogwheelLoop do
			local remainingMs = getCurrentMs()
			local totalMs = getTotalMs()
			local timeLeft = totalMs - remainingMs

			if timeLeft <= 15_000 then
				LEDS["JOGWHEEL RING LED"].Transparency = 1
				task.wait(.1)
				if not jogwheelLoop then break end
				LEDS["JOGWHEEL RING LED"].Transparency = 0
				task.wait(.1)
			elseif timeLeft <= 30_000 then
				LEDS["JOGWHEEL RING LED"].Transparency = 1
				task.wait(.5)
				if not jogwheelLoop then break end
				LEDS["JOGWHEEL RING LED"].Transparency = 0
				task.wait(.5)
			else break end
		end
		jogwheelLoop = nil
	end)

	jogwheelLoop()
end

local function stopBlinkJogwheel()
	if jogwheelLoop then
		jogwheelLoop = nil
		LEDS["JOGWHEEL RING LED"].Transparency = 0
	end
end

local function toggleSlip()
	isSlip = not isSlip
	LEDS["JOGWHEEL LED"].LED.SLIP.Visible = isSlip
	LEDS["JOGWHEEL LED"].LED.SLIPROTATE.Visible = isSlip

	SCREEN.SlipButtons.Visible = isSlip
	SCREEN.Waveform.MainWaveform.Size = UDim2.fromOffset(1280, isSlip and 96 or 191)
	SCREEN.Waveform.WaveformCenter1.Size = UDim2.fromOffset(5, isSlip and 144 or 237)
	SCREEN.Waveform.BottomLines.Position = UDim2.fromOffset(0, isSlip and 325 or 418)

	local function changeLEDs(state: boolean)
		local material = state and Enum.Material.Neon or Enum.Material.SmoothPlastic
		local hotCueColor = state and Color3.fromRGB(8, 138, 255) or Color3.fromRGB(25, 25, 25)
		local neonButtonColor = state and Color3.fromRGB(172, 125, 63) or Color3.fromRGB(100, 100, 100)
		local imageButtonColor = state and Color3.fromRGB(172, 125, 63) or Color3.fromRGB(25, 25, 25)
		local playRingColor = state and Color3.fromRGB(15, 160, 25) or Color3.fromRGB(100, 100, 100)

		for _,hotCueButton in LEDS:GetChildren() do
			if not string.find(hotCueButton.Name, "HOT CUE") then continue end
			hotCueButton.Color = hotCueColor
		end

		LEDS["LOOP IN"].Material = material
		LEDS["LOOP OUT"].Material = material
		LEDS["LOOP IN"].Color = neonButtonColor
		LEDS["LOOP OUT"].Color = neonButtonColor

		LEDS["BEAT LOOP 4"].Color = imageButtonColor
		LEDS["BEAT LOOP 8"].Color = imageButtonColor
		LEDS["RELOOP LED"].Color = imageButtonColor

		LEDS["PLAY RING"].Material = material
		LEDS["PLAY RING"].Color = playRingColor
		LEDS["JOGWHEEL RING LED"].Transparency = state and 0 or 1
		LEDS["DIRECTION SCREEN"].LED.REV.ImageColor3 = state and Color3.fromRGB(255, 0, 0) or Color3.fromRGB(30, 30, 30)
	end

	if isSlip then
		task.spawn(function()
			for _,hotCueButton in LEDS:GetChildren() do
				if not string.find(hotCueButton.Name, "HOT CUE") then continue end
				hotCueButton.Color = Color3.fromRGB(8, 138, 255)
			end
			LEDS["DIRECTION SCREEN"].LED.REV.ImageColor3 = Color3.fromRGB(255, 0, 0)
			LEDS["RELOOP LED"].Color = Color3.fromRGB(172, 125, 63)

			task.wait(.25); changeLEDs(false)
			task.wait(.25); changeLEDs(true)
			task.wait(.25); changeLEDs(false)

			task.wait(.25)
			for _,hotCueButton in LEDS:GetChildren() do
				if not string.find(hotCueButton.Name, "HOT CUE") then continue end
				local splitName = hotCueButton.Name:split("HOT CUE ")
				local buttonId = tonumber(splitName[2])

				hotCueButton.Color = hotCueColors[buttonId]
			end

			LEDS["LOOP IN"].Material = Enum.Material.Neon
			LEDS["LOOP OUT"].Material = Enum.Material.Neon
			LEDS["LOOP IN"].Color = Color3.fromRGB(172, 125, 63)
			LEDS["LOOP OUT"].Color = Color3.fromRGB(172, 125, 63)	

			LEDS["BEAT LOOP 4"].Color = Color3.fromRGB(172, 125, 63)
			LEDS["BEAT LOOP 8"].Color = Color3.fromRGB(172, 125, 63)

			LEDS["PLAY RING"].Material = Enum.Material.Neon
			LEDS["PLAY RING"].Color = Color3.fromRGB(15, 160, 25)
			LEDS["JOGWHEEL RING LED"].Transparency = 0
		end)
	end
end

local function changeTrack()
	LEDS["JOGWHEEL LED"].LED.SLIPROTATE.Rotation = -45
	LEDS["JOGWHEEL LED"].LED.ROTATE.Rotation = -45

	resetWaveformPosition()
	stopBlinkJogwheel()
	changeTrackName()
	changeTrackNumber()
	changeBPM(currentSong.bpm)
	blinkEncoder()
end

local function startCountdown(countdownTime: {minutes: number, seconds: number})
	local minutes, seconds = countdownTime.minutes, countdownTime.seconds
	local remainingTime = (minutes*60 + seconds) * 1000
	local totalSongMs = remainingTime

	setRemainingMs = function(ms: number)
		local maxMs = (minutes*60 + seconds) * 1000
		remainingTime = math.clamp(ms, 0, maxMs)
	end

	local function updateTime()
		local millisec = remainingTime % 1000
		local secs = remainingTime // 1000
		local mins = secs // 60
		secs %= 60

		return millisec, secs, mins
	end

	local connection
	local counter = 0
	local rate = 1 / refreshRate

	connection = runService.Heartbeat:Connect(function(deltaTime)
		if not isPlaying then return end
		remainingTime -= deltaTime*1000
		counter += deltaTime

		if awaitUpdate then
			awaitUpdate = false
			remainingTime = (minutes*60 + seconds) * 1000
		end

		if bLoopStates.active and bLoopStates.inMs and bLoopStates.outMs then
			local currentMs = totalSongMs - remainingTime
			if currentMs >= bLoopStates.outMs then
				local overflow = currentMs - bLoopStates.outMs
				local target = bLoopStates.inMs + overflow

				remainingTime = totalSongMs - target
				jumpWaveformToMs(target)
				rotateJogwheelByMs(target - currentMs)
			end
		end

		if remainingTime <= 30_000 and not jogwheelLoop then
			blinkJogwheel()
		elseif remainingTime > 30_000 and jogwheelLoop then
			stopBlinkJogwheel()
		end

		if remainingTime <= 0 then
			remainingTime = 0
			stopBlinkJogwheel()

			connection:Disconnect()
			countdownEvent:Fire()
			connection = nil
		end

		if counter >= rate then
			counter -= rate

			local millisec, secs, mins = updateTime()
			bigRemaining.Text = string.format("%.2i:%.2i.", mins, secs)
			smallRemaining.Text = string.format("%.3i", millisec)
			updateLoopOverlay()
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

changeTrack()

countdown = startCountdown({minutes = currentSong.length.minutes, seconds = currentSong.length.seconds})
countdown:Connect(function()
 	changeTrack()
	countdown = startCountdown({minutes = currentSong.length.minutes, seconds = currentSong.length.seconds})
end)

for ID = 1, numWaveformParts do
	local newImage = Instance.new("ImageLabel")
	newImage.Image = waveformParts[ID]
	newImage.Parent = Waveform
	newImage.Name = ID
	newImage.BackgroundTransparency = 1
	newImage.AnchorPoint = Vector2.new(0, .5)
	newImage.Size = UDim2.new(0, imageWidth, 1, 0)
	newImage.Position = UDim2.fromScale(2, 2)
	images[ID] = newImage
end

LEDS["play button"].ClickDetector.MouseClick:Connect(function()
	if not isPlaying then
		if waveformLoop then return end
		local counter = 0
		local rate = 1 / refreshRate

		waveformLoop = runService.Heartbeat:Connect(function(deltaTime)
			counter += deltaTime

			if counter >= rate then
				counter -= rate
				xPos -= waveformSpeed

				if xPos <= -imageWidth then
					xPos = 0; currentImage += 1
					if currentImage > numWaveformParts then currentImage = 1 end
				end

				for index = 0, numVisibleImages - 1 do
					local imageIndex = currentImage + index
					if imageIndex > numWaveformParts then imageIndex -= numWaveformParts end
					images[imageIndex].Position = UDim2.new(0, xPos + index*imageWidth, .5, 0)
				end

				LEDS["JOGWHEEL LED"].LED.ROTATE.Rotation += degPerUpdate * (1+tempoMultiplier)
				LEDS["JOGWHEEL LED"].LED.SLIPROTATE.Rotation += degPerUpdate * (1+tempoMultiplier)
				updateLoopOverlay()
			end
		end)

		SCREEN.Changable.PlayerNumber.OnAir.Visible = true
		mixer.VolumeMeter:Fire(PlayerNumber, true)
		playButtonLoop = false; cueButtonLoop = false
		isPlaying = true

	else
		playButtonLoop = coroutine.wrap(function()
			while true do
				if not playButtonLoop then break end
				LEDS["PLAY RING"].Material = Enum.Material.SmoothPlastic
				LEDS["PLAY RING"].Color = Color3.fromRGB(100, 100, 100)
				task.wait(.5)
				LEDS["PLAY RING"].Material = Enum.Material.Neon
				LEDS["PLAY RING"].Color = Color3.fromRGB(15, 160, 25)
				task.wait(.5)
			end
		end)

		cueButtonLoop = coroutine.wrap(function()
			while true do
				if not cueButtonLoop then break end
				LEDS["CUE RING"].Material = Enum.Material.SmoothPlastic
				LEDS["CUE RING"].Color = Color3.fromRGB(100, 100, 100)
				task.wait(.25)
				LEDS["CUE RING"].Material = Enum.Material.Neon
				LEDS["CUE RING"].Color = Color3.fromRGB(160, 103, 78)
				task.wait(.25)
			end
		end)

		SCREEN.Changable.PlayerNumber.OnAir.Visible = false
		mixer.VolumeMeter:Fire(PlayerNumber, false)
		stopBlinkJogwheel()
		playButtonLoop(); cueButtonLoop()
		isPlaying = false

		if not waveformLoop then return end
		waveformLoop:Disconnect(); waveformLoop = nil
	end
end)

LEDS["cue button"].ClickDetector.MouseClick:Connect(function()
	if isPlaying then
		playButtonLoop = coroutine.wrap(function()
			while true do
				if not playButtonLoop then break end
				LEDS["PLAY RING"].Material = Enum.Material.SmoothPlastic
				LEDS["PLAY RING"].Color = Color3.fromRGB(100, 100, 100)
				task.wait(.5)
				LEDS["PLAY RING"].Material = Enum.Material.Neon
				LEDS["PLAY RING"].Color = Color3.fromRGB(15, 160, 25)
				task.wait(.5)
			end
		end)

		SCREEN.Changable.PlayerNumber.OnAir.Visible = false
		mixer.VolumeMeter:Fire(PlayerNumber, false)
		playButtonLoop()
		stopBlinkJogwheel()
		isPlaying = false; awaitUpdate = true

		if waveformLoop then
			waveformLoop:Disconnect()
			waveformLoop = nil
		end

		clearLoop()
		resetWaveformPosition()
		LEDS["JOGWHEEL LED"].LED.ROTATE.Rotation = -45
		LEDS["JOGWHEEL LED"].LED.SLIPROTATE.Rotation = -45
		bigRemaining.Text = string.format("%.2i:%.2i.", currentSong.length.minutes, currentSong.length.seconds)
		smallRemaining.Text = string.format("%.3i", 0)
	end
end)

LEDS["TEMPO"].ClickDetector.MouseClick:Connect(function()
	currentTempo = currentTempo >= 4 and 1 or currentTempo + 1
	local thisColor = tempoColors[currentTempo]
	local rangeLabel = SCREEN.Changable.TempoRange :: TextLabel
	
	if currentTempo >= 1 and currentTempo <= 3 then
		rangeLabel.BackgroundColor3 = thisColor
		rangeLabel.TextColor3 = Color3.new(0, 0, 0)
	elseif currentTempo == 4 then
		rangeLabel.BackgroundColor3 = Color3.new(0, 0, 0)
		rangeLabel.TextColor3 = thisColor
	end

	rangeLabel.Text = tempoLabel[currentTempo]
	currentTempoPercentage = tempoPercentages[currentTempo]
end)

LEDS["TEMPO RESET"].ClickDetector.MouseClick:Connect(function()
	if LEDS["TEMPO RESET LED"].Material == Enum.Material.SmoothPlastic then
		LEDS["TEMPO RESET LED"].Material = Enum.Material.Neon
		LEDS["TEMPO RESET LED"].Color = Color3.fromRGB(91, 154, 76)
		bypassTempo = true
		changeBPM(currentBPM)
	else
		LEDS["TEMPO RESET LED"].Material = Enum.Material.SmoothPlastic
		LEDS["TEMPO RESET LED"].Color = Color3.fromRGB(100, 100, 100)
		bypassTempo = false
	end
end)

LEDS["SLIP"].ClickDetector.MouseClick:Connect(function()
	LEDS["SLIP"].Color = LEDS["SLIP"].Color == Color3.fromRGB(25, 25, 25) and Color3.fromRGB(150, 74, 74) or Color3.fromRGB(25, 25, 25)
	toggleSlip()
end)

LEDS["LOOP IN"].ClickDetector.MouseClick:Connect(function()
	local nowMs = getCurrentMs()
	bLoopStates.inMs = math.clamp(nowMs, 0, getTotalMs())
	bLoopStates.outMs = nil
	bLoopStates.active = false

	updateLoopOverlay()
end)

LEDS["LOOP OUT"].ClickDetector.MouseClick:Connect(function()
	local totalMs = getTotalMs()
	if not bLoopStates.inMs then
		bLoopStates.inMs = math.clamp(getCurrentMs(), 0, totalMs)
	end

	local nowMs = getCurrentMs()
	local minLen = 500
	bLoopStates.outMs = math.clamp(math.max(nowMs, bLoopStates.inMs + minLen), 0, totalMs)
	bLoopStates.active = true

	updateLoopOverlay()
	toggleLoopUi(true)

	if isPlaying and nowMs >= bLoopStates.outMs then
		local target = bLoopStates.inMs + (nowMs - bLoopStates.outMs)

		setCurrentMs(target)
		jumpWaveformToMs(target)
		rotateJogwheelByMs(target - nowMs)
	end

	LEDS["RELOOP LED"].Color = Color3.fromRGB(172, 125, 63)
end)

LEDS["RELOOP"].ClickDetector.MouseClick:Connect(clearLoop)

mixer.FaderStatus.Event:Connect(function(deckNumber: number, faderValue: number)
	if deckNumber ~= PlayerNumber then return end
	local faderThreshold = 275
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

faderControl.Event:Connect(function(fType: string, args: {dragPosition: number, range: number})
	if fType == "speed" then
		local faderValue = args.dragPosition / args.range
		changeTempo(currentTempoPercentage * faderValue)
	elseif fType == "jogwheel" then
		local delta = args.dragPosition
		if delta == 0 then return end

		local direction = (delta > 0) and 1 or -1
		local scrubAmount = math.abs(delta)
		
		if canSetWasPlaying then wasPlaying = isPlaying; canSetWasPlaying = false end
		if isPlaying and waveformLoop then
			waveformLoop:Disconnect()
			waveformLoop = nil
			isPlaying = false
		end

		local currentTime = {
			minutes = tonumber(bigRemaining.Text:sub(1, 2)),
			seconds = tonumber(bigRemaining.Text:sub(4, 5)),
			millisecs = tonumber(smallRemaining.Text)
		}

		local totalMs = (currentTime.minutes*60 + currentTime.seconds)*1000 + currentTime.millisecs
		totalMs = math.clamp(totalMs + (direction*scrubAmount * 1000), 0, getTotalMs())

		local newMs = totalMs % 1000
		local newSecs = (totalMs // 1000) % 60
		local newMins = totalMs // 60000
		bigRemaining.Text = string.format("%.2i:%.2i.", newMins, newSecs)
		smallRemaining.Text = string.format("%.3i", newMs)

		if setRemainingMs then setRemainingMs(totalMs) end

		xPos = xPos + (direction*scrubAmount * waveformSpeed * 10)
		local currentMs = getCurrentMs()
		local isAtStart = currentMs <= 0
		local waveformCenter = Waveform.AbsoluteSize.X/2

        if xPos <= -imageWidth then
            xPos = 0; currentImage = (currentImage % numWaveformParts) + 1
        elseif xPos >= 0 and not isAtStart then
            if currentImage > 1 then xPos -= imageWidth; currentImage -= 1 else xPos = math.max(xPos, 0) end
        elseif isAtStart then
            xPos = math.min(xPos, waveformCenter)
        end

        for index = 0, numVisibleImages - 1 do
            local imageIndex = (currentImage + index - 1) % numWaveformParts + 1
            images[imageIndex].Position = UDim2.new(0, xPos + index*imageWidth, .5, 0)
        end

		local rotationAmount = direction*scrubAmount * 60
		LEDS["JOGWHEEL LED"].LED.ROTATE.Rotation += rotationAmount * -1
    	LEDS["JOGWHEEL LED"].LED.SLIPROTATE.Rotation += rotationAmount * -1

		updateLoopOverlay()

		scrubSeq += 1
		local thisSeq = scrubSeq

		task.delay(resumeScrubDelay, function()
			if thisSeq ~= scrubSeq then return end
			canSetWasPlaying = true

			if wasPlaying and not isPlaying and not waveformLoop then
				isPlaying = true
				local counter = 0
				local rate = 1 / refreshRate

				waveformLoop = runService.Heartbeat:Connect(function(deltaTime)
					counter += deltaTime

					if counter >= rate then
						counter -= rate
						xPos -= waveformSpeed

						if xPos <= -imageWidth then
							xPos = 0; currentImage += 1
							if currentImage > numWaveformParts then currentImage = 1 end
						end

						for index = 0, numVisibleImages - 1 do
							local imageIndex = currentImage + index
							if imageIndex > numWaveformParts then imageIndex -= numWaveformParts end
							images[imageIndex].Position = UDim2.new(0, xPos + index*imageWidth, .5, 0)
						end

						LEDS["JOGWHEEL LED"].LED.ROTATE.Rotation += degPerUpdate * (1+tempoMultiplier)
						LEDS["JOGWHEEL LED"].LED.SLIPROTATE.Rotation += degPerUpdate * (1+tempoMultiplier)
					end
				end)
			end
		end)
	end
end)

LEDS["MASTER"].ClickDetector.MouseClick:Connect(function()
	local BPM = SCREEN.Changable.BPM
	local BPMMaster = SCREEN.Changable.BPMMaster
	
	if LEDS["MASTER"].Color == Color3.fromRGB(25, 25, 25) then
		local MasterSettings = {
			MasterDeck = PlayerNumber,
			MasterBPM = tonumber(BPM.BigNum.Text)
		}
		Master:SetAttribute("MasterSettings", httpService:JSONEncode(MasterSettings))
		BPM.Visible = false
		BPMMaster.Visible = true

		LEDS["MASTER"].Color = Color3.fromRGB(172, 125, 63)
		LEDS["BEAT SYNC"].Color = Color3.fromRGB(25, 25, 25)
		LEDS["JOGWHEEL LED"].LED.MASTER.Visible = true
		LEDS["JOGWHEEL LED"].LED.SYNC.Visible = false

		BPM.BPM.Text = "BPM"
		BPMMaster.BPM.Text = "BPM"
	else
		Master:SetAttribute("MasterSettings", "")
		BPM.Visible = true
		BPMMaster.Visible = false
		LEDS["MASTER"].Color = Color3.fromRGB(25, 25, 25)
		LEDS["JOGWHEEL LED"].LED.MASTER.Visible = false
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
	LEDS["MASTER"].Color = Color3.fromRGB(25, 25, 25)
	LEDS["JOGWHEEL LED"].LED.MASTER.Visible = false
end)
	
LEDS["BEAT SYNC"].ClickDetector.MouseClick:Connect(function()
	if Master:GetAttribute("MasterSettings") == "" then return end
	
	local MasterSettings = httpService:JSONDecode(Master:GetAttribute("MasterSettings"))
	if MasterSettings.MasterDeck == PlayerNumber then return end
	
	local BPM = SCREEN.Changable.BPM
	local BPMMaster = SCREEN.Changable.BPMMaster
	
	if LEDS["BEAT SYNC"].Color == Color3.fromRGB(25, 25, 25) then
		changeBPM(MasterSettings.MasterBPM)
		BPM.Visible = true
		BPMMaster.Visible = false
		
		LEDS["MASTER"].Color = Color3.fromRGB(25, 25, 25)
		LEDS["BEAT SYNC"].Color = Color3.fromRGB(160, 160, 160)
		LEDS["JOGWHEEL LED"].LED.MASTER.Visible = false
		LEDS["JOGWHEEL LED"].LED.SYNC.Visible = true

		BPM.BPM.Text = "BEAT SYNC"
		BPMMaster.BPM.Text = "BEAT SYNC"
	else
		LEDS["BEAT SYNC"].Color = Color3.fromRGB(25, 25, 25)
		LEDS["JOGWHEEL LED"].LED.SYNC.Visible = false

		BPM.BPM.Text = "BPM"
		BPMMaster.BPM.Text = "BPM"
	end
end)

task.spawn(function()
	bLoopLed = coroutine.wrap(function()
		while true do
			if not bLoopLed then break end
			if bLoopStates.inMs then
				LEDS["LOOP IN"].Material = Enum.Material.SmoothPlastic
				LEDS["LOOP IN"].Color = Color3.fromRGB(100, 100, 100)
			end
			if bLoopStates.outMs then
				LEDS["LOOP OUT"].Material = Enum.Material.SmoothPlastic
				LEDS["LOOP OUT"].Color = Color3.fromRGB(100, 100, 100)
			end

			task.wait(.27)

			if bLoopStates.inMs then
				LEDS["LOOP IN"].Material = Enum.Material.Neon
				LEDS["LOOP IN"].Color = Color3.fromRGB(172, 125, 63)
			end
			if bLoopStates.outMs then
				LEDS["LOOP OUT"].Material = Enum.Material.Neon
				LEDS["LOOP OUT"].Color = Color3.fromRGB(172, 125, 63)
			end

			task.wait(.27) 
		end
	end); bLoopLed()
end)

print(`player{PlayerNumber} init (new gen)`)