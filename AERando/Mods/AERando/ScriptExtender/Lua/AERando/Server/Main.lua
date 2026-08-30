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
local kethericFlag = false

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
	if #iconTable > 0 then
		for i, uuid in ipairs(iconTable) do
			Channels.IconReplacer:Broadcast(uuid)
		end
		iconTable = {}
	end
end

function clearHelperIconTable()
	for i, uuid in ipairs(PersistentVars.turnHelperCollection) do
		Channels.IconReplacer:Broadcast(uuid)
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

    Osi.SetTag(turnhelper, "9787450d-f34d-43bd-be88-d2bac00bb8ee") -- AI_UNPREFERRED_TARGET
    Osi.SetFaction(turnhelper, "64321d50-d516-b1b2-cfac-2eb773de1ff6")
	
	Osi.ApplyStatus(turnhelper, "AER_TURNHELPER", -1.0)
	
	local players = Osi.DB_Players:Get(nil)
	for _, entry in ipairs(players) do
		local player = strip_uuid(entry[1])
		if player ~= PersistentVars.gameMaster then
			Osi.SetHostileAndEnterCombat("64321d50-d516-b1b2-cfac-2eb773de1ff6", "9fac6ec7-642b-3553-1bc8-6b8e0edae7d5", turnhelper, player)
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
	for i = 1, 15 do
		local turnhelper = gmTurnHelper(i)
		table.insert(PersistentVars.turnHelperCollection, turnhelper)
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
		createTurnHelperList()
		Ext.Timer.WaitFor(4000, clearHelperIconTable)
	end
	local map = Osi.GetRegion(Host)
	for monster, _ in pairs(PersistentVars.spawnedEnemyTable) do
		if not PersistentVars.currentCombatMembers[monster] then
			local missingHP = 0

			local player, distance = Osi.GetClosestPlayer(monster)
			if (distance and player) then
				if distance < 200 then
					for key, val in pairs(PersistentVars.currentlyRandomizedEnemyTable) do
						character_uuid = strip_uuid(monster)
						if val[1] == character_uuid then
							-- I know this is inefficient don't @ me
							missingHP = Osi.GetMaxHitpoints(key) - Osi.GetHitpoints(key)				
							if statusTable[key] then
								Osi.ApplyStatus(monster, "SURPRISED", 6.0, 1, monster)
								statusTable[key] = nil
							end
						end
					end
					
					if missingHP > 0 and Osi.GetHitpointsPercentage(monster) == 100.0 then
						Osi.ApplyDamage(monster,missingHP,"Force",Host)
					end
						

					local creatureFaction = Osi.GetFaction(monster)
					if not MCM.Get("gm_mode") then
						Osi.SteerTo(monster, Host, 1)
						Osi.SetHostileAndEnterCombat(creatureFaction, playerFaction, monster, Host)
					else
						local players = Osi.DB_Players:Get(nil)
						Osi.SetFaction(PersistentVars.gameMaster, creatureFaction)
						Osi.AddPartyFollower(monster, PersistentVars.gameMaster)
						for _, entry in ipairs(players) do
							local player = strip_uuid(entry[1])
							if player ~= PersistentVars.gameMaster then
								Osi.SetHostileAndEnterCombat(creatureFaction, "9fac6ec7-642b-3553-1bc8-6b8e0edae7d5", monster, player)
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
		createTurnHelperList()
		Ext.Timer.WaitFor(4000, clearHelperIconTable)
	end
	local map = Osi.GetRegion(Host)
	for monster, _ in pairs(PersistentVars.spawnedEnemyTable) do
		if not PersistentVars.currentCombatMembers[monster] then
			local missingHP = 0

			local player, distance = Osi.GetClosestPlayer(monster)
			if (distance and player) then
				if distance < 200 then
					for key, val in pairs(PersistentVars.currentlyRandomizedEnemyTable) do
						character_uuid = strip_uuid(monster)
						if val[1] == character_uuid then
							missingHP = Osi.GetMaxHitpoints(key) - Osi.GetHitpoints(key)				
							if statusTable[key] then
								Osi.ApplyStatus(monster, "SURPRISED", 6.0, 1, monster)
								statusTable[key] = nil
							end
						end
					end
					
					if missingHP > 0 and Osi.GetHitpointsPercentage(monster) == 100.0 then
						Osi.ApplyDamage(monster,missingHP,"Force",Host)
					end
						

					local creatureFaction = Osi.GetFaction(monster)
					if not MCM.Get("gm_mode") then
						Osi.SteerTo(monster, Host, 1)
						Osi.PROC_SetRelationTemporaryHostile(monster,Host)
						Osi.EnterCombat(monster,Host)
						Osi.EnterCombat(Host,monster)
					else
						local players = Osi.DB_Players:Get(nil)
						Osi.SetFaction(PersistentVars.gameMaster, creatureFaction)
						Osi.AddPartyFollower(monster, PersistentVars.gameMaster)
						for _, entry in ipairs(players) do
							local player = strip_uuid(entry[1])
							if player ~= PersistentVars.gameMaster then
								Osi.SetHostileAndEnterCombat(creatureFaction, "9fac6ec7-642b-3553-1bc8-6b8e0edae7d5", monster, player)
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
		createTurnHelperList()
		Ext.Timer.WaitFor(4000, clearHelperIconTable)
	end
	local map = Osi.GetRegion(Host)
	for monster, _ in pairs(PersistentVars.spawnedEnemyTable) do
		if not PersistentVars.currentCombatMembers[monster] then
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
					missingHP = Osi.GetMaxHitpoints(key) - Osi.GetHitpoints(key)				
					if statusTable[key] then
						Osi.ApplyStatus(monster, "SURPRISED", 6.0, 1, monster)
						statusTable[key] = nil
					end
				end
			end
			
			if missingHP > 0 and Osi.GetHitpointsPercentage(monster) == 100.0 then
				Osi.ApplyDamage(monster,missingHP,"Force",Host)
			end
				

			local creatureFaction = Osi.GetFaction(monster)
			if not MCM.Get("gm_mode") then
				Osi.SteerTo(monster, Host, 1)
				
				if not (success and result) then
					pcall(function()
						local entity = Ext.Entity.Get(Host)
						local narrativeCombatId = entity.CombatParticipant.CombatHandle.CombatState.MyGuid
						Osi.SetInNarrativeCombat(monster, narrativeCombatId, 1)
					end)
				end
			else
				local players = Osi.DB_Players:Get(nil)
				Osi.SetFaction(PersistentVars.gameMaster, creatureFaction)
				Osi.AddPartyFollower(monster, PersistentVars.gameMaster)
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
	local aggroFlag = false
	local returnFlag = false
	local countermeasureFlag = false
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
		aggroFlag = lookup.aggroFlag
		returnFlag = lookup.returnFlag
		countermeasureFlag = lookup.countermeasureFlag
	end
	
	if returnFlag then
		return
	end
	
	if countermeasureFlag and Osi.DB_END_BrainBattle_DominationDone:Get(1)[1] then
		return
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
		elseif level < 9 and (map == C.Regions.Act3 or map == C.Regions.Act3b) then
			index = 4 -- high
		elseif level < 11 then
			index = 5 -- ultra
		elseif level < 13 then
			index = 6 -- epic
		elseif level < 14 then
			index = 7 -- legendary
		elseif level < 21 then
			index = 8 -- mythical
		elseif level < 28 then
			index = 9 -- divine
		else
			index = 10 -- avatar
		end
	end

	local apostleFlag = Osi.HasActiveStatus(character, "MOO_KETHERIC_APOSTLEFORM") == 1

	if map == C.Regions.Act0 and index > 1 then
		levelmax = levelmax - 1
	elseif map == C.Regions.Act2 and index > 5 and not apostleFlag then
		levelmax = levelmax - 1
	elseif map == C.Regions.Act3c and index < 5 then
		levelmin = levelmin - 1
	end

	if boss then
		index = index + MCM.Get("boss_tier_boost")
	else
		index = index + MCM.Get("enemy_tier_boost")
	end

	local newTable = trimTable(index, difficultyTables, levelmin, levelmax)
	local newEnemy = nil

	if apostleFlag then
		newEnemy = Hash:selectEnemy("KETHERICPHASETWO", newTable, false)
	else
		newEnemy = Hash:selectEnemy(character, newTable, false)
	end

	if boss and MCM.Get("unique_bosses") then
		salt = 0
		if kethericFlag or not strippedUUID == "e9918f3e-5b87-40a3-a9bd-61545151573f" then
			while PersistentVars.usedBossTable[newEnemy] == true do
				salt = salt + 373
				newEnemy = Hash:selectEnemy(salt, newTable, false)
			end
		end
		PersistentVars.usedBossTable[newEnemy] = true
	end
	return newEnemy, aggroFlag
end

function spawnNewCreature(character, x, y, z)
	local spawnId, aggro = selectCreature(character)
	
	if not spawnId then
		if Osi.IsCharacter(character) == 1 and Osi.IsHitProxy(character) == 0 then
			print("ERROR: ", character, " failed to randomize!")
		end
		return
	end
	
	local x2, y2, z2 = Osi.FindValidPosition(x, y, z, 100, Host, 1)

	local newCreatureId = Osi.CreateAt(spawnId, x2, y2, z2, 0, 1, "")

	return newCreatureId, aggro
end

function randomizeCreature(character)
	local x, y, z = Osi.GetPosition(character)
	if not Host then
		Host = Osi.GetHostCharacter()
	end
	local map = Osi.GetRegion(Host)
	local asylum = getAsylum(map)
	local combatGroup = Ext.Entity.Get(character).CombatParticipant.CombatGroupId

	if PersistentVars.currentlyRandomizedEnemyTable[character] then
		return PersistentVars.currentlyRandomizedEnemyTable[character][1]
	end

	local newCreature, aggro = spawnNewCreature(character, x, y, z)

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
	Osi.TeleportToPosition(character, asylum.asylumX, asylum.asylumY, asylum.asylumZ, "", 0, 0, 0, 0, 1)
	
	character_uuid = strip_uuid(character)
	table.insert(iconTable, character_uuid)
	Ext.Timer.WaitFor(1600, clearIconTables)
	
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
			MCM.Set("enemy_tier_boost", 1)
			MCM.Set("boss_tier_boost", 2)
			MCM.Set("enemy_tier_min", 2)
			MCM.Set("enemy_tier_max", 1)
		end
	end
	if payload.settingId == "preset_extreme" then
		if payload.value and not payload.oldValue then
			MCM.Set("preset_normal", false)
			MCM.Set("preset_hard", false)
			MCM.Set("enemy_tier_boost", 2) 
			MCM.Set("boss_tier_boost", 3)
			MCM.Set("enemy_tier_min", 3)
			MCM.Set("enemy_tier_max", 1)
		end
	end
	if payload.settingId == "advanced_rando_mode" then
		MCM.Set("advanced_mode", payload.value) 
	end
	if payload.settingId == "advanced_mode" then
		MCM.Set("advanced_rando_mode", payload.value) 
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
	
	if MCM.Get("derandomize_othermod") then
		local success, result = pcall(function()
			local fileName = Ext.Template.GetTemplate(character_uuid).FileName
			for _, pattern in ipairs(C.fileNameRegex) do
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
				for _, pattern in ipairs(C.fileNameRegex) do
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
	
	-- Handle Viconia's heartmap for the regular version
	if "15d458c4-c51d-4312-8f5a-cf5ba9042e3f" == stripped_template then
		local players = Osi.DB_Players:Get(nil)
		for _, entry in ipairs(players) do
			local player = entry[1]
			Osi.SetTag(player, "8d2d234e-a25a-4a92-b1a1-df5e90b08ebd")
		end
	end
	
	if PersistentVars.currentlyRandomizedEnemyTable[character] then
		local spawn = PersistentVars.currentlyRandomizedEnemyTable[character][1]
		if Osi.IsDead(spawn) == 1 then
			return
		end
		local tempx, tempy, tempz = Osi.GetPosition(character)
		Osi.TeleportToPosition(character, asylum.asylumX, asylum.asylumY, asylum.asylumZ, "", 0, 0, 0, 0, 1)
		
		
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
		PersistentVars.currentCombatMembers[character_uuid] = true
		return
	end
	
	creatureFaction = Osi.GetFaction(character)
	local players = Osi.DB_Players:Get(nil)
	local realCombat = false
	local narrativeCombat = false
	for _, entry in ipairs(players) do
		local player = entry[1]
		local partyFaction = Osi.GetFaction(player)
		if Osi.GetRelation(creatureFaction, partyFaction) < 40 then
			realCombat = true
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
	elseif (realCombat or MCM.Get("gm_mode")) then
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
				end
				Osi.ApplyDamage(key,999,"Force",Host)
				if key == "S_MOO_Ketheric_e9918f3e-5b87-40a3-a9bd-61545151573f" then
					if Osi.GetFlag("MOO_Assault_Event_KethericTeleportedAway_ba71e8cd-8922-61a4-a2ff-8c5f5ff8aac6", "NULL_00000000-0000-0000-0000-000000000000") == 1 then
						kethericFlag = true
					else
						Osi.PROC_MOO_Assault_KethericLeaves()
					end
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

Ext.Osiris.RegisterListener("LevelLoaded", 1, "after", function(level)
	if level == C.Regions.Act0 then
		gameLoaded()
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

Ext.Osiris.RegisterListener("StatusApplied", 4, "after", function(target, status, caster, storyId)
	if not MCM.Get("mod_enabled") then
		return
	end
	local targetId = strip_uuid(target)
	if status == "SURPRISED" then
		statusTable[target] = "SURPRISED"
	elseif status == "MOO_KETHERIC_APOSTLEFORM" then
		if not PersistentVars.currentlyRandomizedEnemyTable[target] then
			newCreature = randomizeCreature(target)
			if not newCreature then
				print("ERROR: ", target, " failed to spawn the Apostle phase!")
				return
			end
			Osi.SetFaction(newCreature, "2762926d-2d97-4a9c-808f-1690f5f6a4dd")
			Ext.Timer.WaitFor(1600, startCombat)
		end
	elseif status == "KNOCKED_OUT_TEMPORARILY" then
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
			Ext.Timer.WaitFor(4000, function()
				if Osi.IsInCombat(val[1]) == 0 and not (val[5] or map == C.Regions.Act2b) then
					Osi.TeleportToPosition(val[1], asylum.asylumX, asylum.asylumY, asylum.asylumZ, "", 0, 0, 0, 1, 1)
					Osi.TeleportToPosition(key, val[2], val[3], val[4], "", 0, 0, 1, 1, 1)
				end
			end)
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
		Osi.RemovePartyFollower(character_uuid, PersistentVars.gameMaster)
	end
	
	PersistentVars.currentCombatMembers[character_uuid] = nil
	
	if next(PersistentVars.currentCombatMembers) == nil and MCM.Get("gm_mode") then
		Ext.Timer.WaitFor(4000, removeTurnHelperCheck)
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

	local potentialCharacter = Osi.GetOriginalOwner(object)
	local dead = Osi.IsDead(owner)
	local partyMember = Osi.IsPartyMember(owner, 1)



	if mappedUniqueItems[root_template] then
		PersistentVars.randomizedItemTable[root_template] = true
		local newItem = mappedUniqueItems[root_template].RootTemplate
		linkingItems[newItem .. "|" .. owner] = true
		Ext.Timer.WaitFor(200, function()
			Osi.RequestDelete(object)
			Osi.TemplateAddTo(newItem, owner, 1, 1)
		end)
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

Channels.SeedRoll:SetHandler(function()
	rerollSeed()
	regenerateItemMap()
end)

Ext.Events.SessionLoaded:Subscribe(initialize)