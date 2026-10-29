extends CanvasLayer
## Top-left text: which tool is in your hand and how many eggs you carry.

const TOOL_NAMES := {"": "Empty hands", "hoe": "Hoe", "water": "Watering can", "seeds": "Chili seeds"}

@onready var label: Label = $Label


func _ready() -> void:
	await get_tree().process_frame          # wait until the player is in the scene
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	player.inventory_changed.connect(_refresh.bind(player))
	_refresh(player)


func _refresh(player: Node) -> void:
	label.text = "Tool: %s    Eggs: %d" % [TOOL_NAMES.get(player.current_tool, player.current_tool),
		player.items.get("egg", 0)]
