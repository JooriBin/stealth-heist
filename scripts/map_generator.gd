extends Node

# ----------------------------
# Multi-room + corridors + room metadata + DIFFERENT corridor floor tile
# (No Markov Junior yet)
# ----------------------------

@export var map_w: int = 60
@export var map_h: int = 40

@export var room_count: int = 8
@export var room_min_size: int = 6
@export var room_max_size: int = 12

@export var spacing_padding: int = 1 # spacing so rooms don't touch

# --- ROOM FLOOR TILE (inside rooms) ---
@export var room_floor_source_id: int = 1
@export var room_floor_atlas: Vector2i = Vector2i(37, 7)  # your red floor

# --- CORRIDOR FLOOR TILE (hallways) ---
@export var corridor_floor_source_id: int = 1
@export var corridor_floor_atlas: Vector2i = Vector2i(37, 7) # CHANGE to your corridor floor tile coords

# --- WALL TILE ---
@export var wall_source_id: int = 0
@export var wall_atlas: Vector2i = Vector2i(24, 22) # your wall tile (change if needed)

@onready var floor_layer: TileMapLayer = $"../FloorLayer"
@onready var wall_layer: TileMapLayer = $"../WallLayer"

const WALL := 0
const ROOM_FLOOR := 1
const CORRIDOR_FLOOR := 2

# Useful for teammates later
var spawn_cell: Vector2i = Vector2i.ZERO
var exit_cell: Vector2i = Vector2i.ZERO
var vault_cell: Vector2i = Vector2i.ZERO
var security_cell: Vector2i = Vector2i.ZERO

# Rooms are dictionaries:
# { "rect": Rect2i, "center": Vector2i, "type": String }
var rooms: Array = []

func _ready() -> void:
	randomize()
	generate_rooms_map()

func generate_rooms_map() -> void:
	floor_layer.clear()
	wall_layer.clear()
	rooms.clear()

	# grid[y][x] = WALL / ROOM_FLOOR / CORRIDOR_FLOOR
	var grid: Array = []
	for y in range(map_h):
		var row: Array = []
		row.resize(map_w)
		for x in range(map_w):
			row[x] = WALL
		grid.append(row)

	# 1) Place rooms (non-overlapping)
	var tries := 0
	while rooms.size() < room_count and tries < room_count * 50:
		tries += 1

		var w := randi_range(room_min_size, room_max_size)
		var h := randi_range(room_min_size, room_max_size)
		var x := randi_range(1, map_w - w - 2)
		var y := randi_range(1, map_h - h - 2)

		var rect := Rect2i(x, y, w, h)

		var overlaps := false
		for r in rooms:
			var other: Rect2i = r["rect"]
			var inflated := other
			inflated.position -= Vector2i(spacing_padding, spacing_padding)
			inflated.size += Vector2i(spacing_padding * 2, spacing_padding * 2)
			if inflated.intersects(rect):
				overlaps = true
				break

		if overlaps:
			continue

		var center := rect.position + (rect.size / 2)
		var room := {
			"rect": rect,
			"center": center,
			"type": "office"
		}
		rooms.append(room)

		# carve ROOM floors
		for yy in range(rect.position.y, rect.position.y + rect.size.y):
			for xx in range(rect.position.x, rect.position.x + rect.size.x):
				grid[yy][xx] = ROOM_FLOOR

	# If we failed to place any rooms, bail safely
	if rooms.size() == 0:
		push_warning("No rooms placed. Try increasing map size or lowering room_count/room sizes.")
		return

	# 2) Connect rooms with corridors (simple chain)
	for i in range(1, rooms.size()):
		var a_center: Vector2i = rooms[i - 1]["center"]
		var b_center: Vector2i = rooms[i]["center"]
		carve_corridor(grid, a_center, b_center)
	print("Connected corridors between rooms:", max(0, rooms.size() - 1))

	# 3) Assign types + key cells (spawn/vault/security)
	assign_room_types_and_key_cells()

	# 4) Render floors (rooms vs corridors)
	for y in range(map_h):
		for x in range(map_w):
			var v: int = grid[y][x]
			if v == ROOM_FLOOR:
				floor_layer.set_cell(Vector2i(x, y), room_floor_source_id, room_floor_atlas)
			elif v == CORRIDOR_FLOOR:
				floor_layer.set_cell(Vector2i(x, y), corridor_floor_source_id, corridor_floor_atlas)

	# 5) Place walls around any walkable floors
	for y in range(1, map_h - 1):
		for x in range(1, map_w - 1):
			if grid[y][x] == WALL and has_walkable_neighbor(grid, x, y):
				wall_layer.set_cell(Vector2i(x, y), wall_source_id, wall_atlas)

	print("Rooms placed:", rooms.size())
	# Optional debug
	# debug_print_rooms()

func assign_room_types_and_key_cells() -> void:
	# Spawn = first room center
	spawn_cell = rooms[0]["center"]
	exit_cell = spawn_cell

	# Vault = farthest from spawn
	var best_d := -1.0
	var vault_index := 0
	for i in range(rooms.size()):
		var d := spawn_cell.distance_to(rooms[i]["center"])
		if d > best_d:
			best_d = d
			vault_index = i

	rooms[vault_index]["type"] = "vault"
	vault_cell = rooms[vault_index]["center"]

	# Security = farthest from vault (but not vault)
	best_d = -1.0
	var security_index := 0
	for i in range(rooms.size()):
		if i == vault_index:
			continue
		var d := vault_cell.distance_to(rooms[i]["center"])
		if d > best_d:
			best_d = d
			security_index = i

	rooms[security_index]["type"] = "security"
	security_cell = rooms[security_index]["center"]

	# Optional: some storage rooms
	for i in range(rooms.size()):
		if rooms[i]["type"] == "office" and (i % 3 == 0):
			rooms[i]["type"] = "storage"

func carve_corridor(grid: Array, a: Vector2i, b: Vector2i) -> void:
	var x := a.x
	var y := a.y

	# Horizontal then vertical (L-shaped)
	while x != b.x:
		grid[y][x] = CORRIDOR_FLOOR
		x += 1 if b.x > x else -1

	while y != b.y:
		grid[y][x] = CORRIDOR_FLOOR
		y += 1 if b.y > y else -1

	grid[y][x] = CORRIDOR_FLOOR

func is_walkable(v: int) -> bool:
	return v == ROOM_FLOOR or v == CORRIDOR_FLOOR

func has_walkable_neighbor(grid: Array, x: int, y: int) -> bool:
	return is_walkable(grid[y][x - 1]) or is_walkable(grid[y][x + 1]) or is_walkable(grid[y - 1][x]) or is_walkable(grid[y - 1][x]) or is_walkable(grid[y + 1][x])

func debug_print_rooms() -> void:
	print("Spawn:", spawn_cell, " Exit:", exit_cell, " Vault:", vault_cell, " Security:", security_cell)
	for r in rooms:
		print(r["type"], " center=", r["center"], " rect=", r["rect"])
