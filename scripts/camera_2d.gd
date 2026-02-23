
extends Camera2D

@export var map_size: int = 50
@export var tile_size: int = 32


func _ready():
	var world_size = map_size * tile_size
	var window_size = get_viewport_rect().size
	
	# Center camera
	position = Vector2(world_size / 2, world_size / 3)
	
	# Calculate zoom needed
	var zoom_x = (world_size / window_size.x)
	var zoom_y = (world_size / window_size.y)
	
	# Use the larger so entire map fits
	var final_zoom = max(zoom_x, zoom_y)
	zoom = Vector2(final_zoom, final_zoom)/4
