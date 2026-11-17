class_name Crop
extends Sprite2D
## One planted crop. Each frame of the texture is one growth stage (hframes = stage count).
## Grows one stage per in-game day, but ONLY for a day it was watered (Farm.water() calls water()
## on whatever is planted in that cell). Not watered that day = no growth, and the "watered today"
## flag always resets at the next day change, so you have to re-water daily. Planted by Farm.plant().

@export var crop_name: String = "chili"     ## what you get when you harvest it
@export var days_per_stage: int = 1

@export_group("Debug (run the game, select this Crop in the Remote tab, tick a box)")
## Jumps straight to the next growth stage, ignoring watering/days - handy for testing art.
@export var force_next_stage: bool = false:
	set(v):
		if v and is_inside_tree() and not Engine.is_editor_hint():
			stage = mini(stage + 1, hframes - 1)
			frame = stage
			days_grown = 0
## Jumps straight to fully ripe.
@export var force_ripen: bool = false:
	set(v):
		if v and is_inside_tree() and not Engine.is_editor_hint():
			stage = hframes - 1
			frame = stage
## Resets back to a freshly planted seedling.
@export var reset_to_seedling: bool = false:
	set(v):
		if v and is_inside_tree() and not Engine.is_editor_hint():
			stage = 0
			frame = 0
			days_grown = 0
			is_watered = false

var stage: int = 0
var days_grown: int = 0
var is_watered: bool = false


func _ready() -> void:
	frame = stage


func is_ripe() -> bool:
	return stage == hframes - 1


func water() -> void:
	is_watered = true


## Call once per in-game day (Farm hooks this to TimeManager.day_changed).
func grow_one_day() -> void:
	if is_watered and not is_ripe():
		days_grown += 1
		if days_grown >= days_per_stage:
			days_grown = 0
			stage += 1
			frame = stage
	is_watered = false
