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

function DJDECK:Initialize(deckModel: Model)
	deckModel:SetAttribute("MasterSettings", "")
	if deckModel.Name ~= "DJDECK" then deckModel.Name = "DJDECK" end
	
	local DECKS = {}
	local MIXER = deckModel:WaitForChild("mixer")
	local CHANNELS = MIXER:GetAttribute("ChannelCount")
	local XONE = MIXER:GetAttribute("isXone")
	local RMX = MIXER:GetAttribute("isRMX")
	
	for _,child in deckModel:GetChildren() do
		local playerNumber = child:GetAttribute("PlayerNumber")
		if type(playerNumber) == "number" then
			table.insert(DECKS, child)
		end
	end
	
	
	copyContents(XONE and CONTENTS[`MIXER_XONE`] or CONTENTS[`MIXER_{CHANNELS}CHANNEL`], MIXER)
	for deckNum = 1, #DECKS do
		copyContents(CONTENTS["DECK"], DECKS[deckNum])
	end
end

return DJDECK