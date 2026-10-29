extends CharacterBody2D

signal inventory_changed

const TILE_SIZE := 16

@export var walk_speed: float = 100.0
@export var run_speed: float = 200.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var last_direction: String = "south"
const HOTBAR_SIZE := 10
const MAX_STACK := 99

# Hotbar slots 1..0 (keys 1-9 = slots 0-8, key 0 = slot 9). "" = empty slot.
var hotbar: Array[String] = ["hoe", "water", "", "", "", "", "", "", "", ""]
# Stack size per slot. -1 = a tool (no number shown), 0 = empty slot.
var hotbar_counts: Array[int] = [-1, -1, 0, 0, 0, 0, 0, 0, 0, 0]
var selected_slot: int = 0
var current_tool: String = "hoe"         # always mirrors hotbar[selected_slot]
var items: Dictionary = {}               # things you carry, e.g. {"egg": 2}
var is_busy: bool = false


func _ready() -> void:
	add_to_group("player")
	current_tool = hotbar[selected_slot]


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


func _unhandled_input(event: InputEvent) -> void:
	# Event-based (not polled) so a click the hotbar already used never swings the tool.
	if event.is_action_pressed("use_tool"):
		if not is_busy:
			_use_tool()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E:
			_try_pickup()
		elif event.keycode >= KEY_1 and event.keycode <= KEY_9:
			select_slot(event.keycode - KEY_1)      # keys 1..9 -> slots 0..8
		elif event.keycode == KEY_0:
			select_slot(9)                          # key 0 -> last slot
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cycle_slot(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cycle_slot(1)


# ---------------------------------------------------------------- items
func _try_pickup() -> void:
	if is_busy:
		return
	for pickup in get_tree().get_nodes_in_group("pickup"):
		if pickup.global_position.distance_to(global_position) < pickup.pickup_range:
			if add_item(pickup.item_id):        # hotbar full -> item stays on the ground
				pickup.queue_free()
			return


## Returns true if the item was stored. Eggs stack up to MAX_STACK per slot.
func add_item(item_id: String) -> bool:
	if item_id == "hoe" or item_id == "water":
		if item_id in hotbar:
			return false
		var free_tool := hotbar.find("")
		if free_tool == -1:
			return false
		hotbar[free_tool] = item_id
		hotbar_counts[free_tool] = -1
	else:
		var slot := -1
		for i in HOTBAR_SIZE:                    # 1) top up an existing stack
			if hotbar[i] == item_id and hotbar_counts[i] < MAX_STACK:
				slot = i
				break
		if slot == -1:                           # 2) otherwise take the first empty slot
			slot = hotbar.find("")
		if slot == -1:
			return false                         # no room
		hotbar[slot] = item_id
		hotbar_counts[slot] += 1
		items[item_id] = items.get(item_id, 0) + 1
	inventory_changed.emit()
	return true


func select_slot(index: int) -> void:
	if is_busy or index < 0 or index >= HOTBAR_SIZE:
		return
	selected_slot = index
	current_tool = hotbar[index]
	inventory_changed.emit()


# Mouse wheel: jump to the next/previous slot that has something in it.
func _cycle_slot(direction: int) -> void:
	if is_busy:
		return
	for step in range(1, HOTBAR_SIZE + 1):
		var i := posmod(selected_slot + direction * step, HOTBAR_SIZE)
		if hotbar[i] != "":
			select_slot(i)
			return


func _use_tool() -> void:
	# "farm" group is optional for now - digging/watering wires up once a Farm node exists.
	var farm := get_tree().get_first_node_in_group("farm")
	var cell := Vector2i.ZERO
	if farm:
		cell = farm.world_to_cell(global_position + _facing_vector() * TILE_SIZE)
		if farm.harvest(cell):          # a ripe crop in front of you is picked, even with empty hands
			return

	if current_tool != "hoe" and current_tool != "water":
		return                                   # eggs etc. are not tools

	is_busy = true
	velocity = Vector2.ZERO
	# The swing animation plays ONLY here, while the action happens.
	var anim := current_tool + "_" + _view()
	if animated_sprite.sprite_frames.has_animation(anim):
		animated_sprite.play(anim)
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
		animated_sprite.play("idle_" + _view())     # normal idle, whatever tool is selected
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
