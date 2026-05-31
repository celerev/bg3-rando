local baseMonsterList = Ext.Require("AERando/Server/Templates/Enemies.lua")
local tabletopMonsterList = Ext.Require("AERando/Server/Templates/ATTTemplates.lua")
local exandriaMonsterList = Ext.Require("AERando/Server/Templates/SOEEnemies.lua")

local C = Ext.Require("AERando/Constants.lua")
local Hash = Ext.Require("AERando/Hash.lua")
local RNG = Ext.Require("AERando/RNG.lua")

local seed = nil

if not seed then
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
	Hash.gameSeed = RNG:random(1, 4294967296)
else
	Hash.gameSeed = seed
end

print(Hash.gameSeed)

DefaultConfig = {
    ChaosMode = false, -- any enemy can be randomized to any creature, regardless of level
	tabletopMonsters = false, -- allow creatures adapted from tabletop D&D5e to be included
	exandriaMonsters = false, -- allow creatures adapted from Exandria to be included
}

-- TODO Figure out a way to meaningfully gauge difficulty of NPC being replaced and base selection on it

activeMonsterList = tabletopMonsterList

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


for _, tier in ipairs(difficultyTables) do
	for _, enemy in ipairs(activeMonsterList) do
		if tier.name == enemy.Tier then
			table.insert(tier.enemies, enemy.TemplateId)
		end
	end
end


CurrentlyRandomizedEnemyTable = {}

SpawnedEnemyTable = {}

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

function selectCreature(character)
	return Hash:selectEnemy(character, difficultyTables)
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
	SpawnedEnemyTable[Ext.Entity.Get(newCreature)] = true
	CurrentlyRandomizedEnemyTable[character] = {newCreature, x, y, z}
	Osi.TeleportToPosition(character, asylum.asylumX, asylum.asylumY, asylum.asylumZ, "", 1, 1, 1, 0, 1)
	
	print("Current table: ", CurrentlyRandomizedEnemyTable)
	
	return newCreature
end

Ext.Osiris.RegisterListener("EnteredCombat", 2, "after", function(character, _)
    if Osi.IsPlayer(character) == 1 or Osi.IsPartyFollower(character) == 1 then
        return
    end
	
	print("TABLE:  ", SpawnedEnemyTable[Ext.Entity.Get(character)])
	print(character)
	if SpawnedEnemyTable[Ext.Entity.Get(character)] then
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
	for key, val in pairs(CurrentlyRandomizedEnemyTable) do
		if val[1] == character then
			Osi.TeleportToPosition(key, val[2], val[3], val[4], "", 1, 1, 1, 0, 1)
			Osi.Die(key, "DEATHTYPE.DoT", "NULL_00000000-0000-0000-0000-000000000000", 0, 1, 0.0)
			CurrentlyRandomizedEnemyTable[key] = nil
		end
	end
	if SpawnedEnemyTable[character] then
		SpawnedEnemyTable[character] = nil
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