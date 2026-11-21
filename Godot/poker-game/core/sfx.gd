extends Node
## Sound effects, available everywhere as the `Sfx` autoload: Sfx.play("deal").
## Every sound is synthesised at startup (no audio files needed). Buttons get a
## click and cards a tick automatically. Muted when the start screen's sound
## switch is off (GameSettings.sfx_enabled()).

const MIX_RATE := 22050
const VOICES := 8  # sounds that can overlap

var _streams: Dictionary = {}  # name -> AudioStreamWAV
var _players: Array[AudioStreamPlayer] = []
var _next_player := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 7  # same noise every run, so sounds don't change between launches
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	_build_sounds()
	get_tree().node_added.connect(_on_node_added)


## Plays a sound by name; volume_db shifts its loudness, pitch varies it slightly.
func play(sound: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not GameSettings.sfx_enabled() or not _streams.has(sound):
		return
	var player := _players[_next_player]
	_next_player = (_next_player + 1) % VOICES
	player.stream = _streams[sound]
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play()


## Plays the sound `count` times, `gap` seconds apart (e.g. cards being dealt).
func play_series(sound: String, count: int, gap: float, volume_db: float = 0.0) -> void:
	for i in count:
		play(sound, volume_db, 0.9 + 0.2 * _rng.randf())
		await get_tree().create_timer(gap).timeout


func has_sound(sound: String) -> bool:
	return _streams.has(sound)


# --- Automatic clicks ----------------------------------------------------------

func _on_node_added(node: Node) -> void:
	if node is CardView:
		node.pressed.connect(play.bind("select", -4.0))
	elif node is Button:
		node.pressed.connect(play.bind("click", -6.0))


# --- Synthesis -------------------------------------------------------------------

func _build_sounds() -> void:
	# UI button: short bright blip.
	_streams["click"] = _make(0.05, func(t: float) -> float:
		return sin(TAU * 1400.0 * t) * _env(t, 0.002, 0.05) * 0.5)
	# Picking up a card: soft papery tick.
	_streams["select"] = _make(0.05, func(t: float) -> float:
		return (_noise() * 0.6 + sin(TAU * 900.0 * t) * 0.4) * _env(t, 0.001, 0.035) * 0.6)
	# One card sliding off the deck.
	_streams["deal"] = _make(0.09, _filtered_noise(0.35, func(t: float) -> float: return _env(t, 0.01, 0.09) * 0.55))
	# Cards slapped onto the table: noise burst plus a low thump.
	_streams["play"] = _make(0.16, _layer([
		_filtered_noise(0.5, func(t: float) -> float: return _env(t, 0.002, 0.08) * 0.3),
		func(t: float) -> float: return sin(TAU * 140.0 * t) * _env(t, 0.002, 0.14) * 0.35,
	]))
	# Pass: two soft falling notes.
	_streams["pass"] = _make(0.26, func(t: float) -> float:
		var f := 520.0 if t < 0.12 else 390.0
		var local := fmod(t, 0.12) if t < 0.24 else 0.12
		return sin(TAU * f * t) * _env(local, 0.005, 0.12) * 0.35)
	# Bid / landlord chosen: bell-like ding.
	_streams["bid"] = _make(0.45, func(t: float) -> float:
		return (sin(TAU * 880.0 * t) + 0.4 * sin(TAU * 1760.0 * t) + 0.2 * sin(TAU * 2640.0 * t)) * _env(t, 0.003, 0.45) * 0.3)
	# Bomb / rocket: falling boom with rumble.
	_streams["bomb"] = _make(0.8, _layer([
		func(t: float) -> float: return sin(TAU * (90.0 - 50.0 * t) * t) * _env(t, 0.005, 0.8) * 0.55,
		_filtered_noise(0.12, func(t: float) -> float: return _env(t, 0.005, 0.6) * 0.6),
	]))
	# Not a legal play: low buzz.
	_streams["illegal"] = _make(0.18, func(t: float) -> float:
		return (1.0 if sin(TAU * 140.0 * t) > 0.0 else -1.0) * _env(t, 0.005, 0.18) * 0.18)
	# Three tiles matched: quick bright two-note chime.
	_streams["match"] = _notes([1046.5, 1568.0], 0.07, 0.3)
	# Countdown tick.
	_streams["tick"] = _make(0.06, func(t: float) -> float:
		return sin(TAU * 1050.0 * t) * _env(t, 0.001, 0.06) * 0.35)
	# Round won: rising arpeggio C E G C.
	_streams["win"] = _notes([523.25, 659.25, 783.99, 1046.5], 0.11, 0.45)
	# Round lost: falling notes G E C.
	_streams["lose"] = _notes([392.0, 329.63, 261.63], 0.16, 0.4)


## Renders `seconds` of mono 16-bit audio from a function of time (-1..1).
func _make(seconds: float, wave: Callable) -> AudioStreamWAV:
	var frames := int(seconds * MIX_RATE)
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in frames:
		var sample := clampf(wave.call(float(i) / MIX_RATE), -1.0, 1.0)
		data.encode_s16(i * 2, int(sample * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream


## A short tune: each note a soft bell, the last one held longer.
func _notes(freqs: Array, step: float, tail: float) -> AudioStreamWAV:
	var total := step * (freqs.size() - 1) + tail
	return _make(total, func(t: float) -> float:
		var sum := 0.0
		for i in freqs.size():
			var start := step * i
			if t >= start:
				var local := t - start
				var length := tail if i == freqs.size() - 1 else step * 1.6
				sum += (sin(TAU * freqs[i] * t) + 0.3 * sin(TAU * freqs[i] * 2.0 * t)) * _env(local, 0.004, length)
		return sum * 0.25)


## Noise smoothed by a one-pole low-pass filter (lower `smooth` = darker).
func _filtered_noise(smooth: float, envelope: Callable) -> Callable:
	var state := [0.0]
	return func(t: float) -> float:
		state[0] += (_noise() - state[0]) * smooth
		return state[0] * 2.0 * envelope.call(t)


func _layer(waves: Array) -> Callable:
	return func(t: float) -> float:
		var sum := 0.0
		for w in waves:
			sum += w.call(t)
		return sum


func _noise() -> float:
	return _rng.randf() * 2.0 - 1.0


## Quick fade-in over `attack`, then an exponential-ish fade to silence by `length`.
func _env(t: float, attack: float, length: float) -> float:
	if t < 0.0 or t >= length:
		return 0.0
	if t < attack:
		return t / attack
	var x := (t - attack) / (length - attack)
	return pow(1.0 - x, 2.0)
