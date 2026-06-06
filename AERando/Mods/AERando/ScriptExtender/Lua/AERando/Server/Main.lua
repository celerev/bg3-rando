local baseMonsterList = Ext.Require("AERando/Server/Templates/Enemies.lua")
local tabletopMonsterList = Ext.Require("AERando/Server/Templates/ATTTemplates.lua")
local exandriaMonsterList = Ext.Require("AERando/Server/Templates/SOEEnemies.lua")

local C = Ext.Require("AERando/Constants.lua")
local Hash = Ext.Require("AERando/Hash.lua")
local RNG = Ext.Require("AERando/RNG.lua")

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
	Hash.gameSeed = MCM.Get("rando_seed")
else
	Hash.gameSeed = MCM.Get("rando_seed")
end

print(Hash.gameSeed)

activeMonsterList = {}
currentlyRandomizedEnemyTable = {}
spawnedEnemyTable = {}

difficultyTables = { 
	{ name = "low", weight = 20, enemies = {}},
	{ name = "mid", weight = 20, enemies = {}},
	{ name = "high", weight = 15, enemies = {}},
	{ name = "ultra", weight = 15, enemies = {}},
	{ name = "epic", weight = 10, enemies = {}},
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
    local dropList = {}

    for i = 1, range do
        if index - i >= 1 then
            table.insert(dropList, index - i)
        end
    end

    for i = 1, range do
        if index + i <= #difficultyTables then
            table.insert(dropList, index + i)
        end
    end
    
    local dropSet = {}
    for _, idx in ipairs(dropList) do
        dropSet[idx] = true
    end
    
    local newTable = {}
    for i, tier in ipairs(difficultyTables) do
        if not dropSet[i] then
            table.insert(newTable, tier)
        end
    end
    
    return newTable
end


function selectCreature(character)
	-- figure out syntax
	local boss = false
	if Ext.Entity.Get(character).CombatParticipant.Flags.IsBoss
		boss = true
	end
	
	
	local level = Osi.GetLevel(character)
	local levelvar = MCM.Get("enemy_tier_variance")
	
	-- TODO Figure out a way to meaningfully gauge difficulty of NPC being replaced and base selection on it
	local tier = low

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
		
	local newTable = trimTable(index, difficultyTables, levelvar)
	
	return Hash:selectEnemy(character, newTable)
end

function spawnNewCreature(character, x, y, z)
	spawnId = selectCreature(character)
	
	print("Spawn ID: ", spawnId)
	x2, y2, z2 = Osi.FindValidPosition(x, y, z, 100, Osi.GetHostCharacter(), 1)
	print("Correct coords: ", x2,y2,z2)
	newCreatureId = Osi.CreateAt(spawnId, x2, y2, z2, 0, 1, "")
	print("Is there an actual creature ID: ", newCreatureId)
	return newCreatureId
end

function randomizeCreature(character)
	x, y, z = Osi.GetPosition(character)
	
	print("Creature position", x," ", y," ", z)
	local map = Osi.GetRegion(Osi.GetHostCharacter())
	print("Map: ", map)
	asylum = getAsylum(map)
	print("Asylum: ", asylum)

	newCreature = spawnNewCreature(character, x, y, z)
	print("New: ", newCreature)
	spawnedEnemyTable[Ext.Entity.Get(newCreature)] = true
	currentlyRandomizedEnemyTable[character] = {newCreature, x, y, z}
	Osi.TeleportToPosition(character, asylum.asylumX, asylum.asylumY, asylum.asylumZ, "", 1, 1, 1, 0, 1)
	
	print("Current table: ", currentlyRandomizedEnemyTable)
	
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

	if spawnedEnemyTable[Ext.Entity.Get(character)] then
		return
	end
	
	creatureFaction = Osi.GetFaction(character)
	playerFaction = Osi.GetFaction(Osi.GetHostCharacter())
	
	if Osi.GetRelation(creatureFaction, playerFaction) < 40 then
		print("Randomizing ", character)
		newCreature = randomizeCreature(character)
		Osi.SetFaction(newCreature, creatureFaction)
		Osi.SetHostileAndEnterCombat(creatureFaction, playerFaction, newCreature, Osi.GetHostCharacter())
	end

end)

Ext.Osiris.RegisterListener("Died", 1, "after", function(character)
	for key, val in pairs(currentlyRandomizedEnemyTable) do
		if val[1] == character then
			Osi.TeleportToPosition(key, val[2], val[3], val[4], "", 1, 1, 1, 0, 1)
			Osi.Die(key, "DEATHTYPE.DoT", "NULL_00000000-0000-0000-0000-000000000000", 0, 1, 0.0)
			currentlyRandomizedEnemyTable[key] = nil
		end
	end
	if spawnedEnemyTable[character] then
		spawnedEnemyTable[character] = nil
	end
end)

-- GameState.OnLoad(function()
	-- local attspells = Ext.Mod.IsModLoaded("fa49db03-caa7-49c8-7c76-e6c38b60267a")
	-- if attspells then
		-- attInfo = Ext.Mod.GetMod("fa49db03-caa7-49c8-7c76-e6c38b60267a").Info
		-- if not (attInfo.ModVersion[1] == 1 and attInfo.ModVersion[2] == 1 and attInfo.ModVersion[3] == 9 and attInfo.ModVersion[4] >= 1) then
			-- Player.AskConfirmation([[
-- The expected version of the required dependency, AdvancedTabletopSpells is not loaded. If your version is older than 1.1.9.1, please exit the game, then update to 1.1.9.1 or newer.]])
		-- end
	-- else
		-- Player.AskConfirmation([[
-- AdvancedTabletopSpells is not loaded. The majority of AER's content will be missing, and the mod will be unstable.
-- Please exit the game, then install AdvancedTabletopSpells version 1.1.9.1 or newer.]])
	-- end
-- end)