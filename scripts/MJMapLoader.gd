extends Node

@export var layouts: Array[Texture2D]

@onready var floor_layer: TileMapLayer = $"../FloorLayer"
@onready var wall_layer: TileMapLayer = $"../WallLayer"


@export var floor_source_id: int = 1
@export var floor_atlas: Vector2i = Vector2i(42, 8)

@export var wall_source_id: int = 0
@export var wall_atlas: Vector2i = Vector2i(24, 22)


# We'll match colors approximately (tolerance-based)
# Your MJ output looks like: orange = floor, light gray = wall, brown = empty/background
@export var floor_color: Color = Color(0.37, 0.34, 0.31, 1.0)
@export var wall_color: Color = Color(0.76, 0.76, 0.78, 1.0)
@export var color_tolerance: float = 0.08

func _ready():
	if layouts.is_empty():
		push_error("No layouts assigned!")
		return
	
	var random_layout = layouts[randi() % layouts.size()]
	load_from_image(random_layout.get_image())

func load_from_image(img: Image) -> void:
	floor_layer.clear()
	wall_layer.clear()

	var w := img.get_width()
	var h := img.get_height()

	for y in range(h):
		for x in range(w):
			var c: Color = img.get_pixel(x, y)
			var cell := Vector2i(x, y)

			if is_similar_rgb(c, floor_color, color_tolerance):
				floor_layer.set_cell(cell, floor_source_id, floor_atlas)
			elif is_similar_rgb(c, wall_color, color_tolerance):
				wall_layer.set_cell(cell, wall_source_id, wall_atlas)

func is_similar_rgb(a: Color, b: Color, tol: float) -> bool:
	return abs(a.r - b.r) <= tol and abs(a.g - b.g) <= tol and abs(a.b - b.b) <= tol
