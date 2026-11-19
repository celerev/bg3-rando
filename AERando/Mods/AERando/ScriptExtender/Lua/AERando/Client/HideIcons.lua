local Channels = Ext.Require("AERando/Shared.lua")

local function RemoveHelperPortraits(character)
	local rootList = Ext.UI.GetRoot():Find("ContentRoot")
	for i = 1, rootList.ChildrenCount do
		local node = rootList:Child(i)
		local datalist = node:GetProperty("DataContext")
		if datalist then
			local combatantsCheck = Ext.DumpExport(datalist:GetAllProperties())
			if string.find(combatantsCheck, "Combatants") then
				local combatantList = datalist:GetProperty("Combatants")
				if combatantList then
					for i = #combatantList, 1, -1 do
						if combatantList[i]:GetProperty("CurrentCombatant"):GetProperty("EntityUUID") == character then
							combatantList[i] = nil
						end
					end
				end
			end
		end
	end
end

function seedReroller()
	MCM.Set("rando_seed", "0")
	Channels.SeedRoll:SendToServer()
end

Channels.IconReplacer:SetHandler(function(character, user)
	RemoveHelperPortraits(character)
end)

Channels.SeedRoller:SetHandler(function(user)
	if not MCM.EventButton.IsEnabled("reroll_button") then
		MCM.EventButton.RegisterCallback("reroll_button", seedReroller)
	end
end)

MCM.EventButton.RegisterCallback("reroll_button", seedReroller)