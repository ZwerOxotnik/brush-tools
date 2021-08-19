require("prototypes.custom-input")
require("prototypes.tools")


local default_gui = data.raw["gui-style"].default
if default_gui.invisible_button == nil then
	default_gui.invisible_button = {
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
