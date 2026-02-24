extends CharacterBody2D

enum State { PATROL, CHASE, RETURN }

@export var move_speed: float = 90.0
@export var chase_speed: float = 130.0
@export var detection_radius: float = 140.0
@export var catch_radius: float = 18.0
@export var lose_target_time: float = 1.5
@export var waypoint_reach_distance: float = 6.0

var state: State = State.PATROL
var player: Node2D = null
var game_manager: Node = null

var patrol_points: Array[Vector2] = []
var patrol_index: int = 0

var return_target: Vector2 = Vector2.ZERO
var last_seen_player_pos: Vector2 = Vector2.ZERO
var lose_timer: float = 0.0

func _ready() -> void:
	add_to_group("guards")

func setup_guard(p_player: Node2D, p_game_manager: Node, p_patrol_points: Array[Vector2]) -> void:
	player = p_player
	game_manager = p_game_manager
	patrol_points = p_patrol_points.duplicate()

	if patrol_points.is_empty():
		patrol_points.append(global_position)

	patrol_index = 0
	return_target = patrol_points[0]
	state = State.PATROL

func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var dist_to_player := global_position.distance_to(player.global_position)
	var can_see_player := dist_to_player <= detection_radius
	var can_catch_player := dist_to_player <= catch_radius

	if can_catch_player:
		_on_player_caught()
		return

	match state:
		State.PATROL:
			if can_see_player:
				_enter_chase()
			else:
				_patrol_move(delta)

		State.CHASE:
			if can_see_player:
				last_seen_player_pos = player.global_position
				lose_timer = 0.0
				_chase_move(delta)
			else:
				lose_timer += delta
				_chase_move_to_last_seen(delta)
				if lose_timer >= lose_target_time:
					_enter_return()

		State.RETURN:
			if can_see_player:
				_enter_chase()
			else:
				_return_move(delta)

	move_and_slide()

func _enter_chase() -> void:
	state = State.CHASE
	last_seen_player_pos = player.global_position
	lose_timer = 0.0
	# print("[Guard] CHASE")

func _enter_return() -> void:
	state = State.RETURN
	return_target = _get_current_patrol_target()
	# print("[Guard] RETURN")

func _patrol_move(delta: float) -> void:
	var target := _get_current_patrol_target()

	if global_position.distance_to(target) <= waypoint_reach_distance:
		patrol_index = (patrol_index + 1) % patrol_points.size()
		target = _get_current_patrol_target()

	velocity = (target - global_position).normalized() * move_speed

func _chase_move(delta: float) -> void:
	var dir := (player.global_position - global_position)
	velocity = dir.normalized() * chase_speed if dir.length() > 0.001 else Vector2.ZERO

func _chase_move_to_last_seen(delta: float) -> void:
	var dir := (last_seen_player_pos - global_position)
	if dir.length() <= waypoint_reach_distance:
		velocity = Vector2.ZERO
	else:
		velocity = dir.normalized() * chase_speed

func _return_move(delta: float) -> void:
	var target := return_target
	if global_position.distance_to(target) <= waypoint_reach_distance:
		state = State.PATROL
		velocity = Vector2.ZERO
		# print("[Guard] back to PATROL")
		return

	var dir := (target - global_position)
	velocity = dir.normalized() * move_speed if dir.length() > 0.001 else Vector2.ZERO

func _get_current_patrol_target() -> Vector2:
	if patrol_points.is_empty():
		return global_position
	return patrol_points[clamp(patrol_index, 0, patrol_points.size() - 1)]

func _on_player_caught() -> void:
	# 优先调用 game_manager 中的处理函数（如果你加了）
	if game_manager and game_manager.has_method("on_player_caught"):
		game_manager.call("on_player_caught")
	else:
		print("PLAYER CAUGHT")
		get_tree().reload_current_scene()
