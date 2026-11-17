class_name Pickup
extends Node2D
## An item lying on the ground. Walk up to it and press E to pick it up.
## The player does the picking up (player.gd → _try_interact).

@export var item_id: String = "egg"      ## "hoe", "water" (watering can) or "egg"
@export var pickup_range: float = 14.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var hint: Sprite2D = $Hint

var time: float = 0.0


func _ready() -> void:
	add_to_group("pickup")
	hint.visible = false


func _process(delta: float) -> void:
	# gentle bob, in whole pixels so it stays crisp
	time += delta
	sprite.position.y = -7 + roundf(sin(time * 3.0))

	# show the "E" key when the player is close enough
	var player := get_tree().get_first_node_in_group("player") as Node2D
	hint.visible = player != null and global_position.distance_to(player.global_position) < pickup_range


## Build a ground pickup entirely from code - no per-item .tscn needed. Used to drop a
## harvested crop (or anything else) on the ground when the hotbar/bag has no room for it.
## Node layout matches egg.tscn exactly (Shadow / Sprite2D / Hint) so @onready above resolves.
static func spawn(item_id: String, pos: Vector2, parent: Node) -> Pickup:
	var pickup := Pickup.new()
	pickup.name = "Dropped_" + item_id
	pickup.item_id = item_id
	pickup.position = pos

	var shadow := Sprite2D.new()
	shadow.name = "Shadow"
	shadow.texture = ItemIcons.SHADOW
	pickup.add_child(shadow)

	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.position = Vector2(0, -7)
	sprite.texture = ItemIcons.get_icon(item_id)
	pickup.add_child(sprite)

	var hint := Sprite2D.new()
	hint.name = "Hint"
	hint.position = Vector2(0, -21)
	hint.texture = ItemIcons.HINT
	pickup.add_child(hint)

	parent.add_child(pickup)
	return pickup
