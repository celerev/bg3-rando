-- Shared: create channels for both server and client
Channels = {}
Channels.IconReplacer = Ext.Net.CreateChannel(ModuleUUID, "IconReplacer")
Channels.SeedRoller = Ext.Net.CreateChannel(ModuleUUID, "SeedRoller")
Channels.SeedRoll = Ext.Net.CreateChannel(ModuleUUID, "SeedRoll")
return Channels