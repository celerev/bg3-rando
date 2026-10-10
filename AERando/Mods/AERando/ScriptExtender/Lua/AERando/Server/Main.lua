local baseMonsterList = Ext.Require("AERando/Server/Templates/Enemies.lua")
local tabletopMonsterList = Ext.Require("AERando/Server/Templates/ATTTemplates.lua")
local exandriaMonsterList = Ext.Require("AERando/Server/Templates/SOEEnemies.lua")
local uniqueMonsterLookup = Ext.Require("AERando/Server/Templates/uniqueMonsterLookup.lua")
local rootTemplateItemList, aTTRootTemplateItemList, exandriaRootTemplateItemList = Ext.Require("AERando/Server/Templates/ItemList.lua")
local startRegex, containsRegex, endsRegex = Ext.Require("AERando/Server/Templates/ItemBlacklist.lua")

local C = Ext.Require("AERando/Constants.lua")
local Hash = Ext.Require("AERando/Hash.lua")
local RNG = Ext.Require("AERando/RNG.lua")
local Channels = Ext.Require("AERando/Shared.lua")

mappedUniqueItems = {}
nonUniqueItems = {}
linkingItems = {}

Host = nil
playerFaction = "6545a015-1b3d-66a4-6a0e-6ec62065cdb7"

if not PersistentVars then
	PersistentVars = {}
end
if not PersistentVars.currentlyRandomizedEnemyTable then
	PersistentVars.currentlyRandomizedEnemyTable = {}
end
if not PersistentVars.spawnedEnemyTable then
	PersistentVars.spawnedEnemyTable = {}
end
if not PersistentVars.deadRandomTable then
	PersistentVars.deadRandomTable = {}
end
if not PersistentVars.usedBossTable then
	PersistentVars.usedBossTable = {}
end
if not PersistentVars.turnHelperCollection then
	PersistentVars.turnHelperCollection = {}
end
if not PersistentVars.currentCombatMembers then
	PersistentVars.currentCombatMembers = {}
end
if not PersistentVars.gameMaster then
	PersistentVars.gameMaster = ""
end
if not PersistentVars.randomizedItemTable then
	PersistentVars.randomizedItemTable = {}
end
if not PersistentVars.existingMappedItemTable then
	PersistentVars.existingMappedItemTable = {}
end

activeMonsterList = {}
activeItemList = {}
iconTable = {}
statusTable = {}
tempBattle = {}

local exandriaCheck = Ext.Mod.IsModLoaded("a27fdbe3-4d1a-641d-d05f-1ba4ee529da8")
local ethelFlag = false
local kethericFlag = false
local kethericRolledApostleFlag = false
local gmBroadcastProtection = false

if exandriaCheck then
	MCM.Set("soe_loaded", true)
else
	MCM.Set("soe_loaded", false)
end

difficultyTables = { 
	{ name = "zero", weight = MCM.Get("zero_weight"), enemies = {}},
	{ name = "low", weight = MCM.Get("one_weight"), enemies = {}},
	{ name = "mid", weight = MCM.Get("two_weight"), enemies = {}},
	{ name = "high", weight = MCM.Get("three_weight"), enemies = {}},
	{ name = "ultra", weight = MCM.Get("four_weight"), enemies = {}},
	{ name = "epic", weight = MCM.Get("five_weight"), enemies = {}},
	{ name = "legendary", weight = MCM.Get("six_weight"), enemies = {}},
	{ name = "mythical", weight = MCM.Get("seven_weight"), enemies = {}},
	{ name = "divine", weight = MCM.Get("eight_weight"), enemies = {}},
	{ name = "avatar", weight = MCM.Get("nine_weight"), enemies = {}},
}

rarityTables = { 
	{ name = "Common", weight = MCM.Get("common_weight"), items = {}},
	{ name = "Uncommon", weight = MCM.Get("uncommon_weight"), items = {}},
	{ name = "Rare", weight = MCM.Get("rare_weight"), items = {}},
	{ name = "VeryRare", weight = MCM.Get("veryrare_weight"), items = {}},
	{ name = "Legendary", weight = MCM.Get("legendary_weight"), items = {}},
}


if MCM.Get("vanilla_mon") then
	for _, monster in ipairs(baseMonsterList) do	
		table.insert(activeMonsterList, monster)
	end
end
if MCM.Get("att_mon") then
	for _, monster in ipairs(tabletopMonsterList) do	
		table.insert(activeMonsterList, monster)
	end
end
if MCM.Get("soe_mon") and exandriaCheck then
	for _, monster in ipairs(exandriaMonsterList) do	
		table.insert(activeMonsterList, monster)
	end
end
for _, item in ipairs(rootTemplateItemList) do	
	table.insert(activeItemList, item)
end
if MCM.Get("att_loot") then
	for _, item in ipairs(aTTRootTemplateItemList) do	
		table.insert(activeItemList, item)
	end
end
if MCM.Get("soe_loot") and exandriaCheck then
	for _, item in ipairs(exandriaRootTemplateItemList) do	
		table.insert(activeItemList, item)
	end
end

-- Utility functions
function setEnemyTables()
	for _, tier in ipairs(difficultyTables) do
		tier.enemies = {}
		for _, enemy in ipairs(activeMonsterList) do
			if tier.name == enemy.Tier then
				table.insert(tier.enemies, enemy.TemplateId)
			end
		end
	end
end

function setRarityTables()
	for _, tier in ipairs(rarityTables) do
		tier.items = {}
		for _, item in ipairs(nonUniqueItems) do
			if tier.name == item.Rarity then
				table.insert(tier.items, item.RootTemplate)
			end
		end
	end
end

function initialize()
	if MCM.Get("preset_normal") and not (MCM.Get("preset_hard") or MCM.Get("preset_extreme") or MCM.Get("advanced_mode")) then
		MCM.Set("enemy_tier_boost", 0) 
		MCM.Set("boss_tier_boost", 1) 
		MCM.Set("enemy_tier_min", 1)
		MCM.Set("enemy_tier_max", 1)
	end
	
	if not MCM.Get("advanced_mode") then
		MCM.Set("zero_weight", 14)
		MCM.Set("one_weight", 18)
		MCM.Set("two_weight", 16)
		MCM.Set("three_weight", 16)
		MCM.Set("four_weight", 14)
		MCM.Set("five_weight", 10)
		MCM.Set("six_weight", 6)
		MCM.Set("seven_weight", 4)
		MCM.Set("eight_weight", 2)
		MCM.Set("nine_weight", 1)
	end
	
	if not PersistentVars then
		PersistentVars = {}
	end
	if not PersistentVars.currentlyRandomizedEnemyTable then
		PersistentVars.currentlyRandomizedEnemyTable = {}
	end
	if not PersistentVars.spawnedEnemyTable then
		PersistentVars.spawnedEnemyTable = {}
	end
	if not PersistentVars.deadRandomTable then
		PersistentVars.deadRandomTable = {}
	end
	if not PersistentVars.usedBossTable then
		PersistentVars.usedBossTable = {}
	end
	if not PersistentVars.turnHelperCollection then
		PersistentVars.turnHelperCollection = {}
	end
	if not PersistentVars.currentCombatMembers then
		PersistentVars.currentCombatMembers = {}
	end
	if not PersistentVars.gameMaster then
		PersistentVars.gameMaster = ""
	end
	if not PersistentVars.randomizedItemTable then
		PersistentVars.randomizedItemTable = {}
	end
	if not PersistentVars.existingMappedItemTable then
		PersistentVars.existingMappedItemTable = {}
	end
end

function rerollSeed()
	local rand_1 = math.random(1, 16777216)
	local rand_2 = math.random(1, 16777216)
	local rand_3 = math.random(1, 16777216)

	local seed = rand_1 + rand_2 + rand_3


	local iter = math.floor(tonumber(tostring(tonumber(tostring({}):gsub("table: ", ""), 16) / 0xFFFFFFF))+seed)
	local iterMod = math.random(1, 2500)

	local iterFinal = iter % iterMod

	for i = 1, iterFinal do
		math.random()
	end

	local finalseed = math.random(1, 4294967296)

	RNG:init(finalseed)

	for i = 1, math.random(3,23) do
		RNG:random()
	end
	local seed = RNG:random(1, 2147483647)
	MCM.Set("rando_seed", seed)
	Hash.gameSeed = seed
end

function initializeItemMap()
	if not Hash.gameSeed then
		local seed = MCM.Get("rando_seed")
		if seed == 0 then
			rerollSeed()
		else
			Hash.gameSeed = seed
		end
	end
	local players = nil
	pcall(function()
		players = Osi.DB_Players:Get(nil)
	end)
	-- Make player inventories ineligible for randomization if initialized mid save-file
	if players then
		for _, entry in ipairs(players) do
			local playerItems = Ext.Entity.Get(entry[1]).InventoryOwner.PrimaryInventory.InventoryContainer.Items
			for _, item in ipairs(playerItems) do
				local ownedItem = item.Item.Uuid.EntityUuid
				PersistentVars.existingMappedItemTable[ownedItem] = true
			end
		end
	end
	mappedUniqueItems, nonUniqueItems = Hash:createUniqueItemMapping(activeItemList)
	setRarityTables()
end

initializeItemMap()

function regenerateItemMap()
	mappedUniqueItems = {}
	nonUniqueItems = {}
	local players = nil
	pcall(function()
		players = Osi.DB_Players:Get(nil)
	end)
	if players then
		for _, entry in ipairs(players) do
			local playerItems = Ext.Entity.Get(entry[1]).InventoryOwner.PrimaryInventory.InventoryContainer.Items
			for _, item in ipairs(playerItems) do
				local ownedItem = item.Item.Uuid.EntityUuid
				PersistentVars.existingMappedItemTable[ownedItem] = true
			end
		end
	end
	mappedUniqueItems, nonUniqueItems = Hash:createUniqueItemMapping(activeItemList)
	setRarityTables()
end

function gameLoaded()
	Host = Osi.GetHostCharacter()
	playerFaction = Osi.GetFaction(Host)
	Channels.SeedRoller:Broadcast()
	initializeItemMap()
end

function strip_uuid(uuid)
	character_uuid = string.sub(uuid, -36)
	return character_uuid
end

function clearIconTables()
	for i, uuid in ipairs(PersistentVars.turnHelperCollection) do
		Channels.IconReplacer:Broadcast(uuid)
	end
	local success, result = pcall(function()
		if #iconTable > 0 then
			for i, uuid in ipairs(iconTable) do
				Channels.IconReplacer:Broadcast(uuid)
			end
			iconTable = {}
		end
	end)
	if not success then
		print("ERROR during icon clearing: ", result)
	end
end

function clearHelperIconTable()
	if not gmBroadcastProtection then
		gmBroadcastProtection = true
		for i, uuid in ipairs(PersistentVars.turnHelperCollection) do
			Channels.IconReplacer:Broadcast(uuid)
		end
		gmBroadcastProtection = false
	end
end

function loadMonsterTable(monsterTable)
	for _, monster in ipairs(monsterTable) do	
		table.insert(activeMonsterList, monster)
	end
end

function unloadMonsterTable(monsterTable)
	local monstersToRemove = {}
	for _, monster in ipairs(monsterTable) do
		monstersToRemove[monster.TemplateId] = true
	end
	for i = #activeMonsterList, 1, -1 do
		if monstersToRemove[activeMonsterList[i].TemplateId] then
			table.remove(activeMonsterList, i)
		end
	end
end

function loadItemTable(itemTable)
	for _, item in ipairs(itemTable) do	
		table.insert(activeItemList, item)
	end
end

function unloadItemTable(itemTable)
	local itemsToRemove = {}
	for _, item in ipairs(itemTable) do
		itemsToRemove[item.RootTemplate] = true
	end
	for i = #activeItemList, 1, -1 do
		if itemsToRemove[activeItemList[i].RootTemplate] then
			table.remove(activeItemList, i)
		end
	end
end

function gmTurnHelper(index)
	local x, y, z = Osi.GetPosition(PersistentVars.gameMaster)
	local x2, y2, z2 = Osi.FindValidPosition(x, y, z, 100, PersistentVars.gameMaster, 1)
    local turnhelper = Osi.CreateAt("3f0377a6-1bf5-4e9e-a186-d2a934f0a0c0", x2, y2, z2, 0, 1, "")
	
    if not turnhelper then
        return
    end
	
	local gmFaction = Osi.GetFaction(PersistentVars.gameMaster)

    Osi.SetTag(turnhelper, "9787450d-f34d-43bd-be88-d2bac00bb8ee") -- AI_UNPREFERRED_TARGET
    Osi.SetFaction(turnhelper, gmFaction)
	
	Osi.ApplyStatus(turnhelper, "AER_TURNHELPER", -1.0)
	
	local players = Osi.DB_Players:Get(nil)
	for _, entry in ipairs(players) do
		local player = strip_uuid(entry[1])
		if player ~= PersistentVars.gameMaster then
			Osi.SetHostileAndEnterCombat(gmFaction, "9fac6ec7-642b-3553-1bc8-6b8e0edae7d5", turnhelper, player)
			Ext.Entity.Get(turnhelper).CombatParticipant.InitiativeRoll = index
			Ext.Entity.Get(turnhelper):Replicate("CombatParticipant")
		end
	end


	return turnhelper
end

function removeHelpersFromCombat()
	for _, item in ipairs(PersistentVars.turnHelperCollection) do
		Osi.ApplyStatus(item, "ATT_ETHEREALNESS", -1.0)
	end
end

function createTurnHelperList()
	if next(PersistentVars.turnHelperCollection) == nil then
		for i = 1, 15 do
			local turnhelper = gmTurnHelper(i)
			PersistentVars.turnHelperCollection[i] = turnhelper
		end
	end
	Ext.Timer.WaitFor(5000, removeHelpersFromCombat)
end

function removeTurnHelper()
	for _, item in ipairs(PersistentVars.turnHelperCollection) do
		Osi.RemoveStatus(item, "ATT_ETHEREALNESS")
		Osi.RemoveStatus(item, "AER_TURNHELPER")
		Osi.SetOnStage(item, 0)
		Osi.Die(item, 2, "NULL_00000000-0000-0000-0000-000000000000", 0, 1)
	end
	PersistentVars.turnHelperCollection = {}
end

function removeTurnHelperCheck()
	if next(PersistentVars.currentCombatMembers) == nil then
		removeTurnHelper()
	end
end

function startCombat()
	if MCM.Get("gm_mode") and next(PersistentVars.turnHelperCollection) == nil then
		if next(PersistentVars.turnHelperCollection) == nil then
			Ext.Timer.WaitFor(400, function()
				createTurnHelperList()
			end)
		end
		Ext.Timer.WaitFor(4000, clearHelperIconTable)
	end
	local map = Osi.GetRegion(Host)
	for monster, _ in pairs(PersistentVars.spawnedEnemyTable) do
		if not PersistentVars.currentCombatMembers[monster] then
			PersistentVars.currentCombatMembers[monster] = true
			Ext.Timer.WaitFor(200, function()
				Osi.RemoveStatus(monster, "AER_INVULNERABLE")
			end)
			local missingHP = 0

			local players = Osi.DB_PartyMembers:Get(nil)
			local player, distance = Osi.GetClosestPlayer(monster)
			if (distance and player) then
				if distance < 200 then
					for key, val in pairs(PersistentVars.currentlyRandomizedEnemyTable) do
						character_uuid = strip_uuid(monster)
						if val[1] == character_uuid then
							-- I know this is inefficient don't @ me
							pcall(function()
								missingHP = Osi.GetMaxHitpoints(key) - Osi.GetHitpoints(key)				
							end)
							if statusTable[key] then
								Ext.Timer.WaitFor(300, function()
									Osi.ApplyStatus(monster, "SURPRISED", 6.0, 1, monster)
									statusTable[key] = nil
								end)
							end
						end
					end
					
					if missingHP > 0 and Osi.GetHitpointsPercentage(monster) == 100.0 then
						Ext.Timer.WaitFor(1200, function()
							Osi.ApplyDamage(monster,missingHP,"Force",Host)
						end)
					end
						

					local creatureFaction = Osi.GetFaction(monster)
					if not MCM.Get("gm_mode") then
						for _, entry in ipairs(players) do
							local partymember = strip_uuid(entry[1])
							if Osi.GetDistanceTo(partymember, monster) < 200 then
								local partyFaction = Osi.GetFaction(partymember)
								Osi.SetHostileAndEnterCombat(creatureFaction, partyFaction, monster, partymember)
							end
						end
					else
						if creatureFaction then
							Osi.SetFaction(PersistentVars.gameMaster, creatureFaction)
						end
						print("Adding GM minion: ", monster)
						Osi.AddPartyFollower(monster, PersistentVars.gameMaster)
						for _, entry in ipairs(players) do
							local player = strip_uuid(entry[1])
							local playerFaction = Osi.GetFaction(player)
							if player ~= PersistentVars.gameMaster then
								Osi.SetHostileAndEnterCombat(creatureFaction, playerFaction, monster, player)
							end
						end
					end
				end
			end
		end
	end
end

function startCombatTemp()
	if MCM.Get("gm_mode") and next(PersistentVars.turnHelperCollection) == nil then
		if next(PersistentVars.turnHelperCollection) == nil then
			Ext.Timer.WaitFor(400, function()
				createTurnHelperList()
			end)
		end
		Ext.Timer.WaitFor(4000, clearHelperIconTable)
	end
	local map = Osi.GetRegion(Host)
	for monster, _ in pairs(PersistentVars.spawnedEnemyTable) do
		if not PersistentVars.currentCombatMembers[monster] then
			PersistentVars.currentCombatMembers[monster] = true
			Ext.Timer.WaitFor(200, function()
				Osi.RemoveStatus(monster, "AER_INVULNERABLE")
			end)
			local missingHP = 0
			
			local players = Osi.DB_PartyMembers:Get(nil)
			local player, distance = Osi.GetClosestPlayer(monster)
			if (distance and player) then
				if distance < 200 then
					for key, val in pairs(PersistentVars.currentlyRandomizedEnemyTable) do
						character_uuid = strip_uuid(monster)
						if val[1] == character_uuid then
							pcall(function()
								missingHP = Osi.GetMaxHitpoints(key) - Osi.GetHitpoints(key)				
							end)
							if statusTable[key] then
								Ext.Timer.WaitFor(300, function()
									Osi.ApplyStatus(monster, "SURPRISED", 6.0, 1, monster)
									statusTable[key] = nil
								end)
							end
						end
					end
					
					if missingHP > 0 and Osi.GetHitpointsPercentage(monster) == 100.0 then
						Ext.Timer.WaitFor(1200, function()
							Osi.ApplyDamage(monster,missingHP,"Force",Host)
						end)
					end
						

					local creatureFaction = Osi.GetFaction(monster)
					if not MCM.Get("gm_mode") then
						for _, entry in ipairs(players) do
							local partymember = strip_uuid(entry[1])
							if Osi.GetDistanceTo(partymember, monster) < 100 then
								Osi.PROC_SetRelationTemporaryHostile(monster,partymember)
								Osi.EnterCombat(monster,partymember)
								Osi.EnterCombat(partymember,monster)
							end
						end
					else
						if creatureFaction then
							Osi.SetFaction(PersistentVars.gameMaster, creatureFaction)
						end
						print("Adding GM minion: ", monster)
						Osi.AddPartyFollower(monster, PersistentVars.gameMaster)
						for _, entry in ipairs(players) do
							local partymember = strip_uuid(entry[1])
							local playerFaction = Osi.GetFaction(partymember)
							if player ~= PersistentVars.gameMaster then
								Osi.SetHostileAndEnterCombat(creatureFaction, playerFaction, monster, partymember)
							end
						end
					end
				end
			end
		end
	end
end

function startCombatNarrative()
	if MCM.Get("gm_mode") and next(PersistentVars.turnHelperCollection) == nil then
		if next(PersistentVars.turnHelperCollection) == nil then
			Ext.Timer.WaitFor(400, function()
				createTurnHelperList()
			end)
		end
		Ext.Timer.WaitFor(4000, clearHelperIconTable)
	end
	local map = Osi.GetRegion(Host)
	for monster, _ in pairs(PersistentVars.spawnedEnemyTable) do
		if not PersistentVars.currentCombatMembers[monster] then
			PersistentVars.currentCombatMembers[monster] = true
			Ext.Timer.WaitFor(200, function()
				Osi.RemoveStatus(monster, "AER_INVULNERABLE")
			end)
			local success, result = false
			local missingHP = 0
			for key, val in pairs(PersistentVars.currentlyRandomizedEnemyTable) do
				character_uuid = strip_uuid(monster)
				if val[1] == character_uuid then
					val[5] = true
					success, result = pcall(function()
						local entity = Ext.Entity.Get(key)
						local narrativeCombatId = entity.CombatParticipant.CombatHandle.CombatState.MyGuid
						if narrativeCombatId then
							Osi.SetInNarrativeCombat(val[1], narrativeCombatId, 1)
							return true
						else
							return false
						end
					end)
					pcall(function()
						missingHP = Osi.GetMaxHitpoints(key) - Osi.GetHitpoints(key)				
					end)
					if statusTable[key] then
						Ext.Timer.WaitFor(300, function()
							Osi.ApplyStatus(monster, "SURPRISED", 6.0, 1, monster)
							statusTable[key] = nil
						end)
					end
				end
			end
			
			if missingHP > 0 and Osi.GetHitpointsPercentage(monster) == 100.0 then
				Ext.Timer.WaitFor(1200, function()
					Osi.ApplyDamage(monster,missingHP,"Force",Host)
				end)
			end
				
			local creatureFaction = Osi.GetFaction(monster)
			if not MCM.Get("gm_mode") then
				if not (success and result) then
					pcall(function()
						local entity = Ext.Entity.Get(Host)
						local narrativeCombatId = entity.CombatParticipant.CombatHandle.CombatState.MyGuid
						Osi.SetInNarrativeCombat(monster, narrativeCombatId, 1)
					end)
				end
			else
				local players = Osi.DB_PartyMembers:Get(nil)
				if creatureFaction then
					Osi.SetFaction(PersistentVars.gameMaster, creatureFaction)
				end
				Osi.AddPartyFollower(monster, PersistentVars.gameMaster)
				print("Adding GM minion: ", monster)
				for _, entry in ipairs(players) do
					local player = strip_uuid(entry[1])
					if player ~= PersistentVars.gameMaster then
						pcall(function()
							local entity = Ext.Entity.Get(player)
							local narrativeCombatId = entity.CombatParticipant.CombatHandle.CombatState.MyGuid
							Osi.SetInNarrativeCombat(monster, narrativeCombatId, 1)
						end)
					end
				end
			end
		end
	end
end

function getAsylum(region)
	local asylum = {}

	if region == C.Regions.Act0 then
        asylum = C.Asylum.Act0
    elseif region == C.Regions.Act1 then
        asylum = C.Asylum.Act1
    elseif region == C.Regions.Act1b then
        asylum = C.Asylum.Act1b
    elseif region == C.Regions.Act2 then
        asylum = C.Asylum.Act2
    elseif region == C.Regions.Act2b then
        asylum = C.Asylum.Act2b
    elseif region == C.Regions.Act3 then
        asylum = C.Asylum.Act3
    elseif region == C.Regions.Act3b then
        asylum = C.Asylum.Act3b
    elseif region == C.Regions.Act3c then
        asylum = C.Asylum.Act3c
    elseif region == C.Regions.Act3i then
        asylum = C.Asylum.Act3i
    end
	
	return asylum
end

function trimTable(index, difficultyTables, minimum, maximum)
	local newTable = {}
    local keepList = {}

    for i = 1, minimum do
        if index - i >= 1 then
            table.insert(keepList, index - i)
        end
    end
    
    table.insert(keepList, index)

    for i = 1, maximum do
        if index + i <= #difficultyTables then
            table.insert(keepList, index + i)
        end
    end
    
    local keepSet = {}
    for _, idx in ipairs(keepList) do
        keepSet[idx] = true
    end
    
    for i, tier in ipairs(difficultyTables) do
        if keepSet[i] then
            table.insert(newTable, tier)
        end
    end
    
    return newTable
end



function selectCreature(character)
	local lookupFlag = false
	local ethelLookupFlag = false
	local aggroFlag = false
	local returnFlag = false
	local countermeasureFlag = false
	local actThreeMiniBossFlag = false
	local superbossFlag = false
	local aerTemplateId = ""
	local boss = false
	
	local level = Osi.GetLevel(character)

	if not level then
		return
	end
	
	local map = Osi.GetRegion(Host)
	local asylum = getAsylum(map)
	
	if Osi.IsHitProxy(character) == 1 then
		Osi.TeleportToPosition(character, asylum.asylumX, asylum.asylumY, asylum.asylumZ, "", 0, 0, 0, 0, 1)
		return
	end
	
	local index = nil
	
	if MCM.Get("chaos_mode") then
		return Hash:selectEnemy(character, difficultyTables, true)
	end
	
	if Ext.Entity.Get(character).CombatParticipant.Flags.IsBoss then
		boss = true
	end

	local levelmin = MCM.Get("enemy_tier_min")
	local levelmax = MCM.Get("enemy_tier_max")
	
	strippedUUID = strip_uuid(character)
	
	local lookup = uniqueMonsterLookup[strippedUUID]
	if lookup then
		index = lookup.index
		boss = lookup.boss
		lookupFlag = lookup.lookupFlag
		ethelLookupFlag = lookup.ethelLookupFlag
		aggroFlag = lookup.aggroFlag
		returnFlag = lookup.returnFlag
		countermeasureFlag = lookup.countermeasureFlag
		actThreeMiniBossFlag = lookup.actThreeMiniBossFlag
		superbossFlag = lookup.superbossFlag
		aerTemplateId = lookup.aerTemplateId
	end
	
	if returnFlag then
		return "returnstring"
	end
	
	if countermeasureFlag and Osi.DB_END_BrainBattle_DominationDone:Get(1)[1] then
		return "returnstring"
	end

	if not lookupFlag then
		if level < 2 then
			index = 1 -- zero
		elseif level < 4 then
			index = 2 -- low
		elseif level < 6 then
			index = 3 -- mid
		elseif level < 8 then
			index = 4 -- high
		elseif level < 11 and (map == C.Regions.Act3 or map == C.Regions.Act3b) then
			index = 4 -- high
		elseif level < 13 then
			index = 5 -- ultra
		elseif level < 15 then
			index = 6 -- epic
		elseif level < 18 then
			index = 7 -- legendary
		elseif level < 23 then
			index = 8 -- mythical
		elseif level < 27 then
			index = 9 -- divine
		else
			index = 10 -- avatar
		end
	end
	
	if ethelLookupFlag then
		if map == C.Regions.Act3b then
			index = 6
		else
			levelmin = levelmin - 1
		end
	end

	local apostleFlag = Osi.HasActiveStatus(character, "MOO_KETHERIC_APOSTLEFORM") == 1
	local slayerFlag = Osi.HasActiveStatus(character, "LOW_BHAALTEMPLE_ORINSLAYER") == 1

	if map == C.Regions.Act0 and index > 1 then
		levelmax = levelmax - 1
	elseif map == C.Regions.Act3i then
		levelmax = levelmax - 1
	elseif map == C.Regions.Act3c and index < 5 then
		levelmin = levelmin - 1
	end
	
	pcall(function()
		local charTemplate = Osi.GetTemplate(character)
		local charTemplateUUID = strip_uuid(charTemplate)
		if charTemplateUUID == "27385ea6-d768-47ce-91b8-8d957c0aabd9" or charTemplateUUID == "70417e3e-9278-4f96-a1d8-5bd90bf5d07a" then
			levelmax = levelmax - 1
		end
	end)

	if boss then
		index = index + MCM.Get("boss_tier_boost")
		if not superbossFlag then
			local nextIndex = index + 1
			local nextNextIndex = index + 2
			if nextIndex < 11 then
				difficultyTables[nextIndex].weight = difficultyTables[nextIndex].weight + 6
			end
			if nextNextIndex < 11 then
				difficultyTables[nextNextIndex].weight = difficultyTables[nextNextIndex].weight + 4
			end
		end
	else
		index = index + MCM.Get("enemy_tier_boost")
	end

	if actThreeMiniBossFlag and not apostleFlag then
		levelmax = levelmax - 1
	end
	
	if superbossFlag then
		levelmin = levelmin - 1
		difficultyTables[8].weight = difficultyTables[8].weight * 4
		difficultyTables[9].weight = difficultyTables[9].weight * 5
		difficultyTables[10].weight = (difficultyTables[10].weight * 6) + 6
	end

	local newTable = trimTable(index, difficultyTables, levelmin, levelmax)
	
	if boss and not superbossFlag then
		local nextIndex = index + 1
		local nextNextIndex = index + 2
		if nextIndex < 11 then
			difficultyTables[nextIndex].weight = difficultyTables[nextIndex].weight - 6
		end
		if nextNextIndex < 11 then
			difficultyTables[nextNextIndex].weight = difficultyTables[nextNextIndex].weight - 4
		end
	end
	
	if superbossFlag then
		difficultyTables[8].weight = difficultyTables[8].weight / 4
		difficultyTables[9].weight = difficultyTables[9].weight / 5
		difficultyTables[10].weight = (difficultyTables[10].weight - 6)  / 6
	end

	local newEnemy = nil

	if apostleFlag then
		newEnemy = Hash:selectEnemy("KETHERICPHASETWO", newTable, false)
	else
		newEnemy = Hash:selectEnemy(character, newTable, false)
	end

	if boss and MCM.Get("unique_bosses") and not ethelFlag then
		local salt = 0
		if kethericFlag or strippedUUID ~= "e9918f3e-5b87-40a3-a9bd-61545151573f" then
			while PersistentVars.usedBossTable[newEnemy] == true do
				if salt > 18650 then
					print(character, " could not find an unused boss in acceptable ranges. Exiting loop without randomizing.")
					return
				end
				salt = salt + 373
				newEnemy = Hash:selectEnemy(salt, newTable, false)
			end
		end
		PersistentVars.usedBossTable[newEnemy] = true
	end
	if apostleFlag and newEnemy == "30d6a794-fbf1-453d-9e3f-35b51058cd15" then
		kethericRolledApostleFlag = true
		return
	elseif slayerFlag and newEnemy == "7201d8fd-f4b2-40b3-8416-714b156e2088" then
		print(character, " rolled their own template: ", newEnemy, ". Exiting loop without randomizing.")
		return "returnstring"
	elseif aerTemplateId == newEnemy then
		print(character, " rolled their own template: ", newEnemy, ". Exiting loop without randomizing.")
		return "returnstring"
	end
	return newEnemy, aggroFlag
end

function spawnNewCreature(character, x, y, z, asylum)
	local spawnId, aggro = selectCreature(character)
	
	
	if spawnId == "returnstring" then
		return "returnstring"
	end
	if not spawnId then
		if Osi.IsCharacter(character) == 1 and Osi.IsHitProxy(character) == 0 and not kethericRolledApostleFlag then
			print("ERROR: ", character, " failed to randomize!")
		end
		return
	end
	
	local newCreatureId = Osi.CreateAt(spawnId, asylum.asylumX, asylum.asylumY, asylum.asylumZ, 0, 1, "")
	
	if not newCreatureId then
		print("SPAWN ERROR: ", character, " failed to spawn randomized ", spawnId)
		return
	end
	
	local x2, y2, z2 = Osi.FindValidPosition(x, y, z, 100, Host, 1)
	
	Ext.Timer.WaitFor(300, function()
		Osi.TeleportToPosition(newCreatureId, x2, y2, z2, "", 0, 0, 0, 0, 1)
	end)

	return newCreatureId, aggro
end

function spawnNewCreatureOnNautiloid(character, x, y, z)
	local spawnId, aggro = selectCreature(character)
	
	
	if spawnId == "returnstring" then
		return "returnstring"
	end
	if not spawnId then
		if Osi.IsCharacter(character) == 1 and Osi.IsHitProxy(character) == 0 and not kethericRolledApostleFlag then
			print("ERROR: ", character, " failed to randomize!")
		end
		return
	end
	
	local x2, y2, z2 = Osi.FindValidPosition(x, y, z, 100, Host, 1)
	local newCreatureId = Osi.CreateAt(spawnId, x2, y2, z2, 0, 1, "")
	
	if not newCreatureId then
		print("SPAWN ERROR: ", character, " failed to spawn randomized ", spawnId)
		return
	end

	return newCreatureId, aggro
end

function randomizeCreature(character)
	local x, y, z = Osi.GetPosition(character)
	if not Host then
		Host = Osi.GetHostCharacter()
	end
	local map = Osi.GetRegion(Host)
	local asylum = getAsylum(map)
	if next(asylum) == nil then
		print("ERROR: Asylum not found. The randomizer cannot support an unknown map.")
		return
	end
	local combatGroup = ""
	
	local entitySuccess, entityResult = pcall(function()
		combatGroup = Ext.Entity.Get(character).CombatParticipant.CombatGroupId
	end)
	
	if not entitySuccess then
		print("ERROR while accessing entity for ", character, ":", entityResult)
	end

	if PersistentVars.currentlyRandomizedEnemyTable[character] then
		return PersistentVars.currentlyRandomizedEnemyTable[character][1]
	end

	local newCreature = nil
	local aggro = nil

	if map == C.Regions.Act0 then
		newCreature, aggro = spawnNewCreatureOnNautiloid(character, x, y, z)
	else
		newCreature, aggro = spawnNewCreature(character, x, y, z, asylum)
	end

	if newCreature == "returnstring" then
		return
	end
	-- TODO: set a loop here to catch terrain spawning problems
	if not newCreature then
		if Osi.IsCharacter(character) == 1 and Osi.IsHitProxy(character) == 0 then
			print("ERROR: ", character, " failed to spawn!")
		end
		return
	end

	Ext.Entity.Get(newCreature).CombatParticipant.CombatGroupId = combatGroup
	Ext.Entity.Get(newCreature):Replicate("CombatParticipant")
	
	PersistentVars.spawnedEnemyTable[newCreature] = true
	PersistentVars.currentlyRandomizedEnemyTable[character] = {newCreature, x, y, z}

	if Osi.HasActiveStatus(character, "MOO_KETHERIC_INVULNERABLE") == 0 and not PersistentVars.currentCombatMembers[newCreature] then
		Osi.ApplyStatus(newCreature, "AER_INVULNERABLE", -1.0,1)
	else
		local percentage = Osi.GetHitpointsPercentage("S_MOO_Ketheric_e9918f3e-5b87-40a3-a9bd-61545151573f")
		Osi.SetHitpointsPercentage(newCreature, percentage)
	end
	Osi.TeleportToPosition(character, asylum.asylumX, asylum.asylumY, asylum.asylumZ, "", 0, 0, 0, 0, 1)
	
	character_uuid = strip_uuid(character)
	table.insert(iconTable, character_uuid)
	Ext.Timer.WaitFor(2400, clearIconTables)
	
	-- heavily incentivise Zhalk to aggro Mind Flayer
	if character == "S_TUT_Helm_Devil_005_ed103005-fd71-457d-ae6c-39654bbd8f2e" then
		Osi.RequestSetBaseArchetype(newCreature, "cinematic_melee")
		Osi.ApplyStatus(newCreature, "AER_ZHALK_FIX", -1.0, 1, newCreature)
	elseif character == "S_END_MindBrain_f8bb04a3-22e5-41b0-aed7-5dcf852343d1" then
		-- send Netherbrain's random to the correct location
		Osi.TeleportToPosition(newCreature, 219, -61, 4255, "", 0, 0, 0, 0, 1)
	end
	
	if aggro then
		Osi.ApplyStatus(newCreature, "MADNESS", -1.0,1, newCreature)
	end
	
	Ext.Timer.WaitFor(400, function()
		local success, result = pcall(function()
			-- UNDEAD OR CONSTRUCT
			if Osi.IsTagged(newCreature, "33c625aa-6982-4c27-904f-e47029a9b140") == 1 or Osi.IsTagged(newCreature, "22e5209c-eaeb-40dc-b6ef-a371794110c2") == 1 then
				Osi.SetTag(newCreature, "b47643e0-583c-4808-b108-f6d3b605b0a9") -- ACT2_SHADOW_CURSE_IMMUNE
			elseif Osi.HasActiveStatus(character, "SCL_SHADOW_CURSE_UNDEAD_NEW_HALSINLAKESIDE") == 1 then
				Osi.ApplyStatus(newCreature, "SCL_SHADOW_CURSE_UNDEAD_NEW_HALSINLAKESIDE", -1.0)
			elseif Osi.HasActiveStatus(character, "SCL_SHADOW_CURSE_UNDEAD_NEW") == 1 then
				Osi.ApplyStatus(newCreature, "SCL_SHADOW_CURSE_UNDEAD_NEW", -1.0)
			end
		end)
		if not success then
			print("ERROR on Shadow Curse Check: ", result)
		end
	end)
	
	return newCreature
end

setEnemyTables()

if MCM.Get("rando_seed") == 0 then
	rerollSeed()
else
	Hash.gameSeed = MCM.Get("rando_seed")
end

print("Seed:", Hash.gameSeed)

Ext.ModEvents.BG3MCM["MCM_Setting_Saved"]:Subscribe(function(payload)
    if not payload or payload.modUUID ~= ModuleUUID or not payload.settingId then
        return
    end
	-- Update monster tables if toggles change
	local changeTables = false
    if payload.settingId == "vanilla_mon" then
        if payload.value and not payload.oldValue then
			loadMonsterTable(baseMonsterList)
			changeTables = true
		elseif payload.oldValue and not payload.value then
			unloadMonsterTable(baseMonsterList)
			changeTables = true
		end
    end
	if payload.settingId == "att_mon" then
        if payload.value and not payload.oldValue then
			local soeCheck = MCM.Get("soe_mon")
			if soeCheck then
				unloadMonsterTable(exandriaMonsterList)
			end
			loadMonsterTable(tabletopMonsterList)
			if soeCheck then
				loadMonsterTable(exandriaMonsterList)
			end
			changeTables = true
		elseif payload.oldValue and not payload.value then
			unloadMonsterTable(tabletopMonsterList)
			changeTables = true
		end
    end
	if payload.settingId == "soe_mon" then
        if payload.value and not payload.oldValue then
			loadMonsterTable(exandriaMonsterList)
			changeTables = true
		elseif payload.oldValue and not payload.value then
			unloadMonsterTable(exandriaMonsterList)
			changeTables = true
		end
    end
	-- Update item tables if toggles change
	local changeItemTables = false
	if payload.settingId == "att_loot" then
        if payload.value and not payload.oldValue then
			local soeCheck = MCM.Get("soe_loot")
			if soeCheck then
				unloadItemTable(exandriaRootTemplateItemList)
			end
			loadItemTable(aTTRootTemplateItemList)
			if soeCheck then
				loadItemTable(exandriaRootTemplateItemList)
			end
			changeItemTables = true
		elseif payload.oldValue and not payload.value then
			unloadItemTable(aTTRootTemplateItemList)
			changeItemTables = true
		end
    end
	if payload.settingId == "soe_loot" then
        if payload.value and not payload.oldValue then
			loadItemTable(exandriaRootTemplateItemList)
			changeItemTables = true
		elseif payload.oldValue and not payload.value then
			unloadItemTable(exandriaRootTemplateItemList)
			changeItemTables = true
		end
    end
	
	if payload.settingId == "zero_weight" then
        if payload.value and not payload.oldValue then
			difficultyTables[1].weight = payload.value
		end
    end
	if payload.settingId == "one_weight" then
        if payload.value and not payload.oldValue then
			difficultyTables[2].weight = payload.value
		end
    end
	if payload.settingId == "two_weight" then
        if payload.value and not payload.oldValue then
			difficultyTables[3].weight = payload.value
		end
    end
	if payload.settingId == "three_weight" then
        if payload.value and not payload.oldValue then
			difficultyTables[4].weight = payload.value
		end
    end
	if payload.settingId == "four_weight" then
        if payload.value and not payload.oldValue then
			difficultyTables[5].weight = payload.value
		end
    end
	if payload.settingId == "five_weight" then
        if payload.value and not payload.oldValue then
			difficultyTables[6].weight = payload.value
		end
    end
	if payload.settingId == "six_weight" then
        if payload.value and not payload.oldValue then
			difficultyTables[7].weight = payload.value
		end
    end
	if payload.settingId == "seven_weight" then
        if payload.value and not payload.oldValue then
			difficultyTables[8].weight = payload.value
		end
    end
	if payload.settingId == "eight_weight" then
        if payload.value and not payload.oldValue then
			difficultyTables[9].weight = payload.value
		end
    end
	if payload.settingId == "nine_weight" then
        if payload.value and not payload.oldValue then
			difficultyTables[10].weight = payload.value
		end
    end

	if payload.settingId == "common_weight" then
        if payload.value and not payload.oldValue then
			rarityTables[1].weight = payload.value
		end
    end
	if payload.settingId == "uncommon_weight" then
        if payload.value and not payload.oldValue then
			rarityTables[2].weight = payload.value
		end
    end
	if payload.settingId == "rare_weight" then
        if payload.value and not payload.oldValue then
			rarityTables[3].weight = payload.value
		end
    end
	if payload.settingId == "veryrare_weight" then
        if payload.value and not payload.oldValue then
			rarityTables[4].weight = payload.value
		end
    end
	if payload.settingId == "legendary_weight" then
        if payload.value and not payload.oldValue then
			rarityTables[5].weight = payload.value
		end
    end
	
	if payload.settingId == "preset_normal" then
		if payload.value and not payload.oldValue then
			MCM.Set("preset_hard", false)
			MCM.Set("preset_extreme", false)
			MCM.Set("enemy_tier_boost", 0) 
			MCM.Set("boss_tier_boost", 1)
			MCM.Set("enemy_tier_min", 1)
			MCM.Set("enemy_tier_max", 1)
		end
	end
	if payload.settingId == "preset_hard" then
		if payload.value and not payload.oldValue then
			MCM.Set("preset_normal", false)
			MCM.Set("preset_extreme", false)
			MCM.Set("enemy_tier_boost", 0) 
			MCM.Set("boss_tier_boost", 1)
			MCM.Set("enemy_tier_min", 1)
			MCM.Set("enemy_tier_max", 2)
		end
	end
	if payload.settingId == "preset_extreme" then
		if payload.value and not payload.oldValue then
			MCM.Set("preset_normal", false)
			MCM.Set("preset_hard", false)
			MCM.Set("enemy_tier_boost", 0) 
			MCM.Set("boss_tier_boost", 1)
			MCM.Set("enemy_tier_min", 1)
			MCM.Set("enemy_tier_max", 3)
		end
	end
	if payload.settingId == "advanced_rando_mode" then
		MCM.Set("advanced_mode", payload.value) 
	end
	if payload.settingId == "advanced_mode" then
		MCM.Set("advanced_rando_mode", payload.value) 
	end
	if payload.settingId == "advanced_mode" or payload.settingId == "advanced_rando_mode" then
		if payload.oldValue and not payload.value then
			MCM.Set("preset_normal", true)
			MCM.Set("preset_hard", false)
			MCM.Set("preset_extreme", false)
			MCM.Set("enemy_tier_boost", 0) 
			MCM.Set("boss_tier_boost", 1)
			MCM.Set("enemy_tier_min", 1)
			MCM.Set("enemy_tier_max", 1)
		end
	end
	
	if payload.settingId == "gm_mode" then
		if payload.value then
			PersistentVars.gameMaster = Osi.GetHostCharacter()
			Osi.ApplyStatus(PersistentVars.gameMaster, "ATT_ETHEREALNESS", -1.0)
			Osi.ApplyStatus(PersistentVars.gameMaster, "AER_TURNHELPER", -1.0)
		else
			Osi.RemoveStatus(PersistentVars.gameMaster, "ATT_ETHEREALNESS")
			Osi.RemoveStatus(PersistentVars.gameMaster, "AER_TURNHELPER")
			Osi.SetFaction(PersistentVars.gameMaster, playerFaction)
		end
	end
	
	if changeTables then
		setEnemyTables()
	end
	if changeItemTables then
		regenerateItemMap()
	end
	
	-- Update game seed if value changes
	if payload.settingId == "rando_seed" and payload.value ~= payload.oldValue then
		Hash.gameSeed = MCM.Get("rando_seed")
		regenerateItemMap()
	end
	
	if payload.settingId == "randomize_loot" and payload.value ~= payload.oldValue then
		initializeItemMap()
	end
end)

-- Main function

Ext.Osiris.RegisterListener("EnteredCombat", 2, "after", function(character, _)
	if not MCM.Get("mod_enabled") then
		return
	end
    if Osi.IsPlayer(character) == 1 or Osi.IsPartyFollower(character) == 1 then
        return
    end
	if Osi.IsSummon(character) == 1 and not MCM.Get("randomize_summons") then
		return
	end
	if Osi.HasActiveStatus(character, "LOW_CAZADORSPALACE_RITUAL_CRYSTALLISED") == 1 then
		return
	end
	
	local stripped_template = strip_uuid(Osi.GetTemplate(character))
	if "3f0377a6-1bf5-4e9e-a186-d2a934f0a0c0" == stripped_template then -- Turn Divider
		return
	end
	if "f7b54c47-dc24-47b7-89a8-cfdf72b32354" == stripped_template then -- Arcane Cannon
		return
	end
	if "dc180f8b-9c3d-40e4-97f0-af6759781bcf" == stripped_template then -- Arcane Turret 
		return
	end
	
	character_uuid = strip_uuid(character)

	if kethericFlag and character_uuid == "e9918f3e-5b87-40a3-a9bd-61545151573f" then
		return
	end
	if kethericRolledApostleFlag and character_uuid == "fec67606-9665-4942-b5bb-c211e2e03499" then
		return
	end
	
	if MCM.Get("derandomize_othermod") then
		local success, result = pcall(function()
			local fileName = Ext.Template.GetTemplate(character_uuid).FileName
			for _, pattern in ipairs(C.FileNameRegex) do
				if string.match(fileName, pattern) then
					return true
				end
			end
			return false
		end)
		if not success then
			result = false
			success, result = pcall(function()
				local fileName = Ext.Template.GetTemplate(stripped_template).FileName
				for _, pattern in ipairs(C.FileNameRegex) do
					if string.match(fileName, pattern) then
						return true
					end
				end
				return false
			end)
		end
		if success and not result then
			return
		end
	end

	local map = Osi.GetRegion(character)
	local asylum = getAsylum(map)
	
	if PersistentVars.currentlyRandomizedEnemyTable[character] then
		local spawn = PersistentVars.currentlyRandomizedEnemyTable[character][1]
		if Osi.IsDead(spawn) == 1 then
			return
		end
		local tempx, tempy, tempz = Osi.GetPosition(character)
		
		if not C.DoNotTeleportList[character] then
			Osi.TeleportToPosition(character, asylum.asylumX, asylum.asylumY, asylum.asylumZ, "", 0, 0, 0, 0, 1)
		end
		
		if Osi.IsInCombat(spawn) == 1 then
			local success, mundane = pcall(function()
				local entity = Ext.Entity.Get(character)
				local narrativeCombat = entity.CombatParticipant.CombatHandle.CombatState.IsInNarrativeCombat
				if narrativeCombat then
					local narrativeCombatId = entity.CombatParticipant.CombatHandle.CombatState.MyGuid
					Osi.TeleportToPosition(spawn, PersistentVars.currentlyRandomizedEnemyTable[character][2], PersistentVars.currentlyRandomizedEnemyTable[character][3], PersistentVars.currentlyRandomizedEnemyTable[character][4], "", 0, 0, 0, 0, 1)
					Osi.SetInNarrativeCombat(spawn, narrativeCombatId, 1)
					PersistentVars.currentlyRandomizedEnemyTable[character][5] = true
					return false
				else
					return true
				end
			end)
			return
		end
		local player, distance = Osi.GetClosestPlayer(spawn)
		if (distance and player) then
			if distance > 100 then
				Osi.TeleportToPosition(spawn, tempx, tempy, tempz, "", 0, 0, 0, 0, 1)
			end
		end	
	end
	
	if PersistentVars.deadRandomTable[character_uuid] then
		return
	end

	if PersistentVars.spawnedEnemyTable[character_uuid] then
		local invulnCheckSuccess, invulnCheckResult = pcall(function()
			Ext.Timer.WaitFor(4800, function()
				if Osi.HasActiveStatus(character_uuid, "AER_INVULNERABLE") == 1 then
					Osi.RemoveStatus(character_uuid, "AER_INVULNERABLE")
				end
			end)
		end)
		if not invulnCheckSuccess then
			print("ERROR IN INVULN CHECK: ", invulnCheckResult)
		end
		return
	end
	
	creatureFaction = Osi.GetFaction(character)
	local players = Osi.DB_PartyMembers:Get(nil)
	local realCombat = false
	local narrativeCombat = false
	for _, entry in ipairs(players) do
		local player = entry[1]
		local partyFaction = Osi.GetFaction(player)
		local relationCheckSuccess, relationCheckResult = pcall(function()
			if Osi.GetRelation(creatureFaction, partyFaction) < 40 then
				realCombat = true
			end
		end)
		if not relationCheckSuccess then
			print("ERROR - Faction check failed for: ", player, ",", playerFaction, "-", relationCheckResult)
		end
		pcall(function()
			local entity = Ext.Entity.Get(player)
			if entity.CombatParticipant.CombatHandle.CombatState.IsInNarrativeCombat then
				narrativeCombat = true
			end
        end)
		pcall(function()
			local entity = Ext.Entity.Get(character_uuid)
			if entity.CombatParticipant.CombatHandle.CombatState.IsInNarrativeCombat then
				narrativeCombat = true
			end
        end)
	end
	
	local tempDB = Osi.DB_GLO_Combat_TemporaryHostile:Get(character)

	if tempBattle[character] or next(tempDB) ~= nil then
		newCreature = randomizeCreature(character)
		if not newCreature then
			return
		end
		if Osi.HasActiveStatus(character, "MOO_KETHERIC_INVULNERABLE") == 1 then
			Osi.ApplyStatus(newCreature, "MOO_KETHERIC_INVULNERABLE", -1.0)
		end
		Osi.SetFaction(newCreature, creatureFaction)
		if narrativeCombat then
			Ext.Timer.WaitFor(2400, startCombatNarrative)
		else 
			Ext.Timer.WaitFor(1600, startCombatTemp)
		end
		tempBattle[character] = nil
	elseif realCombat then
		newCreature = randomizeCreature(character)
		if not newCreature then
			return
		end
		if Osi.HasActiveStatus(character, "MOO_KETHERIC_INVULNERABLE") == 1 then
			Osi.ApplyStatus(newCreature, "MOO_KETHERIC_INVULNERABLE", -1.0)
		end
		Osi.SetFaction(newCreature, creatureFaction)
		if narrativeCombat then
			Ext.Timer.WaitFor(2400, startCombatNarrative)
		else 
			Ext.Timer.WaitFor(1600, startCombat)
		end
	elseif MCM.Get("randomize_allies") and map ~= C.Regions.Act3i then
		newCreature = randomizeCreature(character)
		if not newCreature then
			return
		end
		Osi.SetFaction(newCreature, creatureFaction)
		PersistentVars.currentlyRandomizedEnemyTable[character].ally = true
		if narrativeCombat then
			Ext.Timer.WaitFor(2400, startCombatNarrative)
		end
	end
	
	Ext.Timer.WaitFor(3600, function()
		PersistentVars.currentCombatMembers[character_uuid] = true
	end)
end)

-- character handling
Ext.Osiris.RegisterListener("EnteredCombat", 2, "after", function(character, _)
	if not MCM.Get("mod_enabled") then
		return
	end
	
	local stripped_template = strip_uuid(Osi.GetTemplate(character))
	
	-- Handle Viconia's heartmap for the regular version
	if "15d458c4-c51d-4312-8f5a-cf5ba9042e3f" == stripped_template then
		local players = Osi.DB_Players:Get(nil)
		for _, entry in ipairs(players) do
			local player = entry[1]
			Osi.SetTag(player, "8d2d234e-a25a-4a92-b1a1-df5e90b08ebd")
		end
	-- Handle Keene's daggers, which started breaking for some reason (yes they must be separate)
	elseif "26d18c80-cec7-453c-aaa4-e86f54d427f0" == stripped_template then
		for i = 1, 18 do
			Osi.TemplateAddTo("569b0f3d-abcd-4b01-aaf0-979091288163", character, 1, 0)
		end
	end
end)

-- Zlorb in Last Light
Ext.Osiris.RegisterListener("EnteredCombat", 2, "after", function(character, _)
	if not MCM.Get("mod_enabled") then
		return
	end
	
	if character == "S_GLO_DevilishOx_49eb5b4b-c6ed-4d37-8f68-97b1128b7d56" then
		Ext.Timer.WaitFor(1400, function()
			Osi.PROC_SetRelationToPlayers("Act2_HAV_Phasm_9fec6a42-f208-436d-904c-0a3b1843838b", 0)
			Osi.SetFaction("S_GLO_DevilishOx_49eb5b4b-c6ed-4d37-8f68-97b1128b7d56", "Act2_HAV_Phasm_9fec6a42-f208-436d-904c-0a3b1843838b")
			Osi.SetFlag("HAV_DevilishOx_State_MonsterRevealed_32e50fb0-ab45-44cf-86af-3984de34f338", "NULL_00000000-0000-0000-0000-000000000000")
			
			if PersistentVars.currentlyRandomizedEnemyTable["S_GLO_DevilishOx_49eb5b4b-c6ed-4d37-8f68-97b1128b7d56"] then
				local randoZlorb = PersistentVars.currentlyRandomizedEnemyTable["S_GLO_DevilishOx_49eb5b4b-c6ed-4d37-8f68-97b1128b7d56"][1]
				Osi.SetFaction(randoZlorb, "Act2_HAV_Phasm_9fec6a42-f208-436d-904c-0a3b1843838b")
			end
			
			Ext.Timer.WaitFor(2800, function()
				Osi.PROC_SetRelationToPlayers("Act2_HAV_Haven_e52bfc8c-7826-470d-a9f5-f6fae80dde82", 100)
				Osi.PROC_SetRelationToPlayers("Act2_HAV_Tieflings_f4ff1850-c9fc-4ee5-80e7-fa6b2a958d39", 100)
				Osi.PROC_SetRelationToPlayers("ACT2_SCL_HarpersAmbush_f9940d88-f049-4522-a2ae-4b8304e4563c", 100)
				Osi.PROC_SetRelationToPlayers("Act2_HAV_RealOxen_f81a448a-46e0-4d4d-ab72-267f5338d8ce", 100)
				for key, val in pairs(PersistentVars.currentlyRandomizedEnemyTable) do
					local keyFaction = Osi.GetFaction(key)
					if keyFaction == "Act2_HAV_Haven_e52bfc8c-7826-470d-a9f5-f6fae80dde82" then
						Osi.SetFaction(val[1], "Act2_HAV_Haven_e52bfc8c-7826-470d-a9f5-f6fae80dde82")
					elseif keyFaction == "Act2_HAV_Tieflings_f4ff1850-c9fc-4ee5-80e7-fa6b2a958d39" then
						Osi.SetFaction(val[1], "Act2_HAV_Tieflings_f4ff1850-c9fc-4ee5-80e7-fa6b2a958d39")
					elseif keyFaction == "ACT2_SCL_HarpersAmbush_f9940d88-f049-4522-a2ae-4b8304e4563c" then
						Osi.SetFaction(val[1], "ACT2_SCL_HarpersAmbush_f9940d88-f049-4522-a2ae-4b8304e4563c")
					elseif keyFaction == "Act2_HAV_RealOxen_f81a448a-46e0-4d4d-ab72-267f5338d8ce" then
						Osi.SetFaction(val[1], "Act2_HAV_RealOxen_f81a448a-46e0-4d4d-ab72-267f5338d8ce")
					end
				end
			end)
		end)
	end
end)

-- Gerringothe Visages
Ext.Osiris.RegisterListener("EnteredCombat", 2, "after", function(character, _)
	if not MCM.Get("mod_enabled") then
		return
	end
	
	if character == "S_TWN_Tollhouse_Face_Heartlessness_f335ce62-1d8b-4f70-969d-ef75f0dd78b1" then
		Ext.Timer.WaitFor(4800, function()
			Osi.ApplyStatus(character, "AER_VISAGE_ICON", -1.0, 1, character)
			Osi.TeleportTo(character, "S_TWN_Tollhouse_Face_Heartlessness_CombatPosition_e430bf7a-c9d8-451c-bb32-c49a85d92894", "", 0, 0, 0, 0, 1)
		end)
	end
end)
Ext.Osiris.RegisterListener("EnteredCombat", 2, "after", function(character, _)
	if not MCM.Get("mod_enabled") then
		return
	end
	
	if character == "S_TWN_Tollhouse_Face_Guilt_2321affc-6302-4800-87dc-bcd220642920" then
		Ext.Timer.WaitFor(4800, function()
			Osi.ApplyStatus(character, "AER_VISAGE_ICON", -1.0, 1, character)
			Osi.TeleportTo(character, "S_TWN_Tollhouse_Face_Guilt_CombatPosition_1e2717e9-63f6-4760-bf64-620098361d57", "", 0, 0, 0, 0, 1)
		end)
	end
end)
Ext.Osiris.RegisterListener("EnteredCombat", 2, "after", function(character, _)
	if not MCM.Get("mod_enabled") then
		return
	end
	
	if character == "S_TWN_Tollhouse_Face_Obedience_0e35df6f-31f8-4ebb-a44f-e472c2e6a9c9" then
		Ext.Timer.WaitFor(4800, function()
			Osi.ApplyStatus(character, "AER_VISAGE_ICON", -1.0, 1, character)
			Osi.TeleportTo(character, "S_TWN_Tollhouse_Face_Obedience_CombatPosition_a842e8e6-0f54-4560-9785-ad6412af5c3f", "", 0, 0, 0, 0, 1)
		end)
	end
end)
Ext.Osiris.RegisterListener("EnteredCombat", 2, "after", function(character, _)
	if not MCM.Get("mod_enabled") then
		return
	end
	
	if character == "S_TWN_Tollhouse_Face_Cowardice_efea0b12-68eb-4329-8fd9-14078e983607" then
		Ext.Timer.WaitFor(4800, function()
			Osi.ApplyStatus(character, "AER_VISAGE_ICON", -1.0, 1, character)
			Osi.TeleportTo(character, "S_TWN_Tollhouse_Face_Cowardice_CombatPosition_06b03415-2e55-48b9-b3f4-5060dc88ab28", "", 0, 0, 0, 0, 1)
		end)
	end
end)
Ext.Osiris.RegisterListener("EnteredCombat", 2, "after", function(character, _)
	if not MCM.Get("mod_enabled") then
		return
	end
	
	if character == "S_TWN_Tollhouse_Face_Greed_46e0f41a-6603-43ee-8e99-5dd91e7e9bb9" then
		Ext.Timer.WaitFor(4800, function()
			Osi.ApplyStatus(character, "AER_VISAGE_ICON", -1.0, 1, character)
			Osi.TeleportTo(character, "S_TWN_Tollhouse_Face_Greed_CombatPosition_1ea0f0c4-cc31-4db1-866d-5150836a0047", "", 0, 0, 0, 0, 1)
		end)
	end
end)
Ext.Osiris.RegisterListener("EnteredCombat", 2, "after", function(character, _)
	if not MCM.Get("mod_enabled") then
		return
	end
	
	if character == "S_TWN_Tollhouse_Face_Regret_f5206c52-e481-4c2c-b24b-f186904d768d" then
		Ext.Timer.WaitFor(4800, function()
			Osi.ApplyStatus(character, "AER_VISAGE_ICON", -1.0, 1, character)
			Osi.TeleportTo(character, "S_TWN_Tollhouse_Face_Regret_CombatPosition_73f38710-090c-4642-b03e-02ef8fc8f9d5", "", 0, 0, 0, 0, 1)
		end)
	end
end)

-- Ansur's arena
Ext.Osiris.RegisterListener("EnteredCombat", 2, "after", function(character, _)
	if not MCM.Get("mod_enabled") then
		return
	end
	if character == "S_WYR_SkeletalDragon_67770922-5e0a-40c5-b3f0-67e8eb50493a" then
		-- probably unnecessary, but this feels unsafe
		local success, result = pcall(function()
			Ext.Timer.WaitFor(2400, function()
				Osi.SetOnStage("S_WYR_SkeletalDragonBlocker_67511a5c-75f8-496c-81c6-17d4820c2b38", 0)
				Osi.SetOnStage("S_WYR_SkeletalDragonBlocker_000_bdf56ccd-6990-4988-a9ee-792f9fc69a24", 0)
				Osi.SetOnStage("S_WYR_SkeletalDragonBlocker_001_68f502f3-0833-4d48-ac34-38f800a54c63", 0)
				Osi.SetOnStage("S_WYR_SkeletalDragonBlocker_002_342df486-09b7-4259-bc4e-ddc96a010571", 0)
				Osi.SetOnStage("S_WYR_SkeletalDragonBlocker_003_2826c2c1-f846-4320-a76a-8b88558773dc", 0)
				Osi.SetOnStage("S_WYR_SkeletalDragonBlocker_004_6bcdd409-9503-4b1b-a69f-b284b2e4b644", 0)
				Osi.SetOnStage("S_WYR_SkeletalDragonBlocker_005_50bbde3b-48a2-4dcd-be67-f19f612372b3", 0)
				Osi.SetOnStage("S_WYR_SkeletalDragonBlocker_006_e49292d1-3320-47ad-a0a1-c6aea3b839c1", 0)
				Osi.SetOnStage("S_WYR_SkeletalDragonBlocker_007_7215d6ab-0c4f-4c6c-84fe-8a087152078d", 0)
				Osi.SetOnStage("S_WYR_SkeletalDragonBlocker_008_a11d3452-8ac9-4441-8077-54e8d30c046e", 0)
				Osi.SetOnStage("S_WYR_SkeletalDragonBlocker_009_e7162ac4-22f9-4c15-8afb-2a4817982c4d", 0)
				Osi.SetOnStage("S_WYR_SkeletalDragonBlocker_010_b22845fa-8463-4b71-bb25-4e9bc68376e9", 0)
				Osi.SetOnStage("S_WYR_SkeletalDragonBlocker_011_ada3a431-2465-40c6-a380-9afac2bcd128", 0)
				Osi.SetOnStage("S_WYR_SkeletalDragonBlocker_012_c6a9a13e-3fb6-4b88-a6c9-5b7180d463ed", 0)
				Osi.SetOnStage("S_WYR_SkeletalDragonBlocker_014_0ea74d6a-1644-40e2-9fb5-6e88b8445536", 0)
				Osi.SetOnStage("S_WYR_SkeletalDragonBlocker_015_cf2f3042-76d5-4868-b8f5-20413f1b52e5", 0)
			end)
		end)
		if not success then
			print("ERROR preparing Ansur arena: ", result)
		end
	end
end)

Ext.Osiris.RegisterListener("Died", 1, "after", function(character)
	if not MCM.Get("mod_enabled") then
		return
	end
	-- does wildshape ending fire this event? sanity check
	if Osi.IsDead(character) == 0 then
		return
	end
	if "3f0377a6-1bf5-4e9e-a186-d2a934f0a0c0" == strip_uuid(Osi.GetTemplate(character)) then
		return
	end

	character_uuid = strip_uuid(character)

	for key, val in pairs(PersistentVars.currentlyRandomizedEnemyTable) do
		if key == character then
			Osi.Die(val[1], 0, "NULL_00000000-0000-0000-0000-000000000000", 1, 0, 0.0)
			Osi.TeleportToPosition(key, val[2], val[3], val[4], "", 0, 0, 0, 0, 1)
		elseif val[1] == character_uuid then
			if Osi.IsImmortal(key) == 1 then
				if key == "S_WYR_SkeletalDragon_67770922-5e0a-40c5-b3f0-67e8eb50493a" then
					Osi.RemoveStatus(key, "DEATH_WARD_DRAGON_SKELETAL", key)
					Osi.RemoveStatus(key, "STORMHEART_RESOLVE", key)
					Osi.PROC_WYR_SkeletalDragon_RemoveImmortality()
					Ext.Timer.WaitFor(200, function()
						if Osi.IsDead(key) == 0 then
							Osi.ApplyDamage(key,999,"Force",Host)
						end
					end)
				end
				Osi.ApplyDamage(key,999,"Force",Host)
				if key == "S_MOO_Ketheric_e9918f3e-5b87-40a3-a9bd-61545151573f" then
					if Osi.GetFlag("MOO_Assault_Event_KethericTeleportedAway_ba71e8cd-8922-61a4-a2ff-8c5f5ff8aac6", "NULL_00000000-0000-0000-0000-000000000000") == 1 then
						kethericFlag = true
					else
						Osi.PROC_MOO_Assault_KethericLeaves()
					end
				elseif key == "S_GLO_Cazador_2f1880e6-1297-4ca3-a79c-9fabc7f179d3" then
					Ext.Timer.WaitFor(1000, function()
						Osi.PROC_LOW_CazadorsPalace_SendCazadorToCoffin()
					end)
				end
			else
				Osi.Die(key, 0, "NULL_00000000-0000-0000-0000-000000000000", 1, 0, 0.0)
			end
			Osi.TeleportToPosition(key, val[2], val[3], val[4], "", 0, 0, 0, 0, 1)
			Ext.Timer.WaitFor(2400, function()
				Osi.SetOnStage(val[1], 0)
				PersistentVars.currentlyRandomizedEnemyTable[key] = nil
			end)
		end
	end
	if PersistentVars.spawnedEnemyTable[character_uuid] then
		PersistentVars.deadRandomTable[character_uuid] = true
		PersistentVars.spawnedEnemyTable[character_uuid] = nil
	end
	
	if MCM.Get("gm_mode") then
		pcall(function()
			Osi.RemovePartyFollower(character_uuid, PersistentVars.gameMaster)
		end)
	end
	
	PersistentVars.currentCombatMembers[character_uuid] = nil
	
	if next(PersistentVars.currentCombatMembers) == nil and MCM.Get("gm_mode") then
		Ext.Timer.WaitFor(2400, removeTurnHelperCheck)
	end
end)

-- Zlorb death handling
Ext.Osiris.RegisterListener("Died", 1, "after", function(character)
	if not MCM.Get("mod_enabled") then
		return
	end
	
	if character == "S_GLO_DevilishOx_49eb5b4b-c6ed-4d37-8f68-97b1128b7d56" and Osi.IsDead(character) == 1 then
		Osi.SetOnStage("S_GLO_DevilishOx_49eb5b4b-c6ed-4d37-8f68-97b1128b7d56", 1)
	end
end)

-- Courage Trial Cleanup
Ext.Osiris.RegisterListener("PROC_WYR_CourageTrial_Cleanup", 0, "after", function()
	if not MCM.Get("mod_enabled") then
		return
	end

	for key, val in pairs(PersistentVars.currentlyRandomizedEnemyTable) do
		if C.CourageTrialEnemies[key] then
			Osi.Die(val[1], 0, "NULL_00000000-0000-0000-0000-000000000000", 1, 0, 0.0)
		end
	end
end)

Ext.Osiris.RegisterListener("LevelLoaded", 1, "after", function(level)
	if level == C.Regions.Act0 then
		gameLoaded()
	end
end)

-- Handling High Hall
Ext.Osiris.RegisterListener("LevelLoaded", 1, "after", function(level)
	if level == C.Regions.Act3c then
		local success, result = pcall(function()
			Ext.Timer.WaitFor(1000, function()
				Osi.PROC_Reinforcements_CharactersCanFight()
				Osi.DB_END_Reinforcements_Characters:Delete(nil,nil)
			end)
		end)
		if not success then
			print("ERROR processing High Hall: ", result)
		end
	end
end)

Ext.Osiris.RegisterListener("SavegameLoaded", 0, "after", function()
	gameLoaded()
end)

Ext.Osiris.RegisterListener("PROC_SetRelationTemporaryHostile", 2, "before", function(char1, char2	)
	if not MCM.Get("mod_enabled") then
		return
	end
	tempBattle[char1] = true
end)

Ext.Osiris.RegisterListener("PROC_CRIME_SetRelationTemporaryHostile", 4, "before", function(crimeiD, number, char1, char2)
	if not MCM.Get("mod_enabled") then
		return
	end
	tempBattle[char1] = true
end)

-- Surprise Rounds
Ext.Osiris.RegisterListener("StatusApplied", 4, "after", function(target, status, caster, storyId)
	if not MCM.Get("mod_enabled") then
		return
	end
	local targetId = strip_uuid(target)
	if status == "SURPRISED" then
		statusTable[target] = "SURPRISED"
	end
end)

-- Other pre-combat statuses, 
-- but this won't work because the timer is ticking for the original, 
-- and the new one won't be attached to concentration
-- Ext.Osiris.RegisterListener("StatusApplied", 4, "after", function(target, status, caster, storyId)
	-- if not MCM.Get("mod_enabled") then
		-- return
	-- end
	-- Ext.Timer.WaitFor(2000, function()
		-- if PersistentVars.currentlyRandomizedEnemyTable[target] and Osi.IsPartyMember(caster, 1) == 1 then
			-- if Osi.HasActiveStatus(target, status) == 1 then
				-- local turnCount = Osi.GetStatusCurrentLifetime(target, status)
				-- Osi.ApplyStatus(target, status, turnCount, caster)
			-- end
		-- end
	-- end)
-- end)

-- Ketheric
Ext.Osiris.RegisterListener("StatusApplied", 4, "after", function(target, status, caster, storyId)
	if not MCM.Get("mod_enabled") then
		return
	end
	local target_uuid = strip_uuid(target)
	if status == "MOO_KETHERIC_APOSTLEFORM" then
		if not PersistentVars.currentlyRandomizedEnemyTable[target] and not PersistentVars.spawnedEnemyTable[target_uuid] then
			local map = Osi.GetRegion(target)
			local asylum = getAsylum(map)

			newCreature = randomizeCreature(target)
			while not (newCreature or kethericRolledApostleFlag) do
				print("ERROR: ", target, " failed to spawn the Apostle phase! Trying again.")
				newCreature = randomizeCreature(target)
			end
			if kethericRolledApostleFlag then
				print(target, " rolled the Apostle. Exit loop without randomizing.")
			else
				Osi.SetFaction(newCreature, "2762926d-2d97-4a9c-808f-1690f5f6a4dd")
				Ext.Timer.WaitFor(1600, startCombat)
				Ext.Timer.WaitFor(3000, function()
					Osi.TeleportToPosition(target, asylum.asylumX, asylum.asylumY, asylum.asylumZ, "", 0, 0, 0, 0, 1)
				end)
			end
		end
	end
end)

-- Ethel
Ext.Osiris.RegisterListener("DialogStarted", 2, "after", function(dialogId, charId)
	if not MCM.Get("mod_enabled") then
		return
	end
	if dialogId == "HAG_Hag_Lair_a70f5acb-ecbe-8d0a-ae9c-be07a532e2d8" then
		Osi.TeleportTo("S_HAG_Hag_c457d064-83fb-4ec6-b74d-1f30dfafd12d","HAG_Lair_HagSpot_fdd01e3a-b187-4109-8444-195574033955","",1,1,1)
	end
end)

Ext.Osiris.RegisterListener("FlagSet", 3, "after", function(flag, speaker, dialogId)
	if not MCM.Get("mod_enabled") then
		return
	end
	if flag == "HAG_Hag_State_ToLairBecauseCombat_256770d9-04b6-4cdb-92db-e14e30b2700d" then
		if PersistentVars.currentlyRandomizedEnemyTable["S_HAG_Hag_c457d064-83fb-4ec6-b74d-1f30dfafd12d"] then
			local rando = PersistentVars.currentlyRandomizedEnemyTable["S_HAG_Hag_c457d064-83fb-4ec6-b74d-1f30dfafd12d"][1]
			local success, result = pcall(function()
				if Osi.IsDead("ff840420-d46a-4837-868b-ac02f45e4586") == 0 then
					local tempX,tempY,tempZ = Osi.FindValidPosition(-35, 4.8, 269, 30, "ff840420-d46a-4837-868b-ac02f45e4586", 1)
					Osi.TeleportToPosition("ff840420-d46a-4837-868b-ac02f45e4586", tempX, tempY, tempZ, "", 0, 0, 0, 0, 1)
					Osi.PlayEffectAtPosition("VFX_Script_Stub_Poof_01_f0cf792a-0f74-d17e-ad0d-6052a6131416",tempX,tempY,tempZ)
				end
				if Osi.IsDead("2b08981e-5cb0-496d-98cf-15e6a92121ec") == 0 then
					local tempX,tempY,tempZ = Osi.FindValidPosition(-39.78, 4.2, 271.52, 30, "2b08981e-5cb0-496d-98cf-15e6a92121ec", 1)
					Osi.TeleportToPosition("2b08981e-5cb0-496d-98cf-15e6a92121ec", tempX, tempY, tempZ, "", 0, 0, 0, 0, 1)
					Osi.PlayEffectAtPosition("VFX_Script_Stub_Poof_01_f0cf792a-0f74-d17e-ad0d-6052a6131416",tempX,tempY,tempZ)
				end
				if Osi.IsDead("14026955-2546-4d31-bc0c-4bfe0c34bd8a") == 0 then
					local tempX,tempY,tempZ = Osi.FindValidPosition(-37.5, 4.58, 264.76, 30, "14026955-2546-4d31-bc0c-4bfe0c34bd8a", 1)
					Osi.TeleportToPosition("14026955-2546-4d31-bc0c-4bfe0c34bd8a", tempX, tempY, tempZ, "", 0, 0, 0, 0, 1)
					Osi.PlayEffectAtPosition("VFX_Script_Stub_Poof_01_f0cf792a-0f74-d17e-ad0d-6052a6131416",tempX,tempY,tempZ)
				end
				if Osi.IsDead("30a871b1-9df3-42bb-87cb-c284cafd32eb") == 0 then
					local tempX,tempY,tempZ = Osi.FindValidPosition(-35.25, 4.92, 272.3, 30, "30a871b1-9df3-42bb-87cb-c284cafd32eb", 1)
					Osi.TeleportToPosition("30a871b1-9df3-42bb-87cb-c284cafd32eb", tempX, tempY, tempZ, "", 0, 0, 0, 0, 1)
					Osi.PlayEffectAtPosition("VFX_Script_Stub_Poof_01_f0cf792a-0f74-d17e-ad0d-6052a6131416",tempX,tempY,tempZ)
				end
			end)
			if not success then
				print("ERROR moving Redcaps: ", result)
			end
			Ext.Timer.WaitFor(1600, function()
				Osi.TeleportToPosition(rando, C.Asylum.Act1.asylumX, C.Asylum.Act1.asylumY, C.Asylum.Act1.asylumZ, "", 0, 0, 1, 1, 1)
			end)
			Ext.Timer.WaitFor(3600, function()
				Osi.TeleportTo("S_HAG_Hag_c457d064-83fb-4ec6-b74d-1f30dfafd12d","HAG_Lair_HagSpot_fdd01e3a-b187-4109-8444-195574033955","",1,1,1)
				local randoTemplate = Osi.GetTemplate(rando)
				local strippedTemplate = strip_uuid(randoTemplate)
				PersistentVars.currentlyRandomizedEnemyTable["S_HAG_Hag_c457d064-83fb-4ec6-b74d-1f30dfafd12d"] = nil
				PersistentVars.usedBossTable[strippedTemplate] = nil
				PersistentVars.spawnedEnemyTable[strippedTemplate] = nil
				Osi.SetOnStage(rando, 0)
			end)
		end
	end
end)

Ext.Osiris.RegisterListener("CastSpell", 5, "before", function(caster, spell, spellType, spellElement, storyActionID)
	if not MCM.Get("mod_enabled") then
		return
	end
	
	if spell == "Target_LOW_HagShroom_Resurrect" then
		ethelFlag = true
	end
end)

Ext.Osiris.RegisterListener("CastedSpell", 5, "after", function(caster, spell, spellType, spellElement, storyActionID)
	if not MCM.Get("mod_enabled") then
		return
	end
	
	if spell == "Target_LOW_HagShroom_Resurrect" then
		Ext.Timer.WaitFor(2000, function()
			ethelFlag = false
		end)
	end
end)

Ext.Osiris.RegisterListener("StatusRemoved", 4, "after", function(target, status, cause, storyId)
	if not MCM.Get("mod_enabled") then
		return
	end
	if target == "S_HAG_Hag_c457d064-83fb-4ec6-b74d-1f30dfafd12d" and PersistentVars.currentlyRandomizedEnemyTable[target] then
		local rando = PersistentVars.currentlyRandomizedEnemyTable[target][1]
		local ethelHP = Osi.GetHitpointsPercentage(target)
		if status == "KNOCKED_OUT" or status == "KNOCKED_OUT_TEMPORARILY" then
			Osi.SetHitpointsPercentage(rando, ethelHP)
			Osi.RemoveStatus(rando, status)
		end
	end
end)

Ext.Osiris.RegisterListener("StatusApplied", 4, "after", function(target, status, caster, storyId)
	if not MCM.Get("mod_enabled") then
		return
	end
	if target == "S_HAG_Hag_c457d064-83fb-4ec6-b74d-1f30dfafd12d" and status == "KNOCKED_OUT" and Osi.IsInTrigger(caster, "S_HAG_HagLair_SUB_CombatArea_0ace1ca2-9f1b-44d2-ae49-5bde98e1d251") == 1 then
		Osi.SetHitpointsPercentage(target, 2.0)
		Osi.RemoveStatus(target, status)
		Osi.SetCanJoinCombat(target, 0)
		Ext.Timer.WaitFor(200, function()
			Osi.PROC_ForceStopDialog(caster)
			Osi.PROC_ForceStopDialog(target)
			Osi.QRY_StartDialogCustom("HAG_HagLair_HagBegsForMercy_071783af-7275-172e-a255-aa0b600b9a0f", target, "S_HAG_Hagspawn_SurrogateMother_08c970d7-3138-45e8-8965-68eadf4b07cd", caster, 0, 0, -1, 0)
			Osi.SetFlag("HAG_HagLair_Event_HagBegsForMercy_591edd40-4668-4eca-99d1-3a41a4189bbf", "NULL_00000000-0000-0000-0000-000000000000", 0)
		end)
		Ext.Timer.WaitFor(400, function()
			Osi.PROC_HAG_Surrender_TeleportMayrina("S_HAG_Hagspawn_SurrogateMother_08c970d7-3138-45e8-8965-68eadf4b07cd")
		end)
	end
end)

Ext.Osiris.RegisterListener("DialogEnded", 2, "after", function(dialogId, charId)
	if not MCM.Get("mod_enabled") then
		return
	end
	if dialogId == "HAG_HagLair_HagBegsForMercy_071783af-7275-172e-a255-aa0b600b9a0f" then
		if Osi.GetFlag("HAG_Hag_State_HagGivenMercy_a3c0a36a-ccce-4f35-7b54-9ab22d6ac534", "NULL_00000000-0000-0000-0000-000000000000") == 1 then
			Ext.Timer.WaitFor(8000, function()
				Osi.SetCanJoinCombat("S_HAG_Hag_c457d064-83fb-4ec6-b74d-1f30dfafd12d", 1)
			end)
		else
			Osi.SetCanJoinCombat("S_HAG_Hag_c457d064-83fb-4ec6-b74d-1f30dfafd12d", 1)
			Osi.PROC_SetRelationToPlayers("GLO_Hag_313edae9-c797-2c65-9f7c-47e1f4e3221e", 0)
		end
	end
end)

Ext.Osiris.RegisterListener("FlagSet", 3, "after", function(flag, speaker, dialogId)
	if not MCM.Get("mod_enabled") then
		return
	end

	if flag == "HAG_Hag_State_HagGivenMercy_a3c0a36a-ccce-4f35-7b54-9ab22d6ac534" then
		Osi.ClearFlag("HAG_Hag_State_HagDefeated_7a1acad0-589f-ae02-f712-f0d24080d720", "NULL_00000000-0000-0000-0000-000000000000")
	end
end)

Ext.Osiris.RegisterListener("PROC_State_Progress", 3, "after", function(hag, sequence, event)
	if not MCM.Get("mod_enabled") then
		return
	end
	if hag == "S_HAG_Hag_c457d064-83fb-4ec6-b74d-1f30dfafd12d" and event == "AfterLairScene" then
		Osi.SetFlag("HAG_Hag_SummonedVictims_755d8269-7864-b72c-f355-b00aa02cd17e", "NULL_00000000-0000-0000-0000-000000000000")
	end
end)

Ext.Osiris.RegisterListener("PROC_LOW_HagRetreatsToOrlop", 0, "after", function()
	if not MCM.Get("mod_enabled") then
		return
	end
	if PersistentVars.currentlyRandomizedEnemyTable["S_HAG_Hag_c457d064-83fb-4ec6-b74d-1f30dfafd12d"] then
		local rando = PersistentVars.currentlyRandomizedEnemyTable["S_HAG_Hag_c457d064-83fb-4ec6-b74d-1f30dfafd12d"][1]
		Ext.Timer.WaitFor(800, function()
			Osi.TeleportToPosition(rando, C.Asylum.Act3b.asylumX, C.Asylum.Act3b.asylumY, C.Asylum.Act3b.asylumZ, "", 0, 0, 1, 1, 1)
		end)
		Ext.Timer.WaitFor(3600, function()
			Osi.TeleportTo("S_HAG_Hag_c457d064-83fb-4ec6-b74d-1f30dfafd12d","S_LOW_BlushingMermaid_HagCellarTeleportSpot_78b85f90-81ba-4509-a7d5-b30b836f212c","LOW_HagTeleportedToCellar",1,1,1,1,1)
			Osi.SetCombatGroupID(rando,"LOW_HagBossFight")
		end)
	end
end)


-- Knocked Out
Ext.Osiris.RegisterListener("StatusApplied", 4, "after", function(target, status, caster, storyId)
	if not MCM.Get("mod_enabled") then
		return
	end
	local targetId = strip_uuid(target)
	if status == "KNOCKED_OUT_TEMPORARILY" then
		for key, val in pairs(PersistentVars.currentlyRandomizedEnemyTable) do
			if val[1] == targetId then
				Osi.ApplyStatus(key, "KNOCKED_OUT_TEMPORARILY", -1.0, 1, Host)
			end
		end
	elseif status == "KNOCKED_OUT" then
		for key, val in pairs(PersistentVars.currentlyRandomizedEnemyTable) do
			if val[1] == targetId then
				Osi.ApplyStatus(key, "KNOCKED_OUT", -1.0, 1, Host)
			end
		end
	end
end)

-- Failsafe for spawn handling
Ext.Osiris.RegisterListener("StatusApplied", 4, "after", function(target, status, caster, storyId)
	if not MCM.Get("mod_enabled") then
		return
	end
	if status == "AER_INVULNERABLE" then
		Ext.Timer.WaitFor(8600, function()
			if Osi.HasActiveStatus(target, "AER_INVULNERABLE") == 1 then
				Osi.RemoveStatus(target, "AER_INVULNERABLE")
			end
		end)
	end
end)

-- The easy fix for Myrkul if ATT is disabled
Ext.Osiris.RegisterListener("StatusApplied", 4, "after", function(target, status, caster, storyId)
	if not MCM.Get("mod_enabled") then
		return
	end
	if status == "Mykrul_Aura" and not MCM.Get("att_mon") then
		Ext.Timer.WaitFor(100, function()
			Osi.RemoveStatus(target, "Mykrul_Aura")
			Osi.ApplyStatus(target, "AER_WEAK_MYRKUL_AURA", -1.0, 1, target)
		end)
	end
end)

-- Orin's Ritual
Ext.Osiris.RegisterListener("StatusApplied", 4, "after", function(target, status, caster, storyId)
	if not MCM.Get("mod_enabled") then
		return
	end
	if target == "S_GLO_Orin_bf24e0ec-a3a6-4905-bd2d-45dc8edf8101" then
		if status == "DEATHSHEAD_UNSTOPPABLE_12" or status == "LOW_ORIN_BHAALBUFF_HARDCORE" then
			if PersistentVars.currentlyRandomizedEnemyTable["S_GLO_Orin_bf24e0ec-a3a6-4905-bd2d-45dc8edf8101"] then
				Osi.ApplyStatus(PersistentVars.currentlyRandomizedEnemyTable["S_GLO_Orin_bf24e0ec-a3a6-4905-bd2d-45dc8edf8101"][1] , "DEATHSHEAD_UNSTOPPABLE_12", -1.0, 1, caster)
			end
		elseif status == "DEATHSHEAD_UNSTOPPABLE_7" then
			if PersistentVars.currentlyRandomizedEnemyTable["S_GLO_Orin_bf24e0ec-a3a6-4905-bd2d-45dc8edf8101"] then
				Osi.ApplyStatus(PersistentVars.currentlyRandomizedEnemyTable["S_GLO_Orin_bf24e0ec-a3a6-4905-bd2d-45dc8edf8101"][1] , "DEATHSHEAD_UNSTOPPABLE_7", -1.0, 1, caster)
			end
		end
	end
end)

Ext.Osiris.RegisterListener("StatusRemoved", 4, "after", function(target, status, caster, storyId)
	if not MCM.Get("mod_enabled") then
		return
	end
	if status == "MOO_KETHERIC_INVULNERABLE" then
		for key, val in pairs(PersistentVars.currentlyRandomizedEnemyTable) do
			if key == target then
				Osi.RemoveStatus(val[1], "MOO_KETHERIC_INVULNERABLE")
			end
		end
	end
end)

Ext.Osiris.RegisterListener("LongRestStarted", 0, "before", function()
	if not MCM.Get("mod_enabled") then
		return
	end
	local map = Osi.GetRegion(Host)
	local asylum = getAsylum(map)

	for key, val in pairs(PersistentVars.currentlyRandomizedEnemyTable) do
		if Osi.IsDead(key) == 0 and Osi.IsDead(val[1]) == 0 then
			Osi.TeleportToPosition(val[1], asylum.asylumX, asylum.asylumY, asylum.asylumZ, "", 1, 1, 1, 0, 1)
			Osi.TeleportToPosition(key, val[2], val[3], val[4], "", 1, 1, 1, 0, 1)
		end
		if Osi.HasActiveStatus(key, "PARALYZED") then
			RemoveStatus(key, "PARALYZED", key)
		end
	end
end)

Ext.Osiris.RegisterListener("CombatEnded", 1, "after", function(guid)
	if not MCM.Get("mod_enabled") then
		return
	end
	local map = Osi.GetRegion(Host)
	local asylum = getAsylum(map)

	for key, val in pairs(PersistentVars.currentlyRandomizedEnemyTable) do
		if val.ally then
			Osi.TeleportToPosition(val[1], asylum.asylumX, asylum.asylumY, asylum.asylumZ, "", 0, 0, 0, 0, 1)
			Osi.TeleportToPosition(key, val[2], val[3], val[4], "", 0, 0, 0, 0, 1)
		elseif (Osi.HasActiveStatus(val[1], "KNOCKED_OUT_TEMPORARILY") == 1 or Osi.HasActiveStatus(val[1], "KNOCKED_OUT") == 1) then
			Osi.TeleportToPosition(val[1], asylum.asylumX, asylum.asylumY, asylum.asylumZ, "", 0, 0, 0, 0, 1)
			Osi.TeleportToPosition(key, val[2], val[3], val[4], "", 0, 0, 0, 0, 1)
		else
			if key ~= "S_HAG_Hag_c457d064-83fb-4ec6-b74d-1f30dfafd12d" then
				Ext.Timer.WaitFor(4000, function()
					if Osi.IsInCombat(val[1]) == 0 and not (val[5] or map == C.Regions.Act2b) then
						Osi.TeleportToPosition(val[1], asylum.asylumX, asylum.asylumY, asylum.asylumZ, "", 0, 0, 0, 1, 1)
						Osi.TeleportToPosition(key, val[2], val[3], val[4], "", 0, 0, 1, 1, 1)
					end
				end)
			end
		end
	end
	
	if MCM.Get("gm_mode") then
		Ext.Timer.WaitFor(5000, removeTurnHelperCheck)
		Osi.SetFaction(PersistentVars.gameMaster, playerFaction)
	end
end)

Ext.Osiris.RegisterListener("LeftCombat", 2, "after", function(charId, combatId)
	if not MCM.Get("mod_enabled") then
		return
	end
	local map = Osi.GetRegion(Host)
	local asylum = getAsylum(map)

	character_uuid = strip_uuid(charId)

	for key, val in pairs(PersistentVars.currentlyRandomizedEnemyTable) do
		if val[1] == character_uuid then
			if val.ally then
				Osi.TeleportToPosition(val[1], asylum.asylumX, asylum.asylumY, asylum.asylumZ, "", 0, 0, 0, 0, 1)
				Osi.TeleportToPosition(key, val[2], val[3], val[4], "", 0, 0, 0, 0, 1)
			elseif (Osi.HasActiveStatus(val[1], "KNOCKED_OUT_TEMPORARILY") == 1 or Osi.HasActiveStatus(val[1], "KNOCKED_OUT") == 1) then
				Osi.TeleportToPosition(val[1], asylum.asylumX, asylum.asylumY, asylum.asylumZ, "", 0, 0, 0, 0, 1)
				Osi.TeleportToPosition(key, val[2], val[3], val[4], "", 0, 0, 0, 0, 1)
			else
				if key ~= "S_HAG_Hag_c457d064-83fb-4ec6-b74d-1f30dfafd12d" then
					Ext.Timer.WaitFor(4000, function()
						if Osi.IsInCombat(val[1]) == 0 and not (val[5] or map == C.Regions.Act2b) then
							Osi.TeleportToPosition(val[1], asylum.asylumX, asylum.asylumY, asylum.asylumZ, "", 0, 0, 0, 1, 1)
							Osi.TeleportToPosition(key, val[2], val[3], val[4], "", 0, 0, 1, 1, 1)
						end
					end)
				end
			end
		end
	end
	
	if MCM.Get("gm_mode") then
		Osi.RemovePartyFollower(character_uuid, PersistentVars.gameMaster)
	end
	
	PersistentVars.currentCombatMembers[character_uuid] = nil
	
	if next(PersistentVars.currentCombatMembers) == nil and MCM.Get("gm_mode") then
		Ext.Timer.WaitFor(4000, removeTurnHelperCheck)
	end
end)

Ext.Osiris.RegisterListener("PROC_LevelLoadedOnce", 1, "before", function(levelId)
	-- lowkey worried about performance when we start iterating at endgame
	if levelId == C.Regions.Act1 or levelId == C.Regions.Act3 or levelId == C.Regions.Act3c then
		PersistentVars.currentlyRandomizedEnemyTable = {}
		PersistentVars.spawnedEnemyTable = {}
		PersistentVars.currentCombatMembers = {}
	elseif levelId == C.Regions.Act2 then
		if PersistentVars.currentlyRandomizedEnemyTable["S_GOB_DrowCommander_25721313-0c15-4935-8176-9f134385451b"] then
			PersistentVars.currentlyRandomizedEnemyTable["S_GOB_DrowCommander_25721313-0c15-4935-8176-9f134385451b"] = nil
		end
	end
end)

-- Marcus
Ext.Osiris.RegisterListener("PROC_HAV_SetupFactionsSpyAlly", 0, "after", function()
	for key, val in pairs(PersistentVars.currentlyRandomizedEnemyTable) do
		local keyFaction = Osi.GetFaction(key)
		if keyFaction == "Act2_HAV_FlamingSpy_Ally_e3da5c3f-056c-4391-83c9-7a78b0703856" then
			Osi.SetFaction(val[1], "Act2_HAV_FlamingSpy_Ally_e3da5c3f-056c-4391-83c9-7a78b0703856")
		end
	end
end)

-- Minthara
Ext.Osiris.RegisterListener("CharacterJoinedParty", 1, "before", function(charId)
	if not MCM.Get("mod_enabled") then
		return
	end
	if PersistentVars.currentlyRandomizedEnemyTable[charId] then
		PersistentVars.currentlyRandomizedEnemyTable[charId] = nil
	end
end)

Ext.Osiris.RegisterListener("TurnStarted", 1, "before", function(charId)
	if not MCM.Get("mod_enabled") then
		return
	end
	if Osi.GetTemplate(charId) == "AER_Turn_Helper_3f0377a6-1bf5-4e9e-a186-d2a934f0a0c0" then
		Osi.EndTurn(charId)
	end
	if PersistentVars.currentlyRandomizedEnemyTable[charId] then
		Osi.EndTurn(charId)
	end
	if charId == "S_END_MindBattleHelper_be50f7cd-c14a-4131-82d3-29337f3a4759" then
		Osi.EndTurn(charId)
	end
end)

Ext.Osiris.RegisterListener("TemplateAddedTo", 4, "before", function(template, object, owner, addtype)
	if not MCM.Get("randomize_loot") then
		return
	end

	-- I know it could be one list, I did this just to think about it in three parts
	for _, pattern in ipairs(startRegex) do    
		if string.match(object, pattern) then
			return
		end
	end
	for _, pattern in ipairs(containsRegex) do    
		if string.match(object, pattern) then
			return
		end
	end
	for _, pattern in ipairs(endsRegex) do    
		if string.match(object, pattern) then
			return
		end
	end
	
	root_template = strip_uuid(template)
	object_uuid = strip_uuid(object)

	if linkingItems[root_template .. "|" .. owner] then
		PersistentVars.existingMappedItemTable[object_uuid] = true
		linkingItems[root_template .. "|" .. owner] = nil
		return
	end

	if PersistentVars.randomizedItemTable[root_template] or PersistentVars.existingMappedItemTable[object_uuid] then
		return	
	end
	
	if Osi.IsCharacter(object) == 1 then
		return
	end

	local potentialCharacter = Osi.GetOriginalOwner(object)
	local dead = Osi.IsDead(owner)
	local partyMember = Osi.IsPartyMember(owner, 1)

	if mappedUniqueItems[root_template] then
		if potentialCharacter and Osi.IsPlayer(potentialCharacter) == 0 and Osi.IsPartyMember(potentialCharacter, 1) == 0 and Osi.IsEquipped(object) == 1 then
			return
		end
		PersistentVars.randomizedItemTable[root_template] = true
		local newItem = mappedUniqueItems[root_template].RootTemplate
		linkingItems[newItem .. "|" .. owner] = true
		Ext.Timer.WaitFor(200, function()
			Osi.RequestDelete(object)
			Osi.TemplateAddTo(newItem, owner, 1, 1)
		end)
		
		if newItem == "9ff968d4-08ff-4da1-a288-959ac8d7abe1" then
			Osi.SetFlag("END_IllithidOptions_State_ArrivedWithOrphicHammer_a350e277-55a7-4e03-9c14-db154b6c682e")
		end
	elseif potentialCharacter and (Osi.IsPlayer(potentialCharacter) == 1 or Osi.IsPartyMember(potentialCharacter, 1) == 1) then
		return
	else
		if addtype == "Regular" and dead == 0 and partyMember == 0 then
			return
		end
		local newItem = Hash:selectItemByTemplate(object, rarityTables)

		linkingItems[newItem .. "|" .. owner] = true
		Ext.Timer.WaitFor(100, function()
			Osi.RequestDelete(object)
			Osi.TemplateAddTo(newItem, owner, 1, 1)
		end)
	end
end)

-- Orin's Netherstone
Ext.Osiris.RegisterListener("AddedTo", 3, "after", function(objectId, receieverId, addType)
	if not MCM.Get("randomize_loot") then
		return
	end
	if objectId	==  "S_GLO_Orin_Bhaalist_Dagger_51c312d5-ce5e-4f8c-a5ad-edc2beced3e6" and Osi.IsPartyMember(receieverId, 1) == 1 then
		Ext.Timer.WaitFor(800, function()
			Osi.PROC_GEN_OrinsAbduction_GiveStone(receieverId)
			if Osi.IsInInventoryOf(objectId, receieverId) == 1 then
				if PersistentVars.randomizedItemTable["d90abf24-3c4e-4bbf-84aa-def05ca9962a"] then
					Osi.RequestDelete(objectId)
				else
					PersistentVars.randomizedItemTable["d90abf24-3c4e-4bbf-84aa-def05ca9962a"] = true
					local newItem = mappedUniqueItems["d90abf24-3c4e-4bbf-84aa-def05ca9962a"].RootTemplate
					linkingItems[newItem .. "|" .. receieverId] = true
					Ext.Timer.WaitFor(200, function()
						Osi.RequestDelete(objectId)
						Osi.TemplateAddTo(newItem, receieverId, 1, 1)
					end)
				end
			end
		end)
	end
end)

-- Blood of Lathander
Ext.Osiris.RegisterListener("AddedTo", 3, "after", function(objectId, receieverId, addType)
	if not MCM.Get("randomize_loot") then
		return
	end
	if objectId	==  "S_CRE_BloodOfLathander_e26f0c19-6185-43a7-b7f7-7155b936c59c" and Osi.IsPartyMember(receieverId, 1) == 1 then
		Ext.Timer.WaitFor(1400, function()
			if Osi.IsInInventoryOf(objectId, receieverId) == 1 then
				PersistentVars.randomizedItemTable["96a35552-0c05-4df0-9974-2a8f142e4be6"] = true
				local newItem = mappedUniqueItems["96a35552-0c05-4df0-9974-2a8f142e4be6"].RootTemplate
				linkingItems[newItem .. "|" .. receieverId] = true
				Ext.Timer.WaitFor(200, function()
					Osi.RequestDelete(objectId)
					Osi.TemplateAddTo(newItem, receieverId, 1, 1)
				end)
			end
		end)
	end
end)

-- Flawed Helldusk Armor
Ext.Osiris.RegisterListener("TemplateAddedTo", 4, "after", function(templateId, objectId, receieverId, addType)
	if not MCM.Get("randomize_loot") then
		return
	end
	
	if templateId == "QUEST_HAV_InfernalReward_001_d9863839-e955-47a2-8a06-070f5c3c9541" and Osi.IsPartyMember(receieverId, 1) == 1 then
		Ext.Timer.WaitFor(1400, function()
			if Osi.IsInInventoryOf(objectId, receieverId) == 1 then
				PersistentVars.randomizedItemTable["d76dd47b-e1bf-4e30-b366-6069d9eb9e22"] = true
				local newItem = mappedUniqueItems["d76dd47b-e1bf-4e30-b366-6069d9eb9e22"].RootTemplate
				linkingItems[newItem .. "|" .. receieverId] = true
				Ext.Timer.WaitFor(200, function()
					Osi.RequestDelete(objectId)
					Osi.TemplateAddTo(newItem, receieverId, 1, 1)
				end)
			end
		end)
	end
end)

-- Flawed Helldusk Helmet
Ext.Osiris.RegisterListener("TemplateAddedTo", 4, "after", function(templateId, objectId, receieverId, addType)
	if not MCM.Get("randomize_loot") then
		return
	end

	if templateId == "QUEST_HAV_InfernalReward_002_6d60fcbb-e7a5-47ad-9cca-44565cbc0856" and Osi.IsPartyMember(receieverId, 1) == 1 then
		Ext.Timer.WaitFor(1400, function()
			if Osi.IsInInventoryOf(objectId, receieverId) == 1 then
				PersistentVars.randomizedItemTable["2b69a73f-0d1b-4514-bdae-5565a8045e26"] = true
				local newItem = mappedUniqueItems["2b69a73f-0d1b-4514-bdae-5565a8045e26"].RootTemplate
				linkingItems[newItem .. "|" .. receieverId] = true
				Ext.Timer.WaitFor(200, function()
					Osi.RequestDelete(objectId)
					Osi.TemplateAddTo(newItem, receieverId, 1, 1)
				end)
			end
		end)
	end
end)

-- Flawed Helldusk Gloves
Ext.Osiris.RegisterListener("TemplateAddedTo", 4, "after", function(templateId, objectId, receieverId, addType)
	if not MCM.Get("randomize_loot") then
		return
	end
	
	if templateId == "QUEST_HAV_InfernalReward_003_b673f1dc-d925-4811-a78e-53adcce847e8" and Osi.IsPartyMember(receieverId, 1) == 1 then
		Ext.Timer.WaitFor(1400, function()
			if Osi.IsInInventoryOf(objectId, receieverId) == 1 then
				PersistentVars.randomizedItemTable["cbc9b5dd-76e5-4e22-b0cf-26e957033a9d"] = true
				local newItem = mappedUniqueItems["cbc9b5dd-76e5-4e22-b0cf-26e957033a9d"].RootTemplate
				linkingItems[newItem .. "|" .. receieverId] = true
				Ext.Timer.WaitFor(200, function()
					Osi.RequestDelete(objectId)
					Osi.TemplateAddTo(newItem, receieverId, 1, 1)
				end)
			end
		end)
	end
end)

Channels.SeedRoll:SetHandler(function()
	rerollSeed()
	regenerateItemMap()
end)

Ext.Events.SessionLoaded:Subscribe(initialize)