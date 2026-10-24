extends CharacterBody2D

@export var walk_speed: float = 100.0
@export var run_speed: float = 200.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var last_direction: String = "south"


func _physics_process(_delta: float) -> void:
	var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var is_running := Input.is_action_pressed("run")

	var speed := run_speed if is_running else walk_speed
	velocity = input_vector * speed
	move_and_slide()

	_update_direction(input_vector)
	_update_animation(input_vector, is_running)


func _update_direction(input_vector: Vector2) -> void:
	if input_vector == Vector2.ZERO:
		return

	# Horizontal takes priority when moving diagonally
	if input_vector.x != 0:
		last_direction = "east" if input_vector.x > 0 else "west"
	else:
		last_direction = "south" if input_vector.y > 0 else "north"


func _update_animation(input_vector: Vector2, is_running: bool) -> void:
	var action := "idle"
	if input_vector != Vector2.ZERO:
		action = "run" if is_running else "walk"

	var view := "side"
	match last_direction:
		"south":
			view = "down"
		"north":
			view = "up"

	# Side animations face right; flip them for west
	animated_sprite.flip_h = last_direction == "west"
	animated_sprite.play(action + "_" + view)
