extends StaticBody2D

@export var message_duration: float = 1.2

@onready var body_col: CollisionShape2D = $CollisionShape2D
@onready var trigger: Area2D = $Trigger
@onready var msg: Label = $MessageLabel  # Add a Label node for message

var _busy := false

func _ready() -> void:
	add_to_group("exit_door")  # ← 新增
	trigger.body_entered.connect(_on_trigger_body_entered)
	if msg:
		msg.visible = false


func _on_trigger_body_entered(body: Node) -> void:
	if _busy:
		return
	if not body.is_in_group("player"):
		return

	var gm := _find_game_manager()
	if gm == null:
		push_warning("ExitDoor: GameManager not found")
		return

	# If player does NOT have key
	if not gm.has_key:
		_show_message()
		return

	# Player HAS key → open door
	_busy = true

	# Disable collisions
	if body_col:
		body_col.disabled = true

	trigger.monitoring = false

	# Hide door visually
	$Sprite2D.visible = false

	# Optional: remove it completely
	queue_free()

	# If you want to reload level when opened:
	# gm.reload_level()


func _show_message() -> void:
	if msg == null:
		return

	msg.visible = true
	await get_tree().create_timer(message_duration).timeout
	if is_instance_valid(msg):
		msg.visible = false


func _find_game_manager() -> Node:
	var n: Node = self
	while n != null:
		if n.has_method("add_coins") and n.has_method("set_has_key"):
			return n
		n = n.get_parent()
	return null
