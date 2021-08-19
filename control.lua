local event_handler = require("event_handler")
local module = require("drawing-control")

if remote.interfaces["disable-brush-tools"] then
	module.events = nil
	module.on_nth_tick = nil
	module.commands = nil
	module.on_load = nil
	module.add_remote_interface = nil
	module.add_commands = nil
end

event_handler.add_lib(module)
