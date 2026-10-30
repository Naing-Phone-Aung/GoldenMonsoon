class_name WoodHotbar
extends CanvasLayer
## Hotbar + energy bar. This root node only holds the settings (so they show up in the Inspector);
## the drawing is done by HotbarView (scripts/ui/hotbar_view.gd), created in code.

@export_group("Look")
## Drag a .ttf here (e.g. the same font as the Clock). Empty = pixel_font.ttf, else Godot's default.
@export var pixel_font: Font:
	set(value):
		pixel_font = value
		_apply()
## Pixel size of the frame details. Keep it equal to the Clock's "Ui Scale".
@export var ui_scale := 1.5:
	set(value):
		ui_scale = value
		_apply()
## Gap between the hotbar and the bottom of the screen (screen px).
@export var bottom_margin := 8.0:
	set(value):
		bottom_margin = value
		_apply()
## Every icon is fitted into a square this big (art px), so all items look the same size.
@export var icon_box := 20:
	set(value):
		icon_box = value
		_apply()
@export_group("Energy bar")
@export var show_energy_bar := true:
	set(value):
		show_energy_bar = value
		_apply()

var view: HotbarView


func _ready() -> void:
	layer = 10                                  # above the world and the rain, below fade-outs
	view = HotbarView.new()
	view.name = "HotbarView"
	add_child(view)
	_apply()


func _apply() -> void:
	if view != null:
		view.configure(ui_scale, bottom_margin, icon_box, pixel_font, show_energy_bar)
