extends CharacterBody2D

signal inventory_changed
signal energy_changed
signal energy_empty                      # energy just hit 0 (the energy bar blinks red)

const TILE_SIZE := 16

@export var walk_speed: float = 100.0
@export var run_speed: float = 200.0
## Where the player's feet are, relative to the node origin (the sprite centre).
## The tile you stand on, and so the clickable area around you, is worked out from this point.
## Nudge Y if the area feels off by a row.
@export var feet_offset: Vector2 = Vector2(0, 14)
## Click-to-use: you can use a tool on any tile within this many tiles of your feet
## (1 = the 3x3 square around you, 2 = 5x5, ...).
@export var tool_range: int = 1
## Master switch for the target highlight on the tile under the mouse.
@export var show_target: bool = true
## false = the target only appears on tiles the tool can work on (green).
## true  = the target always appears on any tile in range (green = works, red = doesn't).
@export var always_show_target: bool = false
## Draws the faint white square of tiles around the player that you can click.
@export var show_action_area: bool = false
## Tick to make it rain (or press R in game). Rain also waters farmland automatically.
@export var raining: bool = false:
	set(value):
		raining = value
		if is_inside_tree():
			var weather := get_tree().get_first_node_in_group("weather")
			if weather != null:
				weather.set_raining(value)

@export_group("Energy")
## Full energy bar. Everything below is in the same units, so tweak freely.
@export var max_energy: float = 100.0:
	set(value):
		max_energy = maxf(1.0, value)
		energy = minf(energy, max_energy)
		energy_changed.emit()
## Energy one swing of the hoe costs.
@export var hoe_energy_cost: float = 2.0
## Energy one use of the watering can costs.
@export var water_energy_cost: float = 1.0
## Refill to full when a new day starts (after sleeping).
@export var refill_on_new_day: bool = true
## When energy reaches 0 the player faints and the game restarts (placeholder until sleeping is added).
@export var faint_at_zero_energy: bool = true
## Tick to refill energy right now (handy for testing).
@export var refill_energy: bool = false:
	set(value):
		if value:
			restore_energy()
@export_group("")

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
var energy: float = 100.0                # current energy (starts full)
var fainting: bool = false


func _ready() -> void:
	add_to_group("player")
	current_tool = hotbar[selected_slot]
	energy = max_energy
	_fade_in_after_restart()
	var tm := get_node_or_null("/root/TimeManager")
	if tm:
		tm.day_changed.connect(_on_new_day)
	_ensure_farm.call_deferred()
	_ensure_weather.call_deferred()


# ---------------------------------------------------------------- energy
func get_tool_cost(tool_name: String) -> float:
	match tool_name:
		"hoe":
			return hoe_energy_cost
		"water":
			return water_energy_cost
	return 0.0


func restore_energy() -> void:
	energy = max_energy
	energy_changed.emit()


func _on_new_day(_day: int, _season: int, _year: int) -> void:
	if refill_on_new_day:
		restore_energy()


# ---------------------------------------------------------------- fainting
## Energy hit 0: play the faint animation, fade to black, then restart (for now).
func _faint() -> void:
	if fainting:
		return
	fainting = true
	is_busy = true
	velocity = Vector2.ZERO
	animated_sprite.flip_h = false
	energy_empty.emit()
	var frames := animated_sprite.sprite_frames
	frames.set_animation_loop("faint", false)    # play once and stay lying down
	animated_sprite.play("faint")
	await animated_sprite.animation_finished
	await get_tree().create_timer(0.8).timeout   # lie there for a moment

	var fade := _make_fade_layer()
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, 1.0)
	await tween.finished
	_restart_game()


## Full restart for now: clock back to day 1, scene reloaded. The black screen stays up
## during the reload and fades out again in the new scene (see _fade_in_after_restart).
func _restart_game() -> void:
	var tm := get_node_or_null("/root/TimeManager")
	if tm:
		tm.year = 1
		tm.season = 0
		tm.day = 1
		tm.hour = tm.START_HOUR
		tm.minute = 0
		tm._accum = 0.0
		tm.paused = false
	get_tree().reload_current_scene()


# A black overlay that lives on the root, so it survives the scene reload.
func _make_fade_layer() -> ColorRect:
	var layer := CanvasLayer.new()
	layer.layer = 100
	layer.add_to_group("faint_fade")
	var rect := ColorRect.new()
	rect.color = Color(0, 0, 0, 0)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(rect)
	get_tree().root.add_child(layer)
	return rect


func _fade_in_after_restart() -> void:
	var layer := get_tree().get_first_node_in_group("faint_fade")
	if layer == null:
		return
	var rect := layer.get_child(0) as ColorRect
	var tween := layer.create_tween()
	tween.tween_property(rect, "color:a", 0.0, 1.0)
	tween.tween_callback(layer.queue_free)


# Rain is added automatically too (above the world, below the hotbar).
func _ensure_weather() -> void:
	var weather := get_tree().get_first_node_in_group("weather")
	if weather == null:
		weather = Weather.new()
		weather.name = "Weather"
		get_parent().add_child(weather)
	weather.set_raining(raining, true)        # start in whatever state the checkbox says


# If the scene has no Farm node, add one right after the tile layers (so farmland
# draws above the path but under the player and animals).
func _ensure_farm() -> void:
	if get_tree().get_first_node_in_group("farm") != null:
		return
	var parent := get_parent()
	var farm := Farm.new()
	farm.name = "Farm"
	parent.add_child(farm)
	var last_layer := -1
	for i in parent.get_child_count():
		if parent.get_child(i) is TileMapLayer:
			last_layer = i
	parent.move_child(farm, last_layer + 1)


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
		if is_busy:
			return
		var farm := get_tree().get_first_node_in_group("farm")
		if farm == null:
			return
		# Left click: use the tool on the tile under the cursor, if it is close enough.
		var clicked: Vector2i = farm.world_to_cell(get_global_mouse_position())
		if is_in_tool_range(farm, clicked):
			_use_tool(farm, clicked)
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


func _use_tool(farm: Node, cell: Vector2i) -> void:
	if farm.harvest(cell):     # a ripe crop is picked, even with empty hands
		return

	if current_tool != "hoe" and current_tool != "water":
		return                                   # eggs etc. are not tools

	if fainting:
		return
	if energy <= 0.0:
		energy_empty.emit()                       # out of energy: the bar blinks red
		return
	# A swing is allowed while there is any energy left; the last one takes you to 0.
	energy = maxf(0.0, energy - get_tool_cost(current_tool))
	energy_changed.emit()

	is_busy = true
	velocity = Vector2.ZERO
	_face_cell(farm, cell)                        # swing toward the tile you clicked
	# The swing animation plays ONLY here, while the action happens.
	var anim := current_tool + "_" + _view()
	if animated_sprite.sprite_frames.has_animation(anim):
		animated_sprite.play(anim)
		await animated_sprite.animation_finished
	farm.use_tool(current_tool, cell)
	if energy <= 0.0 and faint_at_zero_energy:
		await _faint()                            # stays busy: no moving while fainted
		return
	is_busy = false


## Turn to look at a tile (side-to-side wins ties, like movement does).
func _face_cell(farm: Node, cell: Vector2i) -> void:
	var delta: Vector2 = farm.cell_to_world(cell) - get_feet_position()
	if absf(delta.x) < 1.0 and absf(delta.y) < 1.0:
		return                                   # clicked the tile you stand on: keep facing
	if absf(delta.x) >= absf(delta.y):
		last_direction = "east" if delta.x > 0 else "west"
	else:
		last_direction = "south" if delta.y > 0 else "north"
	animated_sprite.flip_h = last_direction == "west"


## True if the tile is inside the square of tiles around the player's feet.
func is_in_tool_range(farm: Node, cell: Vector2i) -> bool:
	var feet: Vector2i = farm.world_to_cell(get_feet_position())
	var d := (cell - feet).abs()
	return maxi(d.x, d.y) <= tool_range


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


func get_feet_position() -> Vector2:
	return global_position + feet_offset
