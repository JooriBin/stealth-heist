extends CharacterBody2D

enum State { PATROL, CHASE, RETURN }

@export var move_speed: float = 90.0
@export var chase_speed: float = 130.0
@export var detection_radius: float = 140.0
@export var catch_radius: float = 18.0
@export var lose_target_time: float = 1.5
@export var waypoint_reach_distance: float = 6.0

# 角色显示缩放（你前面说想放大 2 倍）
@export var sprite_scale: float = 2.0

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

var state: State = State.PATROL
var player: Node2D = null
var game_manager: Node = null

var patrol_points: Array[Vector2] = []
var patrol_index: int = 0

var return_target: Vector2 = Vector2.ZERO
var last_seen_player_pos: Vector2 = Vector2.ZERO
var lose_timer: float = 0.0

var is_disabled: bool = false

# 记录最后朝向：down / up / left / right
var last_facing: String = "down"

func _ready() -> void:
	add_to_group("guards")
	if anim:
		anim.scale = Vector2(sprite_scale, sprite_scale)
		_play_idle(last_facing)

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
	if is_disabled:
		velocity = Vector2.ZERO
		move_and_slide()
		_update_animation_from_velocity()
		return

	if player == null or not is_instance_valid(player):
		velocity = Vector2.ZERO
		move_and_slide()
		_update_animation_from_velocity()
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
				_patrol_move()

		State.CHASE:
			if can_see_player:
				last_seen_player_pos = player.global_position
				lose_timer = 0.0
				_chase_move()
			else:
				lose_timer += delta
				_chase_move_to_last_seen()
				if lose_timer >= lose_target_time:
					_enter_return()

		State.RETURN:
			if can_see_player:
				_enter_chase()
			else:
				_return_move()

	move_and_slide()
	_update_animation_from_velocity()

func _enter_chase() -> void:
	state = State.CHASE
	last_seen_player_pos = player.global_position
	lose_timer = 0.0
	# print("[Guard] CHASE")

func _enter_return() -> void:
	state = State.RETURN
	return_target = _get_current_patrol_target()
	# print("[Guard] RETURN")

func _patrol_move() -> void:
	var target := _get_current_patrol_target()

	if global_position.distance_to(target) <= waypoint_reach_distance:
		patrol_index = (patrol_index + 1) % patrol_points.size()
		target = _get_current_patrol_target()

	var dir := target - global_position
	velocity = dir.normalized() * move_speed if dir.length() > 0.001 else Vector2.ZERO

func _chase_move() -> void:
	var dir := player.global_position - global_position
	velocity = dir.normalized() * chase_speed if dir.length() > 0.001 else Vector2.ZERO

func _chase_move_to_last_seen() -> void:
	var dir := last_seen_player_pos - global_position
	if dir.length() <= waypoint_reach_distance:
		velocity = Vector2.ZERO
	else:
		velocity = dir.normalized() * chase_speed

func _return_move() -> void:
	var target := return_target
	if global_position.distance_to(target) <= waypoint_reach_distance:
		state = State.PATROL
		velocity = Vector2.ZERO
		# print("[Guard] back to PATROL")
		return

	var dir := target - global_position
	velocity = dir.normalized() * move_speed if dir.length() > 0.001 else Vector2.ZERO

func _get_current_patrol_target() -> Vector2:
	if patrol_points.is_empty():
		return global_position
	return patrol_points[clamp(patrol_index, 0, patrol_points.size() - 1)]

func _on_player_caught() -> void:
	# 防止重复触发
	if is_disabled:
		return
	is_disabled = true
	velocity = Vector2.ZERO

	# 停掉所有守卫，避免多个守卫同时重复调用 player.die()
	for g in get_tree().get_nodes_in_group("guards"):
		if g.has_method("disable_guard"):
			g.call("disable_guard")

	# 触发玩家死亡动画（动画结束后由 player.gd 重启场景）
	if player and is_instance_valid(player) and player.has_method("die"):
		player.call("die")
		return

	# 兜底
	if game_manager and game_manager.has_method("on_player_caught"):
		game_manager.call("on_player_caught")
	else:
		get_tree().reload_current_scene()
		
		
func disable_guard() -> void:
	is_disabled = true
	velocity = Vector2.ZERO
	_play_idle(last_facing)

# =========================
# 动画控制（和 player 同风格）
# =========================
func _update_animation_from_velocity() -> void:
	if anim == null:
		return

	if velocity.length() <= 0.01:
		_play_idle(last_facing)
		return

	var dir := velocity.normalized()

	# 轴优先判定，避免斜向时抖动切换
	if abs(dir.x) > abs(dir.y):
		if dir.x < 0:
			last_facing = "left"
			anim.flip_h = true
		else:
			last_facing = "right"
			anim.flip_h = false

		if anim.animation != "run_right":
			anim.play("run_right")
	else:
		anim.flip_h = false
		if dir.y < 0:
			last_facing = "up"
			if anim.animation != "run_up":
				anim.play("run_up")
		else:
			last_facing = "down"
			if anim.animation != "run_down":
				anim.play("run_down")

func _play_idle(facing: String) -> void:
	if anim == null:
		return

	match facing:
		"up":
			anim.flip_h = false
			if anim.animation != "idle_up":
				anim.play("idle_up")

		"left":
			anim.flip_h = true
			if anim.animation != "idle_right":
				anim.play("idle_right")

		"right":
			anim.flip_h = false
			if anim.animation != "idle_right":
				anim.play("idle_right")

		_:
			anim.flip_h = false
			if anim.animation != "idle_down":
				anim.play("idle_down")

# 可选：如果你以后想让守卫也有死亡动画
func die() -> void:
	is_disabled = true
	velocity = Vector2.ZERO
	if anim:
		anim.flip_h = false
		anim.play("die")
