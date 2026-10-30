class_name Weather
extends CanvasLayer
## Rain: slanted falling streaks (near + far layer), ground splashes and a cool, darker tint.
## Everything is drawn from code - no image files needed. Sits above the world but below the hotbar.
##
## set_raining(true/false) fades the rain in/out and tells the Farm, so farmland gets wet.
## Tuning: change the constants below.

# ---- look & feel ---------------------------------------------------------
const FADE_TIME := 1.5                       # seconds to fade rain in/out
const SLANT := 0.28                          # how far drops lean to the right (0 = straight down)
const TINT := Color(0.66, 0.74, 0.88)        # world is multiplied by this at full rain (white = no change)
const DROP_COLOR_NEAR := Color(0.86, 0.93, 1.0, 0.85)
const DROP_COLOR_FAR := Color(0.74, 0.85, 1.0, 0.45)
const NEAR_AMOUNT := 150
const FAR_AMOUNT := 240
const SPLASHES_PER_SEC := 110.0              # ground splashes at full rain
const SPLASH_LIFE := 0.32
const SPLASH_COLOR := Color(0.88, 0.95, 1.0)

var raining := false
var intensity := 0.0                         # 0 = dry, 1 = full rain (animated)

var tint_rect: ColorRect
var drops_near: CPUParticles2D
var drops_far: CPUParticles2D
var splash_layer: SplashLayer
var splash_timer := 0.0
var tween: Tween


func _ready() -> void:
	layer = 5                                # hotbar is layer 10, so it stays clean
	add_to_group("weather")

	# darker, cooler world (multiply blend, like a CanvasModulate that leaves the UI alone)
	tint_rect = ColorRect.new()
	tint_rect.color = Color.WHITE
	tint_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tint_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	tint_rect.material = mat
	add_child(tint_rect)

	var streak := _make_streak_texture()
	drops_far = _make_drops(streak, FAR_AMOUNT, 520.0, 640.0, 0.55, 0.8, DROP_COLOR_FAR)
	drops_near = _make_drops(streak, NEAR_AMOUNT, 800.0, 960.0, 1.0, 1.3, DROP_COLOR_NEAR)
	add_child(drops_far)
	add_child(drops_near)

	splash_layer = SplashLayer.new()
	splash_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(splash_layer)

	get_viewport().size_changed.connect(_fit_to_screen)
	_fit_to_screen()
	_apply(0.0)


# ---------------------------------------------------------------- public API
func set_raining(on: bool, instant := false) -> void:
	raining = on
	get_tree().call_group("farm", "set_raining", on)     # wet farmland while it rains
	if tween:
		tween.kill()
	var target := 1.0 if on else 0.0
	if instant:
		intensity = target
		_apply(intensity)
		return
	tween = create_tween()
	tween.tween_property(self, "intensity", target, FADE_TIME)


func toggle() -> void:
	set_raining(not raining)


# ---------------------------------------------------------------- per frame
func _process(delta: float) -> void:
	_apply(intensity)
	if intensity <= 0.01 and splash_layer.splashes.is_empty():
		return

	var vp := get_viewport().get_visible_rect().size
	splash_timer += delta * SPLASHES_PER_SEC * intensity
	while splash_timer >= 1.0:
		splash_timer -= 1.0
		splash_layer.splashes.append({
			"pos": Vector2(randf() * vp.x, randf() * vp.y).round(),
			"age": 0.0,
			"size": randf_range(0.7, 1.2),
		})
	for s in splash_layer.splashes:
		s["age"] += delta
	splash_layer.splashes = splash_layer.splashes.filter(func(s): return s["age"] < SPLASH_LIFE)
	splash_layer.queue_redraw()


func _apply(amount: float) -> void:
	tint_rect.color = Color.WHITE.lerp(TINT, amount)
	var on := amount > 0.01
	for p in [drops_near, drops_far]:
		p.emitting = on
		p.modulate.a = amount                # fade the streaks in/out
	tint_rect.visible = on


# ---------------------------------------------------------------- building blocks
# Where the drops start/end depends on the window size, so refit when it changes.
func _fit_to_screen() -> void:
	var vp := get_viewport().get_visible_rect().size
	for p in [drops_near, drops_far]:
		if p == null:
			continue
		var spread := vp.y * SLANT + 40.0    # extra width so slanted drops still cover the left edge
		p.position = Vector2(vp.x / 2.0 - spread / 2.0, -24.0)
		p.emission_rect_extents = Vector2(vp.x / 2.0 + spread / 2.0, 4.0)


func _make_drops(tex: Texture2D, amount: int, v_min: float, v_max: float,
		s_min: float, s_max: float, color: Color) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = tex
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.amount = amount
	p.lifetime = 1.0
	p.lifetime_randomness = 0.15
	p.local_coords = true                    # screen-space rain, ignores camera movement
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.direction = Vector2(SLANT, 1.0).normalized()
	p.spread = 1.5
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = v_min
	p.initial_velocity_max = v_max
	p.scale_amount_min = s_min
	p.scale_amount_max = s_max
	p.particle_flag_align_y = true           # streak points along its fall direction
	p.color = color
	p.emitting = false
	return p


# 2x10 streak, brightest at the leading (bottom) end.
func _make_streak_texture() -> ImageTexture:
	var img := Image.create(2, 10, false, Image.FORMAT_RGBA8)
	for y in 10:
		var a := float(y + 1) / 10.0
		for x in 2:
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


## Draws the little expanding ripples where drops hit the ground.
class SplashLayer extends Node2D:
	var splashes: Array = []

	func _draw() -> void:
		for s in splashes:
			var t: float = s["age"] / Weather.SPLASH_LIFE
			var radius: float = (1.5 + t * 5.5) * s["size"]
			var color := Weather.SPLASH_COLOR
			color.a = (1.0 - t) * 0.7
			draw_set_transform(s["pos"], 0.0, Vector2(1.0, 0.5))   # flattened = seen from above at an angle
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 14, color, 1.3)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
