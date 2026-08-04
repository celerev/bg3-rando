local localItemList, globalItemList, rootTemplateItemList = Ext.Require("AERando/Server/Templates/ItemList.lua")

local C = Ext.Require("AERando/Constants.lua")
local Hash = Ext.Require("AERando/Hash.lua")
local RNG = Ext.Require("AERando/RNG.lua")


-- Fix Later: This won't update when the seed changes
local mappedUniqueItems = Hash:createUniqueItemMapping(rootTemplateItemList)


TemplateAddedTo((ROOT)_ObjectTemplate, (GUIDSTRING)_Object, (GUIDSTRING)_InventoryHolder, (STRING)_AddType)

Ext.Osiris.RegisterListener("TemplateAddedTo", 4, "before", function(template, object, owner, addtype)
	
end)