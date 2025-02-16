
local M = {}


--#region Singleplayer data
local sp_prev_fiqures = {}
---#endregion


--#region Global data
local player_last_point
local player_prev_fiqures
local player_check_colors
local player_last_entity
---#endregion


--#region Constants
local draw_rectangle = rendering.draw_rectangle
local draw_circle = rendering.draw_circle
local draw_light = rendering.draw_light
local draw_text = rendering.draw_text
local draw_line = rendering.draw_line
local get_rendered_by_id = rendering.get_object_by_id
local tremove = table.remove
local MAX_BRUSH_SIZE = 150
local MAX_LIGHT_TOOL_SIZE = 100
local MAX_DISTANCE = 150
local HALF_MAX_DISTANCE = MAX_DISTANCE / 2
local TOOLS = {
	"pen",
	"circle",
	"rectangle",
	"speech-bubble",
	"light"
}
local PEN_ID = 1
local CIRCLE_ID = 2
local RECTANGLE_ID = 3
local SPEECH_BUBBLE_ID = 4
local LIGHT_ID = 5

local TOOLS_ID = {
	pen = PEN_ID,
	circle = CIRCLE_ID,
	rectangle = RECTANGLE_ID,
	["speech-bubble"] = SPEECH_BUBBLE_ID,
	light = LIGHT_ID
}
--#endregion


if script.mod_name ~= "brush-tools" then
	remote.remove_interface("disable-brush-tools")
	remote.add_interface("disable-brush-tools", {
		get_source = function()
			return script.mod_name
		end
	}) -- trying to disable another mod
end


--#region Utilities

---@param	player_index number
---@param new_id number
local function remeber_fiqure(player_index, new_id)
	local prev_fiqures = player_prev_fiqures[player_index] or sp_prev_fiqures

	for i=#prev_fiqures, 1, -1 do
		local rendered = get_rendered_by_id(prev_fiqures[i])
		if rendered.valid then
			if rendered.visible == false then -- TODO: check
				rendered.destroy()
				tremove(prev_fiqures, i)
			end
		else
			tremove(prev_fiqures, i)
		end
	end

	local count = #prev_fiqures
	if count >= 20 then
		for i=2, count - 1, 1 do
			prev_fiqures[i] = prev_fiqures[i + 1]
		end
		prev_fiqures[count] = new_id
	else
		prev_fiqures[#prev_fiqures+1] = new_id
	end
end

---@return boolean
local function find_point(p1, p2, p3)
	return (p3.x < p1.x and p3.x > p2.x and p3.y < p1.y and p3.y > p2.y)
end

---@return number
local function get_distance(start, stop)
	local xdiff = start.x - stop.x
	local ydiff = start.y - stop.y
	return (xdiff * xdiff + ydiff * ydiff)^0.5
end

---@return string
local function check_stack(cursor_stack)
	if cursor_stack and cursor_stack.valid_for_read then
		return cursor_stack.name
	end
end

---@param player table LuaPlayer
---@return table
local function get_tool_color(player)
	local color
	local rgb_button = player.gui.top.rgb_button
	if rgb_button and rgb_button.valid then
		color = rgb_button.style.font_color
		color.a = 0.5
	end
	return color
end

---@param player_index number
local function remove_player_invisible_fiqures(player_index)
	local prev_fiqures = player_prev_fiqures[player_index] or sp_prev_fiqures
	for i=#prev_fiqures, 1, -1 do
		local rendered = get_rendered_by_id(prev_fiqures[i])
		if rendered.valid and rendered.visible == false then
			rendered.destroy()
		end
	end
end

---@param surface table LuaSurface
---@param player table LuaPlayer
---@param left_top table position
---@param right_bottom table position
---@param color table color
---@param filled boolean
local function draw_rectangle_by_tool(surface, player, left_top, right_bottom, color, filled)
	local brush_size = player.get_item_count("rectangle")
	if not filled then
		filled = brush_size >= MAX_BRUSH_SIZE
	end
	remeber_fiqure(player.index, draw_rectangle({
		surface = surface,
		left_top = left_top,
		right_bottom = right_bottom,
		color = color,
		width = brush_size,
		filled = filled,
		visible = true,
		draw_on_ground = true,
		only_in_alt_mode = true
	}).id)
	if player.admin and player.mod_settings["brush-tools_dev-mode"].value then
		local message = "rendering.draw_rectangle{\n" ..
			"	surface = game.surfaces[\"" .. player.surface.name .. "\"],\n" ..
			"	left_top = {" .. left_top.x .. ", " .. left_top.y .. "},\n" ..
			"	right_bottom = {" .. right_bottom.x .. ", " .. right_bottom.y .. "},\n" ..
			"	color = " .. serpent.line(color) .. ",\n" ..
			"	width = " .. brush_size .. ",\n" ..
			"	filled = " .. tostring(filled) .. ",\n" ..
			"	visible = true,\n" ..
			"}\n"
		helpers.write_file("brush-tools-output.lua", message, true, player.index)
	end
end

---Creates a button on top for player to show tool color
---@param player table LuaPlayer
local function create_button(player)
	local gui = player.gui.top
	if gui.rgb_button then
		return
	end

	-- local widget = gui.add{type = "empty-widget", name = "rgb_widget", style = "color_indicator"} -- I can't change the color
	local button = gui.add{type = "button", name = "rgb_button", style = "invisible_button", caption = '■'}
	button.style.font_color = {0, 0, 0, 1}
end

---@param player table LuaPlayer
local function destroy_drawing_settings_gui(player)
	local gui = player.gui.left.drawing_settings
	if gui then
		player_check_colors[player.index] = nil
		gui.destroy()
	end
end

---Creates/removes a GUI where a player can adjust the tool settings
---@param player table LuaPlayer
local function toggle_drawing_settings_gui(player)
	local gui = player.gui.left
	if gui.drawing_settings then
		player_check_colors[player.index] = nil
		gui.drawing_settings.destroy()
		return
	end

	local color
	local rgb_button = player.gui.top.rgb_button
	if rgb_button and rgb_button.valid then
		color = rgb_button.style.font_color
	else
		return
	end

	player_check_colors[player.index] = true -- This is necessary to check colors
	local frame = gui.add{type = "frame", name = "drawing_settings"}
	local main_table = frame.add{type = "table", name = "colors", column_count = 2}
	main_table.add{type = "label", caption = "R"}
	main_table.add{type = "slider", name = "r_DC_slider", style = "red_slider", maximum_value = 255, value = color.r * 255}
	main_table.add{type = "label", caption = "G"}
	main_table.add{type = "slider", name = "g_DC_slider", style = "green_slider", maximum_value = 255, value = color.g * 255}
	main_table.add{type = "label", caption = "B"}
	main_table.add{type = "slider", name = "b_DC_slider", style = "blue_slider", maximum_value = 255, value = color.b * 255}
end

local function destroy_speech_bubble_UI(player)
	local gui = player.gui.center.speech_bubble_menu
	if gui then
		gui.destroy()
	end
end

---Creates GUI to setup settings of new text on map
---@param player table LuaPlayer
---@param target_position table position
local function create_speech_bubble_UI(player, target_position)
	destroy_speech_bubble_UI(player)

	-- TODO: Refactor style
	local frame = player.gui.center.add{type = "frame", name = "speech_bubble_menu"}
	local sub_table
	local main_table = frame.add{type = "table", column_count = 1}
	sub_table = main_table.add{type = "table", name = "target", column_count = 4}
	sub_table.add{type = "label", caption = "x: "}
	sub_table.add{type = "label", name = "x", caption = target_position.x}
	sub_table.add{type = "label", caption = "y: "}
	sub_table.add{type = "label", name = "y", caption = target_position.y}
	sub_table = main_table.add{type = "table", name = "table_text", column_count = 2}
	sub_table.add{type = "label", caption = "Text: "}
	sub_table.add{type = "textfield", name = "textfield"}
	sub_table = main_table.add{type = "table", column_count = 2}
	sub_table.add{type = "label", caption = "Size: "}
	-- local slider = sub_table2.add{type = "slider", name = "speech_bubble_size", maximum_value = 130}
	-- slider.style.horizontally_stretchable = true
	local button = main_table.add{type = "button", name = "speech_bubble_add_text_button", caption = "Add text"}
	button.style.horizontally_stretchable = true
end

---Creates text using LuaRendering
---@param player table LuaPlayer
---@param speech_bubble_add_text_button table GuiElement
local function add_speech_bubble_text(player, speech_bubble_add_text_button)
	local color = get_tool_color(player)
	if color == nil then return end
	local main_table = speech_bubble_add_text_button.parent
	local brush_size = player.get_item_count("speech-bubble")
	if brush_size < 1 then
		brush_size = 8
	elseif brush_size > 150 then
		brush_size = 150
	end

	local text = main_table.table_text.textfield.text
	if text == "" then
		player.print("Text no found")
	elseif #text > 400 / (brush_size / 14) then
		player.print("Too long text")
	else
		local target_position = {main_table.target.x.caption, main_table.target.y.caption - brush_size / 3.2}
		remeber_fiqure(player.index, draw_text({
			surface = player.surface,
			color = color,
			scale = brush_size,
			target = target_position,
			text = text,
			visible = true,
			alignment = "center",
			only_in_alt_mode = true
		}).id)
		if player.admin and player.mod_settings["brush-tools_dev-mode"].value then
			local message = "rendering.draw_text{\n" ..
				"	surface = game.surfaces[\"" .. player.surface.name .. "\"],\n" ..
				"	color = " .. serpent.line(color) .. ",\n" ..
				"	scale = " .. brush_size .. ",\n" ..
				"	target = {" .. target_position[1] .. ", " .. target_position[2] .. "},\n" ..
				"	text = \"" .. text .. "\",\n" ..
				"	visible = true,\n" ..
				"	alignment = \"center\",\n" ..
				"}\n"
			helpers.write_file("brush-tools-output.lua", message, true, player.index)
		end
	end
	player.gui.center.speech_bubble_menu.destroy()
end

---Sets a brush tool for a player
---@param player table LuaPlayer
---@param tool_name string
---@param tool_id number
local function set_new_tool(player, tool_name, tool_id)
	local main_inventory = player.get_main_inventory()
	if not (main_inventory and main_inventory.valid) then return end
	local item_count = player.get_item_count(tool_name)
	local cursor_stack = player.cursor_stack
	if item_count > 0 then
		if player.clear_cursor() then
			local new_stack, new_stack_index = main_inventory.find_item_stack(tool_name)
			cursor_stack.transfer_stack(new_stack)
			player.hand_location = {inventory = main_inventory.index, slot = new_stack_index}
		end
	else
		local count = 12
		if tool_id == SPEECH_BUBBLE_ID then
			count = 8
		elseif tool_id == LIGHT_ID then
			count = MAX_LIGHT_TOOL_SIZE
		end
		local stack_spec = {name = tool_name, count = count}
		-- insert into main inventory first, then transfer and set the hand location
		if main_inventory.can_insert(stack_spec) and player.clear_cursor() then
			main_inventory.insert(stack_spec)
			local new_stack, new_stack_index = main_inventory.find_item_stack(tool_name)
			cursor_stack.transfer_stack(new_stack)
			player.hand_location = {inventory = main_inventory.index, slot = new_stack_index}
		else
			player.print{"cant-clear-cursor"}
		end
	end
	create_button(player)
end

---@param player table LuaPlayer
---@param tool_name string
local function set_service_tool(player, tool_name)
	local main_inventory = player.get_main_inventory()
	if not (main_inventory and main_inventory.valid) then return end
	local cursor_stack = player.cursor_stack
	local stack_spec = {name = tool_name}
	-- insert into main inventory first, then transfer and set the hand location
	if main_inventory.can_insert(stack_spec) and player.clear_cursor() then
		main_inventory.insert(stack_spec)
		local new_stack, new_stack_index = main_inventory.find_item_stack(tool_name)
		cursor_stack.transfer_stack(new_stack)
		player.hand_location = {inventory = main_inventory.index, slot = new_stack_index}
	else
		player.print{"cant-clear-cursor"}
	end
end

---Removes drawings in selected area
---@param surface table LuaSurface
---@param right_bottom table position
---@param left_top table position
local function erase_from_surface(surface, right_bottom, left_top)
	-- TODO: It must be optimized better
	local heaviness = 0
	local ids = rendering.get_all_objects()
	for i=1, #ids do
		local rendered = get_rendered_by_id(ids[i])
		if rendered.valid and rendered.surface == surface then
			local target = rendered.target
			if target then
				if target.entity then
					if find_point(right_bottom, left_top, target.entity.position) then
						rendered.destroy()
					end
				else
					if find_point(right_bottom, left_top, target.position) then
						rendered.destroy()
					end
				end
			else
				-- TODO: optimize this!
				local target1 = rendered.left_top or rendered.from
				local target2 = rendered.right_bottom or rendered.to
				if target1 and target1.position and target2 and target2.position then
					if find_point(right_bottom, left_top, target1.position)
						and find_point(right_bottom, left_top, target2.position)
					then
						rendered.destroy()
					end
				end
			end
			heaviness = heaviness + 14
		end
		heaviness = heaviness + 2
		if heaviness > 60000 then
			break
		end
	end
end

--#endregion


--#region Functions of events

local SHORTCUTS = {
	["eraser-bt-shortcut"] = function(player)
		set_service_tool(player, "eraser")
		player_check_colors[player.index] = nil
		local gui = player.gui
		local rgb_button = gui.top.rgb_button
		if rgb_button and rgb_button.valid then
			rgb_button.destroy()
		end
		local drawing_settings = gui.left.drawing_settings
		if drawing_settings and drawing_settings.valid then
			drawing_settings.destroy()
		end
	end,
	["recolor-bt-shortcut"] = function(player)
		set_service_tool(player, "recolor-bt")
		create_button(player)
	end,
	["brush-bt-shortcut"] = function(player)
		local tool_name = check_stack(player.cursor_stack)
		local tool_id = TOOLS_ID[tool_name]
		if tool_id then
			-- Select next tool
			tool_id = tool_id + 1
			if tool_id > #TOOLS then
				tool_id = 1
			end
			tool_name = TOOLS[tool_id]
			set_new_tool(player, tool_name, tool_id)
		else
			set_new_tool(player, "pen", PEN_ID)
		end
	end,
}

---Gives a brush tool to a player
local function on_lua_shortcut(event)
	local f = SHORTCUTS[event.prototype_name]
	if f then f(game.get_player(event.player_index)) end
end

---Trying to draw something by using a brush tool
local function on_script_trigger_effect(event)
	if event.source_entity == nil then return end -- doesn't work with players who don't have characters
	local tool_name = event.effect_id
	local tool_id = TOOLS_ID[tool_name]
	if tool_id == nil then return end

	local entity = event.source_entity
	entity.insert({name = tool_name})
	local target_position = event.target_position
	local brush_size = entity.get_item_count(tool_name)
	local player = entity.player
	if brush_size == 1 and player.clear_cursor() then
		local main_inventory = player.get_main_inventory()
		local new_stack, new_stack_index = main_inventory.find_item_stack(tool_name)
		player.cursor_stack.transfer_stack(new_stack)
		player.hand_location = {inventory = main_inventory.index, slot = new_stack_index}
	end

	if tool_id == SPEECH_BUBBLE_ID then
		create_speech_bubble_UI(player, target_position)
		return
	end

	local color = get_tool_color(player)
	if color == nil then return end
	local player_index = player.index

	local is_entity = false
	if tool_id == LIGHT_ID then
		if player_last_entity[player_index] then
			is_entity = true
		else
			local selected_entity = player.selected
			if selected_entity then
				if selected_entity.valid then
					if selected_entity.type ~= "entity-ghost" then
						player_last_entity[player_index] = selected_entity
						return
					end
				else
					return
				end
			end
		end
	end

	local prev_point_brush
	local prev_point_brush_id = player_last_point[player_index]
	if is_entity == false then
		-- TODO: recheck it for circle
		if prev_point_brush_id == nil then
			player_last_point[player_index] = draw_circle({
				surface = event.surface_index,
				radius = 0.2,
				color = color,
				filled = true,
				target = target_position,
				players = {player},
				time_to_live = 60 * 20,
				draw_on_ground = true
			}).id
			return
		end

		local rendered = get_rendered_by_id(prev_point_brush_id)
		if rendered.valid == false then
			player_last_point[player_index] = draw_circle({
				surface = event.surface_index,
				radius = 0.2,
				color = color,
				filled = true,
				target = target_position,
				players = {player},
				time_to_live = 60 * 20,
				draw_on_ground = true
			}).id
			return
		end
		prev_point_brush = rendered.target.position
		if prev_point_brush == target_position then return end
	end

	if tool_id == PEN_ID then
		local distance = get_distance(prev_point_brush, target_position)
		if distance > MAX_DISTANCE then
			player.print({"brush-tools.respons.big-distance"})
		else
			remeber_fiqure(player_index, draw_line({
				surface = event.surface_index,
				color = color,
				width = brush_size,
				from = prev_point_brush,
				to = target_position,
				visible = true,
				draw_on_ground = true,
				only_in_alt_mode = true
			}).id)
			if player.admin and player.mod_settings["brush-tools_dev-mode"].value then
				local message = "rendering.draw_line{\n" ..
					"	surface = game.surfaces[\"" .. player.surface.name .. "\"],\n" ..
					"	color = " .. serpent.line(color) .. ",\n" ..
					"	width = " .. brush_size .. ",\n" ..
					"	from = {" .. prev_point_brush.x .. ", " .. prev_point_brush.y .. "},\n" ..
					"	to = {" .. target_position.x .. ", " .. target_position.y .. "},\n" ..
					"	visible = true,\n" ..
					"}\n"
				helpers.write_file("brush-tools-output.lua", message, true, player.index)
			end
		end
	elseif tool_id == CIRCLE_ID then
		local distance = get_distance(prev_point_brush, target_position)
		if distance > HALF_MAX_DISTANCE then
			player.print({"brush-tools.respons.big-distance"})
		else
			remeber_fiqure(player_index, draw_circle({
				surface = event.surface_index,
				radius = distance,
				color = color,
				filled = brush_size >= MAX_BRUSH_SIZE,
				width = brush_size,
				target = prev_point_brush,
				visible = true,
				draw_on_ground = true,
				only_in_alt_mode = true
			}).id)
			if player.admin and player.mod_settings["brush-tools_dev-mode"].value then
				local message = "rendering.draw_circle{\n" ..
					"	surface = game.surfaces[\"" .. player.surface.name .. "\"],\n" ..
					"	radius = " .. distance .. ",\n" ..
					"	color = " .. serpent.line(color) .. ",\n" ..
					"	filled = " .. tostring(brush_size >= MAX_BRUSH_SIZE) .. ",\n" ..
					"	width = " .. brush_size .. ",\n" ..
					"	target = {" .. prev_point_brush.x .. ", " .. prev_point_brush.y .. "},\n" ..
					"	visible = true,\n" ..
					"}\n"
				helpers.write_file("brush-tools-output.lua", message, true, player.index)
			end
		end
	elseif tool_id == LIGHT_ID then
		if player.admin then
			local last_entity = player_last_entity[player_index]
			if last_entity then
				if not last_entity.valid then
					return
				end
			end
			local target = last_entity or prev_point_brush
			local distance = get_distance(target.position or target, target_position)
			if distance > HALF_MAX_DISTANCE then
				player.print({"brush-tools.respons.big-distance"})
			else
				if color.r == 0 and color.g == 0 and color.b == 0 then
					player.print("Color is black, change your color")
				else
					remeber_fiqure(player_index, draw_light({
						surface = event.surface_index,
						sprite = "utility/light_medium",
						scale = distance / 3.4,
						color = color,
						intensity = brush_size / MAX_LIGHT_TOOL_SIZE,
						target = target,
						visible = true,
						only_in_alt_mode = false
					}).id)
					if prev_point_brush and player.mod_settings["brush-tools_dev-mode"].value then
						local message = "rendering.draw_light{\n" ..
							"	surface = game.surfaces[\"" .. player.surface.name .. "\"],\n" ..
							" sprite = \"utility/light_cone\",\n" ..
							"	scale = " .. distance / 3.4 .. ",\n" ..
							"	color = " .. serpent.line(color) .. ",\n" ..
							"	intensity = " .. brush_size / MAX_LIGHT_TOOL_SIZE .. ",\n" ..
							"	target = {" .. prev_point_brush.x .. ", " .. prev_point_brush.y .. "},\n" ..
							"	visible = true,\n" ..
							"}\n"
						helpers.write_file("brush-tools-output.lua", message, true, player.index)
						end
				end
			end
		else
			player.print({"command-output.parameters-require-admin"})
		end
	end

	if prev_point_brush_id then
		local rendered = get_rendered_by_id(prev_point_brush_id)
		rendered.destroy()
		player_last_point[player_index] = nil
	end
	player_last_entity[player_index] = nil
end

---Reduces size of selected brush tool
local function decrease_size(event, count)
	local player = game.get_player(event.player_index)
	local tool_name = check_stack(player.cursor_stack)
	if not (tool_name and TOOLS_ID[tool_name]) then return end

	local brush_size = player.get_item_count(tool_name)
	if brush_size <= 1 then
		return
	elseif brush_size <= count then
		count = brush_size - 1
	end
	player.remove_item({name = tool_name, count = count})
end

---Increases size of selected brush tool
local function increase_size(event, count)
	local player = game.get_player(event.player_index)
	local tool_name = check_stack(player.cursor_stack)
	local tool_id = TOOLS_ID[tool_name]
	if tool_id == nil then return end

	local brush_size = player.get_item_count(tool_name)
	if brush_size >= MAX_BRUSH_SIZE then
		return
	elseif brush_size + count >= MAX_BRUSH_SIZE then
		count = MAX_BRUSH_SIZE - brush_size
		if count < 1 then return end
	end
	player.insert({name = tool_name, count = count})
end

local function select_prev_brush_tool(event)
	local player = game.get_player(event.player_index)
	if not (player and player.valid) then return end
	local tool_name = check_stack(player.cursor_stack)
	local tool_id = TOOLS_ID[tool_name]
	if tool_id == nil then return end

	-- Selects prev tool
	tool_id = tool_id - 1
	if tool_id <= 0 then
		tool_id = #TOOLS
	end
	tool_name = TOOLS[tool_id]

	set_new_tool(player, tool_name, tool_id)
end

local function select_next_brush_tool(event)
	local player = game.get_player(event.player_index)
	local tool_name = check_stack(player.cursor_stack)
	local tool_id = TOOLS_ID[tool_name]
	if tool_id == nil then return end

	-- Select next tool
	tool_id = tool_id + 1
	if tool_id > #TOOLS then
		tool_id = 1
	end
	tool_name = TOOLS[tool_id]

	set_new_tool(player, tool_name, tool_id)
end

local TOOLS_ON_SELECTING = {
	["recolor-bt"] = function(event, player)
		local area = event.area
		local right_bottom = area.right_bottom
		local left_top = area.left_top
		local surface = event.surface

		-- TODO: It must be optimized better
		-- Removes drawings in selected area
		local color = get_tool_color(player)
		if color == nil then return end
		local heaviness = 0
		local ids = rendering.get_all_objects()
		for i=1, #ids do
			local rendered = get_rendered_by_id(ids[i])
			if rendered.valid and rendered.surface == surface then
				local target = rendered.target
				if target then -- TODO: recheck
					if target.entity then
						if find_point(right_bottom, left_top, target.entity.position) then
							rendered.color = color
						end
					else
						if find_point(right_bottom, left_top, target.position) then
							rendered.color = color
						end
					end
				else
					local target1 = rendered.left_top or rendered.from
					local target2 = rendered.right_bottom or rendered.to
					if target1 and target2 and target1.position and target2.position then
						if find_point(right_bottom, left_top, target1.position)
							and find_point(right_bottom, left_top, target2.position)
						then
							rendered.color = color
						end
					end
				end
				heaviness = heaviness + 14
			end
			heaviness = heaviness + 2
			if heaviness > 60000 then
				break
			end
		end

		-- TODO: refactor
		local id = player_last_point[event.player_index]
		if id then
			player_last_point[event.player_index] = nil
			local rendered = get_rendered_by_id(id)
			if rendered.valid then
				rendered.destroy()
			end
		end
	end,
	["eraser"] = function(event, player)
		local area = event.area
		erase_from_surface(event.surface, area.right_bottom, area.left_top)

		-- TODO: refactor
		local id = player_last_point[event.player_index]
		if id then
			player_last_point[event.player_index] = nil
			local rendered = get_rendered_by_id(id)
			if rendered.valid then
				rendered.destroy()
			end
		end
	end,
	["rectangle"] = function(event, player)
		local area = event.area
		local right_bottom = area.right_bottom
		local left_top = area.left_top
		local distance = get_distance(left_top, right_bottom)
		if distance > MAX_DISTANCE then
			player.print({"brush-tools.respons.big-distance"})
		else
			draw_rectangle_by_tool(event.surface, player, left_top, right_bottom, get_tool_color(player))
		end

		-- TODO: refactor
		local id = player_last_point[event.player_index]
		if id then
			player_last_point[event.player_index] = nil
			local rendered = get_rendered_by_id(id)
			if rendered.valid then
				rendered.destroy()
			end
		end
	end
}

---Trying to draw or paint or remove fiqures
local function on_player_selected_area(event)
	local f = TOOLS_ON_SELECTING[event.item]
	if f then f(event, game.get_player(event.player_index)) end
end

---Draw a rectangle
local function on_player_alt_selected_area(event)
	if event.item == "rectangle" then
		local area = event.area
		local player = game.get_player(event.player_index)
		draw_rectangle_by_tool(event.surface, player, area.left_top, area.right_bottom, get_tool_color(player), true)
	end
end

local GUIS = {
	["rgb_button"] = function(element, player)
		toggle_drawing_settings_gui(player)
	end,
	["speech_bubble_add_text_button"] = function(element, player)
		add_speech_bubble_text(player, element)
	end,
}
local function on_gui_click(event)
	local element = event.element
	local f = GUIS[element.name]
	if f then f(element, game.get_player(event.player_index)) end
end

---We use update_color_button() instead of this slow method (left it as a reminder)
-- local function on_gui_value_changed(event)
-- 	local element = event.element
-- 	if not (element and element.valid) then return end
-- 	local player = game.get_player(event.player_index)
-- 	if not (player and player.valid) then return end
-- 	local color_name, p = element.name:gsub("_DC_slider", '')
-- 	if p < 1 then return end
-- 	local rgb_button = player.gui.top.rgb_button
-- 	if not (rgb_button and rgb_button.valid) then return end

-- 	local new_color = rgb_button.style.font_color
-- 	new_color[color_name] = element.slider_value / 255
-- 	rgb_button.style.font_color = new_color
-- end

---Makes invisible previous fiqure
local function undo(event)
	local player_index = event.player_index
	local player = game.get_player(player_index)

	local prev_fiqures = player_prev_fiqures[player_index] or sp_prev_fiqures
	for i=#prev_fiqures, 1, -1 do
		local rendered = get_rendered_by_id(prev_fiqures[i])
		if rendered.valid then
			if rendered.visible then
				rendered.visible = false
				player.play_sound{path = "utility/undo", position = player.position, override_sound_type = "game-effect"}
				break
			end
		else
			prev_fiqures[i] = nil
		end
	end
end

---Makes visible last invisible fiqure
local function redo(event)
	local player = game.get_player(event.player_index)

	local prev_fiqures = player_prev_fiqures[event.player_index] or sp_prev_fiqures
	for i=1, #prev_fiqures do
		local rendered = get_rendered_by_id(prev_fiqures[i])
		if rendered.valid then
			if not rendered.visible then
				rendered.visible = true
				player.play_sound{path = "utility/blueprint_selection_ended", position = player.position, override_sound_type = "game-effect"}
				break
			end
		else
			prev_fiqures[i] = nil
		end
	end
end

local function delete_player_data(event)
	local player_index = event.player_index

	if player_prev_fiqures[player_index] then
		remove_player_invisible_fiqures(player_index)
		player_prev_fiqures[player_index] = nil
	end
	player_last_point[player_index] = nil
	player_last_entity[player_index] = nil
	player_check_colors[player_index] = nil
end

local function clear_player_data(event)
	local player_index = event.player_index
	local player = game.get_player(player_index)
	if not(player and player.valid) then return end

	remove_player_invisible_fiqures(player_index)
	player_last_point[player_index] = nil
	player_last_entity[player_index] = nil
	player_prev_fiqures[player_index] = {}
	destroy_speech_bubble_UI(player)
end

---Adjusting player data
local function on_player_created(event)
	local player_index = event.player_index
	local player = game.get_player(player_index)
	if not (player and player.valid) then return end

	player_last_point[player_index] = nil
	player_last_entity[player_index] = nil
	player_prev_fiqures[player_index] = {}
end

---Adjusting player data
local function on_player_joined_game(event)
	local player_index = event.player_index
	local player = game.get_player(player_index)
	if not (player and player.valid) then return end

	if player_prev_fiqures[player_index] then
		remove_player_invisible_fiqures(player_index)
	end

	player_last_point[player_index] = nil
	player_last_entity[player_index] = nil
	player_prev_fiqures[player_index] = {}
	destroy_drawing_settings_gui(player)
	destroy_speech_bubble_UI(player)
end

---Adjusting player data
local function on_player_left_game(event)
	local player_index = event.player_index
	player_last_point[player_index] = nil
	player_last_entity[player_index] = nil
	if player_prev_fiqures[player_index] then
		remove_player_invisible_fiqures(player_index)
		player_prev_fiqures[player_index] = nil
	end

	local player = game.get_player(player_index)
	if not (player and player.valid) then return end
	destroy_drawing_settings_gui(player)
	destroy_speech_bubble_UI(player)
end

-- TODO: optimize
---@param player_index number
local function update_color_button(player_index)
	local gui = game.get_player(player_index).gui
	local colors_UI = gui.left.drawing_settings.colors
	gui.top.rgb_button.style.font_color = {
		r = colors_UI.r_DC_slider.slider_value,
		g = colors_UI.g_DC_slider.slider_value,
		b = colors_UI.b_DC_slider.slider_value
	}
end

--#endregion


--#region Commands

local function remove_paintings_command(cmd)
	local player = game.get_player(cmd.player_index)
	if not (player and player.valid) then return end
	if not player.admin then
		player.print({"command-output.parameters-require-admin"})
		return
	end

	local heaviness = 0
	local surface = player.surface
	local ids = rendering.get_all_objects()
	for i=1, #ids do
		local rendered = get_rendered_by_id(ids[i])
		if rendered.surface == surface then -- TODO: check
			rendered.destroy()
		end
		heaviness = heaviness + 3
		if heaviness > 60000 then
			break
		end
	end
	player.print("All paintings are removed on surface \"" .. surface.name .. "\"")
end

local function remove_paintings_all_command(cmd)
	if cmd.player_index == 0 then
		rendering.clear()
		print("All paintings are removed")
		return
	end

	local player = game.get_player(cmd.player_index)
	if not (player and player.valid) then return end
	if not player.admin then
		player.print({"command-output.parameters-require-admin"})
		return
	end

	rendering.clear()
	player.print("All paintings are removed")
end

local function count_paintings_command(cmd)
	local player = game.get_player(cmd.player_index)
	if not (player and player.valid) then return end
	if not player.admin then
		player.print({"command-output.parameters-require-admin"})
		return
	end

	local surface = player.surface
	local count = 0
	local ids = rendering.get_all_objects()
	for i=1, #ids do
		local rendered = get_rendered_by_id(ids[i])
		if rendered.surface == surface then
			count = count + 1
		end
	end

	player.print("Paintings on this surface: " .. tostring(count))
end

local function count_all_paintings_command(cmd)
	if cmd.player_index == 0 then
		print("Paintings: " .. #rendering.get_all_objects())
		return
	end
	local player = game.get_player(cmd.player_index)
	if not (player and player.valid) then return end
	player.print("Paintings: " .. #rendering.get_all_objects())
end

local function delete_UI_command(cmd)
	if cmd.player_index == 0 then
		print("Deleted UIs")
	else
		local player = game.get_player(cmd.player_index)
		if not (player and player.valid) then return end
		if not player.admin then
			player.print({"command-output.parameters-require-admin"})
			return
		end
		player.print("Deleted UIs")
	end

	for _, player in pairs(game.players) do
		if player.valid then
			player_check_colors[player.index] = nil
			local gui = player.gui
			local rgb_button = gui.top.rgb_button
			if rgb_button and rgb_button.valid then
				rgb_button.destroy()
			end
			destroy_drawing_settings_gui(player)
			destroy_speech_bubble_UI(player)
		end
	end
end

--#endregion


--#region Pre-game stage

local function link_data()
	player_last_point = storage.player_last_point
	player_prev_fiqures = storage.player_prev_fiqures
	player_check_colors = storage.player_check_colors
	player_last_entity = storage.player_last_entity
end

local function update_global_data()
	storage.player_last_point = {}
	storage.player_check_colors = {}
	storage.player_last_entity = {}
	storage.player_prev_fiqures = storage.player_prev_fiqures or {}

	link_data()

	for player_index in pairs(player_prev_fiqures) do
		if player_prev_fiqures[player_index] then
			remove_player_invisible_fiqures(player_index)
			player_prev_fiqures[player_index] = nil
		end
		local player = game.get_player(player_index) --TODO: recheck
		destroy_drawing_settings_gui(player)
		destroy_speech_bubble_UI(player)
	end
end


M.on_init = update_global_data
M.on_configuration_changed = update_global_data
M.on_load = link_data

--#endregion


-- TODO: add support of on_player_muted etc

---@type table<number|string, function>
M.events = {
	[defines.events.on_lua_shortcut] = function(e) pcall(on_lua_shortcut, e) end,
	[defines.events.on_script_trigger_effect] = function(e) pcall(on_script_trigger_effect, e) end,
	[defines.events.on_player_selected_area] = function(e) pcall(on_player_selected_area, e) end,
	[defines.events.on_player_alt_selected_area] = function(e) pcall(on_player_alt_selected_area, e) end,
	[defines.events.on_gui_click] = function(e) pcall(on_gui_click, e) end,
	[defines.events.on_player_created] = on_player_created,
	[defines.events.on_player_joined_game] = on_player_joined_game,
	[defines.events.on_player_left_game] = on_player_left_game,
	[defines.events.on_player_removed] = delete_player_data,
	[defines.events.on_player_changed_surface] = clear_player_data,
	[defines.events.on_player_respawned] = clear_player_data,
	-- [defines.events.on_gui_value_changed] = on_gui_value_changed, -- please, do not use it. It impacts UPS significantly
	["undo-bt"]  = function(e) pcall(undo, e) end,
	["redo-bt"]  = function(e) pcall(redo, e) end,
	["plus_size-bt"]   = function(e) pcall(increase_size, e, 1) end,
	["plus_10size-bt"] = function(e) pcall(increase_size, e, 10) end,
	["-10size-bt"]     = function(e) pcall(decrease_size, e, 10) end,
	["-size-bt"]       = function(e) pcall(decrease_size, e, 1) end,
	["select-prev-brush-tool"] = function(e) pcall(select_prev_brush_tool, e) end,
	["select-next-brush-tool"] = function(e) pcall(select_next_brush_tool, e) end,
	["give-paint-bt"] = function(event)
		event.prototype_name = "brush-bt-shortcut"
		pcall(on_lua_shortcut, event)
	end,
	["give-eraser-bt"] = function(event)
		event.prototype_name = "eraser-bt-shortcut"
		pcall(on_lua_shortcut, event)
	end,
	["give-recolor-bt"] = function(event)
		event.prototype_name = "recolor-bt-shortcut"
		pcall(on_lua_shortcut, event)
	end,
}

---@type table<number, function>
M.on_nth_tick = {
	[50] = function()
		for player_index in pairs(player_check_colors) do
			pcall(update_color_button, player_index)
		end
	end
}

M.add_commands = function ()
	commands.add_command("remove-paintings", {"brush-tools-commands.description.remove-paintings"}, remove_paintings_command)
	commands.add_command("remove-all-paintings", {"brush-tools-commands.description.remove-all-paintings"}, remove_paintings_all_command)
	commands.add_command("count-paintings", {"brush-tools-commands.count-paintings"}, count_paintings_command)
	commands.add_command("count-all-paintings", {"brush-tools-commands.count-all-paintings"}, count_all_paintings_command)
	commands.add_command("delete-brush-tools-UI", {"brush-tools-commands.delete_UI"}, delete_UI_command)
end


return M
