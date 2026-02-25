extends Area2D

@export var amount: int = 1
var _taken := false

func _ready() -> void:
	# optional, keep if you use it anywhere
	add_to_group("gold")

	# ensure this Area2D detects bodies
	monitoring = true
	monitorable = true

	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if _taken:
		return
	if not body.is_in_group("player"):
		return

	_taken = true

	# ✅ must be deferred inside physics callback
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)

	var gm := _find_game_manager()
	if gm != null and gm.has_method("add_coins"):
		gm.add_coins(amount)
	else:
		push_warning("Gold: GameManager not found or missing add_coins(amount)")

	# ✅ defer free to avoid physics lock warnings
	call_deferred("queue_free")

func _find_game_manager() -> Node:
	# 1) Best: group lookup (make sure GameManager does add_to_group("game_manager"))
	var gms := get_tree().get_nodes_in_group("game_manager")
	if gms.size() > 0:
		return gms[0]

	# 2) Fallback: node named "GameManager" under current scene
	var root := get_tree().current_scene
	if root:
		var by_name := root.get_node_or_null("GameManager")
		if by_name:
			return by_name

	# 3) Last resort: walk up parents
	var n: Node = self
	while n != null:
		if n.has_method("add_coins"):
			return n
		n = n.get_parent()

	return null
