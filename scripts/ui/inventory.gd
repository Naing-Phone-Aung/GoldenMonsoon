class_name Inventory
extends CanvasLayer
## Root for the full bag screen. Starts closed; player.gd calls toggle()/is_open() with KEY_I
## (see Player._toggle_inventory). The drawing itself lives in InventoryView.
## (The CanvasLayer stays visible the whole time - InventoryView.visible is the real on/off
## switch, since only a Control's own visibility reliably gates its _gui_input.)

var view: InventoryView


func _ready() -> void:
	add_to_group("inventory_ui")
	layer = 20                                  # above the hotbar/clock, below the fade overlay
	view = InventoryView.new()
	view.name = "InventoryView"
	view.visible = false
	add_child(view)


func is_open() -> bool:
	return view.visible


func toggle() -> void:
	view.visible = not view.visible


func close() -> void:
	view.visible = false
