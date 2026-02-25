extends Area2D

@export var amount: int = 1
var _taken := false

func _ready() -> void:
	# Make sure the Area2D actually detects bodies
	add_to_group("gold")   # ← 新增
	monitoring = true
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if _taken:
		return
	if not body.is_in_group("player"):
		return

	_taken = true
	monitoring = false

	# Find GameManager (walk up)
	var gm := _find_manager()
	if gm:
		gm.call("add_coins", amount)
	else:
		push_warning("Gold: GameManager not found")

	queue_free()

func _find_manager() -> Node:
	var n: Node = self
	while n:
		if n.has_method("add_coins"):
			return n
		n = n.get_parent()
	return null
