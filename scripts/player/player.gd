extends CharacterBody2D

@export var walk_speed: float = 100.0
@export var run_speed: float = 200.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var last_direction: String = "south"


func _physics_process(_delta: float) -> void:
	var input_vector := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var is_running := Input.is_key_pressed(KEY_SHIFT)

	var current_speed := run_speed if is_running else walk_speed
	velocity = input_vector * current_speed
	move_and_slide()

	_update_animation(input_vector, is_running)


func _update_animation(input_vector: Vector2, is_running: bool) -> void:
	if input_vector.length() > 0.1:
		# Horizontal takes priority over vertical when both are pressed (e.g. W+A)
		if input_vector.x != 0:
			last_direction = "east" if input_vector.x > 0 else "west"
		else:
			last_direction = "south" if input_vector.y > 0 else "north"

		var prefix := "run_" if is_running else "walk_"
		animated_sprite.play(prefix + last_direction)
	else:
		animated_sprite.play("idle_" + last_direction)
