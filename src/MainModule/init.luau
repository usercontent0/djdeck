local DJDECK = {}
local CONTENTS = script.Contents

local function copyContents(oldParent: Instance, newParent: Instance)
	for _,child in oldParent:GetChildren() do
		local clone = child:Clone()
		if oldParent.Name:find("MIXER")	then
			CONTENTS.ModuleLoader:Clone().Parent = clone
		end
		clone.Parent = newParent
	end
end

local availableUsbColors = {
	Color3.fromRGB(177, 125, 182),
	Color3.fromRGB(218, 62, 52),
	Color3.fromRGB(206, 138, 84),
	Color3.fromRGB(232, 211, 106),
	Color3.fromRGB(114, 193, 89),
	Color3.fromRGB(80, 181, 224),
	Color3.fromRGB(51, 98, 174),
	Color3.fromRGB(101, 83, 163),
}

function DJDECK:Initialize(deckModel: Model)
	deckModel:SetAttribute("USBColor", availableUsbColors[math.random(1, #availableUsbColors)])
	deckModel:SetAttribute("MasterSettings", "")
	if deckModel.Name ~= "DJDECK" then deckModel.Name = "DJDECK" end
	
	local DECKS = {}
	local MIXER = deckModel:WaitForChild("mixer")
	local CHANNELS = MIXER:GetAttribute("ChannelCount")
	local XONE = MIXER:GetAttribute("isXone")
	
	for _,child in deckModel:GetChildren() do
		local playerNumber = child:GetAttribute("PlayerNumber")
		if type(playerNumber) == "number" then
			table.insert(DECKS, child)
		end
	end
	
	copyContents(XONE and CONTENTS[`MIXER_XONE`] or CONTENTS[`MIXER_{CHANNELS}CHANNEL`], MIXER)
	for deckNum = 1, #DECKS do
		local isNewDeck = DECKS[deckNum]:GetAttribute("IsNewGeneration")
		copyContents(CONTENTS[isNewDeck and "DECK_NEW" or "DECK"], DECKS[deckNum])
	end
end

return DJDECK