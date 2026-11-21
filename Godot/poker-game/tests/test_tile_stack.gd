extends SceneTree
## Run: godot --headless --path . --script tests/test_tile_stack.gd

const State := TileStackGame.State
const KINDS := 12

var failures := 0


func _init() -> void:
	GameSettings.save_to_disk = false  # never change the player's saved settings
	test_levels_are_well_formed()
	test_levels_are_solvable()
	test_difficulty_grows()
	test_covering()
	test_tray()
	test_losing()
	test_undo_and_shuffle()
	test_auto_finish()
	test_tile_faces()
	print("FAILED: %d" % failures if failures > 0 else "ALL PASSED")
	quit(1 if failures > 0 else 0)


func check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		print("FAIL: ", label)


func test_levels_are_well_formed() -> void:
	for level in range(1, 21):
		var g := TileStackGame.new()
		g.start(level, KINDS)
		var p := TileStackGame.level_params(level, KINDS)
		check(g.tiles.size() == p["triples"] * 3, "level %d has %d tiles (got %d)" % [level, p["triples"] * 3, g.tiles.size()])
		var counts := {}
		for t in g.tiles:
			counts[t.kind] = counts.get(t.kind, 0) + 1
			check(t.kind >= 0 and t.kind < g.kind_count, "level %d kind in range" % level)
		for k in counts:
			check(counts[k] % 3 == 0, "level %d: kind %d comes in threes" % [level, k])
		var free := g.tiles.filter(func(t) -> bool: return g.is_free(t))
		check(not free.is_empty(), "level %d has something to pick" % level)
		# Same level number -> same layout.
		var again := TileStackGame.new()
		again.start(level, KINDS)
		check(again.tiles[0].x == g.tiles[0].x and again.tiles[-1].kind == g.tiles[-1].kind, "level %d is repeatable" % level)


func test_levels_are_solvable() -> void:
	for level in range(1, 21):
		var g := TileStackGame.new()
		g.start(level, KINDS)
		var most := 0
		for id in g.solution:
			var ok := g.pick(g.tiles[id]) >= 0
			if not ok:
				check(false, "level %d: solution step blocked" % level)
				break
			most = maxi(most, g.tray.size())
			g.resolve()
		check(g.is_won(), "level %d is solvable" % level)
		check(most < TileStackGame.TRAY_SIZE, "level %d solution never fills the tray (max %d)" % [level, most])


func test_difficulty_grows() -> void:
	var a := TileStackGame.level_params(1, KINDS)
	var b := TileStackGame.level_params(10, KINDS)
	check(b["triples"] > a["triples"], "later levels have more tiles")
	check(b["kinds"] > a["kinds"], "later levels have more kinds")
	check(b["layers"] > a["layers"], "later levels have more layers")
	check(b["step"] < a["step"], "later levels shift layers more finely")
	check(b["cover_shade"] > a["cover_shade"], "covered tiles are harder to spot later")
	check(a["piles"] == 0 and b["piles"] > 0, "side piles appear later")
	var g := TileStackGame.new()
	g.start(7, KINDS)
	var odd := g.tiles.filter(func(t) -> bool: return fmod(t.x, 0.5) != 0.0)
	check(not odd.is_empty(), "level 7 uses quarter-tile offsets")


func test_covering() -> void:
	var g := TileStackGame.new()
	g.tiles.clear()
	var low := _tile(g, 0, 0.0, 0.0, 0, 0)
	var high := _tile(g, 1, 0.5, 0.5, 1, 0)
	var beside := _tile(g, 2, 1.0, 0.0, 1, 0)
	for t in g.tiles:
		for o in g.tiles:
			if o.z > t.z and TileStackGame.covers(o, t):
				t.above.append(o)
	check(not g.is_free(low), "half-overlapping tile above covers")
	check(g.is_free(high) and g.is_free(beside), "top tiles are free")
	check(not low.above.has(beside), "a tile exactly one width away does not cover")
	high.state = State.GONE
	check(g.is_free(low), "uncovered once the tile above is gone")


func test_tray() -> void:
	var g := TileStackGame.new()
	g.tiles.clear()
	for i in 6:
		_tile(g, i, float(i), 0.0, 0, [0, 1, 0, 2, 0, 1][i])
	check(g.pick(g.tiles[0]) == 0, "first tile in slot 0")
	check(g.pick(g.tiles[1]) == 1, "other kind after it")
	check(g.pick(g.tiles[2]) == 1, "same kind goes next to its match")
	check(g.resolve().is_empty(), "two of a kind don't match yet")
	g.pick(g.tiles[4])
	var removed := g.resolve()
	check(removed.size() == 3 and g.tray.size() == 1, "three of a kind disappear")
	check(g.tiles[0].state == State.GONE, "matched tiles are gone")
	check(not g.is_won(), "not won with tiles left")


func test_losing() -> void:
	var g := TileStackGame.new()
	g.tiles.clear()
	for i in 8:
		_tile(g, i, float(i), 0.0, 0, i)  # all different
	for i in 7:
		g.pick(g.tiles[i])
		g.resolve()
	check(g.is_lost(), "seven unmatched tiles lose")
	check(g.pick(g.tiles[7]) == -1, "no picking after losing")


func test_undo_and_shuffle() -> void:
	var g := TileStackGame.new()
	g.start(3, KINDS)
	var first: TileStackGame.Tile = g.tiles[g.solution[0]]
	g.pick(first)
	g.resolve()
	check(g.undo(), "undo works once")
	check(first.state == State.BOARD and g.tray.is_empty(), "undo puts the tile back")
	g.pick(first)
	check(not g.undo(), "only one undo per level")

	var before := {}
	for t in g.tiles:
		if t.state == State.BOARD:
			before[t.kind] = before.get(t.kind, 0) + 1
	check(g.shuffle(), "shuffle works once")
	var after := {}
	for t in g.tiles:
		if t.state == State.BOARD:
			after[t.kind] = after.get(t.kind, 0) + 1
	check(before == after, "shuffle keeps how many of each kind")
	check(not g.shuffle(), "only one shuffle per level")


func _link(g: TileStackGame) -> void:
	for t in g.tiles:
		t.above.clear()
		for o in g.tiles:
			if o.z > t.z and TileStackGame.covers(o, t):
				t.above.append(o)


func test_auto_finish() -> void:
	# Flat board (nothing stacked): can finish.
	var flat := TileStackGame.new()
	flat.tiles.clear()
	for i in 6:
		_tile(flat, i, float(i), 0.0, 0, [0, 1, 0, 1, 1, 0][i])
	_link(flat)
	var plan := flat.auto_finish_plan()
	check(not plan.is_empty(), "flat board can be finished")
	check(flat.board_count() == 6 and flat.tray.is_empty(), "planning doesn't change the board")
	for id in plan:
		flat.pick(flat.tiles[id])
		flat.resolve()
	check(flat.is_won(), "the plan clears the level")

	# Still stacked with two kinds: not yet.
	var stacked := TileStackGame.new()
	stacked.tiles.clear()
	for i in 6:
		_tile(stacked, i, 0.0 if i < 2 else float(i), 0.0, 1 if i == 1 else 0, [0, 1, 0, 1, 1, 0][i])
	_link(stacked)
	check(not stacked.can_auto_finish(), "stacked tiles of several kinds can't be skipped")

	# One kind left, even stacked: can finish.
	var single := TileStackGame.new()
	single.tiles.clear()
	for i in 6:
		_tile(single, i, 0.0, 0.0, i, 2)
	_link(single)
	check(single.can_auto_finish(), "only one kind left can be finished")

	# A clogged tray can't be rescued.
	var clogged := TileStackGame.new()
	clogged.tiles.clear()
	for i in 18:
		_tile(clogged, i, float(i), 0.0, 0, i % 6)
	_link(clogged)
	for i in 6:
		clogged.pick(clogged.tiles[i])
		clogged.resolve()
	check(clogged.tray.size() == 6 and not clogged.can_auto_finish(), "no finish button when it would fail")

	# A real level, played until it is flat, can be finished.
	var g := TileStackGame.new()
	g.start(6, KINDS)
	var steps := 0
	while not g.can_auto_finish() and steps < g.solution.size():
		g.pick(g.tiles[g.solution[steps]])
		g.resolve()
		steps += 1
	check(g.can_auto_finish() and steps < g.solution.size(), "level 6 offers finishing before the last tile (after %d of %d)" % [steps, g.solution.size()])


func test_tile_faces() -> void:
	check(TileFaces.images().size() >= 4, "party emblem pictures are loaded (%d)" % TileFaces.images().size())
	check(TileFaces.kind_count() >= 12, "enough tile kinds for the hardest levels")
	var heart: Color = TileFaces.SUITS[1][1]
	var diamond: Color = TileFaces.SUITS[2][1]
	check(absf(heart.h - diamond.h) > 0.3 or heart.s < 0.3 or diamond.s < 0.3, "hearts and diamonds have clearly different colours")


func _tile(g: TileStackGame, id: int, x: float, y: float, z: int, kind: int) -> TileStackGame.Tile:
	var t := TileStackGame.Tile.new()
	t.id = id
	t.x = x
	t.y = y
	t.z = z
	t.kind = kind
	g.tiles.append(t)
	return t
