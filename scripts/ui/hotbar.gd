class_name WoodHotbar
extends Control
## Myanmar farm-style wooden hotbar: teak planks, rope lashings, iron nails.
## The frame is drawn from code; item icons come from assets/items.
## It only DISPLAYS the player's hotbar (player.hotbar / hotbar_counts / selected_slot).

const SLOT_COUNT := 10

const ICONS := {
	"hoe": preload("res://assets/items/hoe.png"),
	"water": preload("res://assets/items/watering_can.png"),
	"egg": preload("res://assets/items/egg.png"),
}

@export var slot_size := 58            ## width/height of each wooden slot
@export var icon_box := 38             ## hidden box every icon is fitted into (same visual size for all items)
@export var bottom_margin := 12

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
var hover := -1                        # slot under the mouse (-1 = none)
var icon_rects := {}                   # item id -> opaque area of its PNG (so empty margins are ignored)

# ---- colours (teak wood, rope, dark lacquer) ----------------------------
var C_OUT := Color("#2a1608")
var C_WOOD := Color("#8a5a2b")
var C_HI := Color("#b37a3c")
var C_SHADE := Color("#5a3818")
var C_SEAM := Color("#3b2410")
var C_GRAIN_D := Color("#74491f")
var C_GRAIN_L := Color("#a06c35")
var C_ROPE := Color("#d9b97a")
var C_ROPE_DK := Color("#8f6d36")
var C_NAIL := Color("#1c1c1c")
var C_SLOT := Color("#b8864a")
var C_SLOT_SEL := Color("#ffe0a0")
var C_SLOT_HOVER := Color("#d2a064")
var C_BG := Color("#3a2410")
var C_BG_SEL := Color("#5c3a18")
var C_TEXT := Color("#fff3d6")


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_PASS     # wheel still reaches the player; left clicks are eaten below
	mouse_exited.connect(_on_mouse_exited)
	_cache_icon_bounds()
	_layout()
	await get_tree().process_frame               # wait until the player is in the scene
	player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	player.inventory_changed.connect(queue_redraw)
	queue_redraw()


# ----------------------------------------------------------------- layout
func _layout() -> void:
	slot_px = slot_size
	bar_w = end_pad * 2 + SLOT_COUNT * slot_px + (SLOT_COUNT - 1) * slot_gap
	bar_h = slot_px + v_pad * 2
	top_y = raise + 2                            # room for the lifted selected slot
	var total_h := top_y + bar_h

	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	offset_left = -bar_w / 2.0
	offset_right = bar_w / 2.0
	offset_top = -(total_h + bottom_margin)
	offset_bottom = -bottom_margin
	custom_minimum_size = Vector2(bar_w, total_h)

	grain.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 46:
		grain.append([
			Vector2i(rng.randi_range(4, bar_w - 24), rng.randi_range(top_y + 5, top_y + bar_h - 7)),
			rng.randi_range(8, 30),
			rng.randf() < 0.6,
		])
	queue_redraw()


## Find the visible pixels of every icon, so a big empty margin in one PNG
## can't make that item look smaller than the others.
func _cache_icon_bounds() -> void:
	for id in ICONS:
		var img: Image = (ICONS[id] as Texture2D).get_image()
		var used := img.get_used_rect()
		if used.size == Vector2i.ZERO:
			used = Rect2i(Vector2i.ZERO, img.get_size())
		icon_rects[id] = used


func _slot_rect(i: int) -> Rect2:
	var x := end_pad + i * (slot_px + slot_gap)
	var y := top_y + (bar_h - slot_px) / 2
	return Rect2(x, y, slot_px, slot_px)


# ------------------------------------------------------------------ input
func _slot_at(pos: Vector2) -> int:
	for i in SLOT_COUNT:
		var r := _slot_rect(i)
		# a little taller upward so the lifted (selected) slot is still clickable
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
		# Eat every left click on the bar so it never swings the tool.
		accept_event()
		if event.pressed and player != null:
			var i := _slot_at(event.position)
			if i != -1:
				player.select_slot(i)


func _on_mouse_exited() -> void:
	if hover != -1:
		hover = -1
		queue_redraw()


# ------------------------------------------------------------------- draw
func _draw() -> void:
	var f: Font = ThemeDB.fallback_font

	# --- teak plank body
	draw_rect(Rect2(0, top_y, bar_w, bar_h), C_OUT)
	draw_rect(Rect2(2, top_y + 2, bar_w - 4, bar_h - 4), C_WOOD)
	draw_rect(Rect2(2, top_y + 2, bar_w - 4, 2), C_HI)
	draw_rect(Rect2(2, top_y + bar_h - 4, bar_w - 4, 2), C_SHADE)
	draw_rect(Rect2(2, top_y + bar_h / 2 - 1, bar_w - 4, 2), C_SEAM)   # plank join
	for g in grain:
		var p: Vector2i = g[0]
		draw_rect(Rect2(p.x, p.y, g[1], 1), C_GRAIN_D if g[2] else C_GRAIN_L)

	# --- rope lashings at both ends
	for rx in [7, bar_w - 15]:
		draw_rect(Rect2(rx, top_y, 8, bar_h), C_ROPE)
		draw_rect(Rect2(rx, top_y, 1, bar_h), C_ROPE_DK)
		draw_rect(Rect2(rx + 7, top_y, 1, bar_h), C_ROPE_DK)
		var yy := top_y + 1
		while yy < top_y + bar_h - 3:
			draw_line(Vector2(rx, yy + 3), Vector2(rx + 8, yy), C_ROPE_DK)
			yy += 3

	# --- iron nails
	for nx in [3, bar_w - 5]:
		for ny in [top_y + 3, top_y + bar_h - 5]:
			draw_rect(Rect2(nx, ny, 2, 2), C_NAIL)

	# --- slots
	for i in SLOT_COUNT:
		var r := _slot_rect(i)
		var sel: bool = player != null and i == player.selected_slot
		if sel:
			r.position.y -= raise
		draw_rect(r.grow(2), C_OUT)
		draw_rect(r, C_SLOT_SEL if sel else (C_SLOT_HOVER if i == hover else C_SLOT))
		var inner := r.grow(-3)
		draw_rect(inner, C_BG_SEL if sel else C_BG)
		draw_rect(Rect2(inner.position, Vector2(inner.size.x, 2)), C_OUT)  # inset shadow

		# slot number (1..9, 0)
		var kt := str((i + 1) % 10)
		draw_string_outline(f, r.position + Vector2(5, 11), kt, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, 3, C_OUT)
		draw_string(f, r.position + Vector2(5, 11), kt, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, C_SLOT_SEL)

		if player == null:
			continue
		var id: String = player.hotbar[i]
		if id == "":
			continue
		var tex: Texture2D = ICONS.get(id)
		if tex:
			# Fit the visible part of the icon into the same hidden box, centred in the slot.
			var used: Rect2i = icon_rects[id]
			var k := float(icon_box) / float(maxi(used.size.x, used.size.y))
			var dst_size := Vector2(used.size) * k
			var dst_pos := (r.position + (Vector2(slot_px, slot_px) - dst_size) / 2.0).round()
			draw_texture_rect_region(tex, Rect2(dst_pos, dst_size), Rect2(used))

		# stack count (tools have -1 = no number)
		var c: int = player.hotbar_counts[i]
		if c >= 0:
			var ct := str(c)
			var cw := f.get_string_size(ct, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
			var cp := r.position + Vector2(r.size.x - cw - 5, r.size.y - 5)
			draw_string_outline(f, cp, ct, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 3, C_OUT)
			draw_string(f, cp, ct, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, C_TEXT)
