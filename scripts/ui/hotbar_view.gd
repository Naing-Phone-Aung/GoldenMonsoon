class_name HotbarView
extends Control
## Draws the hotbar like the Clock: teak planks with grain + noise, gold bevelled frames, parchment
## wells, season gems and a built-in energy bar. Settings come from the WoodHotbar root node.
## It only DISPLAYS the player's data (hotbar / hotbar_counts / selected_slot / energy / max_energy).

const SLOT_COUNT := 10
const DEFAULT_FONT_PATH := "res://assets/fonts/pixel_font.ttf"   # same font as the Clock

const ICONS := {
	"hoe": preload("res://assets/items/hoe.png"),
	"water": preload("res://assets/items/watering_can.png"),
	"egg": preload("res://assets/items/egg.png"),
}

# ---- layout (art pixels) ------------------------------------------------
const SLOT := 32
const GAP := 3
const END_PAD := 13
const TOP_PAD := 7
const ENERGY_GAP := 4
const ENERGY_H := 12
const BOTTOM_PAD := 6
const RAISE := 3                            # how far the selected slot lifts up
const FINIAL_H := 8                         # gold crest on top, like the Clock's dial
const TOP := FINIAL_H + 1

# ---- palette (shared with the Clock art) --------------------------------
const OUTLINE := Color("#33200f")
const WOOD_TONES := [Color("#6b4423"), Color("#8f5d2c"), Color("#b8803f"), Color("#e0b070")]  # dark .. highlight
const GOLD := Color("#f2c230")
const GOLD_HI := Color("#fff0a0")
const GOLD_SHADE := Color("#c98a1a")
const GOLD_EDGE := Color("#7a4a0c")
const GOLD_BRIGHT := Color("#ffd23a")
const PARCHMENT := Color("#dcc78f")
const PARCHMENT_SHADE := Color("#cdb67c")
const PARCHMENT_LIGHT := Color("#e6d4a0")
const PARCHMENT_SEL := Color("#f0dfae")
const PARCHMENT_SEL_SHADE := Color("#dcc78f")
const PARCHMENT_SEL_LIGHT := Color("#fff4d0")
const GLOW := Color("#fff08a")
const TEXT := Color("#33200f")
const TEXT_LIGHT := Color("#fff3d6")
const WELL_DARK := Color("#3a2410")
const ALERT := Color("#d63a2f")

# season gems: summer, rainy, thadingyut, winter  (dark, light) - same accents as the Clock
const GEM_DARK := [Color("#d98a10"), Color("#1f6f78"), Color("#7a1830"), Color("#4a7fa5")]
const GEM_LIGHT := [Color("#ffd23a"), Color("#7fe0d8"), Color("#ff9a5a"), Color("#d8f0ff")]

# stepped pixel corners: radius -> row insets
const CORNERS := {1: [1], 2: [2, 1], 3: [3, 1, 1]}

var ui_scale := 1.5
var bottom_margin := 8.0
var icon_box := 20
var show_energy_bar := true
var user_font: Font

var player: Node
var _font: Font
var bar_w := 0
var bar_h := 0
var hover := -1
var _energy_hover := false
var wood_tex: ImageTexture
var specks: Array = []
var icon_rects := {}
var _season := 0
var _flash := 0.0                           # >0 while the energy bar blinks red (energy gone)


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_PASS     # wheel still reaches the player; left clicks are eaten below
	mouse_exited.connect(_on_mouse_exited)
	set_process(false)
	_cache_icon_bounds()
	_pick_font()
	_layout()

	var tm := get_node_or_null("/root/TimeManager")      # gems follow the season
	if tm:
		_season = tm.season
		tm.season_changed.connect(_on_season_changed)

	await get_tree().process_frame               # wait until the player is in the scene
	player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	player.inventory_changed.connect(queue_redraw)
	if player.has_signal("energy_changed"):
		player.energy_changed.connect(queue_redraw)
		player.energy_empty.connect(_on_energy_empty)
	queue_redraw()


## Called by the WoodHotbar root whenever one of its settings changes.
func configure(p_scale: float, p_margin: float, p_icon_box: int, p_font: Font, p_energy: bool) -> void:
	ui_scale = maxf(0.5, p_scale)
	bottom_margin = p_margin
	icon_box = maxi(4, p_icon_box)
	user_font = p_font
	show_energy_bar = p_energy
	if is_inside_tree():
		_pick_font()
		_layout()


func _pick_font() -> void:
	_font = user_font
	if _font == null and ResourceLoader.exists(DEFAULT_FONT_PATH):
		_font = load(DEFAULT_FONT_PATH)
	if _font == null:
		_font = ThemeDB.fallback_font


func _process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta * 1.6)
	queue_redraw()
	if _flash <= 0.0:
		set_process(false)


# ----------------------------------------------------------------- layout
func _layout() -> void:
	bar_w = END_PAD * 2 + SLOT_COUNT * SLOT + (SLOT_COUNT - 1) * GAP
	bar_h = TOP_PAD + SLOT
	bar_h += (ENERGY_GAP + ENERGY_H + BOTTOM_PAD) if show_energy_bar else TOP_PAD
	var total_w := bar_w * ui_scale
	var total_h := (TOP + bar_h) * ui_scale
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	offset_left = -total_w / 2.0
	offset_right = total_w / 2.0
	offset_top = -(total_h + bottom_margin)
	offset_bottom = -bottom_margin
	custom_minimum_size = Vector2(total_w, total_h)

	wood_tex = _make_wood_texture()

	specks.clear()                                # little paper flecks in each parchment well
	var rng := RandomNumberGenerator.new()
	rng.seed = 33
	for i in SLOT_COUNT:
		var list: Array[Vector2] = []
		for k in 7:
			list.append(Vector2(rng.randi_range(6, SLOT - 7), rng.randi_range(9, SLOT - 7)))
		specks.append(list)
	queue_redraw()


func _cache_icon_bounds() -> void:
	for id in ICONS:
		var img: Image = (ICONS[id] as Texture2D).get_image()
		var used := img.get_used_rect()
		if used.size == Vector2i.ZERO:
			used = Rect2i(Vector2i.ZERO, img.get_size())
		icon_rects[id] = used


func _slot_rect(i: int) -> Rect2:                # art px, not raised
	return Rect2(END_PAD + i * (SLOT + GAP), TOP + TOP_PAD, SLOT, SLOT)


func _energy_rect() -> Rect2:                    # art px
	return Rect2(END_PAD, TOP + TOP_PAD + SLOT + ENERGY_GAP, bar_w - END_PAD * 2, ENERGY_H)


# ------------------------------------------------------------------ wood
## Teak planks like the Clock's frame: two alternating plank tones, wavy dark seams with a lit edge,
## horizontal grain streaks and a little speckle noise - all built from the Clock's wood colours.
func _make_wood_texture() -> ImageTexture:
	var w := bar_w
	var h := bar_h
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var grain := FastNoiseLite.new()
	grain.seed = 5
	grain.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	var wave := FastNoiseLite.new()
	wave.seed = 9
	wave.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH

	var edges: Array[int] = [0]                  # plank boundaries
	var yy := 0
	while yy < h:
		yy += rng.randi_range(9, 13)
		edges.append(yy)

	for y in h:
		for x in w:
			if not _in_bar(x, y, w, h):
				continue
			if _is_edge(x, y, w, h):
				img.set_pixel(x, y, OUTLINE)
				continue
			if _is_rim(x, y, w, h):               # lit top / shaded bottom rim, like the Clock
				img.set_pixel(x, y, WOOD_TONES[3] if y < h / 2 else WOOD_TONES[0])
				continue

			var wy := y + int(roundf(wave.get_noise_2d(x * 0.035, y * 0.05) * 2.0))   # planks are slightly wavy
			var pi := 0
			while pi + 1 < edges.size() and edges[pi + 1] <= wy:
				pi += 1
			var tone := 1 if pi % 2 == 0 else 2   # mid / light plank
			var row := wy - edges[pi]
			if row == 0 and pi > 0 and grain.get_noise_2d(x * 0.10, 40.0 + pi) > -0.35:
				tone = 0                          # dark seam between planks (with small gaps)
			elif row == 1 and pi > 0 and grain.get_noise_2d(x * 0.12, 80.0 + pi) > 0.05:
				tone = mini(tone + 1, 3)          # lit upper edge of the next plank
			else:
				var g := grain.get_noise_2d(x * 0.10, wy * 2.2)                 # long horizontal streaks
				if g > 0.40:
					tone = maxi(tone - 1, 0)
				elif g < -0.43:
					tone = mini(tone + 1, 3)
				elif rng.randf() < 0.035:                                        # speckle noise
					tone = clampi(tone + (1 if rng.randf() < 0.5 else -1), 0, 3)
			img.set_pixel(x, y, WOOD_TONES[tone])
	return ImageTexture.create_from_image(img)


func _in_bar(x: int, y: int, w: int, h: int) -> bool:
	if x < 0 or y < 0 or x >= w or y >= h:
		return false
	var d := mini(y, h - 1 - y)
	var inset: int = CORNERS[3][d] if d < 3 else 0
	return x >= inset and x < w - inset


func _is_edge(x: int, y: int, w: int, h: int) -> bool:
	return not (_in_bar(x - 1, y, w, h) and _in_bar(x + 1, y, w, h) and _in_bar(x, y - 1, w, h) and _in_bar(x, y + 1, w, h))


func _is_rim(x: int, y: int, w: int, h: int) -> bool:
	return _is_edge(x - 1, y, w, h) or _is_edge(x + 1, y, w, h) or _is_edge(x, y - 1, w, h) or _is_edge(x, y + 1, w, h)


# ------------------------------------------------------------------ input
func _slot_at(pos: Vector2) -> int:
	var p := pos / ui_scale
	for i in SLOT_COUNT:
		var r := _slot_rect(i)
		# a little taller upward so the lifted (selected) slot is still clickable
		if Rect2(r.position.x, r.position.y - RAISE, r.size.x, r.size.y + RAISE).has_point(p):
			return i
	return -1


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var h := _slot_at(event.position)
		var over_energy := show_energy_bar and _energy_rect().has_point(event.position / ui_scale)
		if h != hover or over_energy != _energy_hover:
			hover = h
			_energy_hover = over_energy
			queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()                           # a click on the bar never swings the tool
		if event.pressed and player != null:
			var i := _slot_at(event.position)
			if i != -1:
				player.select_slot(i)


func _on_season_changed(s: int) -> void:
	_season = s
	queue_redraw()


func _on_energy_empty() -> void:
	_flash = 1.0
	set_process(true)


func _on_mouse_exited() -> void:
	if hover != -1 or _energy_hover:
		hover = -1
		_energy_hover = false
		queue_redraw()


# ------------------------------------------------------------------- draw
func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(ui_scale, ui_scale))   # everything below is in art px
	var gem_d: Color = GEM_DARK[_season]
	var gem_l: Color = GEM_LIGHT[_season]

	# --- plank body (pre-rendered wood texture)
	draw_texture_rect(wood_tex, Rect2(0, TOP, bar_w, bar_h), false)

	# --- gold crest on top, like the Clock's dial
	_draw_finial(bar_w / 2.0, gem_d, gem_l)

	# --- season gems at both ends, level with the slots
	var cy := TOP + TOP_PAD + SLOT / 2.0 - 2.0
	_gem(Vector2(4, cy), gem_d, gem_l)
	_gem(Vector2(bar_w - 9, cy), gem_d, gem_l)

	# --- slots (the selected one last so its glow sits on top)
	var sel := -1 if player == null else int(player.selected_slot)
	for i in SLOT_COUNT:
		if i != sel:
			_draw_slot(i, false)
	if sel >= 0:
		_draw_slot(sel, true)

	if show_energy_bar:
		_draw_energy()

	# --- text is drawn at final size
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_texts(sel)


func _draw_finial(cx: float, gem_d: Color, gem_l: Color) -> void:
	var t := float(TOP)
	var outer := PackedVector2Array([Vector2(cx, t - FINIAL_H), Vector2(cx + 8, t + 1), Vector2(cx - 8, t + 1)])
	var inner := PackedVector2Array([Vector2(cx, t - FINIAL_H + 2.5), Vector2(cx + 6, t), Vector2(cx - 6, t)])
	draw_colored_polygon(outer, OUTLINE)
	draw_colored_polygon(inner, GOLD)
	draw_rect(Rect2(cx - 0.5, t - FINIAL_H + 3.0, 1, FINIAL_H - 3.0), GOLD_HI)       # shine
	draw_rect(Rect2(cx - 5, t - 1, 10, 1), GOLD_SHADE)                               # base shade
	draw_rect(Rect2(cx - 1.5, t - 4, 3, 3), gem_d)                                   # season gem
	draw_rect(Rect2(cx - 0.5, t - 3.5, 1, 1), gem_l)


func _draw_slot(i: int, selected: bool) -> void:
	var r := _slot_rect(i)
	if selected:
		r.position.y -= RAISE
		_prr(r.grow(2), Color(GLOW, 0.5), 2)                                  # soft glow
	var ring := GOLD_BRIGHT if (selected or i == hover) else GOLD
	_rbox(r, ring, OUTLINE, 2)
	# bevel: bright top/left, darker bottom/right
	draw_rect(Rect2(r.position.x + 2, r.position.y + 1, r.size.x - 4, 1), GOLD_HI)
	draw_rect(Rect2(r.position.x + 1, r.position.y + 2, 1, r.size.y - 4), GOLD_HI)
	draw_rect(Rect2(r.position.x + 2, r.end.y - 2, r.size.x - 4, 1), GOLD_SHADE)
	draw_rect(Rect2(r.end.x - 2, r.position.y + 2, 1, r.size.y - 4), GOLD_SHADE)
	# parchment well with a thin dark-gold edge, paper flecks and a lit bottom line
	var well := r.grow(-3)
	draw_rect(well, GOLD_EDGE)
	var inner := well.grow(-1)
	draw_rect(inner, PARCHMENT_SEL if selected else PARCHMENT)
	draw_rect(Rect2(inner.position.x, inner.position.y, inner.size.x, 2),
		PARCHMENT_SEL_SHADE if selected else PARCHMENT_SHADE)                 # inset shadow
	draw_rect(Rect2(inner.position.x, inner.end.y - 1, inner.size.x, 1),
		PARCHMENT_SEL_LIGHT if selected else PARCHMENT_LIGHT)                 # lit bottom line
	var fleck := PARCHMENT_SEL_SHADE if selected else PARCHMENT_SHADE
	for s in specks[i]:
		draw_rect(Rect2(r.position + s, Vector2.ONE), fleck)

	if player == null:
		return
	var id: String = player.hotbar[i]
	var tex: Texture2D = ICONS.get(id)
	if tex == null:
		return
	var used: Rect2i = icon_rects[id]
	var k := float(icon_box) / float(maxi(used.size.x, used.size.y))
	var dst := Vector2(used.size) * k
	var pos := (inner.position + (inner.size - dst) / 2.0 + Vector2(0, 1)).round()
	draw_texture_rect_region(tex, Rect2(pos, dst), Rect2(used))               # same size for every item


func _draw_energy() -> void:
	var ratio := 1.0
	if player != null and "energy" in player:
		ratio = clampf(player.energy / maxf(player.max_energy, 1.0), 0.0, 1.0)
	var e := _energy_rect()
	e.position += Vector2(sin(_flash * 40.0) * _flash, 0.0)                   # tiny shake when it runs dry

	var ring := GOLD.lerp(ALERT, _flash)
	_rbox(e, ring, OUTLINE, 2)
	draw_rect(Rect2(e.position.x + 2, e.position.y + 1, e.size.x - 4, 1), GOLD_HI.lerp(ALERT, _flash))
	draw_rect(Rect2(e.position.x + 2, e.end.y - 2, e.size.x - 4, 1), GOLD_SHADE.lerp(ALERT, _flash))
	var well := e.grow(-2)
	draw_rect(well, WELL_DARK)

	var cols := _energy_colors(ratio)
	var fill_w := floorf(well.size.x * ratio)
	if ratio > 0.0:
		fill_w = maxf(fill_w, 1.0)
	if fill_w > 0.0:
		var f := Rect2(well.position, Vector2(fill_w, well.size.y))
		draw_rect(f, cols[0])
		draw_rect(Rect2(f.position.x, f.position.y, f.size.x, 1), cols[1])    # top shine
		draw_rect(Rect2(f.position.x, f.end.y - 1, f.size.x, 1), cols[2])     # bottom shade
	for k in range(1, 10):                                                      # 10% ticks
		draw_rect(Rect2(roundf(well.position.x + well.size.x * k / 10.0), well.position.y, 1, well.size.y),
			Color(OUTLINE, 0.4))

	# lightning bolt on the wood, left of the bar
	var b := Vector2(3, e.position.y + (ENERGY_H - 10) / 2.0)
	var bolt := PackedVector2Array([
		b + Vector2(5, 0), b + Vector2(0, 6), b + Vector2(3, 6),
		b + Vector2(2, 10), b + Vector2(8, 3), b + Vector2(5, 3)])
	var bolt_line := bolt.duplicate()
	bolt_line.append(bolt[0])
	draw_colored_polygon(bolt, cols[0].lerp(GOLD_BRIGHT, 0.4))
	draw_polyline(bolt_line, OUTLINE, 1.0)


func _draw_texts(sel: int) -> void:
	var ns := maxi(1, roundi(7.0 * ui_scale))
	var cs := maxi(1, roundi(8.0 * ui_scale))
	var outline := maxi(2, roundi(2.0 * ui_scale))
	for i in SLOT_COUNT:
		var r := _slot_rect(i)
		if i == sel:
			r.position.y -= RAISE
		var base := r.position * ui_scale
		# slot number (1..9, 0)
		draw_string(_font, base + Vector2(5.0, 11.0) * ui_scale, str((i + 1) % 10),
			HORIZONTAL_ALIGNMENT_LEFT, -1, ns, TEXT)
		if player == null or player.hotbar[i] == "":
			continue                                 # empty slot: no count
		var c: int = player.hotbar_counts[i]
		if c >= 0:
			var ct := str(c)
			var cw := _font.get_string_size(ct, HORIZONTAL_ALIGNMENT_LEFT, -1, cs).x
			var cp := base + Vector2(r.size.x * ui_scale - cw - 5.0 * ui_scale, (r.size.y - 4.0) * ui_scale)
			draw_string_outline(_font, cp, ct, HORIZONTAL_ALIGNMENT_LEFT, -1, cs, outline, PARCHMENT_SEL)
			draw_string(_font, cp, ct, HORIZONTAL_ALIGNMENT_LEFT, -1, cs, TEXT)

	# the energy value only shows while the mouse is over the bar
	if _energy_hover and show_energy_bar and player != null and "energy" in player:
		var e := _energy_rect()
		var label := "%d/%d" % [ceili(player.energy), ceili(player.max_energy)]
		var es := maxi(1, roundi(6.5 * ui_scale))
		var lw := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, es).x
		var lp := Vector2(e.get_center().x * ui_scale - lw / 2.0, (e.position.y + ENERGY_H / 2.0) * ui_scale + es * 0.36)
		draw_string_outline(_font, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, es, outline, OUTLINE)
		draw_string(_font, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, es, TEXT_LIGHT)


# ---------------------------------------------------------------- helpers
## Rounded rectangle with stepped pixel corners (radius 1-3), filled with one colour.
func _prr(r: Rect2, col: Color, rad: int) -> void:
	var ins: Array = CORNERS[rad]
	var n := ins.size()
	draw_rect(Rect2(r.position.x, r.position.y + n, r.size.x, r.size.y - 2 * n), col)
	for i in n:
		var inset: float = ins[i]
		draw_rect(Rect2(r.position.x + inset, r.position.y + i, r.size.x - 2 * inset, 1), col)
		draw_rect(Rect2(r.position.x + inset, r.end.y - (i + 1), r.size.x - 2 * inset, 1), col)


## Same, with a 1px dark outline.
func _rbox(r: Rect2, fill: Color, line: Color, rad: int) -> void:
	_prr(r, line, rad)
	_prr(r.grow(-1), fill, maxi(rad - 1, 1))


## 5x5 gold diamond with a season-coloured gem in the middle.
func _gem(p: Vector2, gem_dark: Color, gem_light: Color) -> void:
	var rows := ["..o..", ".oGo.", "oGgGo", ".oGo.", "..o.."]
	var cols := {"o": GOLD_EDGE, "G": GOLD, "g": gem_dark}
	for y in 5:
		for x in 5:
			var ch: String = rows[y][x]
			if cols.has(ch):
				draw_rect(Rect2(p + Vector2(x, y), Vector2.ONE), cols[ch])
	draw_rect(Rect2(p + Vector2(2, 1), Vector2.ONE), gem_light)


## [fill, shine, shade] - green when full, through gold and orange to red when low.
func _energy_colors(r: float) -> Array:
	var stops := [
		[0.0, Color("#d63a2f"), Color("#ff8a70"), Color("#8f1f1a")],
		[0.3, Color("#e8790a"), Color("#ffb04a"), Color("#a8500a")],
		[0.6, Color("#f2c230"), Color("#fff0a0"), Color("#c98a1a")],
		[1.0, Color("#6fcf4a"), Color("#b6f07a"), Color("#3f8f2e")],
	]
	for i in stops.size() - 1:
		var a: Array = stops[i]
		var b: Array = stops[i + 1]
		if r <= b[0]:
			var t := inverse_lerp(a[0], b[0], r)
			return [a[1].lerp(b[1], t), a[2].lerp(b[2], t), a[3].lerp(b[3], t)]
	return [stops[3][1], stops[3][2], stops[3][3]]
