extends CharacterBody2D

@export var speed: float = 200.0
@export var max_hp: int = 3
@export var invincible_time: float = 0.7
@export var attack_damage: int = 1
@export var attack_reach: float = 24.0

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

var hp: int
var is_dead: bool = false
var is_attacking: bool = false
var invincible_timer: float = 0.0

# last direction: "down", "up", "right"
var last_facing: String = "down"
# remember if last horizontal facing was left
var last_left: bool = false

func _ready() -> void:
	add_to_group("player")
	hp = max_hp
	_play_idle("down")

func _input(event: InputEvent) -> void:
	if is_dead:
		return

	# Attack button: Project Settings -> Input Map -> add action "attack" (bind Space)
	if event.is_action_pressed("attack") and not is_attacking:
		is_attacking = true
		velocity = Vector2.ZERO

		match last_facing:
			"up":
				anim.flip_h = false
				anim.play("attack_up")
			"right":
				anim.flip_h = last_left
				anim.play("attack_right")
			_:
				anim.flip_h = false
				anim.play("attack_down")
		_do_attack_hit() # ✅ ADD THIS

func _physics_process(delta: float) -> void:
	# invincibility blink
	if invincible_timer > 0.0:
		invincible_timer -= delta
		anim.visible = int(invincible_timer * 10.0) % 2 == 0
	else:
		anim.visible = true

	if is_dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# While attacking, don't move and don't override attack animation
	if is_attacking:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var input_direction := Vector2.ZERO
	input_direction.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	input_direction.y = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	input_direction = input_direction.normalized()

	velocity = input_direction * speed
	move_and_slide()

	_update_animation(input_direction)

func _update_animation(input_direction: Vector2) -> void:
	# No input -> idle
	if input_direction == Vector2.ZERO:
		_play_idle(last_facing)
		return

	# Move -> run (prefer dominant axis)
	if abs(input_direction.x) > abs(input_direction.y):
		last_facing = "right"
		last_left = input_direction.x < 0
		anim.flip_h = last_left
		if anim.animation != "run_right":
			anim.play("run_right")
	else:
		anim.flip_h = false
		if input_direction.y < 0:
			last_facing = "up"
			if anim.animation != "run_up":
				anim.play("run_up")
		else:
			last_facing = "down"
			if anim.animation != "run_down":
				anim.play("run_down")

func _play_idle(facing: String) -> void:
	match facing:
		"up":
			anim.flip_h = false
			if anim.animation != "idle_up":
				anim.play("idle_up")
		"right":
			anim.flip_h = last_left
			if anim.animation != "idle_right":
				anim.play("idle_right")
		_:
			anim.flip_h = false
			if anim.animation != "idle_down":
				anim.play("idle_down")

func take_damage(amount: int) -> bool:
	if is_dead:
		return false
	if invincible_timer > 0.0:
		return false

	hp -= amount
	invincible_timer = invincible_time

	if hp <= 0:
		die()

	return true

func die() -> void:
	if is_dead:
		return

	is_dead = true
	is_attacking = false
	velocity = Vector2.ZERO
	anim.visible = true
	anim.flip_h = false
	anim.play("die")

func _do_attack_hit() -> void:
	# Hit all guards within range (simple melee)
	for g in get_tree().get_nodes_in_group("guards"):
		if not is_instance_valid(g):
			continue
		if global_position.distance_to(g.global_position) <= attack_reach:
			if g.has_method("take_damage"):
				g.take_damage(attack_damage)

# IMPORTANT: connect AnimatedSprite2D -> animation_finished to this function
func _on_animated_sprite_2d_animation_finished() -> void:
	# Attack ended
	if anim.animation.begins_with("attack"):
		is_attacking = false
		_play_idle(last_facing)

	# Death ended -> restart
	if anim.animation == "die":
		get_tree().reload_current_scene()
