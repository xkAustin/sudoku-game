class_name UISoundManager
extends Node

const MIX_RATE := 44100
const PLAYER_COUNT := 4
const RuntimeAudioLoaderScript := preload("res://ui/audio/runtime_audio_loader.gd")

var _players: Array[AudioStreamPlayer] = []
var _cursor := 0
var _tap_stream: AudioStreamWAV
var _selection_stream: AudioStreamWAV
var _custom_stream: AudioStream

func _ready() -> void:
	_tap_stream = _make_tap(0.034, 1180.0, 0.50)
	_selection_stream = _make_tap(0.044, 860.0, 0.42)
	reload_custom_sound(str(AppState.settings.get("custom_ui_sound_path", "")))
	for index in PLAYER_COUNT:
		var player := AudioStreamPlayer.new()
		player.name = "UISound%d" % index
		player.volume_db = -8.0
		player.bus = "Master"
		add_child(player)
		_players.append(player)

func is_ready_to_play() -> bool:
	return not _players.is_empty() \
		and _tap_stream != null and not _tap_stream.data.is_empty() \
		and _selection_stream != null and not _selection_stream.data.is_empty()

func is_any_player_active() -> bool:
	for player in _players:
		if player.playing:
			return true
	return false

func play_tap() -> void:
	_play(_custom_stream if _custom_stream != null else _tap_stream, randf_range(0.975, 1.025))

func play_selection() -> void:
	_play(_custom_stream if _custom_stream != null else _selection_stream, randf_range(0.985, 1.015))

func reload_custom_sound(path: String) -> bool:
	_custom_stream = RuntimeAudioLoaderScript.load_file(path)
	return _custom_stream != null or path.is_empty()

func set_custom_stream(stream: AudioStream) -> void:
	_custom_stream = stream

func has_custom_stream() -> bool:
	return _custom_stream != null

func _play(stream: AudioStream, pitch: float) -> void:
	if _players.is_empty() or stream == null:
		return
	var player := _players[_cursor]
	_cursor = (_cursor + 1) % _players.size()
	player.stream = stream
	player.pitch_scale = pitch
	player.play()

func _make_tap(duration: float, frequency: float, strength: float) -> AudioStreamWAV:
	var sample_count := int(duration * MIX_RATE)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	for index in sample_count:
		var time := float(index) / MIX_RATE
		var attack := 1.0 - exp(-time * 1250.0)
		var decay := exp(-time * 105.0)
		var body := sin(TAU * frequency * time) * 0.58
		body += sin(TAU * frequency * 0.43 * time) * 0.28
		body += sin(TAU * frequency * 1.91 * time) * 0.08
		var transient := sin(TAU * 2850.0 * time) * exp(-time * 260.0) * 0.15
		var sample := clampf((body * attack * decay + transient) * strength, -1.0, 1.0)
		bytes.encode_s16(index * 2, int(sample * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = bytes
	return stream
