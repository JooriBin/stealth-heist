extends Area2D

var _taken := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if _taken:
		return
	if not body.is_in_group("player"):
		return

	_taken = true
	monitoring = false

	var gm := _find_game_manager()
	if gm:
		gm.set_has_key(true)

	queue_free()

func _find_game_manager() -> Node:
	var n: Node = self
	while n != null:
		if n.has_method("set_has_key"):
			return n
		n = n.get_parent()
	return null
