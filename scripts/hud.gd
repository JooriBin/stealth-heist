extends CanvasLayer

@onready var gold_label: Label = $GoldLabel

func _ready() -> void:
	var gm := _find_game_manager()
	if gm == null:
		push_warning("HUD: GameManager not found")
	else:
		gold_label.text = "%d" % gm.coins
		gm.coins_changed.connect(_on_coins_changed)

	# 动态创建小地图（可选）
	if get_node_or_null("Minimap") == null:
		var mm := Control.new()
		mm.name = "Minimap"
		mm.set_script(load("res://scripts/minimap.gd"))
		add_child(mm)

		# 右上角 200x200
		mm.anchor_left = 1.0
		mm.anchor_top = 0.0
		mm.anchor_right = 1.0
		mm.anchor_bottom = 0.0
		mm.offset_left = -220
		mm.offset_top = 20
		mm.offset_right = -20
		mm.offset_bottom = 220
	# set initial value
	gold_label.text = "%d" % gm.coins

	# update when coins change
	gm.coins_changed.connect(_on_coins_changed)

func _on_coins_changed(value: int) -> void:
	gold_label.text = "%d" % value

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
