local baseMonsterList = Ext.Require("AERando/Server/Templates/Enemies.lua")
local tabletopMonsterList = Ext.Require("AERando/Server/Templates/ATTTemplates.lua")
local exandriaMonsterList = Ext.Require("AERando/Server/Templates/SOEEnemies.lua")

local C = Ext.Require("AERando/Constants.lua")
local Hash = Ext.Require("AERando/Hash.lua")
local RNG = Ext.Require("AERando/RNG.lua")
local Channels = Ext.Require("AERando/Shared.lua")

Host = nil
playerFaction = nil

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

if Ext.Mod.IsModLoaded("a27fdbe3-4d1a-641d-d05f-1ba4ee529da8") then
	MCM.Set("soe_loaded", true)
end

activeMonsterList = {}
iconTable = {}
statusTable = {}
currentlyRandomizedEnemyTable = PersistentVars.currentlyRandomizedEnemyTable
spawnedEnemyTable = PersistentVars.spawnedEnemyTable
deadRandomTable = PersistentVars.deadRandomTable

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
if MCM.Get("soe_mon") then
	for _, monster in ipairs(exandriaMonsterList) do	
		table.insert(activeMonsterList, monster)
	end
end

-- Utility functions
function initialize()
	currentlyRandomizedEnemyTable = PersistentVars.currentlyRandomizedEnemyTable
	spawnedEnemyTable = PersistentVars.spawnedEnemyTable
	deadRandomTable = PersistentVars.deadRandomTable
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
	local seed = RNG:random(1, 4294967296)
	MCM.Set("rando_seed", seed)
	Hash.gameSeed = seed
end

function gameLoaded()
	Host = Osi.GetHostCharacter()
	playerFaction = Osi.GetFaction(Host)
	Channels.SeedRoller:Broadcast()
end

function strip_uuid(uuid)
	character_uuid = string.sub(uuid, -36)
	return character_uuid
end

function clearIconTables()
	if #iconTable > 0 then
		for i, uuid in ipairs(iconTable) do
			Channels.IconReplacer:Broadcast(uuid)
		end
		iconTable = {}
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

function startCombat()
	for monster, _ in pairs(spawnedEnemyTable) do
		local missingHP = 0

		local player, distance = Osi.GetClosestPlayer(monster)
		if not (distance and player) then
			return
		end
		if distance > 200 then
			local x, y, z = Osi.GetPosition(player)
			local x2, y2, z2 = Osi.FindValidPosition(x, y, z, 100, Host, 1)
			Osi.TeleportToPosition(monster, x2, y2, z2, "", 1, 1, 1, 0, 1)
		end
		
		for key, val in pairs(currentlyRandomizedEnemyTable) do
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
		Osi.SteerTo(monster, Host, 1)
		Osi.SetHostileAndEnterCombat(creatureFaction, playerFaction, monster, Host)
	end
end

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
	if MCM.Get("chaos_mode") then
		return Hash:selectEnemy(character, difficultyTables, true)
	end

	local boss = false

	if Ext.Entity.Get(character).CombatParticipant.Flags.IsBoss then
		boss = true
	end
	
	local level = Osi.GetLevel(character)
	local levelmin = MCM.Get("enemy_tier_min")
	local levelmax = MCM.Get("enemy_tier_max")
	
	-- TODO Figure out a way to meaningfully gauge difficulty of NPC being replaced and base selection on it
	local index = nil

	if level < 2 then
		index = 1
	elseif level < 4 then
		index = 2
	elseif level < 6 then
		index = 3
	elseif level < 8 then
		index = 4
	elseif level < 10 then
		index = 5
	elseif level < 11 then
		index = 6
	elseif level < 14 then
		index = 7
	elseif level < 21 then
		index = 8
	elseif level < 28 then
		index = 9
	else
		index = 10
	end
	
	local map = Osi.GetRegion(Host)
	if map == C.Regions.Act0 and index > 1 then
		levelmax = levelmax - 1
	end

	if boss then
		index = index + MCM.Get("boss_tier_boost")
	else
		index = index + MCM.Get("enemy_tier_boost")
	end

	local newTable = trimTable(index, difficultyTables, levelmin, levelmax)
	
	return Hash:selectEnemy(character, newTable, false)
end

function spawnNewCreature(character, x, y, z)
	spawnId = selectCreature(character)
	
	local x2, y2, z2 = Osi.FindValidPosition(x, y, z, 100, Host, 1)

	newCreatureId = Osi.CreateAt(spawnId, x2, y2, z2, 0, 1, "")

	return newCreatureId
end

function randomizeCreature(character)
	local x, y, z = Osi.GetPosition(character)
	local map = Osi.GetRegion(Host)
	local asylum = getAsylum(map)
	local combatGroup = Ext.Entity.Get(character).CombatParticipant.CombatGroupId

	local newCreature = spawnNewCreature(character, x, y, z)
	Ext.Entity.Get(newCreature).CombatParticipant.CombatGroupId = combatGroup
	Ext.Entity.Get(newCreature):Replicate("CombatParticipant")
	
	spawnedEnemyTable[newCreature] = true
	currentlyRandomizedEnemyTable[character] = {newCreature, x, y, z}
	Osi.ApplyStatus(character, "PARALYZED", -1.0, 1, character)
	Osi.TeleportToPosition(character, asylum.asylumX, asylum.asylumY, asylum.asylumZ, "", 1, 1, 1, 0, 1)
	
	character_uuid = strip_uuid(character)
	table.insert(iconTable, character_uuid)
	Ext.Timer.WaitFor(1600, clearIconTables)
	
	-- heavily incentivise Zhalk to aggro Mind Flayer
	if character == "S_TUT_Helm_Devil_005_ed103005-fd71-457d-ae6c-39654bbd8f2e" then
		Osi.RequestSetBaseArchetype(newCreature, "cinematic_melee")
		Osi.ApplyStatus(newCreature, "AER_ZHALK_FIX", -1.0, 1, newCreature)
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
			loadMonsterTable(tabletopMonsterList)
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
	
	
	if changeTables then
		setEnemyTables()
	end
	
	-- Update game seed if value changes
	if payload.settingId == "rando_seed" and payload.value ~= payload.oldValue then
		Hash.gameSeed = MCM.Get("rando_seed")
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
	
	if currentlyRandomizedEnemyTable[character] then
		Osi.ApplyStatus(character, "PARALYZED", -1.0, 1, character)
		
		local map = Osi.GetRegion(Host)
		local asylum = getAsylum(map)
		Osi.TeleportToPosition(character, asylum.asylumX, asylum.asylumY, asylum.asylumZ, "", 1, 1, 1, 0, 1)

		return
	end
	
	character_uuid = strip_uuid(character)
	if spawnedEnemyTable[character_uuid] or deadRandomTable[character_uuid] then
		return
	end
	
	creatureFaction = Osi.GetFaction(character)
	if Osi.GetRelation(creatureFaction, playerFaction) < 40 then
		newCreature = randomizeCreature(character)
		Osi.SetFaction(newCreature, creatureFaction)
		Ext.Timer.WaitFor(1400, startCombat)
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

	character_uuid = strip_uuid(character)

	for key, val in pairs(currentlyRandomizedEnemyTable) do
		if val[1] == character_uuid then
			Osi.Die(key, 0, "NULL_00000000-0000-0000-0000-000000000000", 0, 0)
			Osi.TeleportToPosition(key, val[2], val[3], val[4], "", 1, 1, 1, 0, 1)
			currentlyRandomizedEnemyTable[key] = nil
		end
	end
	if spawnedEnemyTable[character_uuid] then
		deadRandomTable[character_uuid] = true
		spawnedEnemyTable[character_uuid] = nil
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

Ext.Osiris.RegisterListener("StatusApplied", 4, "after", function(target, status, caster, storyId)
	if status == "SURPRISED" then
		statusTable[target] = "SURPRISED"
	end
end)

Channels.SeedRoll:SetHandler(function()
	rerollSeed()
end)

Ext.Events.SessionLoaded:Subscribe(initialize)