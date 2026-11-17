class_name Bed
extends Node2D
## A bed you can sleep in: walk up and press E to deliberately end the day (player.gd -> _sleep),
## instead of only being able to progress via fainting. Shows the same "E" hint as item pickups.
##
## PLACEHOLDER ART: no bed sprite exists in the project yet, so this draws a simple pixel-art
## bed procedurally. Drop a real texture on a child Sprite2D and delete _draw() to swap it out.

@export var interact_range: float = 20.0
@export var bed_size: Vector2 = Vector2(32, 24)

const OUTLINE := Color("#2a1c12")
const FRAME := Color("#6b4423")
const FRAME_LIGHT := Color("#8f5d2c")
const MATTRESS := Color("#e6d4a0")
const MATTRESS_SHADE := Color("#cdb67c")
const BLANKET := Color("#7a2f3a")
const BLANKET_LIGHT := Color("#a5455a")
const PILLOW := Color("#f2ead0")

@onready var hint: Sprite2D = $Hint

var time: float = 0.0


func _ready() -> void:
	add_to_group("bed")
	hint.visible = false
	queue_redraw()


func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	hint.visible = player != null and global_position.distance_to(player.global_position) < interact_range


func _draw() -> void:
	var w := bed_size.x
	var h := bed_size.y
	var r := Rect2(-w / 2.0, -h, w, h)                 # feet of the bed sit on this node's origin

	draw_rect(r.grow(1), OUTLINE)                      # outline
	draw_rect(r, FRAME)
	draw_rect(Rect2(r.position, Vector2(r.size.x, 3)), FRAME_LIGHT)   # headboard lip

	var mattress := Rect2(r.position.x + 3, r.position.y + 4, r.size.x - 6, r.size.y - 7)
	draw_rect(mattress, MATTRESS_SHADE)
	draw_rect(mattress.grow(-1), MATTRESS)

	var blanket := Rect2(mattress.position.x, mattress.position.y + mattress.size.y * 0.45,
		mattress.size.x, mattress.size.y * 0.55)
	draw_rect(blanket, BLANKET)
	draw_rect(Rect2(blanket.position, Vector2(blanket.size.x, 2)), BLANKET_LIGHT)

	var pillow := Rect2(mattress.position.x + 2, mattress.position.y + 1, mattress.size.x - 4, 5)
	draw_rect(pillow, PILLOW)

	draw_rect(Rect2(r.position.x - 1, r.end.y - 3, 2, 3), OUTLINE)   # little feet
	draw_rect(Rect2(r.end.x - 1, r.end.y - 3, 2, 3), OUTLINE)
