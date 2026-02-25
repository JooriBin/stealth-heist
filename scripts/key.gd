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
	if gm != null and gm.has_method("set_has_key"):
		gm.set_has_key(true)
	else:
		print("Key pickup: GameManager not found or missing set_has_key(true).")

	queue_free()

func _find_game_manager() -> Node:
	# 1) Best: group lookup
	var gms := get_tree().get_nodes_in_group("game_manager")
	if gms.size() > 0:
		return gms[0]

	# 2) Fallback: try common names in the scene tree
	var root := get_tree().current_scene
	if root:
		var by_name := root.get_node_or_null("GameManager")
		if by_name:
			return by_name

	# 3) Last resort: old parent-walk (in case your GM is parent)
	var n: Node = self
	while n != null:
		if n.has_method("set_has_key"):
			return n
		n = n.get_parent()

	return null
