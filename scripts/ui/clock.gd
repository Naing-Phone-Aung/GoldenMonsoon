# res://scripts/ui/clock.gd
# Attached to scenes/ui/clock.tscn. Builds its own layers, pins itself top-right.
#
# Layers (back -> front): sky -> stars -> moon -> sun -> frame (season PNG) -> text
extends Control

const PANEL_SIZE := Vector2(168, 96)
const PIVOT := Vector2(38, 60)          # horizon centre of the dial (matches PNG)
const ORBIT := 22.0                     # sun / moon orbit radius in px
const SKY_POS := Vector2(10, 24)        # sky texture position
const DEFAULT_FONT_PATH := "res://assets/fonts/pixel_font.ttf"   # auto-loaded if present

const FRAMES := [
	preload("res://assets/ui/clock/clock_summer.png"),
	preload("res://assets/ui/clock/clock_rainy.png"),
	preload("res://assets/ui/clock/clock_thadingyut.png"),
	preload("res://assets/ui/clock/clock_winter.png"),
]
const TEX_SKY := preload("res://assets/ui/clock/clock_sky.png")
const TEX_STARS := preload("res://assets/ui/clock/clock_stars.png")
const TEX_SUN := preload("res://assets/ui/clock/clock_sun.png")
const TEX_MOON := preload("res://assets/ui/clock/clock_moon.png")

# Text slots in panel pixels (x, y, w, h) - centred inside each plaque
const DATE_RECT := Rect2(70, 19, 86, 14)
const TIME_RECT := Rect2(70, 45, 86, 14)
const SEASON_RECT := Rect2(73, 76, 52, 9)

@export_group("Font (drag a .ttf from FileSystem into either slot)")
@export var pixel_font: FontFile:           # drag & drop a font file here
	set(v):
		pixel_font = v
		_apply_font()
@export_file("*.ttf", "*.otf", "*.woff", "*.woff2") var font_path := "":   # or pick/drag a path here
	set(v):
		font_path = v
		_apply_font()

@export_group("Look")
@export var ui_scale := 1.5             # 1 = 168x96 px | 1.5 | 2 = 336x192
@export var margin := 6.0
@export var font_size := 8
@export var season_font_size := 7
@export var text_color := Color("#3b2412")
@export var season_text_color := Color("#fff0c0")
@export var date_offset := Vector2.ZERO     # nudge text (panel px). negative y = up
@export var time_offset := Vector2.ZERO
@export var season_offset := Vector2.ZERO

@export_group("Debug (run the game, select Clock in Remote tab, tick a box)")
@export var debug_keys := true              # F6 +10min | F7 +1h | F8 next day | F9 next season
@export var debug_time_scale := 1.0:
	set(v):
		debug_time_scale = v
		if is_inside_tree() and not Engine.is_editor_hint():
			TimeManager.time_scale = v
@export var skip_10_minutes := false:
	set(v):
		if v and is_inside_tree() and not Engine.is_editor_hint():
			TimeManager.skip_minutes(10)
@export var skip_1_hour := false:
	set(v):
		if v and is_inside_tree() and not Engine.is_editor_hint():
			TimeManager.skip_minutes(60)
@export var skip_to_next_day := false:
	set(v):
		if v and is_inside_tree() and not Engine.is_editor_hint():
			TimeManager.skip_to_next_day()
@export var skip_to_next_season := false:
	set(v):
		if v and is_inside_tree() and not Engine.is_editor_hint():
			TimeManager.skip_to_next_season()

# Sky tint keyed by hour (6..26). Edit to taste.
const SKY_TINTS := [
	[6.0,  Color("#ffd9b0")],
	[8.0,  Color("#ffffff")],
	[17.0, Color("#ffffff")],
	[19.0, Color("#ff9a70")],
	[20.5, Color("#4a4f9a")],
	[22.0, Color("#2b3070")],
	[26.0, Color("#1f2458")],
]

# Draws centred text exactly inside rects (independent of Label quirks).
class TextLayer extends Control:
	var font: Font
	var k := 1.0                     # ui scale: text is drawn at FINAL size (not stretched) -> crisp
	var entries: Array = []          # [{text, rect, color, size}] in panel pixels
	func _draw() -> void:
		var f: Font = font if font else ThemeDB.fallback_font
		for e in entries:
			var sz: int = maxi(1, roundi(float(e["size"]) * k))
			var r: Rect2 = e["rect"]
			r = Rect2(r.position * k, r.size * k)
			var txt: String = e["text"]
			var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
			var asc := f.get_ascent(sz)
			var desc := f.get_descent(sz)
			var x := r.position.x + (r.size.x - tw) * 0.5
			var y := r.position.y + (r.size.y + asc - desc) * 0.5
			draw_string(f, Vector2(roundf(x), roundf(y)), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, e["color"])

var _sky: TextureRect
var _stars: TextureRect
var _sun: TextureRect
var _moon: TextureRect
var _frame: TextureRect
var _text: TextLayer

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = PANEL_SIZE * ui_scale

	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -PANEL_SIZE.x * ui_scale - margin
	offset_right = -margin
	offset_top = margin
	offset_bottom = margin + PANEL_SIZE.y * ui_scale
	pivot_offset = size / 2.0

	var content := Control.new()
	content.scale = Vector2(ui_scale, ui_scale)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content)

	_sky = _tex(content, TEX_SKY, SKY_POS)
	_stars = _tex(content, TEX_STARS, SKY_POS)
	_moon = _tex(content, TEX_MOON, Vector2.ZERO)
	_sun = _tex(content, TEX_SUN, Vector2.ZERO)
	_frame = _tex(content, FRAMES[0], Vector2.ZERO)

	# text lives OUTSIDE the scaled "content" node so glyphs are rasterised at final size
	_text = TextLayer.new()
	_text.font = _resolve_font()
	_text.k = ui_scale
	_text.size = PANEL_SIZE * ui_scale
	_text.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_text)

	TimeManager.time_changed.connect(func(_h, _m): _refresh())
	TimeManager.day_changed.connect(func(_d, _s, _y): _refresh())
	TimeManager.season_changed.connect(_on_season_changed)

	_on_season_changed(TimeManager.season, false)
	_refresh()

# Priority: dropped font resource > font_path > res://assets/fonts/pixel_font.ttf > Godot default
func _resolve_font() -> Font:
	if pixel_font:
		return pixel_font
	if font_path != "" and ResourceLoader.exists(font_path):
		return load(font_path)
	if ResourceLoader.exists(DEFAULT_FONT_PATH):
		return load(DEFAULT_FONT_PATH)
	return null

func _apply_font() -> void:
	if is_instance_valid(_text):
		_text.font = _resolve_font()
		_text.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not debug_keys or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_F6: TimeManager.skip_minutes(10)
		KEY_F7: TimeManager.skip_minutes(60)
		KEY_F8: TimeManager.skip_to_next_day()
		KEY_F9: TimeManager.skip_to_next_season()

func _tex(parent: Control, tex: Texture2D, pos: Vector2) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.position = pos
	t.size = tex.get_size()
	t.stretch_mode = TextureRect.STRETCH_KEEP
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(t)
	return t

func _refresh() -> void:
	_text.entries = [
		{"text": TimeManager.get_date_string(), "rect": Rect2(DATE_RECT.position + date_offset, DATE_RECT.size), "color": text_color, "size": font_size},
		{"text": TimeManager.get_time_string(), "rect": Rect2(TIME_RECT.position + time_offset, TIME_RECT.size), "color": text_color, "size": font_size},
		{"text": TimeManager.get_season_name(), "rect": Rect2(SEASON_RECT.position + season_offset, SEASON_RECT.size), "color": season_text_color, "size": season_font_size},
	]
	_text.queue_redraw()
	var h := TimeManager.get_hour_float()
	_place_orbit(_sun, (h - 6.0) / 14.0)
	_place_orbit(_moon, (h - 20.0) / 12.0)
	_sky.modulate = _sky_tint(h)
	_stars.modulate.a = clampf((h - 19.5) / 2.0, 0.0, 1.0)

# t: 0 = left horizon, 0.5 = top, 1 = right horizon. Outside 0..1 = below horizon (hidden by frame).
func _place_orbit(node: TextureRect, t: float) -> void:
	var ang := PI * (1.0 - t)
	var p := PIVOT + Vector2(cos(ang), -sin(ang)) * ORBIT
	node.position = (p - node.size / 2.0).round()
	node.visible = t > -0.2 and t < 1.2

func _sky_tint(h: float) -> Color:
	for i in range(SKY_TINTS.size() - 1):
		var a: Array = SKY_TINTS[i]
		var b: Array = SKY_TINTS[i + 1]
		if h >= a[0] and h <= b[0]:
			return (a[1] as Color).lerp(b[1], inverse_lerp(a[0], b[0], h))
	return SKY_TINTS[SKY_TINTS.size() - 1][1]

func _on_season_changed(season: int, animate := true) -> void:
	_frame.texture = FRAMES[season]
	if animate:
		var t := create_tween()
		t.tween_property(self, "scale", Vector2(1.06, 1.06), 0.12)
		t.tween_property(self, "scale", Vector2.ONE, 0.12)
