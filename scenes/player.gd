extends CharacterBody2D

@export var speed: float = 200.0

func _physics_process(delta):
	var input_direction = Vector2.ZERO

	input_direction.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	input_direction.y = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")

	input_direction = input_direction.normalized()

	velocity = input_direction * speed
	move_and_slide()
