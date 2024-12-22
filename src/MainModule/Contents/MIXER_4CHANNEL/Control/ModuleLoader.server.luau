local DECK = script:FindFirstAncestor("DJDECK")
for _,module in DECK:GetDescendants() do
	if module.Name == "LocalModule" then require(module) end
end