--- The RNG Class.
-- A Lua port of Johannes Baagøe's Alea
-- From http://baagoe.com/en/RandomMusings/javascript/
-- Johannes Baagøe <baagoe@baagoe.com>, 2010
-- Mirrored at:
-- https://github.com/nquinlan/better-random-numbers-for-javascript-mirror
-- @module ROT.RNG

local RNG = {}
local sha2 = Ext.Require("AERando/Hash.lua")

local function Mash ()
	local n = 0xefc8249d

	local function mash (data)
	data = tostring(data)

	for i = 1, data:len() do
		n = n + data:byte(i)
		local h = 0.02519603282416938 * n
		n = math.floor(h)
		h = h - n
		h = h * n
		n = math.floor(h)
		h = h - n
		n = n + h * 0x100000000 -- 2^32
	end
	return math.floor(n) * 2.3283064365386963e-10 -- 2^-32
	end

	return mash
end

function RNG:init(seed)
	self.s0 = 0
	self.s1 = 0
	self.s2 = 0
	self.c = 1
	self:setSeed(seed)
end

--- Seed.
-- seed the rng
-- @tparam[opt=os.clock()] number s A number to base the rng from
function RNG:setSeed(seed)
	self.c = 1
	self.seed = seed or math.random(1, 4294967296)

	local mash = Mash()
	self.s0 = mash(' ')
	self.s1 = mash(' ')
	self.s2 = mash(' ')

	self.s0 = self.s0 - mash(self.seed)
	if self.s0 < 0 then
		self.s0 = self.s0 + 1
	end
	self.s1 = self.s1 - mash(self.seed)
	if self.s1 < 0 then
		self.s1 = self.s1 + 1
	end
	self.s2 = self.s2 - mash(self.seed)
	if self.s2 < 0 then
		self.s2 = self.s2 + 1
	end
	mash = nil
end

function RNG:getUniform()
	-- return self.implementation()
	local t = 2091639 * self.s0 + self.c * 2.3283064365386963e-10 -- 2^-32
	self.s0 = self.s1
	self.s1 = self.s2
	self.c = math.floor(t)
	self.s2 = t - self.c
	return self.s2
end

function RNG:getUniformFromUUID(uuid)
	-- return self.implementation()
	local oldState = self:getState()
	local input = sha2.hash256(uuid .. ":" .. self.seed)
	local localseed = tonumber(input, 16)
	self:init(localseed)
	local t = 2091639 * self.s0 + self.c * 2.3283064365386963e-10 -- 2^-32
	self.s0 = self.s1
	self.s1 = self.s2
	self.c = math.floor(t)
	local result = t - self.c
	self:setState(oldState)
	return result
end

function RNG:getUniformFromUUIDNoLoop(uuid)
	-- return self.implementation()
	local input = sha2.hash256(uuid .. ":" .. self.seed)
	local localseed = tonumber(input, 16)
	self:init(localseed)
	local t = 2091639 * self.s0 + self.c * 2.3283064365386963e-10 -- 2^-32
	self.s0 = self.s1
	self.s1 = self.s2
	self.c = math.floor(t)
	local result = t - self.c
	return result
end

function RNG:getUniformInt(lowerBound, upperBound)
	local max = math.max(lowerBound, upperBound)
	local min = math.min(lowerBound, upperBound)
	return math.floor(self:getUniform() * (max - min + 1)) + min
end

function RNG:getUniformIntFromUUID(lowerBound, upperBound, uuid)
	local max = math.max(lowerBound, upperBound)
	local min = math.min(lowerBound, upperBound)
	return math.floor(self:getUniformFromUUIDNoLoop(uuid) * (max - min + 1)) + min
end


function RNG:getNormal(mean, stddev)
	repeat
		local u = 2*self:getUniform()-1
		local v = 2*self:getUniform()-1
		local r = u*u + v*v
	until r > 1 or r == 0

	local gauss = u * math.sqrt(-2*math.log(r)/r)
	return (mean or 0) + gauss*(stddev or 1)
end

function RNG:getPercentage()
	return 1 + math.floor(self:getUniform()*100)
end

function RNG:getWeightedValue(tbl)
	local total=0
	for _,v in pairs(tbl) do
		total=total+v
	end
	local rand=self:getUniform()*total
	local part=0
	for k,v in pairs(tbl) do
		part=part+v
		if rand<part then return k end
	end
	return nil
end

--- Get current rng state
-- Returns a table that can be given to the rng to return it to this state.
-- Any RNG of the same type will always produce the same values from this state.
-- @treturn table A table that represents the current state of the rng
function RNG:getState()
	return { self.s0, self.s1, self.s2, self.c, self.seed }
end

--- Set current rng state
-- used to return an rng to a known/previous state
-- @tparam table stateTable The table retrieved from .getState()
function RNG:setState(t)
	self.s0, self.s1, self.s2, self.c, self.seed =
		t[1], t[2], t[3], t[4], t[5]
end

function RNG:clone()
	local clone = self:extend()
	clone:setState(self:getState())
	return clone
end

-- Methods below mirror Lua's math.random and math.randomseed

--- Random.
-- get a random number
-- @tparam[opt=0] int a lower threshold for random numbers
-- @tparam[opt=1] int b upper threshold for random numbers
-- @treturn number a random number
function RNG:random(a, b)
	if not a then
		return self:getUniform()
	elseif not b then
		return self:getUniformInt(1, tonumber(a))
	else
		return self:getUniformInt(tonumber(a), tonumber(b))
	end
end


-- weighted_random forked from lua-misc by kinbei, licensed under MIT
-- https://github.com/kinbei/lua-misc/blob/master/weighted_random.lua
function RNG:weighted_random(tbl_weight, id, weight, uuid)
	id = id or "id"
	weight = weight or "weight"
	uuid = uuid or nil
	
	local t = {}
	local total_index = 0
	local total_weight = 0

	for _, v in pairs(tbl_weight) do
		total_index = total_index + 1
		assert( type(v[weight]) == "number" )
		total_weight = total_weight + v[weight]
		table.insert(t, { [id] = v[id], [weight] = v[weight] })
	end

	return function()
		local rand_index
		local oldState = self:getState()
		
		while true do
			rand_index = self:getUniformInt(1, total_index)
			if uuid then
				if self:getUniformIntFromUUID(1, total_weight, uuid) <= t[rand_index].weight then
					self:setState(oldState)
					return t[rand_index][id]
				end
			else
				if self:getUniformInt(1, total_weight) <= t[rand_index].weight then
					self:setState(oldState)
					return t[rand_index][id]
				end
			end
		end
	end
end

RNG:init(tonumber(MCM.Get("rando_seed")))

local Hash = {}

local function strip_uuid(uuid)
	character_uuid = string.sub(uuid, -36)
	return character_uuid
end

function Hash:selectChaosEnemy(UUID, chaosTable)
	local selectedList = chaosTable[1].enemies
	
	local rand = RNG:getUniformFromUUID(strip_uuid(UUID))

	local selectedEnemy = selectedList[math.floor(rand * #selectedList + 1)]
	return selectedEnemy
end

function Hash:selectEnemy(UUID, difficultyTables)
	local selectedList	= ""
	local validTiers = {}
	
	for _, tier in pairs(difficultyTables) do
		if tier.enemies and #tier.enemies > 0 then
			table.insert(validTiers, tier)
		end
	end
	
	if #validTiers == 0 then
		error("No valid tiers contain enemies. Did you disable the vanilla monster pool? It contains the majority of low and mid-tier enemies.")
	end
	
	local selectedTable = RNG:weighted_random(validTiers,"name","weight")()
	local selectedList = difficultyTables[selectedTable].enemies

	local rand = RNG:getUniformFromUUID(strip_uuid(UUID))
	local selectedEnemy = selectedList[math.floor(rand * #selectedList + 1)]
	return selectedEnemy
end


function Hash:selectItemByTemplate(uuid, rarityTable)
	local rand = RNG:getUniformFromUUID(strip_uuid(uuid))
	local selectedRarity = RNG:weighted_random(rarityTable,"name","weight", strip_uuid(uuid))()
	local selectedList = rarityTable[selectedRarity]

	local selectedItem = selectedList.items[math.floor(rand * #selectedList.items + 1)]

	return selectedItem
end


function Hash:createUniqueItemMapping(itemTable)
	local uniqueItemsList = {}
	local exandriaCheck = Ext.Mod.IsModLoaded("a27fdbe3-4d1a-641d-d05f-1ba4ee529da8")

	for _, item in ipairs(itemTable) do
		if item.ManualUnique then
			table.insert(uniqueItemsList, item)
		elseif Ext.Stats.Get(item.Name).Unique == 1 then
			table.insert(uniqueItemsList, item)
		end
	end
	
	local mapping = {}
	local usedTargets = {}
	local mappedTemplates = {}
	
	for _, item in ipairs(uniqueItemsList) do
		local rand = RNG:getUniformFromUUID(item.RootTemplate)
		local index = math.floor(rand * #uniqueItemsList) + 1

		local fromExandria = false
		if item.Mod[1] == "a27fdbe3-4d1a-641d-d05f-1ba4ee529da8" then
			fromExandria = true
		end

		local newTarget = false
		local targetItem
		for i = 1, #uniqueItemsList do
			local target = uniqueItemsList[index].RootTemplate
			if not usedTargets[target] then
				newTarget = true
				break	
			end	
			index = (index % #uniqueItemsList) + 1
		end
		
		if newTarget then
			targetItem = uniqueItemsList[index]
		else
			targetItem = item
		end
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
			table.insert(filteredList, item)
		end
	end
	
	return mapping, filteredList
end

return RNG, Hash