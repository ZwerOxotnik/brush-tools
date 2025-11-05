local better_commands = require("__BetterCommands__/BetterCommands/control")
better_commands.COMMAND_PREFIX = "BrushT_"
better_commands.create_settings("BrushTools", "BrushT_") -- Adds switchable commands


data:extend({
	{
		type = "bool-setting",
		name = "brush-tools_dev-mode",
		setting_type = "runtime-per-user",
		default_value = false
	}
})
