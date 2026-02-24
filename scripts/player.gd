extends CharacterBody2D

@export var speed: float = 200.0

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

var is_dead: bool = false

# 记录“上一次朝向”，用于停止时决定 idle 方向
# 可选值： "down", "up", "right"
var last_facing: String = "down"

func _ready() -> void:
	# 初始播放 idle_down
	_play_idle("down")

func _physics_process(delta: float) -> void:
	if is_dead:
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
	# 没有输入 -> idle（方向取上一次移动方向）
	if input_direction == Vector2.ZERO:
		_play_idle(last_facing)
		return

	# 有输入 -> run
	# 为了避免斜向时频繁抖动，这里优先看“绝对值更大的轴”
	if abs(input_direction.x) > abs(input_direction.y):
		# 左右移动：统一播放 right，用 flip_h 镜像
		last_facing = "right"
		anim.flip_h = input_direction.x < 0
		if anim.animation != "run_right":
			anim.play("run_right")
	else:
		# 上下移动
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
			# idle 左右统一用 idle_right + flip_h
			# 注意：这里是否 flip_h 取决于“最后一次是否向左”
			# 因为 last_facing 只有 right，不知道左右，所以要保留当前 flip_h 状态
			if anim.animation != "idle_right":
				anim.play("idle_right")
		_:
			anim.flip_h = false
			if anim.animation != "idle_down":
				anim.play("idle_down")
				
func die() -> void:
	if is_dead:
		return

	is_dead = true
	velocity = Vector2.ZERO
	anim.flip_h = false
	anim.play("die")
