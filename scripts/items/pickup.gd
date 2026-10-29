class_name Pickup
extends Node2D
## An item lying on the ground. Walk up to it and press E to pick it up.
## The player does the picking up (player.gd → _try_pickup).

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
