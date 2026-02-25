extends Polygon2D

@export var radius: float = 100.0
@export var segments: int = 32
@export var fill_color: Color = Color.RED

func _ready() -> void:
	color = fill_color
	var points: PackedVector2Array = []
	for i in range(segments):
		var a = TAU * float(i) / float(segments)
		points.append(Vector2(cos(a), sin(a)) * radius)
	polygon = points
