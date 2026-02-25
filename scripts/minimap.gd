extends Control

# 引用路径（默认按你的 world 场景结构）
@export var floor_layer_path: NodePath = NodePath("../FloorLayer")
@export var wall_layer_path: NodePath = NodePath("../WallLayer")
@export var game_manager_path: NodePath = NodePath("../GameManager")

# 样式
@export var panel_padding: float = 8.0
@export var show_floor_tiles: bool = true
@export var tile_draw_size: float = 2.0
@export var marker_size: float = 4.0
@export var update_interval: float = 0.08 # 约 12.5 FPS 刷新，够用了

var floor_layer: TileMapLayer
var wall_layer: TileMapLayer
var game_manager: Node

var _bounds_min: Vector2i = Vector2i.ZERO
var _bounds_max: Vector2i = Vector2i.ONE
var _has_bounds: bool = false

var _timer: float = 0.0

func _ready() -> void:
	# 你的 HUD 是 CanvasLayer，Minimap 在 HUD 下，所以 ../FloorLayer 不一定能直达
	# 这里做多种查找方式，尽量稳
	_resolve_refs()
	_compute_map_bounds()
	queue_redraw()

func _process(delta: float) -> void:
	_timer += delta
	if _timer >= update_interval:
		_timer = 0.0
		queue_redraw()

func _resolve_refs() -> void:
	# 先尝试通过 current_scene（world）找
	var root := get_tree().current_scene
	if root:
		floor_layer = root.get_node_or_null("FloorLayer") as TileMapLayer
		wall_layer = root.get_node_or_null("WallLayer") as TileMapLayer
		game_manager = root.get_node_or_null("GameManager")

	# 如果没找到，再尝试导出路径（可手动指定）
	if floor_layer == null and floor_layer_path != NodePath():
		floor_layer = get_node_or_null(floor_layer_path) as TileMapLayer
	if wall_layer == null and wall_layer_path != NodePath():
		wall_layer = get_node_or_null(wall_layer_path) as TileMapLayer
	if game_manager == null and game_manager_path != NodePath():
		game_manager = get_node_or_null(game_manager_path)

func _compute_map_bounds() -> void:
	if floor_layer == null:
		_has_bounds = false
		return

	var used_cells: Array = floor_layer.get_used_cells()
	if used_cells.is_empty():
		_has_bounds = false
		return

	var min_x := 999999
	var min_y := 999999
	var max_x := -999999
	var max_y := -999999

	for c in used_cells:
		if c is Vector2i:
			min_x = min(min_x, c.x)
			min_y = min(min_y, c.y)
			max_x = max(max_x, c.x)
			max_y = max(max_y, c.y)

	_bounds_min = Vector2i(min_x, min_y)
	_bounds_max = Vector2i(max_x, max_y)
	_has_bounds = true

func _draw() -> void:
	# 背景面板
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.65), true)
	draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.6), false, 2.0)

	if floor_layer == null or not _has_bounds:
		return

	var inner_rect := Rect2(
		Vector2(panel_padding, panel_padding),
		size - Vector2(panel_padding * 2.0, panel_padding * 2.0)
	)

	var map_w_cells = max(1, _bounds_max.x - _bounds_min.x + 1)
	var map_h_cells = max(1, _bounds_max.y - _bounds_min.y + 1)

	# 每格在 minimap 上占多大（自动适配）
	var scale_x := inner_rect.size.x / float(map_w_cells)
	var scale_y := inner_rect.size.y / float(map_h_cells)
	var scale = min(scale_x, scale_y)

	# 居中显示地图
	var map_pixel_size := Vector2(float(map_w_cells) * scale, float(map_h_cells) * scale)
	var map_origin := inner_rect.position + (inner_rect.size - map_pixel_size) * 0.5

	# 1) 画地板轮廓（可选）
	if show_floor_tiles:
		var cells: Array = floor_layer.get_used_cells()
		for c in cells:
			if c is Vector2i:
				var p := _cell_to_minimap_pos(c, map_origin, scale)
				var r := Rect2(p, Vector2(max(1.0, scale * tile_draw_size / 2.0), max(1.0, scale * tile_draw_size / 2.0)))
				# 用小方块表示可走区域
				draw_rect(r, Color(0.75, 0.75, 0.75, 0.8), true)

	# 2) 画边框（地图范围）
	draw_rect(Rect2(map_origin, map_pixel_size), Color(1, 1, 1, 0.35), false, 1.0)

	# 3) 画各种标记（优先后画玩家，避免被盖住）
	_draw_markers(map_origin, scale)

func _draw_markers(map_origin: Vector2, scale: float) -> void:
	# 金币（黄色）
	for n in get_tree().get_nodes_in_group("gold"):
		if n is Node2D and is_instance_valid(n):
			_draw_world_marker(n.global_position, map_origin, scale, Color(1.0, 0.85, 0.1, 1.0), marker_size)

	# 钥匙（青色）
	for n in get_tree().get_nodes_in_group("key"):
		if n is Node2D and is_instance_valid(n):
			_draw_world_marker(n.global_position, map_origin, scale, Color(0.2, 1.0, 1.0, 1.0), marker_size + 0.5)

	# 大门（绿色）
	for n in get_tree().get_nodes_in_group("exit_door"):
		if n is Node2D and is_instance_valid(n):
			_draw_world_marker(n.global_position, map_origin, scale, Color(0.2, 1.0, 0.2, 1.0), marker_size + 1.0, true)

	# 怪物（红色）
	for n in get_tree().get_nodes_in_group("guards"):
		if n is Node2D and is_instance_valid(n):
			_draw_world_marker(n.global_position, map_origin, scale, Color(1.0, 0.2, 0.2, 1.0), marker_size)

	# 玩家（蓝色）最后画，保证最显眼
	var player_node := _find_player()
	if player_node:
		_draw_world_marker(player_node.global_position, map_origin, scale, Color(0.2, 0.6, 1.0, 1.0), marker_size + 1.5, true)

func _draw_world_marker(world_pos: Vector2, map_origin: Vector2, scale: float, color: Color, radius: float, outlined: bool = false) -> void:
	if floor_layer == null:
		return

	var local_pos := floor_layer.to_local(world_pos)
	var cell := floor_layer.local_to_map(local_pos)
	var p := _cell_to_minimap_center(cell, map_origin, scale)

	draw_circle(p, max(2.0, radius), color)
	if outlined:
		draw_circle(p, max(2.0, radius + 1.5), Color(1, 1, 1, 0.9), false, 1.0)

func _cell_to_minimap_pos(cell: Vector2i, map_origin: Vector2, scale: float) -> Vector2:
	var x := float(cell.x - _bounds_min.x) * scale
	var y := float(cell.y - _bounds_min.y) * scale
	return map_origin + Vector2(x, y)

func _cell_to_minimap_center(cell: Vector2i, map_origin: Vector2, scale: float) -> Vector2:
	return _cell_to_minimap_pos(cell, map_origin, scale) + Vector2(scale * 0.5, scale * 0.5)

func _find_player() -> Node2D:
	# 1) group lookup（推荐）
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0 and players[0] is Node2D:
		return players[0]

	# 2) GameManager.player
	if game_manager != null:
		var p = game_manager.get("player")
		if p and p is Node2D:
			return p

	return null
