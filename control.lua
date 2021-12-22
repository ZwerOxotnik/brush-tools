local module = require("drawing-control")

if remote.interfaces["disable-brush-tools"] then
	module.events = nil
	module.on_nth_tick = nil
	module.commands = nil
	module.on_load = nil
	module.add_remote_interface = nil
	module.add_commands = nil
end

require("__zk-lib__/static-libs/lualibs/event_handler_vZO.lua").add_lib(module)
