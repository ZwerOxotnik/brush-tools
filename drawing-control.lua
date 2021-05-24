local module = {}


-- Global data
-- ###########
local player_last_point
local player_prev_fiqures
-- ###########


-- Constants
-- #########
local ABS = math.abs
local MAX_BRUSH_SIZE = 150
local MAX_DISTANCE = 150
local TOOLS = {
	"pen",
	"circle",
	"rectangle",
	"speech-bubble"
}
PEN_ID = 1
CIRCLE_ID = 2
RECTANGLE_ID = 3
SPEECH_BUBBLE_ID = 4
-- #########


local function get_id_tool(name)
	for id, tool_name in pairs(TOOLS) do
		if tool_name == name then
			return id
		end
	end
end

local function remeber_fiqure(player_index, new_id)
	local prev_fiqures = player_prev_fiqures[player_index]

	for key, id in pairs(prev_fiqures) do
		if id and rendering.is_valid(id) then
			if rendering.get_visible(id) == false then
				rendering.destroy(id)
				prev_fiqures[key] = nil
			end
		else
			prev_fiqures[key] = nil
		end
	end

	local count = #prev_fiqures
	if count >= 20 then
		for i=2, count - 1, 1 do
			prev_fiqures[i] = prev_fiqures[i + 1]
		end
		prev_fiqures[count] = new_id
	else
		prev_fiqures[count + 1] = new_id
	end
end

local function find_point(o1, o2, o3)
		return (o3.x < o1.x and o3.x > o2.x and o3.y < o1.y and o3.y > o2.y)
end

local function get_distance(o1, o2)
	return (ABS(o1.x - o2.x)^2 + ABS(o1.y - o2.y)^2)^0.5
end

local function check_stack(cursor_stack)
	if cursor_stack and cursor_stack.valid_for_read then
		return cursor_stack.name
	end
end

local function get_tool_color(player)
	local color
	local rgb_button = player.gui.top.rgb_button
	if rgb_button and rgb_button.valid then
		color = rgb_button.style.font_color
		color.a = 0.5
	end
	return color
end

local function remove_player_invisible_fiqures(player_index)
	local prev_fiqures = player_prev_fiqures[player_index]
	for i=#prev_fiqures, 1, -1 do
		local id = prev_fiqures[i]
		if id and rendering.is_valid(id) then
			if rendering.get_visible(id) == false then
				rendering.destroy(id)
			end
		end
	end
end

local function draw_rectangle(surface, player, left_top, right_bottom, color, filled)
	local brush_size = player.get_item_count("rectangle")
	if not filled then
		filled = brush_size >= MAX_BRUSH_SIZE
	end
	remeber_fiqure(player.index, rendering.draw_rectangle{
		surface = surface,
		left_top = left_top,
		right_bottom = right_bottom,
		color = color,
		filled = filled,
		width = brush_size,
		visible = true,
		draw_on_ground = true,
		only_in_alt_mode = true
	})
end

-- Creates a button on top for player to show tool color
local function create_button(player)
	local gui = player.gui.top
	if gui.rgb_button then
		return
	end

	-- local widget = gui.add{type = "empty-widget", name = "rgb_widget", style = "color_indicator"} -- I can't change the color
	local button = gui.add{type = "button", name = "rgb_button", style = "invisible_button", caption = '■'}
	button.style.font_color = {0, 0, 0, 1}
end

-- Creates/removes a GUI where a player can adjust the tool settings
local function toggle_drawing_settings_gui(player)
	local gui = player.gui.left
	if gui.drawing_settings then
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

	local frame = gui.add{type = "frame", name = "drawing_settings"}
	local main_table = frame.add{type = "table", name = "colors", column_count = 2}
	main_table.add{type = "label", caption = "R"}
	main_table.add{type = "slider", name = "r_DC_slider", style = "red_slider", maximum_value = 255, value = color.r * 255}
	main_table.add{type = "label", caption = "G"}
	main_table.add{type = "slider", name = "g_DC_slider", style = "green_slider", maximum_value = 255, value = color.g * 255}
	main_table.add{type = "label", caption = "B"}
	main_table.add{type = "slider", name = "b_DC_slider", style = "blue_slider", maximum_value = 255, value = color.b * 255}
end

-- Creates GUI to setup settings of new text on map
local function create_speech_bubble_UI(player, target_position)
	local gui = player.gui.center
	if gui.speech_bubble_menu then
		gui.speech_bubble_menu.destroy()
	end

	-- TODO: Refactor style
	local frame = gui.add{type = "frame", name = "speech_bubble_menu"}
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

-- Creates text using LuaRendering
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
		remeber_fiqure(player.index, rendering.draw_text{
			surface = player.surface,
			color = color,
			scale = brush_size,
			target = target_position,
			text = text,
			visible = true,
			alignment = "center",
			only_in_alt_mode = true
		})
	end
	player.gui.center.speech_bubble_menu.destroy()
end

-- Sets a brush tool for a player
local function set_new_tool(player, tool_name, tool_id)
	local main_inventory = player.get_main_inventory()
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

local function set_service_tool(player, tool_name)
	local main_inventory = player.get_main_inventory()
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

-- Gives a brush tool to a player
local function on_lua_shortcut(event)
	local player = game.get_player(event.player_index)
	if not (player and player.valid) then return end
	
	local prototype_name = event.prototype_name
	if prototype_name == "eraser-bt-shortcut" then
		set_service_tool(player, "eraser")
		local gui = player.gui
		local rgb_button = gui.top.rgb_button
		if rgb_button and rgb_button.valid then
			rgb_button.destroy()
		end
		local drawing_settings = gui.left.drawing_settings
		if drawing_settings and drawing_settings.valid then
			drawing_settings.destroy()
		end
	elseif prototype_name == "recolor-bt-shortcut" then
		set_service_tool(player, "recolor-bt")
		create_button(player)
	elseif prototype_name == "brush-bt-shortcut" then
		local tool_name = check_stack(player.cursor_stack)
		local tool_id = get_id_tool(tool_name)
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
	end
end

-- Trying to draw something by using a brush tool
local function on_script_trigger_effect(event)
	if not event.source_entity then return end -- doesn't work with players without characters
	local tool_name = event.effect_id
	local tool_id = get_id_tool(tool_name)
	if tool_id == nil then return end

	local entity = event.source_entity
	if not entity.valid then return end

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
	local prev_point_brush_id = player_last_point[player_index]
	-- TODO: recheck it for circle
	if prev_point_brush_id == nil then
		player_last_point[player_index] = rendering.draw_circle{
			surface = event.surface_index,
			radius = 0.2,
			color = color,
			filled = true,
			target = target_position,
			players = {player},
			time_to_live = 60 * 20,
			draw_on_ground = true
		}
		return
	elseif rendering.is_valid(prev_point_brush_id) == false then
		player_last_point[player_index] = rendering.draw_circle{
			surface = event.surface_index,
			radius = 0.2,
			color = color,
			filled = true,
			target = target_position,
			players = {player},
			time_to_live = 60 * 20,
			draw_on_ground = true
		}
		return
	end

	local prev_point_brush = rendering.get_target(prev_point_brush_id).position
	if prev_point_brush == target_position then return end

	if tool_id == PEN_ID then
		local distance = get_distance(prev_point_brush, target_position)
		if distance > MAX_DISTANCE then
			player.print({"brush-tools.respons.big-distance"})
		else
			remeber_fiqure(player_index, rendering.draw_line{
				surface = event.surface_index,
				color = color,
				width = brush_size,
				from = prev_point_brush,
				to = target_position,
				visible = true,
				draw_on_ground = true,
				only_in_alt_mode = true
			})
		end
	elseif tool_id == CIRCLE_ID then
		local distance = get_distance(prev_point_brush, target_position)
		if distance > (MAX_DISTANCE / 2) then
			player.print({"brush-tools.respons.big-distance"})
		else
			remeber_fiqure(player_index, rendering.draw_circle{
				surface = event.surface_index,
				radius = distance,
				color = color,
				filled = brush_size >= MAX_BRUSH_SIZE,
				width = brush_size,
				target = prev_point_brush,
				visible = true,
				draw_on_ground = true,
				only_in_alt_mode = true
			})
		end
	end
	rendering.destroy(prev_point_brush_id)
	player_last_point[player_index] = nil
end

-- Reduces size of selected brush tool
local function decrease_size(event, count)
	local player = game.get_player(event.player_index)
	if not (player and player.valid) then return end
	local tool_name = check_stack(player.cursor_stack)
	if not (tool_name and get_id_tool(tool_name)) then return end
	
	local brush_size = player.get_item_count(tool_name)
	if brush_size <= 1 then
		return
	elseif brush_size <= count then
		count = brush_size - 1
	end
	player.remove_item({name = tool_name, count = count})
end

-- Increases size of selected brush tool
local function increase_size(event, count)
	local player = game.get_player(event.player_index)
	if not (player and player.valid) then return end
	local tool_name = check_stack(player.cursor_stack)
	local tool_id = get_id_tool(tool_name)
	if not (tool_name and tool_id) then return end

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
	local tool_id = get_id_tool(tool_name)
	if not (tool_name and tool_id) then return end

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
	if not (player and player.valid) then return end
	local tool_name = check_stack(player.cursor_stack)
	local tool_id = get_id_tool(tool_name)
	if not (tool_name and tool_id) then return end

	-- Select next tool
	tool_id = tool_id + 1
	if tool_id > #TOOLS then
		tool_id = 1
	end
	tool_name = TOOLS[tool_id]

	set_new_tool(player, tool_name, tool_id)
end

-- Trying to draw or paint or remove fiqures
local function on_player_selected_area(event)
	local player = game.get_player(event.player_index)
	if not (player and player.valid) then return end

	local right_bottom = event.area.right_bottom
	local left_top = event.area.left_top
	local surface = event.surface
	local tool_name = event.item
	local is_tool = false
	if tool_name == "rectangle" then
		is_tool = true
		local distance = get_distance(left_top, right_bottom)
		if distance > MAX_DISTANCE then
			player.print({"brush-tools.respons.big-distance"})
		else
			draw_rectangle(surface, player, left_top, right_bottom, get_tool_color(player))
		end
	elseif tool_name == "eraser" then
		is_tool = true
		-- TODO: It must be optimized better
		-- Removes drawings in selected area
		local heaviness = 0
		for _, id in pairs(rendering.get_all_ids()) do
			if rendering.get_surface(id) == surface then
				local position = rendering.get_target(id)
				if position then
					if find_point(right_bottom, left_top, position.position) then
						rendering.destroy(id)
					end
				else
					local position1 = rendering.get_left_top(id) or rendering.get_from(id)
					local position2 = rendering.get_right_bottom(id) or rendering.get_to(id)
					if find_point(right_bottom, left_top, position1.position)
						and find_point(right_bottom, left_top, position2.position)
					then
						rendering.destroy(id)
					end
				end
				heaviness = heaviness + 10
			end
			heaviness = heaviness + 1
			if heaviness > 60000 then
				break
			end
		end
	elseif tool_name == "recolor-bt" then
		is_tool = true
		-- TODO: It must be optimized better
		-- Removes drawings in selected area
		local color = get_tool_color(player)
		if color == nil then return end
		local heaviness = 0
		for _, id in pairs(rendering.get_all_ids()) do
			if rendering.get_surface(id) == surface then
				local position = rendering.get_target(id)
				if position then
					if find_point(right_bottom, left_top, position.position) then
						rendering.set_color(id, color)
					end
				else
					local position1 = rendering.get_left_top(id) or rendering.get_from(id)
					local position2 = rendering.get_right_bottom(id) or rendering.get_to(id)
					if find_point(right_bottom, left_top, position1.position)
						and find_point(right_bottom, left_top, position2.position)
					then
						rendering.set_color(id, color)
					end
				end
				heaviness = heaviness + 10
			end
			heaviness = heaviness + 1
			if heaviness > 60000 then
				break
			end
		end
	end

	-- TODO: recheck it. Perhaps, it must be in another place
	if is_tool then
		local id = player_last_point[event.player_index]
		if id then
			player_last_point[event.player_index] = nil
			if rendering.is_valid(id) then
				rendering.destroy(id)
			end
		end
	end
end

-- Draw a rectangle
local function on_player_alt_selected_area(event)
	local player = game.get_player(event.player_index)
	if not (player and player.valid) then return end

	local right_bottom = event.area.right_bottom
	local left_top = event.area.left_top
	local surface = event.surface
	local tool_name = event.item
	if tool_name == "rectangle" then
		draw_rectangle(surface, player, left_top, right_bottom, get_tool_color(player), true)
	end
end

local BUTTONS = {
	["rgb_button"] = true,
	["speech_bubble_add_text_button"] = true,
}
local function on_gui_click(event)
	local element = event.element
	if not (element and element.valid) then return end
	local player = game.get_player(event.player_index)
	if not (player and player.valid) then return end
	if BUTTONS[element.name] == nil then return end

	if element.name == "rgb_button" then
		toggle_drawing_settings_gui(player)
	elseif element.name == "speech_bubble_add_text_button" then
		add_speech_bubble_text(player, element)
	end
end

-- TODO: refactor, there are too much actions during the events therefore it affects UPS
local function on_gui_value_changed(event)
	local element = event.element
	if not (element and element.valid) then return end
	local player = game.get_player(event.player_index)
	if not (player and player.valid) then return end
	local color_name, p = element.name:gsub("_DC_slider", '')
	if p < 1 then return end
	local rgb_button = player.gui.top.rgb_button
	if not (rgb_button and rgb_button.valid) then return end

	local new_color = rgb_button.style.font_color
	new_color[color_name] = element.slider_value / 255
	rgb_button.style.font_color = new_color
end

-- Makes invisible previous fiqure
local function undo(event)
	local player = game.get_player(event.player_index)
	if not (player and player.valid) then return end

	local prev_fiqures = player_prev_fiqures[event.player_index]
	for i=#prev_fiqures, 1, -1 do
		local id = prev_fiqures[i]
		if id and rendering.is_valid(id) then
			if rendering.get_visible(id) then
				rendering.set_visible(id, false)
				player.play_sound{path = "utility/undo", position = player.position, override_sound_type = "game-effect"}
				break
			end
		else
			prev_fiqures[i] = nil
		end
	end
end

-- Makes visible last invisible fiqure
local function redo(event)
	local player = game.get_player(event.player_index)
	if not (player and player.valid) then return end

	local prev_fiqures = player_prev_fiqures[event.player_index]
	for i=1, #prev_fiqures, 1 do
		local id = prev_fiqures[i]
		if id and rendering.is_valid(id) then
			if rendering.get_visible(id) == false then
				rendering.set_visible(id, true)
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
	remove_player_invisible_fiqures(player_index)
	player_last_point[player_index] = nil
	player_prev_fiqures[player_index] = nil
end

local function clear_player_data(event)
	local player_index = event.player_index
	remove_player_invisible_fiqures(player_index)
	player_last_point[player_index] = nil
	player_prev_fiqures[player_index] = {}
end

-- Adjusting player data
local function on_player_created(event)
	local player_index = event.player_index
	local player = game.get_player(player_index)
	if not (player and player.valid) then return end

	player_last_point[player_index] = nil
	player_prev_fiqures[player_index] = {}
end

-- Adjusting player data
local function on_player_joined_game(event)
	local player_index = event.player_index
	local player = game.get_player(player_index)
	if not (player and player.valid) then return end

	local prev_fiqures = player_prev_fiqures[player_index]
	if prev_fiqures then
		remove_player_invisible_fiqures(player_index)
	end

	player_last_point[player_index] = nil
	player_prev_fiqures[player_index] = {}
end

-- Adjusting player data
local function on_player_left_game(event)
	local player_index = event.player_index
	player_last_point[player_index] = nil
	local prev_fiqures = player_prev_fiqures[player_index]
	if prev_fiqures then
		remove_player_invisible_fiqures(player_index)
		prev_fiqures = nil
	end
end

local function remove_paintings_command(cmd)
	local player = game.get_player(cmd.player_index)
	if not (player and player.valid) then return end
	if not player.admin then
		player.print({"command-output.parameters-require-admin"})
		return
	end

	local heaviness = 0
	local surface = player.surface
	for _, id in pairs(rendering.get_all_ids()) do
		if rendering.get_surface(id) == surface then
			rendering.destroy(id)
		end
		heaviness = heaviness + 2
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
	for _, id in pairs(rendering.get_all_ids()) do
		if rendering.get_surface(id) == surface then
			count = count + 1
		end
	end

	player.print("Paintings on this surface: " .. tostring(count))
end

local function count_all_paintings_command(cmd)
	if cmd.player_index == 0 then
		print("Paintings: " .. #rendering.get_all_ids())
		return
	end
	local player = game.get_player(cmd.player_index)
	if not (player and player.valid) then return end
	player.print("Paintings: " .. #rendering.get_all_ids())
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
			local gui = player.gui
			local rgb_button = gui.top.rgb_button
			if rgb_button and rgb_button.valid then
				rgb_button.destroy()
			end
			local speech_bubble_menu = gui.center.speech_bubble_menu
			if speech_bubble_menu and speech_bubble_menu.valid then
				speech_bubble_menu.destroy()
			end
			local drawing_settings = gui.left.drawing_settings
			if drawing_settings then
				drawing_settings.destroy()
				return
			end
		end
	end
end


local function set_variables()
	player_last_point = global.player_last_point
	player_prev_fiqures = global.player_prev_fiqures
end

local function update_global_data()
	global.player_last_point = global.player_last_point or {}
	global.player_prev_fiqures = global.player_prev_fiqures or {}

	for player_index, _ in pairs(game.players) do
		global.player_last_point[player_index] = nil
		local prev_fiqures = global.player_prev_fiqures[player_index]
		if prev_fiqures then
			remove_player_invisible_fiqures(player_index)
			prev_fiqures = nil
		end
	end
end

module.on_init = (function()
	update_global_data()
	set_variables()
end)

module.on_load = (function()
	set_variables()
end)

module.on_configuration_changed = (function()
	update_global_data()
end)

-- TODO: add support of on_player_muted etc
module.events = {
	[defines.events.on_lua_shortcut] = on_lua_shortcut,
	[defines.events.on_script_trigger_effect] = on_script_trigger_effect,
	[defines.events.on_player_selected_area] = on_player_selected_area,
	[defines.events.on_player_alt_selected_area] = on_player_alt_selected_area,
	[defines.events.on_gui_click] = on_gui_click,
	[defines.events.on_player_created] = on_player_created,
	[defines.events.on_player_joined_game] = on_player_joined_game,
	[defines.events.on_player_left_game] = on_player_left_game,
	[defines.events.on_player_removed] = delete_player_data,
	[defines.events.on_player_changed_surface] = clear_player_data,
	[defines.events.on_player_respawned] = clear_player_data,
	[defines.events.on_gui_value_changed] = on_gui_value_changed,
	["undo-bt"] = undo,
	["redo-bt"] = redo,
	["-size-bt"] = function(e) decrease_size(e, 1) end,
	["+size-bt"] = function(e) increase_size(e, 1) end,
	["-10size-bt"] = function(e) decrease_size(e, 10) end,
	["+10size-bt"] = function(e) increase_size(e, 10) end,
	["select-prev-brush-tool"] = select_prev_brush_tool,
	["select-next-brush-tool"] = select_next_brush_tool,
	["give-paint-bt"] = function(event)
		event.prototype_name = "brush-bt-shortcut"
		on_lua_shortcut(event)
	end,
	["give-eraser-bt"] = function(event)
		event.prototype_name = "eraser-bt-shortcut"
		on_lua_shortcut(event)
	end,
	["give-recolor-bt"] = function(event)
		event.prototype_name = "recolor-bt-shortcut"
		on_lua_shortcut(event)
	end,
}

commands.add_command("remove-paintings", {"brush-tools-commands.description.remove-paintings"}, remove_paintings_command)
commands.add_command("remove-all-paintings", {"brush-tools-commands.description.remove-all-paintings"}, remove_paintings_all_command)
commands.add_command("count-paintings", {"brush-tools-commands.count-paintings"}, count_paintings_command)
commands.add_command("count-all-paintings", {"brush-tools-commands.count-all-paintings"}, count_all_paintings_command)
commands.add_command("delete-UI", {"brush-tools-commands.delete-UI"}, delete_UI_command)

return module
