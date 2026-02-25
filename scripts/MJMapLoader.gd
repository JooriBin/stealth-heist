extends Node

@export var layouts: Array[Texture2D]

@onready var floor_layer: TileMapLayer = $"../FloorLayer"
@onready var wall_layer: TileMapLayer = $"../WallLayer"
@onready var deco_layer: TileMapLayer = $"../DecoLayer" # make sure this exists

# Tile sources
@export var floor_source_id: int = 1
@export var wall_source_id: int = 0
@export var deco_source_id: int = 0 # usually same tileset source as walls

# Variants
@export var floor_variants: Array[Vector2i] = [
	Vector2i(42, 8), Vector2i(41, 8), Vector2i(40, 8), Vector2i(39, 8),
	Vector2i(38, 8), Vector2i(37, 8), Vector2i(40, 6),
]
@export var wall_variants: Array[Vector2i] = [
	Vector2i(21, 22), Vector2i(22, 22), Vector2i(23, 22),
	Vector2i(24, 22), Vector2i(25, 22)
]

# Wall-bottom (trim) tiles: put the atlas coords of the "bottom-of-wall" tiles here
@export var wall_bottom_variants: Array[Vector2i] = [
	# TODO: replace with your sprite sheet coords for wall bottoms
	# Example placeholders:
	Vector2i(51, 30), Vector2i(52, 30), Vector2i(53, 30)
]

# Optional: make floors near walls use a separate set of "edge" floor tiles
@export var use_floor_edges: bool = false
@export var floor_edge_variants: Array[Vector2i] = [
	# TODO: put "edge/darker" floor variants here if you have them
	Vector2i(42, 8)
]

# MJ colors
@export var floor_color: Color = Color(0.37, 0.34, 0.31, 1.0)
@export var wall_color: Color = Color(0.76, 0.76, 0.78, 1.0)
@export var color_tolerance: float = 0.08

# Internal types for neighbor rules
const T_EMPTY := 0
const T_FLOOR := 1
const T_WALL  := 2
var type_grid: Array = []   # [h][w] ints

func _ready():
	if layouts.is_empty():
		push_error("No layouts assigned!")
		return

	var random_layout = layouts[randi() % layouts.size()]
	load_from_image(random_layout.get_image())

func load_from_image(img: Image) -> void:
	floor_layer.clear()
	wall_layer.clear()
	if deco_layer:
		deco_layer.clear()

	var w := img.get_width()
	var h := img.get_height()

	# 1) Build type grid from image colors
	type_grid = []
	type_grid.resize(h)
	for y in range(h):
		type_grid[y] = []
		type_grid[y].resize(w)
		for x in range(w):
			var c := img.get_pixel(x, y)
			if is_similar_rgb(c, floor_color, color_tolerance):
				type_grid[y][x] = T_FLOOR
			elif is_similar_rgb(c, wall_color, color_tolerance):
				type_grid[y][x] = T_WALL
			else:
				type_grid[y][x] = T_EMPTY

	# 2) Pass 1: place base floor/wall tiles with variation
	for y in range(h):
		for x in range(w):
			var cell := Vector2i(x, y)
			match type_grid[y][x]:
				T_FLOOR:
					var atlas := _pick(floor_variants)
					if use_floor_edges and _floor_is_near_wall(x, y, w, h):
						atlas = _pick(floor_edge_variants)
					floor_layer.set_cell(cell, floor_source_id, atlas)
				T_WALL:
					wall_layer.set_cell(cell, wall_source_id, _pick(wall_variants))

	# 3) Pass 2: wall-bottom trim wherever WALL has FLOOR directly below
	if deco_layer and not wall_bottom_variants.is_empty():
		for y in range(h - 1):
			for x in range(w):
				if type_grid[y][x] == T_WALL and type_grid[y + 1][x] == T_FLOOR:
					deco_layer.set_cell(Vector2i(x, y), deco_source_id, _pick(wall_bottom_variants))

func _floor_is_near_wall(x: int, y: int, w: int, h: int) -> bool:
	# 4-neighborhood check (N/E/S/W)
	# If any neighbor is wall, this floor is an "edge floor"
	var dirs = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	for d in dirs:
		var nx = x + d.x
		var ny = y + d.y
		if nx < 0 or nx >= w or ny < 0 or ny >= h:
			continue
		if type_grid[ny][nx] == T_WALL:
			return true
	return false

func _pick(arr: Array[Vector2i]) -> Vector2i:
	return arr[randi() % arr.size()]

func is_similar_rgb(a: Color, b: Color, tol: float) -> bool:
	return abs(a.r - b.r) <= tol and abs(a.g - b.g) <= tol and abs(a.b - b.b) <= tol
