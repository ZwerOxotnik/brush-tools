---@param name string
---@param cooldown number?
---@param stack_size number?
local function create_paint_tool(name, cooldown, stack_size)
	data:extend({
		{
			type = "projectile",
			name = name,
			flags = {"not-on-map"},
			acceleration = 100,
			action = {
				{
					-- runs the script when projectile lands:
					type = "direct",
					action_delivery = {{type = "instant", target_effects = {type = "script", effect_id = name}}}
				}
			}
		}, {
			type = "capsule",
			name = name,
			icon = "__brush-tools__/icons/" .. name .. ".png",
			subgroup = "tool",
			order = "b[paint-tool]-a[" .. name .. "]",
			icon_size = 32,
			icon_mipmaps = nil,
			stack_size = stack_size or 150,
			capsule_action = {
				type = "throw",
				attack_parameters = {
					type = "projectile",
					activation_type = "throw",
					ammo_category = "capsule",
					cooldown = cooldown or 10,
					projectile_creation_distance = 0,
					range = 64,
					ammo_type = {
						category = "capsule",
						target_type = "position",
						action = {{type = "direct", action_delivery = {{type = "projectile", projectile = name, starting_speed = 100}}}}
					}
				}
			}
		}
	})
end

---@param name string
---@param stack_size number?
local function create_paint_select_tool(name, stack_size)
	local flags
	if stack_size and stack_size == 1 then
		flags = {"not-stackable", "only-in-cursor", "spawnable"}
	else
		flags = {"spawnable"}
	end

	data:extend({
		{
			type = "selection-tool",
			name = name,
			icon = "__brush-tools__/icons/" .. name .. ".png",
			hidden = true,
			select = {
				border_color = {1, 1, 1},
				mode = {"blueprint"},
				cursor_box_type = "copy",
			},
			alt_select = {
				border_color = {0, 1, 0},
				mode = {"blueprint"},
				cursor_box_type = "copy",
			},
			flags = flags,
			icon_size = 32,
			icon_mipmaps = nil,
			subgroup = "tool",
			order = "b[paint-tool]-a[" .. name .. "]",
			stack_size = stack_size or 150,
			entity_filter_count = nil,
			tile_filter_count = nil,
			selection_color = {230, 145, 0},
			selection_count_button_color = {195, 52, 52},
			alt_selection_color = {239, 153, 34},
			alt_selection_count_button_color = {255, 176, 66},
			selection_mode = {"nothing"},
			alt_selection_mode = {"nothing"},
			selection_cursor_box_type = "not-allowed",
			alt_selection_cursor_box_type = "not-allowed"
		}
	})
end


create_paint_tool("pen")
create_paint_tool("circle", 15)
create_paint_tool("speech-bubble")
create_paint_tool("light", nil, 100)
create_paint_select_tool("rectangle")
create_paint_select_tool("recolor-bt", 1)
create_paint_select_tool("eraser", 1)
