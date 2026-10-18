extends RefCounted
## World maps for the demo, tests and benchmark (deterministic for a given seed).
## A map is a PackedByteArray of width * height terrain ids (row-major), see wang.gd.

const Wang := preload("res://tiles/wang.gd")


static func filled(width: int, height: int, terrain: int) -> PackedByteArray:
	var m: PackedByteArray = []
	m.resize(width * height)
	m.fill(terrain)
	return m


static func rect(m: PackedByteArray, width: int, r: Rect2i, terrain: int) -> void:
	for y: int in range(r.position.y, r.end.y):
		for x: int in range(r.position.x, r.end.x):
			m[y * width + x] = terrain


## Grass with noise patches of tilled soil and (elsewhere) ash.
static func surface_noise(width: int, height: int, seed_value: int) -> PackedByteArray:
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 0.06
	var m: PackedByteArray = filled(width, height, Wang.GRASS)
	for y: int in height:
		for x: int in width:
			var v: float = noise.get_noise_2d(x, y)
			if v > 0.3:
				m[y * width + x] = Wang.SOIL
			elif v < -0.35:
				m[y * width + x] = Wang.ASH
	return m


## Cave-like dungeon: wall where the noise is high, solid border.
static func dungeon_caves(width: int, height: int, seed_value: int) -> PackedByteArray:
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 0.08
	var m: PackedByteArray = filled(width, height, Wang.FLOOR)
	for y: int in height:
		for x: int in width:
			var border: bool = x == 0 or y == 0 or x == width - 1 or y == height - 1
			if border or noise.get_noise_2d(x, y) > 0.05:
				m[y * width + x] = Wang.WALL
	return m


## The demo field: grass, a tilled plot with a few single hoed cells, and a corruption edge.
static func demo_surface(width: int, height: int) -> PackedByteArray:
	var m: PackedByteArray = filled(width, height, Wang.GRASS)
	rect(m, width, Rect2i(2, 3, 5, 3), Wang.SOIL)
	rect(m, width, Rect2i(2, 7, 2, 2), Wang.SOIL)
	for c: Vector2i in [Vector2i(5, 8), Vector2i(7, 10), Vector2i(3, 11), Vector2i(5, 12), Vector2i(6, 12)]:
		m[c.y * width + c.x] = Wang.SOIL
	# Ragged corruption edge on the right.
	var edge: Array[int] = [11, 11, 10, 10, 11, 12, 12, 11, 10, 10, 11, 12, 13, 12, 12, 11, 11]
	for y: int in height:
		var start: int = edge[y % edge.size()] if width > 12 else width
		for x: int in range(start, width):
			m[y * width + x] = Wang.ASH
	m[9 * width + 9] = Wang.ASH  # an ash speck in the grass
	return m


## The demo dungeon room: walls around a room, a pillar, an alcove and a dug tunnel.
static func demo_dungeon(width: int, height: int) -> PackedByteArray:
	var m: PackedByteArray = filled(width, height, Wang.WALL)
	rect(m, width, Rect2i(2, 3, width - 4, height - 6), Wang.FLOOR)
	rect(m, width, Rect2i(6, 7, 2, 2), Wang.WALL)               # pillar 2x2
	m[6 * width + 10] = Wang.WALL                               # single-cell pillar
	rect(m, width, Rect2i(width - 5, 1, 2, 2), Wang.FLOOR)     # alcove in the top wall
	rect(m, width, Rect2i(0, height - 6, 2, 1), Wang.FLOOR)    # tunnel through the left wall
	return m
