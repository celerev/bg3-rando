local Hash = {gameSeed = nil}

local function fnv1a(str)
	local hash = 2166136261
	local fnvPrime = 16777619
	
	for i = 1, #str do
		hash = hash ~ string.byte(str, i) 
		hash = (hash * fnvPrime) & 0xFFFFFFFF
	end
	
	return hash
end


function Hash:selectEnemy(UUID, difficultyTables, chaos)
	if self.gameSeed == nil then
		error("Game seed must be set before generating enemies")
	end
	
	local seedUUID = self.gameSeed .. ":" .. UUID
	local hash = fnv1a(seedUUID)
	
	local totalWeight = 0
	local cumulativeWeights = {}
	
	local validTiers = {}

	for _, tier in ipairs(difficultyTables) do
		if tier.enemies and #tier.enemies > 0 then
			table.insert(validTiers, tier)
		end
	end

	if #validTiers == 0 then
		error("No valid tiers contain enemies. Did you only enable Exandria? It doesn't have Tier 1 or Tier 2 monsters.")
	end
	
	for i, tier in ipairs(validTiers) do
		local weight = chaos and 1 or tier.weight
		totalWeight = totalWeight + weight
		table.insert(cumulativeWeights, totalWeight)
	end
	
	local normalizedHash = hash % totalWeight
	
	local selectedTier = nil
	for i, cumulativeWeight in ipairs(cumulativeWeights) do
		if normalizedHash < cumulativeWeight then
			selectedTier = validTiers[i]
			break
		end
	end
	
	local enemyHash = fnv1a(seedUUID .. "monster")
	local selectedEnemy = selectedTier.enemies[enemyHash % #selectedTier.enemies + 1]
	return selectedEnemy
end


function Hash:selectItemByTemplate(UUID, rarityTable)
    local seedUUID = self.gameSeed .. ":" .. UUID
    local hash = fnv1a(seedUUID)
    
    local totalWeight = 0
    local cumulativeWeights = {}
    local validRarities = {}
    
    for _, rarity in ipairs(rarityTable) do
        if rarity.items and #rarity.items > 0 and rarity.weight and rarity.weight > 0 then
            table.insert(validRarities, rarity)
        end
    end
    
    if #validRarities == 0 then
        error("No valid rarities contain items with positive weight.")
    end
    
    for i, rarity in ipairs(validRarities) do
        totalWeight = totalWeight + rarity.weight
        table.insert(cumulativeWeights, totalWeight)
    end
    
    local normalizedHash = hash % totalWeight


	local selectedRarity = validRarities[1]
	for i, cumulativeWeight in ipairs(cumulativeWeights) do
		if normalizedHash < cumulativeWeight then
			selectedRarity = validRarities[i]
			break
		end
	end

    
    local itemHash = fnv1a(seedUUID .. "item")
    local selectedItem = selectedRarity.items[itemHash % #selectedRarity.items + 1]

    return selectedItem
end



function Hash:createUniqueItemMapping(itemTable)
    local uniqueItemsByTemplate = {}
    local uniqueItemsList = {}
	local exandriaCheck = Ext.Mod.IsModLoaded("a27fdbe3-4d1a-641d-d05f-1ba4ee529da8")

	-- I know this is inefficient, but I'm not updating SOE right now to fix their unique flag
    for _, item in ipairs(itemTable) do
		if string.find(item.Name, "Blessing_Spear$") then
			table.insert(uniqueItemsList, item)
            uniqueItemsByTemplate[item.RootTemplate] = item
		elseif exandriaCheck and (string.find(item.Name, "^MOD_Ishta") or string.find(item.Name, "^MOD_Scream")) then
			table.insert(uniqueItemsList, item)
            uniqueItemsByTemplate[item.RootTemplate] = item
        elseif Ext.Stats.Get(item.Name).Unique == 1 then
            table.insert(uniqueItemsList, item)
            uniqueItemsByTemplate[item.RootTemplate] = item
        end
    end
    
    local mapping = {}
    local usedTargets = {}
    local mappedTemplates = {}
    
    for _, item in ipairs(uniqueItemsList) do

        local seedUUID = self.gameSeed .. ":" .. item.RootTemplate
        local hash = fnv1a(seedUUID)
        local index = (hash % #uniqueItemsList) + 1
		local fromExandria = false
		if item.Mod[1] == "a27fdbe3-4d1a-641d-d05f-1ba4ee529da8" then
			fromExandria = true
		end
        
        local attempts = 0
        while usedTargets[uniqueItemsList[index].RootTemplate] and attempts < #uniqueItemsList do
            index = (index % #uniqueItemsList) + 1
            attempts = attempts + 1
        end
        
        local targetItem = uniqueItemsList[index]
		if (fromExandria and exandriaCheck) or not fromExandria then
			mapping[item.RootTemplate] = targetItem
		end
        usedTargets[targetItem.RootTemplate] = true

        mappedTemplates[item.RootTemplate] = true
        mappedTemplates[targetItem.RootTemplate] = true
    end

    local filteredList = {}
    for _, item in ipairs(itemTable) do
        if not mappedTemplates[item.RootTemplate] then
			local fromExandria = false
			if item.Mod[1] == "a27fdbe3-4d1a-641d-d05f-1ba4ee529da8" then
				fromExandria = true
			end
			if (fromExandria and exandriaCheck) or not fromExandria then
				table.insert(filteredList, item)
			end
        end
    end
    
    return mapping, filteredList
end

return Hash