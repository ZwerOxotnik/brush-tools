data:extend({
	{
		type = "shortcut",
		name = "brush-bt-shortcut",
		associated_control_input = "give-paint-bt",
		order = "d-a-brush",
		action = "lua",
		toggleable = false,
		icon = {
			filename = "__brush-tools__/icons/pen-shortcut.png",
			priority = "extra-high-no-scale",
			size = 32,
			flags = {"gui-icon"}
		}
	}, {
		type = "shortcut",
		name = "eraser-bt-shortcut",
		associated_control_input = "give-eraser-bt",
		order = "d-b-recolor",
		action = "lua",
		toggleable = false,
		icon = {
			filename = "__brush-tools__/icons/eraser.png",
			priority = "extra-high-no-scale",
			size = 32,
			flags = {"gui-icon"}
		}
	}, {
		type = "shortcut",
		name = "recolor-bt-shortcut",
		associated_control_input = "give-recolor-bt",
		order = "d-b-recolor",
		action = "lua",
		toggleable = false,
		icon = {
			filename = "__brush-tools__/icons/recolor-bt.png",
			priority = "extra-high-no-scale",
			size = 32,
			flags = {"gui-icon"}
		}
	}, {
		type = "custom-input",
		name = "-size-bt",
		order = "drawing-",
		key_sequence = "CONTROL + mouse-wheel-down",
		alternative_key_sequence = "CONTROL + KP_DIVIDE",
		consuming = "game-only"
	}, {
		type = "custom-input",
		name = "+size-bt",
		order = "drawing+",
		key_sequence = "CONTROL + mouse-wheel-up",
		alternative_key_sequence = "CONTROL + KP_MULTIPLY",
		consuming = "game-only"
	}, {
		type = "custom-input",
		name = "-10size-bt",
		order = "drawing-10",
		key_sequence = "CONTROL + SHIFT + mouse-wheel-down",
		alternative_key_sequence = "CONTROL + SHIFT + KP_MULTIPLY",
		consuming = "game-only"
	}, {
		type = "custom-input",
		name = "+10size-bt",
		order = "drawing+10",
		key_sequence = "CONTROL + SHIFT + mouse-wheel-up",
		alternative_key_sequence = "CONTROL + SHIFT + KP_MULTIPLY",
		consuming = "game-only"
	}, {
		type = "custom-input",
		name = "select-prev-brush-tool",
		order = "drawing-change-tool-",
		key_sequence = "KP_DIVIDE",
		consuming = "game-only"
	}, {
		type = "custom-input",
		name = "select-next-brush-tool",
		order = "drawing-change-tool+",
		key_sequence = "KP_MULTIPLY",
		consuming = "game-only"
	}, {
		type = "custom-input",
		name = "give-eraser-bt",
		key_sequence = "CONTROL + E",
		consuming = "game-only"
		-- item_to_spawn = "eraser",
		-- action = "spawn-item"
	}, {
		type = "custom-input",
		name = "give-recolor-bt",
		key_sequence = "CONTROL + R",
		consuming = "game-only"
		-- item_to_spawn = "recolor-bt",
		-- action = "spawn-item"
	}, {
		type = "custom-input",
		name = "give-paint-bt",
		key_sequence = "CONTROL + T",
		consuming = "game-only"
	}, {
		type = "custom-input",
		name = "undo-bt",
		key_sequence = "SHIFT + Z",
		consuming = "game-only",
		localised_name = {"controls.undo"}
	}, {
		type = "custom-input",
		name = "redo-bt",
		key_sequence = "SHIFT + Y",
		consuming = "game-only"
	}
})
