class_name WoodHotbar
extends Control
## Golden Monsoon hotbar - carved teak with gold trim, cut-corner slots and a flame finial.
## Styled to match the Clock (same wood + gold palette, season-coloured gems).
## It only DISPLAYS the player's hotbar (player.hotbar / hotbar_counts / selected_slot).

const SLOT_COUNT := 10

const ICONS := {
	"hoe": preload("res://assets/items/hoe.png"),
	"water": preload("res://assets/items/watering_can.png"),
	"egg": preload("res://assets/items/egg.png"),
}

const DEFAULT_FONT_PATH := "res://assets/fonts/pixel_font.ttf"   # same font as the Clock

@export var slot_size := 58            ## width/height of each slot (screen px)
@export var icon_box := 38             ## hidden box every icon is fitted into
@export var bottom_margin := 12
## Pixel size of the frame details. Set it equal to the Clock's ui_scale (1 or 2)
## so wood grain / gold lines have the same pixel density on both.
@export var unit := 1:
	set(v):
		unit = maxi(1, v)
		if is_inside_tree():
			_layout()
@export var font: Font                 ## optional; drag a .ttf here (else pixel_font.ttf, else default)

var slot_gap := 4
var end_pad := 26
var v_pad := 10
var raise := 4                         # how far the selected slot lifts up

var player: Node
var grain: Array = []
var bar_w := 0
var bar_h := 0
var slot_px := 0
var top_y := 0
var u := 1
var hover := -1
var icon_rects := {}
var _season := 0
var _font: Font

# ---- palette (shared with the Clock art) ---------------------------------
const C_OUT := Color("#33200f")
const C_WD := Color("#6b4423")
const C_WM := Color("#8f5d2c")
const C_WL := Color("#b8803f")
const C_WH := Color("#e0b070")
const G1 := Color("#fff0a0")
const G2 := Color("#f2c230")
const G3 := Color("#c98a1a")
const G4 := Color("#7a4a0c")
const C_INLAY := Color("#3a2410")
const C_INLAY_SEL := Color("#5c3a18")
const C_INLAY_HOVER := Color("#4a2e14")
const C_TEXT := Color("#fff3d6")

# season gems: summer, rainy, thadingyut, winter  (dark, light)
const ACC_DARK := [Color("#d98a10"), Color("#1f6f78"), Color("#7a1830"), Color("#4a7fa5")]
const ACC_LIGHT := [Color("#ffd23a"), Color("#7fe0d8"), Color("#ff9a5a"), Color("#d8f0ff")]

# pixel-art rounded corner insets (in units)
const CORNERS := {1: [1], 2: [2, 1], 3: [3, 1, 1], 4: [4, 2, 1, 1]}


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_PASS
	mouse_exited.connect(_on_mouse_exited)
	_font = font
	if _font == null and ResourceLoader.exists(DEFAULT_FONT_PATH):
		_font = load(DEFAULT_FONT_PATH)
	if _font == null:
		_font = ThemeDB.fallback_font
	_cache_icon_bounds()
	_layout()

	var tm := get_node_or_null("/root/TimeManager")      # optional: gems follow the season
	if tm:
		_season = tm.season
		tm.season_changed.connect(_on_season_changed)

	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	player.inventory_changed.connect(queue_redraw)
	queue_redraw()


# ----------------------------------------------------------------- layout
func _layout() -> void:
	u = maxi(1, unit)
	slot_px = slot_size
	bar_w = end_pad * 2 + SLOT_COUNT * slot_px + (SLOT_COUNT - 1) * slot_gap
	bar_h = slot_px + v_pad * 2
	top_y = maxi(raise + 2, 11 * u)                   # room for finial + lifted slot
	var total_h := top_y + bar_h + 3 * u              # + end-cap overhang

	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	offset_left = -bar_w / 2.0
	offset_right = bar_w / 2.0
	offset_top = -(total_h + bottom_margin)
	offset_bottom = -bottom_margin
	custom_minimum_size = Vector2(bar_w, total_h)

	grain.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 60:
		grain.append([
			Vector2i(rng.randi_range(4, bar_w - 24), rng.randi_range(top_y + 5, top_y + bar_h - 7)),
			rng.randi_range(8, 30),
			rng.randf() < 0.6,
		])
	queue_redraw()


func _cache_icon_bounds() -> void:
	for id in ICONS:
		var img: Image = (ICONS[id] as Texture2D).get_image()
		var used := img.get_used_rect()
		if used.size == Vector2i.ZERO:
			used = Rect2i(Vector2i.ZERO, img.get_size())
		icon_rects[id] = used


func _slot_rect(i: int) -> Rect2:
	var x := end_pad + i * (slot_px + slot_gap)
	var y := top_y + (bar_h - slot_px) / 2.0
	return Rect2(x, y, slot_px, slot_px)


# ------------------------------------------------------------------ input
func _slot_at(pos: Vector2) -> int:
	for i in SLOT_COUNT:
		var r := _slot_rect(i)
		if Rect2(r.position.x - 2, r.position.y - 2 - raise, r.size.x + 4, r.size.y + 4 + raise).has_point(pos):
			return i
	return -1


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var h := _slot_at(event.position)
		if h != hover:
			hover = h
			queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if event.pressed and player != null:
			var i := _slot_at(event.position)
			if i != -1:
				player.select_slot(i)


func _on_season_changed(s: int) -> void:
	_season = s
	queue_redraw()


func _on_mouse_exited() -> void:
	if hover != -1:
		hover = -1
		queue_redraw()


# ---------------------------------------------------------- draw helpers
# pixel-art rounded rectangle (corner radius in units)
func _prr(r: Rect2, col: Color, rad := 3) -> void:
	var ins: Array = CORNERS[rad]
	var n := ins.size()
	draw_rect(Rect2(r.position.x, r.position.y + n * u, r.size.x, r.size.y - 2 * n * u), col)
	for i in n:
		var inset: float = ins[i] * u
		draw_rect(Rect2(r.position.x + inset, r.position.y + i * u, r.size.x - 2 * inset, u), col)
		draw_rect(Rect2(r.position.x + inset, r.position.y + r.size.y - (i + 1) * u, r.size.x - 2 * inset, u), col)


# cut-corner (octagon) rectangle like the Clock plaques
func _chamfer(r: Rect2, col: Color, c: float) -> void:
	var x0 := r.position.x
	var y0 := r.position.y
	var x1 := x0 + r.size.x
	var y1 := y0 + r.size.y
	draw_colored_polygon(PackedVector2Array([
		Vector2(x0 + c, y0), Vector2(x1 - c, y0), Vector2(x1, y0 + c), Vector2(x1, y1 - c),
		Vector2(x1 - c, y1), Vector2(x0 + c, y1), Vector2(x0, y1 - c), Vector2(x0, y0 + c)]), col)


func _diamond(c: Vector2, half: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(c.x, c.y - half), Vector2(c.x + half * 0.7, c.y),
		Vector2(c.x, c.y + half), Vector2(c.x - half * 0.7, c.y)]), col)


func _text(pos: Vector2, s: String, size: int, col: Color) -> void:
	draw_string_outline(_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 3 * u, C_OUT)
	draw_string(_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


# ------------------------------------------------------------------- draw
func _draw() -> void:
	var ac_d: Color = ACC_DARK[_season]
	var ac_l: Color = ACC_LIGHT[_season]
	var bar := Rect2(0, top_y, bar_w, bar_h)

	# --- flame finial (centre top, like the Clock's dial)
	var cx := bar_w / 2.0
	var fl := PackedVector2Array([
		Vector2(cx, top_y - 9 * u), Vector2(cx + 2 * u, top_y - 5 * u), Vector2(cx + 5 * u, top_y - 2 * u),
		Vector2(cx + 7 * u, top_y + 2 * u), Vector2(cx - 7 * u, top_y + 2 * u),
		Vector2(cx - 5 * u, top_y - 2 * u), Vector2(cx - 2 * u, top_y - 5 * u)])
	draw_colored_polygon(fl, G2)
	var fl_line := fl.duplicate()
	fl_line.append(fl[0])
	draw_polyline(fl_line, C_OUT, u)
	draw_line(Vector2(cx, top_y - 7 * u), Vector2(cx, top_y), G1, u)
	_diamond(Vector2(cx, top_y - 3 * u), 3 * u, ac_d)
	draw_rect(Rect2(cx - u * 0.5, top_y - 4 * u, u, u), ac_l)

	# --- teak body
	_prr(bar, C_OUT, 4)
	var inner := bar.grow(-u)
	_prr(inner, C_WM, 3)
	var band := 6 * u
	var yy := inner.position.y + 3 * u
	var row := 0
	while yy < inner.end.y - 3 * u:                                  # alternating plank bands
		if row % 2 == 1:
			draw_rect(Rect2(inner.position.x + 2 * u, yy, inner.size.x - 4 * u, minf(band, inner.end.y - 3 * u - yy)), C_WL)
		yy += band
		row += 1
	draw_rect(Rect2(bar.position.x + 3 * u, bar.position.y + u, bar.size.x - 6 * u, u), C_WH)           # top highlight
	draw_rect(Rect2(bar.position.x + 3 * u, bar.end.y - 2 * u, bar.size.x - 6 * u, u), C_WD)            # bottom shade
	draw_rect(Rect2(bar.position.x + 3 * u, bar.position.y + bar_h / 2.0, bar.size.x - 6 * u, u), C_WD)  # plank seam
	for g in grain:
		var p: Vector2i = g[0]
		draw_rect(Rect2(p.x, p.y, g[1], u), C_WD if g[2] else C_WH)

	# --- gold trim running along top and bottom edges
	draw_rect(Rect2(end_pad, top_y + 3 * u, bar_w - end_pad * 2, u), G3)
	draw_rect(Rect2(end_pad, top_y + bar_h - 4 * u, bar_w - end_pad * 2, u), G3)

	# --- little gold diamonds in the gaps between slots
	for i in SLOT_COUNT - 1:
		var gx := end_pad + (i + 1) * (slot_px + slot_gap) - slot_gap / 2.0
		_diamond(Vector2(gx, top_y + v_pad / 2.0 + u), 2.5 * u, G2)
		_diamond(Vector2(gx, top_y + bar_h - v_pad / 2.0 - u), 2.5 * u, G2)

	# --- carved gold end caps (taller than the bar, with a season gem)
	for side in [0, 1]:
		var cw := end_pad - 4 * u
		var cx0 := 2 * u if side == 0 else bar_w - 2 * u - cw
		var cap := Rect2(cx0, top_y - 3 * u, cw, bar_h + 6 * u)
		_prr(cap, C_OUT, 3)
		_prr(cap.grow(-u), G4, 2)
		_prr(cap.grow(-2 * u), G2, 2)
		draw_rect(Rect2(cap.position.x + 3 * u, cap.position.y + 3 * u, u, cap.size.y - 6 * u), G1)                 # shine
		draw_rect(Rect2(cap.end.x - 4 * u, cap.position.y + 3 * u, u, cap.size.y - 6 * u), G3)                      # shade
		_diamond(cap.get_center(), 5 * u, C_OUT)
		_diamond(cap.get_center(), 4 * u, ac_d)
		draw_rect(Rect2(cap.get_center().x - u, cap.get_center().y - 2 * u, u, u), ac_l)
		for sy in [cap.position.y + 5 * u, cap.end.y - 6 * u]:                                                      # studs
			draw_rect(Rect2(cap.get_center().x - u, sy, 2 * u, 2 * u), G3)
			draw_rect(Rect2(cap.get_center().x - u, sy, u, u), G1)

	# --- slots (cut-corner plaques with gold rims)
	for i in SLOT_COUNT:
		var r := _slot_rect(i)
		var sel: bool = player != null and i == player.selected_slot
		var hov := i == hover
		if sel:
			r.position.y -= raise
		_chamfer(r.grow(u), C_OUT, 4 * u)
		_chamfer(r, G4, 3 * u)
		_chamfer(r.grow(-u), G1 if sel else (G2 if hov else G3), 3 * u)
		_chamfer(r.grow(-2 * u), G2 if sel else (G1 if hov else G3), 2 * u)
		var inl := r.grow(-3 * u)
		draw_rect(inl, C_INLAY_SEL if sel else (C_INLAY_HOVER if hov else C_INLAY))
		draw_rect(Rect2(inl.position, Vector2(inl.size.x, 2 * u)), C_OUT)                       # inset shadow
		draw_rect(Rect2(inl.position.x, inl.end.y - u, inl.size.x, u), C_INLAY_SEL)             # bottom light
		if sel:                                                                                    # season gems on the corners
			for corner in [r.position, Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), r.end]:
				_diamond(corner, 3 * u, C_OUT)
				_diamond(corner, 2 * u, ac_l)

		# slot number (1..9, 0)
		var kt := str((i + 1) % 10)
		_text(inl.position + Vector2(3 * u, 11 * u), kt, 9 * u, G1)

		if player == null:
			continue
		var id: String = player.hotbar[i]
		if id == "":
			continue
		var tex: Texture2D = ICONS.get(id)
		if tex:
			var used: Rect2i = icon_rects[id]
			var k := float(icon_box) / float(maxi(used.size.x, used.size.y))
			var dst_size := Vector2(used.size) * k
			var dst_pos := (r.position + (Vector2(slot_px, slot_px) - dst_size) / 2.0).round()
			draw_texture_rect_region(tex, Rect2(dst_pos, dst_size), Rect2(used))

		var c: int = player.hotbar_counts[i]
		if c >= 0:
			var ct := str(c)
			var cs := 11 * u
			var cw2 := _font.get_string_size(ct, HORIZONTAL_ALIGNMENT_LEFT, -1, cs).x
			var cp := Vector2(inl.end.x - cw2 - 3 * u, inl.end.y - 4 * u)
			_text(cp, ct, cs, C_TEXT)
