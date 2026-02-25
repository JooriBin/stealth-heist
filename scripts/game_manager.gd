extends Node2D

@export var player_scene: PackedScene
@export var gold_scene: PackedScene
@export var key_scene: PackedScene
@export var gold_count: int = 10
@export var door_scene: PackedScene

signal coins_changed(value: int)
signal key_changed(has_key: bool)

var coins: int = 0
var has_key: bool = false
var player: Node2D
var exit_zone: Area2D


func _ready():
	coins_changed.emit(coins)
	key_changed.emit(has_key)
	spawn_player_and_exit()


# --------------------------------------------------
# SPAWN LOGIC
# --------------------------------------------------
func spawn_door(pos: Vector2) -> void:
	if door_scene == null:
		push_warning("Door scene not assigned!")
		return

	var door = door_scene.instantiate()
	add_child(door)
	door.global_position = pos
	
func spawn_player_and_exit():
	var floor_layer = get_node("../FloorLayer")
	var used_cells = floor_layer.get_used_cells()

	if used_cells.is_empty():
		push_error("No floor tiles found in FloorLayer.")
		return

	# Spawn player
	var spawn_cell = used_cells.pick_random()
	var spawn_pos = floor_layer.map_to_local(spawn_cell)

	player = player_scene.instantiate()
	add_child(player)
	player.global_position = spawn_pos
	
	
	# Spawn exit far away
	var exit_cell = get_far_cell(used_cells, spawn_cell)
	var exit_pos = floor_layer.map_to_local(exit_cell)
	create_exit(exit_pos)

	# Spawn key
	spawn_key(used_cells, spawn_cell)

	# Spawn gold
	spawn_gold(used_cells)
	
	#spawn door
	spawn_door(exit_pos)   # for testing


func get_far_cell(cells: Array, origin):
	var best_cell = cells[0]
	var best_distance := -1.0

	for cell in cells:
		var d = origin.distance_to(cell)
		if d > best_distance:
			best_distance = d
			best_cell = cell

	return best_cell


# --------------------------------------------------
# EXIT
# --------------------------------------------------

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
	if body.is_in_group("player"):
		print("ESCAPED")
		reload_level()


func reload_level():
	reset_level_state()
	get_tree().reload_current_scene()


# --------------------------------------------------
# GOLD & KEY SPAWN
# --------------------------------------------------

func spawn_gold(cells: Array):
	if gold_scene == null:
		push_warning("Gold scene not assigned")
		return

	var floor_layer = get_node("../FloorLayer")
	var tries_per_gold := 50

	for i in range(gold_count):
		var placed := false

		for t in range(tries_per_gold):
			var cell: Vector2i = cells.pick_random()
			if not is_spawn_cell_ok(cell):
				continue

			var tile_size = Vector2(floor_layer.tile_set.tile_size)
			var pos = floor_layer.map_to_local(cell) + tile_size / 2.0

			var g = gold_scene.instantiate()
			add_child(g)
			g.global_position = pos
			placed = true
			break

		if not placed:
			push_warning("Could not place gold #%d after many tries." % i)


func spawn_key(cells: Array, spawn_cell):
	if key_scene == null:
		push_warning("Key scene not assigned")
		return

	var floor_layer = get_node("../FloorLayer")

	# pick a far cell, but ensure it's not a wall
	var key_cell = get_far_cell(cells, spawn_cell)

	# if the far cell is blocked by a wall tile, fall back to random valid
	if not is_spawn_cell_ok(key_cell):
		var tries := 100
		for t in range(tries):
			var c: Vector2i = cells.pick_random()
			if is_spawn_cell_ok(c):
				key_cell = c
				break

	var tile_size = Vector2(floor_layer.tile_set.tile_size)
	var key_pos = floor_layer.map_to_local(key_cell) + tile_size / 2.0

	var k = key_scene.instantiate()
	add_child(k)
	k.global_position = key_pos


# --------------------------------------------------
# STATE MANAGEMENT
# --------------------------------------------------

func add_coins(amount: int) -> void:
	coins = max(0, coins + amount)
	coins_changed.emit(coins)


func set_has_key(v: bool) -> void:
	has_key = v
	key_changed.emit(has_key)


func reset_level_state() -> void:
	coins = 0
	has_key = false
	coins_changed.emit(coins)
	key_changed.emit(has_key)


func go_to_level(scene_path: String) -> void:
	if scene_path == "":
		push_warning("GameManager: empty scene path")
		return

	get_tree().change_scene_to_file(scene_path)

func is_spawn_cell_ok(cell: Vector2i) -> bool:
	var wall_layer := get_node_or_null("../WallLayer")
	if wall_layer:
		if wall_layer.get_cell_source_id(cell) != -1:
			return false
	return true
