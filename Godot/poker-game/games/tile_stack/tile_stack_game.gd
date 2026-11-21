class_name TileStackGame
extends RefCounted
## "疊牌消消": a stacked tile-matching puzzle. Tiles lie in overlapping layers;
## a tile can be picked only when no tile above it overlaps it. Picked tiles go
## into a 7-slot tray; three of the same kind there disappear. Clear the board
## to win; a full tray with no match loses. No UI: the table scene drives it
## through pick() and resolve().
##
## Levels are generated from the level number. Every level is solvable: tile
## kinds are dealt in triples along an order in which the tiles can actually be
## uncovered, so following that order never puts more than six tiles in the tray.

enum State { BOARD, TRAY, GONE }

const TRAY_SIZE := 7
const MATCH := 3


class Tile:
	var id := 0
	var kind := 0
	var x := 0.0  # position in tile units (1.0 = one tile width / height)
	var y := 0.0
	var z := 0  # layer; higher covers lower
	var in_pile := false  # one of the side piles
	var state := State.BOARD
	var above: Array = []  # tiles in higher layers that overlap this one


var level := 1
var kind_count := 4
var tiles: Array[Tile] = []
var tray: Array[Tile] = []
var undo_left := 1
var shuffle_left := 1
var cover_shade := 0.5  # how dark covered tiles are drawn (UI hint; closer to 1 is harder)
var solution: Array[int] = []  # tile ids in an order that clears the level (from the deal)
var _history: Array = []  # snapshots for undo


## How a level looks. Later levels: more kinds, more layers, finer offsets
## between layers (so it is harder to see what covers what), side piles.
static func level_params(p_level: int, available_kinds: int) -> Dictionary:
	var l := maxi(p_level, 1)
	var step := 1.0
	if l >= 6:
		step = 0.25
	elif l >= 3:
		step = 0.5
	return {
		"triples": mini(6 + 3 * (l - 1), 42),
		"kinds": clampi(3 + l, 4, available_kinds),
		"layers": mini(1 + l, 9),
		"step": step,  # layers are shifted by multiples of this many tiles
		"jitter": l >= 8,  # rows within a layer drift slightly
		"piles": 0 if l < 4 else mini(3 + l, 14),  # tiles in each of the two side piles
		"window": 3 if l <= 2 else 6,  # how far triples are interleaved in the deal
		"cover_shade": lerpf(0.45, 0.8, clampf((l - 1) / 11.0, 0.0, 1.0)),
		"cols": 7,
		"rows": 6,
	}


func start(p_level: int, available_kinds: int, rng: RandomNumberGenerator = null) -> void:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.seed = hash("tile-stack-%d" % p_level)  # the same level always looks the same
	level = p_level
	var p := level_params(level, available_kinds)
	kind_count = p["kinds"]
	cover_shade = p["cover_shade"]
	undo_left = 1
	shuffle_left = 1
	tray.clear()
	_history.clear()
	tiles.clear()

	var positions := _layout(p, rng)
	for i in positions.size():
		var t := Tile.new()
		t.id = i
		t.x = positions[i].x
		t.y = positions[i].y
		t.z = int(positions[i].z)
		t.in_pile = t.x < 0.0 or t.x > p["cols"]
		tiles.append(t)
	for t in tiles:
		for other in tiles:
			if other.z > t.z and covers(other, t):
				t.above.append(other)
	_deal_kinds(p, rng)


# --- Playing ---------------------------------------------------------------

func is_free(tile: Tile) -> bool:
	if tile.state != State.BOARD:
		return false
	for other in tile.above:
		if other.state == State.BOARD:
			return false
	return true


static func covers(top: Tile, below: Tile) -> bool:
	return absf(top.x - below.x) < 0.999 and absf(top.y - below.y) < 0.999


## Moves a free tile into the tray next to its own kind. Returns the slot it
## landed in, or -1 if it can't be picked. Call resolve() afterwards.
func pick(tile: Tile) -> int:
	if is_won() or is_lost() or not is_free(tile) or tray.size() >= TRAY_SIZE:
		return -1
	_history.append(_snapshot())
	var index := tray.size()
	for i in range(tray.size() - 1, -1, -1):
		if tray[i].kind == tile.kind:
			index = i + 1
			break
	tray.insert(index, tile)
	tile.state = State.TRAY
	return index


## Removes three of a kind from the tray if there are. Returns the removed tiles.
func resolve() -> Array[Tile]:
	var removed: Array[Tile] = []
	var counts := {}
	for t in tray:
		counts[t.kind] = counts.get(t.kind, 0) + 1
	for kind in counts:
		if counts[kind] >= MATCH:
			for t in tray:
				if t.kind == kind and removed.size() < MATCH:
					removed.append(t)
			break
	for t in removed:
		tray.erase(t)
		t.state = State.GONE
	return removed


func board_count() -> int:
	return tiles.filter(func(t: Tile) -> bool: return t.state == State.BOARD).size()


func is_won() -> bool:
	return tray.is_empty() and board_count() == 0


## Lost when the tray is full and nothing in it can be matched.
func is_lost() -> bool:
	if tray.size() < TRAY_SIZE:
		return false
	var counts := {}
	for t in tray:
		counts[t.kind] = counts.get(t.kind, 0) + 1
		if counts[t.kind] >= MATCH:
			return false
	return true


func is_over() -> bool:
	return is_won() or is_lost()


# --- Helpers (once per level each) ---------------------------------------------

func can_undo() -> bool:
	return undo_left > 0 and not _history.is_empty() and not is_won()


## Takes back the last pick (even if it made a match).
func undo() -> bool:
	if not can_undo():
		return false
	_restore(_history.pop_back())
	undo_left -= 1
	return true


func can_shuffle() -> bool:
	return shuffle_left > 0 and board_count() > 1 and not is_over()


## Mixes up the kinds of the tiles still on the board.
func shuffle(rng: RandomNumberGenerator = null) -> bool:
	if not can_shuffle():
		return false
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var on_board := tiles.filter(func(t: Tile) -> bool: return t.state == State.BOARD)
	var kinds: Array = on_board.map(func(t: Tile) -> int: return t.kind)
	for i in range(kinds.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = kinds[i]
		kinds[i] = kinds[j]
		kinds[j] = tmp
	for i in on_board.size():
		on_board[i].kind = kinds[i]
	shuffle_left -= 1
	_history.clear()  # undo can't reach back past a shuffle
	return true


func _snapshot() -> Dictionary:
	return {
		"states": tiles.map(func(t: Tile) -> int: return t.state),
		"tray": tray.map(func(t: Tile) -> int: return t.id),
	}


func _restore(snap: Dictionary) -> void:
	for i in tiles.size():
		tiles[i].state = snap["states"][i]
	tray.clear()
	for id in snap["tray"]:
		tray.append(tiles[id])


# --- Level generation ------------------------------------------------------------

## Tile positions (x, y, layer) for a level: mirrored layers shifted against
## each other, plus two side piles in later levels.
func _layout(p: Dictionary, rng: RandomNumberGenerator) -> Array[Vector3]:
	var total: int = p["triples"] * MATCH
	var pile_size: int = mini(p["piles"], total / 4)
	var board_target := total - pile_size * 2
	var cols: int = p["cols"]
	var rows: int = p["rows"]

	# Tiles per layer: the bottom layers hold the most, upper layers fewer.
	var layer_count: int = p["layers"]
	var weights: Array[float] = []
	var weight_sum := 0.0
	for z in layer_count:
		weights.append(1.0 + 0.6 * (layer_count - 1 - z))
		weight_sum += weights[-1]
	var positions: Array[Vector3] = []
	var below: Array[Vector3] = []
	var left := board_target
	var z := 0
	while left > 0 and z < 40:
		var budget := left
		if z < layer_count - 1:
			budget = mini(left, int(round(board_target * weights[z] / weight_sum)))
		var layer := _make_layer(p, rng, z, budget, below)
		positions.append_array(layer)
		left -= layer.size()
		if not layer.is_empty():
			below = layer
		z += 1

	# Side piles: tiles stacked with a small offset so only the top one can be taken.
	var top_z := z + 1
	for side in [-1, 1]:
		var base_x := -2.4 if side < 0 else cols + 1.4
		for i in pile_size:
			positions.append(Vector3(base_x + side * -0.1 * i, rows - 1.0, top_z + i))
	return positions


## One layer of `budget` tiles, mirrored left-right and shifted against the
## layer below by multiples of the level's step. Spots resting on the layer
## below are preferred, so the stack looks piled up rather than floating.
func _make_layer(p: Dictionary, rng: RandomNumberGenerator, z: int, budget: int, below: Array[Vector3]) -> Array[Vector3]:
	var cols: int = p["cols"]
	var rows: int = p["rows"]
	var step: float = p["step"]
	var shifts := int(round(1.0 / step))
	var shift_x := 0.0 if z == 0 else step * rng.randi_range(0, shifts - 1)
	var shift_y := 0.0 if z == 0 else step * rng.randi_range(0, shifts - 1)
	var layer_cols := cols - (1 if shift_x > 0.0 else 0)
	var layer_rows := rows - (1 if shift_y > 0.0 else 0)

	var groups: Array = []  # each: Array[Vector3] of 1 (centre column) or 2 mirrored spots
	for r in layer_rows:
		var drift := 0.0
		if p["jitter"] and z > 0:
			drift = (rng.randf() - 0.5) * 0.3
		for c in (layer_cols + 1) / 2:
			var mirror := layer_cols - 1 - c
			var group: Array[Vector3] = [Vector3(shift_x + c + drift, shift_y + r, z)]
			if mirror != c:
				group.append(Vector3(shift_x + mirror - drift, shift_y + r, z))
			groups.append(group)
	_shuffle_array(groups, rng)
	if not below.is_empty():
		groups.sort_custom(func(a: Array, b: Array) -> bool: return _rests_on(a[0], below) and not _rests_on(b[0], below))

	var layer: Array[Vector3] = []
	for group in groups:
		if layer.size() >= budget:
			break
		if layer.size() + group.size() <= budget:
			layer.append_array(group)
	# An odd budget with no centre spot left: take one side of a pair.
	if layer.size() < budget:
		for group in groups:
			if layer.size() >= budget:
				break
			if not layer.has(group[0]):
				layer.append(group[0])
	return layer


static func _rests_on(spot: Vector3, below: Array[Vector3]) -> bool:
	for b in below:
		if absf(b.x - spot.x) < 0.999 and absf(b.y - spot.y) < 0.999:
			return true
	return false


## Deals kinds in triples along a random order in which tiles can be uncovered,
## so the level can always be solved.
func _deal_kinds(p: Dictionary, rng: RandomNumberGenerator) -> void:
	# Peel the board from the top in a random order (always taking an uncovered tile).
	var order: Array[Tile] = []
	for t in tiles:
		t.state = State.BOARD
	var remaining := tiles.duplicate()
	while not remaining.is_empty():
		var free := remaining.filter(func(t: Tile) -> bool: return is_free(t))
		var chosen: Tile = free[rng.randi_range(0, free.size() - 1)]
		chosen.state = State.GONE
		remaining.erase(chosen)
		order.append(chosen)
	for t in tiles:
		t.state = State.BOARD

	# Kinds in triples, cycling through all kinds so each appears evenly.
	var kinds: Array[int] = []
	var kind_order := range(kind_count)
	for i in tiles.size() / MATCH:
		if i % kind_count == 0:
			_shuffle_array(kind_order, rng)
		for k in MATCH:
			kinds.append(kind_order[i % kind_count])
	# Interleave within a small window so the next triple isn't simply three in a row.
	var window: int = p["window"]
	for start in range(0, kinds.size(), window):
		var chunk := kinds.slice(start, mini(start + window, kinds.size()))
		_shuffle_array(chunk, rng)
		for i in chunk.size():
			kinds[start + i] = chunk[i]
	for i in order.size():
		order[i].kind = kinds[i]
	solution.assign(order.map(func(t: Tile) -> int: return t.id))


static func _shuffle_array(items: Array, rng: RandomNumberGenerator) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = items[i]
		items[i] = items[j]
		items[j] = tmp
