extends Node2D

@export var guard_scene: PackedScene
@export var guard_count: int = 2

# NodePath（是场景节点路径，不是脚本路径）
@export var floor_layer_path: NodePath
@export var game_manager_path: NodePath
@export var map_generator_path: NodePath

# 生成约束（可在 Inspector 调）
@export var min_distance_from_player_cells: int = 8
@export var patrol_radius_cells: int = 10
@export var patrol_point_count: int = 4

var floor_layer: TileMapLayer
var game_manager: Node
var map_generator: Node
var player: Node2D

func _ready() -> void:
	# 等一两帧，确保 MJMapLoader 已经把地图铺好，GameManager 已经生成 player
	await get_tree().process_frame
	await get_tree().process_frame

	_resolve_refs()

	if guard_scene == null:
		push_error("GuardManager: guard_scene not assigned.")
		return

	if floor_layer == null:
		push_error("GuardManager: FloorLayer not found.")
		return

	if game_manager == null:
		push_error("GuardManager: GameManager not found.")
		return

	player = game_manager.get("player")
	if player == null or not is_instance_valid(player):
		push_error("GuardManager: Player not found (GameManager.player is null).")
		return

	spawn_guards()

func _resolve_refs() -> void:
	# 你的 scene tree 是 world 下同级节点，所以默认 ../xxx 正确
	if floor_layer_path != NodePath():
		floor_layer = get_node_or_null(floor_layer_path) as TileMapLayer
	else:
		floor_layer = get_node_or_null("../FloorLayer") as TileMapLayer

	if game_manager_path != NodePath():
		game_manager = get_node_or_null(game_manager_path)
	else:
		game_manager = get_node_or_null("../GameManager")

	if map_generator_path != NodePath():
		map_generator = get_node_or_null(map_generator_path)
	else:
		map_generator = get_node_or_null("../MapGenerator") # 当前是 MJMapLoader.gd，也没关系

func spawn_guards() -> void:
	var used_cells: Array = floor_layer.get_used_cells()
	if used_cells.is_empty():
		push_error("GuardManager: no floor cells found on FloorLayer.")
		return

	var candidate_cells: Array[Vector2i] = _build_candidate_spawn_cells(used_cells)
	if candidate_cells.is_empty():
		push_error("GuardManager: no candidate spawn cells.")
		return

	var taken_cells: Array[Vector2i] = []

	for i in range(guard_count):
		if candidate_cells.is_empty():
			break

		var spawn_cell := _pick_valid_guard_cell(candidate_cells, taken_cells)
		taken_cells.append(spawn_cell)

		var spawn_pos := floor_layer.to_global(floor_layer.map_to_local(spawn_cell))

		var guard = guard_scene.instantiate()
		add_child(guard)
		guard.global_position = spawn_pos

		var patrol_points := _make_patrol_points_for_cell(spawn_cell, used_cells)

		if guard.has_method("setup_guard"):
			guard.setup_guard(player, game_manager, patrol_points)

		print("Spawned guard at cell:", spawn_cell, " | patrol points:", patrol_points.size())

# -----------------------------
# MJMapLoader 适配：没有 rooms 元数据，所以直接从 FloorLayer 地板取候选
# -----------------------------
func _build_candidate_spawn_cells(used_cells: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []

	for c in used_cells:
		if c is Vector2i:
			result.append(c)

	return result

func _pick_valid_guard_cell(candidates: Array[Vector2i], taken_cells: Array[Vector2i]) -> Vector2i:
	var player_cell := floor_layer.local_to_map(floor_layer.to_local(player.global_position))

	var shuffled := candidates.duplicate()
	shuffled.shuffle()

	for c in shuffled:
		if c in taken_cells:
			continue

		# 不要刷在玩家附近
		if c.distance_to(player_cell) < float(min_distance_from_player_cells):
			continue

		# 不要和其他守卫太近（避免叠在一起）
		var too_close_to_other_guard := false
		for t in taken_cells:
			if c.distance_to(t) < 5.0:
				too_close_to_other_guard = true
				break
		if too_close_to_other_guard:
			continue

		return c

	# 如果筛选太严格，兜底返回第一个
	if not shuffled.is_empty():
		return shuffled[0]

	# 理论上不会走到这里
	return Vector2i.ZERO

func _make_patrol_points_for_cell(origin: Vector2i, used_cells: Array) -> Array[Vector2]:
	var nearby: Array[Vector2i] = []

	# 从 origin 周围一定半径内挑地板格子做巡逻点
	for c in used_cells:
		if c is Vector2i and origin.distance_to(c) <= float(patrol_radius_cells):
			nearby.append(c)

	if nearby.is_empty():
		nearby.append(origin)

	nearby.shuffle()

	var picked_cells: Array[Vector2i] = []
	picked_cells.append(origin)

	for c in nearby:
		if picked_cells.size() >= patrol_point_count:
			break

		# 巡逻点之间保持一点距离，避免抖动
		var too_close := false
		for p in picked_cells:
			if p.distance_to(c) < 3.0:
				too_close = true
				break

		if not too_close:
			picked_cells.append(c)

	# 如果挑不到足够多，就补一些
	var idx := 0
	while picked_cells.size() < patrol_point_count and idx < nearby.size():
		var c2 = nearby[idx]
		if not (c2 in picked_cells):
			picked_cells.append(c2)
		idx += 1

	var patrol_points: Array[Vector2] = []
	for cell in picked_cells:
		var local_pos := floor_layer.map_to_local(cell)
		var world_pos := floor_layer.to_global(local_pos)
		patrol_points.append(world_pos)

	return patrol_points
