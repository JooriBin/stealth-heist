extends Node2D

@export var player_scene: PackedScene
@export var gold_scene: PackedScene
@export var key_scene: PackedScene
@export var door_scene: PackedScene
@export var gold_count: int = 10

# Scene-tree node paths (edit in Inspector if names differ)
@export var floor_layer_path: NodePath = NodePath("../FloorLayer")
@export var wall_layer_path: NodePath = NodePath("../WallLayer")
@export var deco_layer_path: NodePath = NodePath("../DecoLayer")

signal coins_changed(value: int)
signal key_changed(has_key: bool)

var coins: int = 0
var has_key: bool = false
var player: Node2D
var exit_zone: Area2D

func _ready() -> void:
	add_to_group("game_manager")
	coins_changed.emit(coins)
	key_changed.emit(has_key)
	spawn_player_and_exit()

# --------------------------------------------------
# LAYER HELPERS
# --------------------------------------------------
func _floor_layer() -> TileMapLayer:
	return get_node(floor_layer_path) as TileMapLayer

func _wall_layer() -> TileMapLayer:
	return get_node_or_null(wall_layer_path) as TileMapLayer

func _deco_layer() -> TileMapLayer:
	return get_node_or_null(deco_layer_path) as TileMapLayer

func _cell_to_world(cell: Vector2i) -> Vector2:
	# always return CENTER of tile in world space
	var fl := _floor_layer()
	var ts: Vector2 = Vector2(fl.tile_set.tile_size)
	return fl.to_global(fl.map_to_local(cell) + ts * 0.5)

func _build_blocked_cells() -> Dictionary:
	# fast set: blocked[cell] = true
	var blocked := {}

	var wl := _wall_layer()
	if wl:
		for c in wl.get_used_cells():
			blocked[c] = true

	var dl := _deco_layer()
	if dl:
		for c in dl.get_used_cells():
			blocked[c] = true

	return blocked

func _build_valid_floor_cells(used_floor_cells: Array, blocked: Dictionary) -> Array[Vector2i]:
	var valid: Array[Vector2i] = []
	var fl := _floor_layer()

	for c in used_floor_cells:
		if not (c is Vector2i):
			continue

		# must be an actual floor tile
		if fl.get_cell_source_id(c) == -1:
			continue

		# must not be blocked by wall/deco tiles
		if blocked.has(c):
			continue

		valid.append(c)

	return valid

# --------------------------------------------------
# SPAWN LOGIC
# --------------------------------------------------
func spawn_player_and_exit() -> void:
	var fl := _floor_layer()
	var used_cells: Array = fl.get_used_cells()

	if used_cells.is_empty():
		push_error("No floor tiles found in FloorLayer.")
		return

	var blocked := _build_blocked_cells()
	var valid_cells := _build_valid_floor_cells(used_cells, blocked)

	if valid_cells.is_empty():
		push_error("No valid floor cells (all blocked by WallLayer/DecoLayer).")
		return

	# Spawn player
	var spawn_cell: Vector2i = valid_cells.pick_random()
	var spawn_pos: Vector2 = _cell_to_world(spawn_cell)

	player = player_scene.instantiate()
	add_child(player)
	player.global_position = spawn_pos

	# Spawn exit far away
	var exit_cell: Vector2i = get_far_cell(valid_cells, spawn_cell)
	var exit_pos: Vector2 = _cell_to_world(exit_cell)
	create_exit(exit_pos)

	# Spawn ONE key near player (not on player)
	spawn_single_key_near_player(valid_cells, blocked)

	# Spawn gold (valid + collision-safe)
	spawn_gold(valid_cells, spawn_cell, exit_cell)

	# Spawn door at exit (testing)
	spawn_door(exit_pos)

func spawn_door(pos: Vector2) -> void:
	if door_scene == null:
		push_warning("Door scene not assigned!")
		return
	var door = door_scene.instantiate()
	add_child(door)
	door.global_position = pos

func get_far_cell(cells: Array[Vector2i], origin: Vector2i) -> Vector2i:
	var best_cell: Vector2i = cells[0]
	var best_distance := -1.0

	for cell in cells:
		var d = origin.distance_to(cell)
		if d > best_distance:
			best_distance = d
			best_cell = cell

	return best_cell

func spawn_single_key_near_player(valid_cells: Array[Vector2i], blocked: Dictionary) -> void:
	if key_scene == null:
		push_warning("Key scene not assigned")
		return
	if player == null or not is_instance_valid(player):
		push_warning("Player not found, cannot spawn key near player.")
		return

	var fl := _floor_layer()
	var player_cell: Vector2i = fl.local_to_map(fl.to_local(player.global_position))

	var offsets: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
	]
	offsets.shuffle()

	var chosen_cell := Vector2i.ZERO
	var found := false

	for off in offsets:
		var c := player_cell + off

		# must not be blocked by wall/deco
		if blocked.has(c):
			continue

		# must be a floor tile
		if fl.get_cell_source_id(c) == -1:
			continue

		# optional safety: collision check (prevents weird placements)
		if not _is_point_free(_cell_to_world(c), 6.0):
			continue

		chosen_cell = c
		found = true
		break

	# fallback: random valid cell (not on player)
	if not found:
		var tries := 400
		for i in range(tries):
			var c2: Vector2i = valid_cells.pick_random()
			if c2 == player_cell:
				continue
			if not _is_point_free(_cell_to_world(c2), 6.0):
				continue
			chosen_cell = c2
			found = true
			break

	if not found:
		push_warning("Could not find a spot for key.")
		return

	var key_pos := _cell_to_world(chosen_cell)
	var k = key_scene.instantiate()
	add_child(k)
	k.global_position = key_pos

	print("Key spawned at cell:", chosen_cell, " pos:", key_pos)

func spawn_gold(valid_cells: Array[Vector2i], player_cell: Vector2i, exit_cell: Vector2i) -> void:
	if gold_scene == null:
		push_warning("Gold scene not assigned")
		return

	if valid_cells.is_empty():
		push_error("No valid cells for gold spawn.")
		return

	var tries_per_gold := 250

	for i in range(gold_count):
		var placed := false

		for t in range(tries_per_gold):
			var cell: Vector2i = valid_cells.pick_random()

			# avoid player and exit cells
			if cell == player_cell:
				continue
			if cell == exit_cell:
				continue

			var pos := _cell_to_world(cell)

			# ✅ collision-based validation (prevents walls/deco with collision)
			if not _is_point_free(pos, 6.0):
				continue

			var g = gold_scene.instantiate()
			add_child(g)
			g.global_position = pos
			placed = true
			break

		if not placed:
			push_warning("Could not place gold #%d (no free spot found)." % i)

# --------------------------------------------------
# EXIT
# --------------------------------------------------
func create_exit(pos: Vector2) -> void:
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

func _on_exit_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		print("ESCAPED")
		reload_level()

func reload_level() -> void:
	reset_level_state()
	get_tree().reload_current_scene()

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

# --------------------------------------------------
# COLLISION CHECK (spawn safety)
# --------------------------------------------------
func _is_point_free(world_pos: Vector2, radius: float = 6.0) -> bool:
	var space := get_world_2d().direct_space_state
	var params := PhysicsShapeQueryParameters2D.new()

	var shape := CircleShape2D.new()
	shape.radius = radius
	params.shape = shape
	params.transform = Transform2D(0.0, world_pos)

	# Don't count the player collider as "blocked"
	if player != null and is_instance_valid(player):
		params.exclude = [player.get_rid()]

	# if any collision hit -> not free
	return space.intersect_shape(params, 1).is_empty()
