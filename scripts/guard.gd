extends CharacterBody2D

@export var move_speed: float = 55.0
@export var detection_radius: float = 110.0
@export var attack_range: float = 18.0
@export var attack_cooldown: float = 1.0
@export var damage: int = 1
@export var max_hp: int = 2
var hp: int

enum State { PATROL, CHASE, ATTACK, HURT, DEAD }
var state: State = State.PATROL

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

var player: Node2D = null
var game_manager: Node = null
var patrol_points: Array[Vector2] = []
var patrol_index: int = 0

var attack_cd_timer: float = 0.0

func setup_guard(p_player: Node2D, p_game_manager: Node, p_patrol_points: Array) -> void:
	player = p_player
	game_manager = p_game_manager
	patrol_points = p_patrol_points
	patrol_index = 0

func _ready() -> void:
	hp = max_hp
	anim.play("idle")

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	attack_cd_timer = max(0.0, attack_cd_timer - delta)

	# 🔴 VERY IMPORTANT
	# While attacking or hurt, do not change animation or move
	if state == State.ATTACK or state == State.HURT:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	_update_state()

	# If state changed to ATTACK inside _update_state(), stop here
	if state == State.ATTACK:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	match state:
		State.PATROL:
			_do_patrol()
		State.CHASE:
			_do_chase()

	_set_facing_from_velocity()
	_play_if_not("idle")
	move_and_slide()

func _update_state() -> void:
	if player == null or not is_instance_valid(player):
		state = State.PATROL
		return

	var dist := global_position.distance_to(player.global_position)

	# Attack when close (cooldown gated)
	if dist <= attack_range and attack_cd_timer <= 0.0:
		_start_attack()
		return

	# Chase if within detection radius
	if dist <= detection_radius:
		state = State.CHASE
	else:
		state = State.PATROL

func _do_patrol() -> void:
	if patrol_points.is_empty():
		velocity = Vector2.ZERO
		return

	var target := patrol_points[patrol_index]
	var to_target := target - global_position

	if to_target.length() < 8.0:
		patrol_index = (patrol_index + 1) % patrol_points.size()
		target = patrol_points[patrol_index]
		to_target = target - global_position

	velocity = to_target.normalized() * move_speed * 0.6

func _do_chase() -> void:
	if player == null:
		velocity = Vector2.ZERO
		return
	var dir := (player.global_position - global_position).normalized()
	velocity = dir * move_speed

func _start_attack() -> void:
	if player == null:
		return

	state = State.ATTACK
	velocity = Vector2.ZERO
	attack_cd_timer = attack_cooldown

	# Face player (right-facing sprites only)
	anim.flip_h = (player.global_position.x < global_position.x)

	anim.play("attack1")

	# Deal damage once per attack (range-based)
	if player.has_method("take_damage"):
		player.take_damage(damage)

func take_damage(amount: int) -> void:
	if state == State.DEAD:
		return

	hp -= amount
	print("Guard HP:", hp)

	if hp <= 0:
		state = State.DEAD
		velocity = Vector2.ZERO

		# play die if you have it, otherwise delete instantly
		if anim.sprite_frames and anim.sprite_frames.has_animation("die"):
			anim.play("die")
		else:
			queue_free()
		return

	# optional hurt anim if you have it
	if anim.sprite_frames and anim.sprite_frames.has_animation("hurt"):
		state = State.HURT
		anim.play("hurt")

func _set_facing_from_velocity() -> void:
	if velocity.x < -0.1:
		anim.flip_h = true
	elif velocity.x > 0.1:
		anim.flip_h = false

func _play_if_not(name: String) -> void:
	if anim.animation != name:
		anim.play(name)

# IMPORTANT: Connect AnimatedSprite2D -> animation_finished to this
func _on_animated_sprite_2d_animation_finished() -> void:
	if anim.animation == "attack1":
		state = State.CHASE
	elif anim.animation == "hurt":
		state = State.CHASE
	elif anim.animation == "die":
		queue_free()
