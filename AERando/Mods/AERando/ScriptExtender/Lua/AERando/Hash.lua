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

return Hash