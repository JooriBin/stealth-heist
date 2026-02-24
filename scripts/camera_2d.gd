extends Camera2D

@export var map_size: int = 50
@export var tile_size: int = 32

# 新增一个参数，数值越大 -> 镜头越近
@export var zoom_in_factor: float = 1

func _ready():
	var world_size = map_size * tile_size
	var window_size = get_viewport_rect().size
	
	# Center camera
	position = Vector2(world_size / 2, world_size / 3)
	
	# Calculate zoom needed (你原逻辑保留)
	var zoom_x = world_size / (2.0 * window_size.x)
	var zoom_y = world_size / (2.0 * window_size.y)
	
	# Use the larger so entire map fits
	var final_zoom = max(zoom_x, zoom_y)
	
	# zoom 越小越近，所以除以更大的数
	zoom = Vector2(final_zoom, final_zoom) / zoom_in_factor
