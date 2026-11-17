class_name InventoryView
extends Control
## The full bag screen: every item you carry (not just the one row the hotbar can show).
## Pure display - Inventory (inventory.gd) owns visibility, the player owns the data (player.items).
## Palette matches the hotbar/clock (teak + gold + parchment) so it feels like the same UI set.

const COLS := 5
const ROWS := 4                             # COLS * ROWS must be >= Player.BAG_SLOTS (20)
const SLOT := 36
const GAP := 6
const PAD := 16
const TITLE_H := 22
const ICON_BOX := 24

const OUTLINE := Color("#33200f")
const WOOD := Color("#8f5d2c")
const WOOD_LIGHT := Color("#b8803f")
const WOOD_DARK := Color("#6b4423")
const GOLD := Color("#f2c230")
const GOLD_HI := Color("#fff0a0")
const GOLD_SHADE := Color("#c98a1a")
const PARCHMENT := Color("#dcc78f")
const PARCHMENT_SHADE := Color("#cdb67c")
const PARCHMENT_LIGHT := Color("#e6d4a0")
const TEXT := Color("#33200f")
const TEXT_LIGHT := Color("#fff3d6")

var ui_scale := 2.0
var player: Node
var _font: Font
var panel_w := 0.0
var panel_h := 0.0
var hover := -1


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_STOP
	visibility_changed.connect(_on_visibility_changed)
	if ResourceLoader.exists("res://assets/fonts/pixel_font.ttf"):
		_font = load("res://assets/fonts/pixel_font.ttf")
	else:
		_font = ThemeDB.fallback_font
	_layout()
	get_viewport().size_changed.connect(_layout)   # keep covering the whole window if it resizes

	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")
	if player != null:
		player.inventory_changed.connect(queue_redraw)
	queue_redraw()


func _layout() -> void:
	panel_w = PAD * 2 + COLS * SLOT + (COLS - 1) * GAP
	panel_h = PAD * 2 + TITLE_H + ROWS * SLOT + (ROWS - 1) * GAP
	# A Control sitting directly under a CanvasLayer (no parent Control) can be a frame or two
	# late resolving anchor-based sizing, so set the rect explicitly from the viewport instead
	# of trusting PRESET_FULL_RECT's "size" to already be right the moment we draw.
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2.ZERO
	size = get_viewport_rect().size
	queue_redraw()


func _on_visibility_changed() -> void:
	if visible:
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var h := _slot_at(event.position)
		if h != hover:
			hover = h
			queue_redraw()
	elif event is InputEventMouseButton:
		accept_event()                           # clicks on the panel never reach the world


func _slot_at(pos: Vector2) -> int:
	var origin := (get_viewport_rect().size - Vector2(panel_w, panel_h) * ui_scale) / 2.0
	var p := (pos - origin) / ui_scale
	for i in COLS * ROWS:
		if _slot_rect(i).has_point(p):
			return i
	return -1


func _slot_rect(i: int) -> Rect2:
	var col := i % COLS
	var row := i / COLS
	return Rect2(PAD + col * (SLOT + GAP), PAD + TITLE_H + row * (SLOT + GAP), SLOT, SLOT)


func _draw() -> void:
	if not visible:
		return
	var vp := get_viewport_rect().size
	# dim the world behind the panel
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0, 0, 0, 0.45))

	draw_set_transform((vp - Vector2(panel_w, panel_h) * ui_scale) / 2.0, 0.0, Vector2(ui_scale, ui_scale))
	var r := Rect2(0, 0, panel_w, panel_h)
	_rbox(r, WOOD, OUTLINE)
	draw_rect(Rect2(r.position.x + 2, r.position.y + 2, r.size.x - 4, 2), WOOD_LIGHT)
	draw_rect(Rect2(r.position.x + 2, r.end.y - 4, r.size.x - 4, 2), WOOD_DARK)

	var items: Dictionary = {} if player == null else player.items
	var keys := items.keys()
	keys.sort()
	for i in COLS * ROWS:
		_draw_slot(i, keys[i] if i < keys.size() else "", items)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_texts(keys.size())


func _draw_slot(i: int, item_id: String, items: Dictionary) -> void:
	var r := _slot_rect(i)
	_rbox(r, GOLD_SHADE if hover == i and item_id != "" else GOLD, OUTLINE)
	var well := r.grow(-3)
	draw_rect(well, PARCHMENT_SHADE)
	var inner := well.grow(-1)
	draw_rect(inner, PARCHMENT)
	draw_rect(Rect2(inner.position, Vector2(inner.size.x, 1)), PARCHMENT_LIGHT)

	if item_id == "":
		return
	var tex: Texture2D = ItemIcons.get_icon(item_id)
	if tex == null:
		return
	var img := tex.get_image()
	var used := img.get_used_rect()
	if used.size == Vector2i.ZERO:
		used = Rect2i(Vector2i.ZERO, img.get_size())
	var k := float(ICON_BOX) / float(maxi(used.size.x, used.size.y))
	var dst := Vector2(used.size) * k
	var pos := (inner.position + (inner.size - dst) / 2.0).round()
	draw_texture_rect_region(tex, Rect2(pos, dst), Rect2(used))


func _draw_texts(item_count: int) -> void:
	var origin := (get_viewport_rect().size - Vector2(panel_w, panel_h) * ui_scale) / 2.0
	var title_size := maxi(1, roundi(9.0 * ui_scale))
	var title := "Bag  (%d/%d)" % [item_count, player.BAG_SLOTS if player != null else 20]
	var tw := _font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x
	var tp := origin + Vector2((panel_w * ui_scale - tw) / 2.0, PAD * ui_scale)
	draw_string_outline(_font, tp, title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, maxi(2, roundi(2 * ui_scale)), OUTLINE)
	draw_string(_font, tp, title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, TEXT_LIGHT)

	var items: Dictionary = {} if player == null else player.items
	var keys := items.keys()
	keys.sort()
	var cs := maxi(1, roundi(7.0 * ui_scale))
	var outline := maxi(2, roundi(2.0 * ui_scale))
	for i in keys.size():
		var r := _slot_rect(i)
		var base := origin + r.position * ui_scale
		var ct := str(items[keys[i]])
		var cw := _font.get_string_size(ct, HORIZONTAL_ALIGNMENT_LEFT, -1, cs).x
		var cp := base + Vector2(r.size.x * ui_scale - cw - 4.0 * ui_scale, (r.size.y - 3.0) * ui_scale)
		draw_string_outline(_font, cp, ct, HORIZONTAL_ALIGNMENT_LEFT, -1, cs, outline, PARCHMENT)
		draw_string(_font, cp, ct, HORIZONTAL_ALIGNMENT_LEFT, -1, cs, TEXT)

	if hover != -1 and hover < keys.size():
		var name_str: String = str(keys[hover]).capitalize()
		var ns := maxi(1, roundi(8.0 * ui_scale))
		var hr := _slot_rect(hover)
		var hp := origin + Vector2(hr.position.x, hr.end.y + 4) * ui_scale
		draw_string_outline(_font, hp, name_str, HORIZONTAL_ALIGNMENT_LEFT, -1, ns, outline, OUTLINE)
		draw_string(_font, hp, name_str, HORIZONTAL_ALIGNMENT_LEFT, -1, ns, TEXT_LIGHT)


func _rbox(r: Rect2, fill: Color, line: Color) -> void:
	draw_rect(r, line)
	draw_rect(r.grow(-2), fill)
