extends CharacterBody2D

signal inventory_changed

const TILE_SIZE := 16

@export var walk_speed: float = 100.0
@export var run_speed: float = 200.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var last_direction: String = "south"
var current_tool: String = ""            # empty hands until you pick up a tool
var tools: Array[String] = ["seeds"]     # tools you own: "hoe", "water", "seeds"
var items: Dictionary = {}               # things you carry, e.g. {"egg": 2}
var is_busy: bool = false


func _ready() -> void:
	add_to_group("player")


func _physics_process(_delta: float) -> void:
	if is_busy:
		return

	var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var is_running := Input.is_action_pressed("run")

	var speed := run_speed if is_running else walk_speed
	velocity = input_vector * speed
	move_and_slide()

	_update_direction(input_vector)
	_update_animation(input_vector, is_running)

	if Input.is_action_just_pressed("use_tool"):
		_use_tool()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_E:
				_try_pickup()
			KEY_1:
				_select_tool("hoe")
			KEY_2:
				_select_tool("water")
			KEY_3:
				_select_tool("seeds")


# ---------------------------------------------------------------- items
func _try_pickup() -> void:
	if is_busy:
		return
	for pickup in get_tree().get_nodes_in_group("pickup"):
		if pickup.global_position.distance_to(global_position) < pickup.pickup_range:
			add_item(pickup.item_id)
			pickup.queue_free()
			return


func add_item(item_id: String) -> void:
	if item_id == "hoe" or item_id == "water":
		if item_id not in tools:
			tools.append(item_id)
		current_tool = item_id               # a new tool goes straight into your hand
	else:
		items[item_id] = items.get(item_id, 0) + 1
	inventory_changed.emit()


func _select_tool(tool_name: String) -> void:
	if tool_name not in tools:
		return
	current_tool = tool_name
	inventory_changed.emit()


func _use_tool() -> void:
	# "farm" group is optional for now - digging/watering wires up once a Farm node exists.
	var farm := get_tree().get_first_node_in_group("farm")
	var cell := Vector2i.ZERO
	if farm:
		cell = farm.world_to_cell(global_position + _facing_vector() * TILE_SIZE)
		if farm.harvest(cell):          # a ripe crop in front of you is picked, even with empty hands
			return

	if current_tool == "":
		return

	is_busy = true
	velocity = Vector2.ZERO
	if current_tool != "seeds":
		animated_sprite.play(current_tool + "_" + _view())
		await animated_sprite.animation_finished
	if farm:
		farm.use_tool(current_tool, cell)
	is_busy = false


# ---------------------------------------------------------------- movement helpers
func _update_direction(input_vector: Vector2) -> void:
	if input_vector == Vector2.ZERO:
		return

	# Horizontal takes priority when moving diagonally
	if input_vector.x != 0:
		last_direction = "east" if input_vector.x > 0 else "west"
	else:
		last_direction = "south" if input_vector.y > 0 else "north"


func _update_animation(input_vector: Vector2, is_running: bool) -> void:
	# Side animations face right; flip them for west
	animated_sprite.flip_h = last_direction == "west"

	if input_vector == Vector2.ZERO:
		if current_tool == "hoe" or current_tool == "water":
			# Stand holding the tool - freeze on the first frame of its swing animation.
			animated_sprite.play(current_tool + "_" + _view())
			animated_sprite.pause()
			animated_sprite.frame = 0
		else:
			animated_sprite.play("idle_" + _view())
	else:
		var action := "run" if is_running else "walk"
		animated_sprite.play(action + "_" + _view())


func _view() -> String:
	match last_direction:
		"south":
			return "down"
		"north":
			return "up"
	return "side"


func _facing_vector() -> Vector2:
	match last_direction:
		"north":
			return Vector2.UP
		"east":
			return Vector2.RIGHT
		"west":
			return Vector2.LEFT
	return Vector2.DOWN
