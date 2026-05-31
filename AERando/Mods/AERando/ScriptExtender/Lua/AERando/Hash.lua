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


function Hash:selectEnemy(UUID, difficultyTables)
	if self.gameSeed == nil then
		error("Game seed must be set before generating enemies")
	end
	
	local seedUUID = self.gameSeed .. ":" .. UUID
	local hash = fnv1a(seedUUID)
	
	local totalWeight = 0
	local cumulativeWeights = {}
	
	for i, tier in ipairs(difficultyTables) do
		totalWeight = totalWeight + tier.weight
		table.insert(cumulativeWeights, totalWeight)
	end
	
	local normalizedHash = hash % totalWeight
	
	local selectedTier = nil
	for i, cumulativeWeight in ipairs(cumulativeWeights) do
		if normalizedHash < cumulativeWeight then
			selectedTier = difficultyTables[i]
			break
		end
	end
	
	local enemyHash = fnv1a(seedUUID .. "monster")
	print("AAAH")
	print(selectedTier)
	print(#selectedTier.enemies)
	print("AAAH")
	local selectedEnemy = selectedTier.enemies[enemyHash % #selectedTier.enemies + 1]
	print(selectedEnemy)
	print("AAAH")
	return selectedEnemy
end

return Hash