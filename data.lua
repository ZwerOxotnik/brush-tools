local MOD_PATH = "__brush-tools__"

local function create_paint_tool(name, cooldown)
	cooldown = cooldown or 10
	data:extend(
	{
		{
			type = "projectile",
			name = name,
			flags = {"not-on-map"},
			acceleration = 100,
			action =
			{{
				-- runs the script when projectile lands:
				type = "direct",
				action_delivery =
				{{
					type = "instant",
					target_effects = {
						type = "script",
						effect_id = name
					}
				}}
			}},
		},
		{
			type = "capsule",
			name = name,
			icon = MOD_PATH .. "/icons/" .. name .. ".png",
			subgroup = "tool",
			order = "b[paint-tool]-a[" .. name .. "]",
			icon_size = 32, icon_mipmaps = nil,
			stack_size = 150,
			capsule_action =
			{
			type = "throw",
			attack_parameters =
			{
				type = "projectile",
				activation_type = "throw",
				ammo_category = "capsule",
				cooldown = cooldown,
				projectile_creation_distance = 0,
				range = 64,
				ammo_type =
				{
				category = "capsule",
				target_type = "position",
				action =
				{{
					type = "direct",
					action_delivery =
					{{
						type = "projectile",
						projectile = name,
						starting_speed = 100
					}}
				}}
				}
			}
			}
		}
	})
end

local function create_paint_select_tool(name, stack_size)
	local flags
	if stack_size and stack_size == 1 then
		flags = {"hidden", "not-stackable", "only-in-cursor", "spawnable"}
	else
		flags = {"hidden", "spawnable"}
	end
	data:extend(
	{{
		type = "selection-tool",
		name = name,
		icon = MOD_PATH .. "/icons/" .. name .. ".png",
		flags = flags,
		icon_size = 32, icon_mipmaps = nil,
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
	}})
end

-- Creates hotkeys
data:extend({
	{
		type = "shortcut",
		name = "brush-bt-shortcut",
		associated_control_input = "give-paint-bt",
		order = "d-a-brush",
		action = "lua",
		toggleable = false,
		icon =
		{
			filename = MOD_PATH .. "/icons/pen-shortcut.png",
			priority = "extra-high-no-scale",
			size = 32,
			flags = { "gui-icon" }
		},
	},
	{
		type = "shortcut",
		name = "eraser-bt-shortcut",
		associated_control_input = "give-eraser-bt",
		order = "d-b-recolor",
		action = "lua",
		toggleable = false,
		icon =
		{
			filename = MOD_PATH .. "/icons/eraser.png",
			priority = "extra-high-no-scale",
			size = 32,
			flags = { "gui-icon" }
		},
	},
	{
		type = "shortcut",
		name = "recolor-bt-shortcut",
		associated_control_input = "give-recolor-bt",
		order = "d-b-recolor",
		action = "lua",
		toggleable = false,
		icon =
		{
			filename = MOD_PATH .. "/icons/recolor-bt.png",
			priority = "extra-high-no-scale",
			size = 32,
			flags = { "gui-icon" }
		},
	},
	{
		type = "custom-input",
		name = "-size-bt",
		order = "drawing-",
		key_sequence = "CONTROL + mouse-wheel-down",
		alternative_key_sequence = "CONTROL + KP_MINUS",
		consuming = "game-only"
	},
	{
		type = "custom-input",
		name = "+size-bt",
		order = "drawing+",
		key_sequence = "CONTROL + mouse-wheel-up",
		alternative_key_sequence = "CONTROL + KP_PLUS",
		consuming = "game-only"
	},
	{
		type = "custom-input",
		name = "-10size-bt",
		order = "drawing-10",
		key_sequence = "CONTROL + SHIFT + mouse-wheel-down",
		alternative_key_sequence = "CONTROL + SHIFT + KP_PLUS",
		consuming = "game-only"
	},
	{
		type = "custom-input",
		name = "+10size-bt",
		order = "drawing+10",
		key_sequence = "CONTROL + SHIFT + mouse-wheel-up",
		alternative_key_sequence = "CONTROL + SHIFT + KP_PLUS",
		consuming = "game-only"
	},
	{
		type = "custom-input",
		name = "select-prev-brush-tool",
		order = "drawing-change-tool-",
		key_sequence = "KP_MINUS",
		consuming = "game-only"
	},
	{
		type = "custom-input",
		name = "select-next-brush-tool",
		order = "drawing-change-tool+",
		key_sequence = "KP_PLUS",
		consuming = "game-only"
	},
	{
		type = "custom-input",
		name = "give-eraser-bt",
		key_sequence = "SHIFT + E",
		consuming = "game-only",
		-- item_to_spawn = "eraser",
		-- action = "spawn-item"
	},
	{
		type = "custom-input",
		name = "give-recolor-bt",
		key_sequence = "SHIFT + R",
		consuming = "game-only",
		-- item_to_spawn = "recolor-bt",
		-- action = "spawn-item"
	},
	{
		type = "custom-input",
		name = "give-paint-bt",
		key_sequence = "SHIFT + T",
		consuming = "game-only"
	},
	{
		type = "custom-input",
		name = "undo-bt",
		key_sequence = "SHIFT + Z",
		consuming = "game-only",
		localised_name = {"controls.undo"}
	},
	{
		type = "custom-input",
		name = "redo-bt",
		key_sequence = "SHIFT + Y",
		consuming = "game-only"
	}
})

create_paint_tool("pen")
create_paint_tool("circle", 15)
create_paint_tool("speech-bubble")
create_paint_select_tool("rectangle")
create_paint_select_tool("recolor-bt", 1)
create_paint_select_tool("eraser", 1)

local default_gui = data.raw["gui-style"].default
if default_gui.invisible_button == nil then
	default_gui.invisible_button =
	{
		type = "button_style",
		font = "default-dialog-button",
		size = 28,
		padding = 4,
		right_margin = -6,
		top_margin = -3,
		clicked_font_color = {1, 1, 1},
		hovered_font_color = {1, 1, 1},
		default_graphical_set = {},
		hovered_graphical_set = {}
	}
end