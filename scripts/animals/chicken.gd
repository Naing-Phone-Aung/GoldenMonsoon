class_name Chicken
extends CharacterBody2D
## A chicken that lives on its own: stands around, walks somewhere nearby,
## pecks at the grass. Same script for the chick, hen and cock.
##
## Scene:
##   Chick (CharacterBody2D, this script)
##     ├─ AnimatedSprite2D
##     ├─ changestatetimer (Timer)   when to pick the next action
##     ├─ walkingtimer     (Timer)   stops a walk that takes too long (stuck)
##     └─ CollisionShape2D

enum State { IDLE, WALK, EAT }

@export var walk_speed: float = 20.0
@export var wander_radius: float = 64.0     ## how far from its start spot it may wander
@export var max_walk_time: float = 4.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var change_state_timer: Timer = $changestatetimer
@onready var walking_timer: Timer = $walkingtimer

var state: State = State.IDLE
var home: Vector2
var target: Vector2
var view: String = "side"                   # "side", "down" or "up"


func _ready() -> void:
	home = global_position
	change_state_timer.one_shot = true
	walking_timer.one_shot = true
	change_state_timer.timeout.connect(_choose_next)
	walking_timer.timeout.connect(_start_idle)
	_start_idle()


func _physics_process(_delta: float) -> void:
	if state != State.WALK:
		return

	var to_target := target - global_position
	if to_target.length() < 2.0:
		_choose_next()
		return

	velocity = to_target.normalized() * walk_speed
	move_and_slide()
	_face(velocity)
	_play("walk")


func _choose_next() -> void:
	match randi() % 3:
		0:
			_start_idle()
		1:
			_start_walk()
		2:
			_start_eat()


func _start_idle() -> void:
	state = State.IDLE
	velocity = Vector2.ZERO
	walking_timer.stop()
	_play("idle")
	change_state_timer.start(randf_range(1.5, 4.0))


func _start_walk() -> void:
	state = State.WALK
	target = home + Vector2.from_angle(randf() * TAU) * randf() * wander_radius
	walking_timer.start(max_walk_time)


func _start_eat() -> void:
	state = State.EAT
	velocity = Vector2.ZERO
	walking_timer.stop()
	view = "side"                          # pecking only exists as a side view
	_play("eat")
	change_state_timer.start(randf_range(2.0, 4.0))


func _face(direction: Vector2) -> void:
	if absf(direction.x) > absf(direction.y):
		view = "side"
		animated_sprite.flip_h = direction.x < 0
	else:
		view = "down" if direction.y > 0 else "up"


func _play(action: String) -> void:
	animated_sprite.play(action + "_" + view)
