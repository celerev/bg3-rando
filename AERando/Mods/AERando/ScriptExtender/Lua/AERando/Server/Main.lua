local baseMonsterList = Ext.Require("AERando/Server/Templates/Enemies.lua")
local tabletopMonsterList = Ext.Require("AERando/Server/Templates/ATTTemplates.lua")
local exandriaMonsterList = Ext.Require("AERando/Server/Templates/SOEEnemies.lua")

local C = Ext.Require("AERando/Constants.lua")
local Hash = Ext.Require("AERando/Hash.lua")
local RNG = Ext.Require("AERando/RNG.lua")
local Channels = Ext.Require("AERando/Shared.lua")

if not PersistentVars then
	PersistentVars = {}
end
if not PersistentVars.currentlyRandomizedEnemyTable then
	PersistentVars.currentlyRandomizedEnemyTable = {}
end
if not PersistentVars.spawnedEnemyTable then
	PersistentVars.spawnedEnemyTable = {}
end

if Ext.Mod.IsModLoaded("a27fdbe3-4d1a-641d-d05f-1ba4ee529da8") then
	MCM.Set("soe_loaded", true)
end

if MCM.Get("rando_seed") == 0 then
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
else
	Hash.gameSeed = MCM.Get("rando_seed")
end

print("Seed:", Hash.gameSeed)

activeMonsterList = {}
iconTable = {}
currentlyRandomizedEnemyTable = PersistentVars.currentlyRandomizedEnemyTable
spawnedEnemyTable = PersistentVars.spawnedEnemyTable

difficultyTables = { 
	{ name = "low", weight = 20, enemies = {}},
	{ name = "mid", weight = 18, enemies = {}},
	{ name = "high", weight = 17, enemies = {}},
	{ name = "ultra", weight = 14, enemies = {}},
	{ name = "epic", weight = 11, enemies = {}},
	{ name = "legendary", weight = 7, enemies = {}},
	{ name = "mythical", weight = 6, enemies = {}},
	{ name = "divine", weight = 5, enemies = {}},
	{ name = "avatar", weight = 2, enemies = {}},
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

-- Error while dispatching user function call: [string "AERando/AERando/Server/Main.lua"]:111: String expected for argument 2, got nil
-- stack traceback:
        -- [C++ Code]: in field 'ApplyDamage'
        -- AERando/AERando/Server/Main.lua:111: in function <AERando/AERando/Server/Main.lua:110>
        -- [C++ Code]: in ?

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

function trimTable(index, difficultyTables, range)
	local newTable = {}
	if range == 0 then
		table.insert(newTable, difficultyTables[index])
		return newTable
	elseif range > 11 then
		table.insert(newTable, difficultyTables[9])
		return newTable
	elseif range > 9 then
		range = 9
	end

    local keepList = {}

    for i = 1, range do
        if index - i >= 1 then
            table.insert(keepList, index - i)
        end
    end
    
    table.insert(keepList, index)

    for i = 1, range do
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
	local levelvar = MCM.Get("enemy_tier_variance")
	
	-- TODO Figure out a way to meaningfully gauge difficulty of NPC being replaced and base selection on it
	local index = nil

	if level < 4 then
		index = 1
	elseif level < 6 then
		index = 2
	elseif level < 8 then
		index = 3
	elseif level < 10 then
		index = 4
	elseif level < 11 then
		index = 5
	elseif level < 14 then
		index = 6
	elseif level < 21 then
		index = 7
	elseif level < 28 then
		index = 8
	else
		index = 9
	end

	if boss then
		index = index + MCM.Get("boss_tier_boost")
	end

	local newTable = trimTable(index, difficultyTables, levelvar)
	
	return Hash:selectEnemy(character, newTable, false)
end

function spawnNewCreature(character, x, y, z)
	spawnId = selectCreature(character)
	
	x2, y2, z2 = Osi.FindValidPosition(x, y, z, 100, Osi.GetHostCharacter(), 1)

	newCreatureId = Osi.CreateAt(spawnId, x2, y2, z2, 0, 1, "")

	return newCreatureId
end

function randomizeCreature(character)
	x, y, z = Osi.GetPosition(character)
	
	local map = Osi.GetRegion(Osi.GetHostCharacter())

	asylum = getAsylum(map)

	newCreature = spawnNewCreature(character, x, y, z)

	spawnedEnemyTable[newCreature] = true
	currentlyRandomizedEnemyTable[character] = {newCreature, x, y, z}
	Osi.TeleportToPosition(character, asylum.asylumX, asylum.asylumY, asylum.asylumZ, "", 1, 1, 1, 0, 1)
	
	character_uuid = strip_uuid(character)
	table.insert(iconTable, character_uuid)
	Ext.Timer.WaitFor(1600, clearIconTables)
	
	return newCreature
end

setEnemyTables()

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
    if Osi.IsPlayer(character) == 1 or Osi.IsPartyFollower(character) == 1 then
        return
    end
	
	character_uuid = strip_uuid(character)
	if spawnedEnemyTable[character_uuid] then
		return
	end
	
	creatureFaction = Osi.GetFaction(character)
	playerFaction = Osi.GetFaction(Osi.GetHostCharacter())
	
	if Osi.GetRelation(creatureFaction, playerFaction) < 40 then
		newCreature = randomizeCreature(character)
		Osi.SetFaction(newCreature, creatureFaction)
		Osi.SetHostileAndEnterCombat(creatureFaction, playerFaction, newCreature, Osi.GetHostCharacter())
	end

end)

Ext.Osiris.RegisterListener("Died", 1, "after", function(character)
	character_uuid = strip_uuid(character)

	for key, val in pairs(currentlyRandomizedEnemyTable) do
		if val[1] == character_uuid then
			Osi.TeleportToPosition(key, val[2], val[3], val[4], "", 1, 1, 1, 0, 1)
			Osi.Die(key, 0, "NULL_00000000-0000-0000-0000-000000000000", 0, 0)
			currentlyRandomizedEnemyTable[key] = nil
		end
	end
	if spawnedEnemyTable[character_uuid] then
		spawnedEnemyTable[character_uuid] = nil
	end
end)

Ext.Events.SessionLoaded:Subscribe(initialize)