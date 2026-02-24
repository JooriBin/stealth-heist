extends Node2D

@export var player_scene: PackedScene

var player: Node2D
var exit_zone: Area2D

func _ready():
	spawn_player_and_exit()

func spawn_player_and_exit():
	var floor_layer = get_node("../FloorLayer")
	var used_cells = floor_layer.get_used_cells()

	if used_cells.is_empty():
		push_error("No floor tiles found in FloorLayer.")
		return

	# Spawn on random floor tile
	var spawn_cell = used_cells.pick_random()
	var spawn_pos = floor_layer.map_to_local(spawn_cell)

	player = player_scene.instantiate()
	add_child(player)
	player.global_position = spawn_pos

	# Exit far from spawn
	var exit_cell = get_far_cell(used_cells, spawn_cell)
	var exit_pos = floor_layer.map_to_local(exit_cell)

	create_exit(exit_pos)

func get_far_cell(cells: Array, origin):
	var best_cell = cells[0]
	var best_distance := -1.0
	for cell in cells:
		var d = origin.distance_to(cell)
		if d > best_distance:
			best_distance = d
			best_cell = cell
	return best_cell

func create_exit(pos: Vector2):
	exit_zone = Area2D.new()
	exit_zone.name = "ExitZone"

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16, 16)
	shape.shape = rect
	exit_zone.add_child(shape)

	exit_zone.global_position = pos
	add_child(exit_zone)

	exit_zone.body_entered.connect(_on_exit_body_entered)

func _on_exit_body_entered(body):
	if body.name == "Player":
		print("ESCAPED")
		get_tree().reload_current_scene()
