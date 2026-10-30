class_name Farm
extends Node2D
## Tilling + watering.
##   hoe on solid PATH ground (the all-brown middle tiles, never the grassy edges/corners) -> dry farmland
##   watering can on dry farmland -> wet farmland
##
## FarmLand_Tile.png holds 4 soil looks, each a full 47-tile autotile set stacked
## 6 rows apart (see Soil below). Soil state is tracked here, and the tile shape is
## picked from which neighbours are farmland, so dry and wet patches still join up.
##
## The player talks to this node through the "farm" group:
##   world_to_cell(pos), harvest(cell), use_tool(tool_name, cell)

enum Soil { DRY, WET, SEEDED, WET_SEEDED }   # = which 6-row block of FarmLand_Tile.png

const TILESET_PATH := "res://scenes/tiles/tileset_farm.tres"
const FARM_SOURCE_ID := 4          # FarmLand_Tile.png in the tileset
const FARM_TERRAIN := 4            # "Farm" terrain
const PATH_SOURCE_ID := 2          # Path_Tile.png in the tileset - the only ground you can till
const BLOCK_ROWS := 6              # rows per soil look in the atlas
const ATLAS_COLS := 8

# Neighbour order used for the shape mask (matches the tileset's peering bits).
const NEIGHBOR_BITS := [
	TileSet.CELL_NEIGHBOR_RIGHT_SIDE,
	TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER,
	TileSet.CELL_NEIGHBOR_BOTTOM_SIDE,
	TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER,
	TileSet.CELL_NEIGHBOR_LEFT_SIDE,
	TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER,
	TileSet.CELL_NEIGHBOR_TOP_SIDE,
	TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
]
const NEIGHBOR_OFFSETS := [
	Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1),
	Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
]

## Optional: the layers that hold your Path tiles. Leave empty to check every
## TileMapLayer next to this node.
@export var path_layers: Array[TileMapLayer] = []

var raining := false                 # set by Weather; rain waters farmland automatically
var layer: TileMapLayer
var cursor: Node2D                   # square showing which tile the tool will hit
var cursor_cell := Vector2i.ZERO
var cursor_ok := false
var cursor_shown := false
var solid_path_tiles: Dictionary = {}  # atlas coords of Path tiles that are 100% path (no grass pixels)
var soil: Dictionary = {}            # Vector2i cell -> Soil
var shape_lookup: Dictionary = {}    # neighbour mask -> atlas coords (in the dry block)


func _ready() -> void:
	add_to_group("farm")
	var ts: TileSet = load(TILESET_PATH)
	layer = TileMapLayer.new()
	layer.name = "FarmLayer"
	layer.tile_set = ts
	add_child(layer)
	cursor = Node2D.new()
	cursor.name = "TargetCursor"
	add_child(cursor)                 # added after FarmLayer, so it draws on top of it
	cursor.draw.connect(_draw_cursor)
	_build_shape_lookup(ts)
	_build_solid_path_tiles(ts)
	var weather := get_tree().get_first_node_in_group("weather")
	if weather != null and weather.raining:
		set_raining(true)


# Green square = the tool will work on that tile, red = it won't.
func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var tool_name: String = player.current_tool
	var shown: bool = player.show_target and (tool_name == "hoe" or tool_name == "water")
	var cell := world_to_cell(player.get_target_position())
	var ok := shown and _can_use(tool_name, cell)
	if shown != cursor_shown or cell != cursor_cell or ok != cursor_ok:
		cursor_shown = shown
		cursor_cell = cell
		cursor_ok = ok
		cursor.queue_redraw()


func _draw_cursor() -> void:
	if not cursor_shown:
		return
	var size := Vector2(layer.tile_set.tile_size)
	var rect := Rect2(layer.map_to_local(cursor_cell) - size / 2.0, size)
	var color := Color(0.45, 1.0, 0.45) if cursor_ok else Color(1.0, 0.45, 0.4)
	cursor.draw_rect(rect, Color(color, 0.2))
	cursor.draw_rect(rect, color, false, 1.0)


func _can_use(tool_name: String, cell: Vector2i) -> bool:
	match tool_name:
		"hoe":
			return not soil.has(cell) and _is_solid_path(cell)
		"water":
			var state := get_soil(cell)
			return state == Soil.DRY or state == Soil.SEEDED
	return false


# ---------------------------------------------------------------- player API
func world_to_cell(world_pos: Vector2) -> Vector2i:
	return layer.local_to_map(layer.to_local(world_pos))


func harvest(_cell: Vector2i) -> bool:
	return false                      # crops come later


func use_tool(tool_name: String, cell: Vector2i) -> void:
	match tool_name:
		"hoe":
			if not till(cell) and not soil.has(cell):
				_explain_no_path(cell)
		"water":
			water(cell)


# ---------------------------------------------------------------- rain
## While it rains, every farmland tile is wet, and newly tilled/seeded tiles come out wet too.
## (Soil stays wet after the rain stops until you add a day/night cycle that dries it.)
func set_raining(on: bool) -> void:
	raining = on
	if not on:
		return
	for cell in soil.keys():
		soil[cell] = _wet_version(soil[cell])
		_draw_cell(cell)


func _wet_version(state: int) -> int:
	match state:
		Soil.DRY:
			return Soil.WET
		Soil.SEEDED:
			return Soil.WET_SEEDED
	return state


# ---------------------------------------------------------------- actions
## Turns path ground into dry farmland. Returns true if something changed.
func till(cell: Vector2i) -> bool:
	if soil.has(cell) or not _is_solid_path(cell):
		return false
	set_soil(cell, Soil.DRY)
	return true


## Dry farmland -> wet farmland (seeded -> wet seeded). Returns true if something changed.
func water(cell: Vector2i) -> bool:
	match get_soil(cell):
		Soil.DRY:
			set_soil(cell, Soil.WET)
			return true
		Soil.SEEDED:
			set_soil(cell, Soil.WET_SEEDED)
			return true
	return false


# ---------------------------------------------------------------- soil state
## -1 if the cell is not farmland, otherwise a Soil value.
func get_soil(cell: Vector2i) -> int:
	return soil.get(cell, -1)


## Use this later for planting, e.g. set_soil(cell, Farm.Soil.SEEDED).
func set_soil(cell: Vector2i, state: int) -> void:
	var was_farmland := soil.has(cell)
	soil[cell] = _wet_version(state) if raining else state
	_draw_cell(cell)
	if not was_farmland:              # a brand-new cell also reshapes its neighbours
		for off in NEIGHBOR_OFFSETS:
			if soil.has(cell + off):
				_draw_cell(cell + off)


# ---------------------------------------------------------------- internals
## True only for the all-brown middle path tiles. Edge and corner path tiles contain grass,
## so they can't be hoed.
func _is_solid_path(cell: Vector2i) -> bool:
	var world_pos := layer.to_global(layer.map_to_local(cell))
	for l in _ground_layers():
		var c := l.local_to_map(l.to_local(world_pos))
		if l.get_cell_source_id(c) == PATH_SOURCE_ID and solid_path_tiles.has(l.get_cell_atlas_coords(c)):
			return true
	return false


# Output-panel hint for the most common reason nothing happens.
func _explain_no_path(cell: Vector2i) -> void:
	var names: Array[String] = []
	for l in _ground_layers():
		names.append(str(l.name))
	print("Farm: no solid (all-brown) Path tile at cell %s, so nothing to till. Layers checked: %s. " % [cell, names]
		+ "Edge/corner path tiles have grass and can't be hoed.")


func _ground_layers() -> Array[TileMapLayer]:
	if not path_layers.is_empty():
		return path_layers
	var found: Array[TileMapLayer] = []
	for n in get_parent().get_children():
		if n is TileMapLayer and n != layer and n.tile_set != null:   # skip empty/unset layers
			found.append(n)
	return found


func _draw_cell(cell: Vector2i) -> void:
	var shape: Vector2i = shape_lookup.get(_shape_mask(cell), Vector2i.ZERO)
	var block := int(soil[cell])
	layer.set_cell(cell, FARM_SOURCE_ID, shape + Vector2i(0, block * BLOCK_ROWS))


## Bit i set = neighbour i is farmland. A corner only counts when both sides touching it do too
## (that is how the 47-tile set is drawn).
func _shape_mask(cell: Vector2i) -> int:
	var has: Array[bool] = []
	for off in NEIGHBOR_OFFSETS:
		has.append(soil.has(cell + off))
	var mask := 0
	for i in 8:
		var on := has[i]
		if i % 2 == 1:
			on = on and has[i - 1] and has[(i + 1) % 8]
		if on:
			mask |= 1 << i
	return mask


## Reads the peering bits of the dry block in the tileset, so the tileset stays the source of truth.
func _build_shape_lookup(ts: TileSet) -> void:
	var src := ts.get_source(FARM_SOURCE_ID) as TileSetAtlasSource
	if src == null:
		push_error("Farm: tileset has no atlas source %d" % FARM_SOURCE_ID)
		return
	for y in BLOCK_ROWS:
		for x in ATLAS_COLS:
			var coords := Vector2i(x, y)
			if not src.has_tile(coords):
				continue
			var td := src.get_tile_data(coords, 0)
			var mask := 0
			for i in 8:
				if td.get_terrain_peering_bit(NEIGHBOR_BITS[i]) == FARM_TERRAIN:
					mask |= 1 << i
			shape_lookup[mask] = coords


## Finds the Path tiles that are fully path (no grass, no see-through pixels) by looking at the art,
## so the middle tile and its plain variants work and the grassy edges/corners don't.
func _build_solid_path_tiles(ts: TileSet) -> void:
	var src := ts.get_source(PATH_SOURCE_ID) as TileSetAtlasSource
	if src == null or src.texture == null:
		push_error("Farm: tileset has no Path atlas source %d" % PATH_SOURCE_ID)
		return
	var img := src.texture.get_image()
	for i in src.get_tiles_count():
		var coords := src.get_tile_id(i)
		var rect := src.get_tile_texture_region(coords)
		var solid := true
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				var col := img.get_pixel(x, y)
				if col.a < 1.0 or (col.g > col.r and col.g > col.b):   # see-through or grass-green
					solid = false
					break
			if not solid:
				break
		if solid:
			solid_path_tiles[coords] = true
