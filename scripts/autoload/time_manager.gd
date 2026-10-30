# res://scripts/autoload/time_manager.gd
# Project Settings > Globals (Autoload) > add this file, Node Name = "TimeManager"
extends Node

signal time_changed(hour: int, minute: int)
signal day_changed(day: int, season: int, year: int)
signal season_changed(season: int)
signal day_ended            # fires at 2:00 am -> player passes out / must sleep

enum Season { SUMMER, RAINY, THADINGYUT, WINTER }

const SEASON_NAMES := ["Summer", "Rainy", "Thadingyut", "Winter"]
const WEEKDAYS := ["Monday", "Tueday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
const DAYS_PER_SEASON := 28            # 4 weeks x 7 days
const START_HOUR := 6                  # day starts 6:00 am
const END_HOUR := 26                   # 26 = 2:00 am next morning (Stardew style)
const MINUTES_PER_TICK := 10
const SECONDS_PER_TICK := 7.0          # 7 real sec = 10 game min

var year := 1
var season: int = Season.SUMMER
var day := 1
var hour := START_HOUR
var minute := 0
var paused := false
var time_scale := 1.0                  # 20.0 is handy for testing

var _accum := 0.0

func _process(delta: float) -> void:
	if paused:
		return
	_accum += delta * time_scale
	while _accum >= SECONDS_PER_TICK:
		_accum -= SECONDS_PER_TICK
		_tick()

func _tick() -> void:
	minute += MINUTES_PER_TICK
	if minute >= 60:
		minute = 0
		hour += 1
	if hour >= END_HOUR:
		hour = END_HOUR
		minute = 0
		paused = true
		time_changed.emit(hour, minute)
		day_ended.emit()
		return
	time_changed.emit(hour, minute)

# Call after the player sleeps (or after day_ended).
func start_new_day() -> void:
	day += 1
	if day > DAYS_PER_SEASON:
		day = 1
		season += 1
		if season > Season.WINTER:
			season = Season.SUMMER
			year += 1
		season_changed.emit(season)
	hour = START_HOUR
	minute = 0
	_accum = 0.0
	paused = false
	day_changed.emit(day, season, year)
	time_changed.emit(hour, minute)

# ---- debug / testing helpers ----
func skip_minutes(m: int) -> void:
	for i in range(m / MINUTES_PER_TICK):
		if paused:
			break
		_tick()

func skip_to_next_day() -> void:
	start_new_day()

func skip_to_next_season() -> void:
	day = DAYS_PER_SEASON      # start_new_day() rolls it over to day 1 of next season
	start_new_day()

func get_weekday() -> String:
	return WEEKDAYS[(day - 1) % 7]

func get_season_name() -> String:
	return SEASON_NAMES[season]

# Hours as a float, 6.0 .. 26.0  (6:30 -> 6.5)
func get_hour_float() -> float:
	return hour + minute / 60.0

# "6:50 am", "12:00 pm", "1:30 am"
func get_time_string() -> String:
	var h24 := hour % 24
	var suffix := "am" if h24 < 12 else "pm"
	var h12 := h24 % 12
	if h12 == 0:
		h12 = 12
	return "%d:%02d %s" % [h12, minute, suffix]

# "Mon 1"
func get_date_string() -> String:
	return "%s %d" % [get_weekday(), day]

func get_save_data() -> Dictionary:
	return {"year": year, "season": season, "day": day, "hour": hour, "minute": minute}

func load_save_data(d: Dictionary) -> void:
	year = d.get("year", 1)
	season = d.get("season", 0)
	day = d.get("day", 1)
	hour = d.get("hour", START_HOUR)
	minute = d.get("minute", 0)
	_accum = 0.0
	paused = false
	season_changed.emit(season)
	day_changed.emit(day, season, year)
	time_changed.emit(hour, minute)
