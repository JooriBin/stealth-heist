extends CanvasLayer

@onready var gold_label: Label = $GoldLabel

func _ready() -> void:
	var gm := _find_game_manager()
	if gm == null:
		push_warning("HUD: GameManager not found")
		return

	# set initial value
	gold_label.text = "Gold: %d" % gm.coins

	# update when coins change
	gm.coins_changed.connect(_on_coins_changed)

func _on_coins_changed(value: int) -> void:
	gold_label.text = "Gold: %d" % value

func _find_game_manager() -> Node:
	# Option A: if HUD and GameManager share the same parent
	var gm := get_parent().get_node_or_null("GameManager")
	if gm:
		return gm

	# Option B: fallback: search upward
	var n: Node = self
	while n:
		if n.name == "GameManager":
			return n
		n = n.get_parent()
	return null
