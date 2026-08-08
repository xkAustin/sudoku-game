extends Node

const RuntimeAudioLoaderScript := preload("res://ui/audio/runtime_audio_loader.gd")

var _player := AudioStreamPlayer.new()
var _error_player := AudioStreamPlayer.new()
var _default_stream: AudioStreamWAV
var _default_error_stream: AudioStreamWAV
var _custom_stream: AudioStream
var _custom_error_stream: AudioStream

func _ready() -> void:
	add_child(_player)
	add_child(_error_player)
	_default_stream = _make_tone()
	_default_error_stream = _make_error_tone()
	reload_custom_sound()
	_player.stream = _default_stream
	_player.volume_db = -18.0
	_error_player.stream = _default_error_stream
	_error_player.volume_db = -7.0
	EventBus.settings_changed.connect(reload_custom_sound)

func input_feedback() -> void:
	if bool(AppState.settings.get("sound", true)):
		_player.stream = _custom_stream if _custom_stream != null else _default_stream
		_player.pitch_scale = 1.0
		_player.play()
	_play_system_haptic(false)

func completion_feedback() -> void:
	if bool(AppState.settings.get("sound", true)):
		_player.stream = _custom_stream if _custom_stream != null else _default_stream
		_player.pitch_scale = 1.5
		_player.play()
	_play_system_haptic(true)

func error_feedback() -> void:
	if bool(AppState.settings.get("sound", true)) and bool(AppState.settings.get("error_sound", true)):
		play_error_sound()
	_play_system_haptic(false)

func play_error_sound() -> void:
	_error_player.stream = _custom_error_stream if _custom_error_stream != null else _default_error_stream
	_error_player.pitch_scale = 1.0
	_error_player.play()

func reload_custom_sound() -> void:
	_custom_stream = RuntimeAudioLoaderScript.load_file(str(AppState.settings.get("custom_ui_sound_path", "")))
	_custom_error_stream = RuntimeAudioLoaderScript.load_file(str(AppState.settings.get("custom_error_sound_path", "")))

func has_custom_error_stream() -> bool:
	return _custom_error_stream != null

func is_error_player_active() -> bool:
	return _error_player.playing

func _play_system_haptic(completion: bool) -> void:
	if not bool(AppState.settings.get("vibration", true)):
		return
	match OS.get_name():
		"Android":
			_android_system_haptic(completion)
		"iOS":
			# iOS applies the user's global System Haptics preference. Using -1 keeps
			# the device-selected strength instead of imposing an app amplitude.
			Input.vibrate_handheld(70 if completion else 24, -1.0)

func _android_system_haptic(completion: bool) -> void:
	var android_runtime: Object = Engine.get_singleton("AndroidRuntime")
	if android_runtime == null:
		return
	var activity: Object = android_runtime.getActivity()
	if activity == null:
		return
	var decor_view: Object = activity.getWindow().getDecorView()
	var constants: Object = JavaClassWrapper.wrap("android.view.HapticFeedbackConstants")
	var build_version: Object = JavaClassWrapper.wrap("android.os.Build$VERSION")
	var feedback_constant := int(constants.KEYBOARD_TAP)
	if completion:
		feedback_constant = int(constants.CONFIRM) if int(build_version.SDK_INT) >= 30 else int(constants.VIRTUAL_KEY)
	var perform := func() -> void:
		# No IGNORE flags: Android therefore honors HAPTIC_FEEDBACK_ENABLED,
		# the view setting, device capabilities, and the user's system strength.
		decor_view.performHapticFeedback(feedback_constant)
	activity.runOnUiThread(android_runtime.createRunnableFromGodotCallable(perform))

func _make_tone() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.stereo = false
	var sample_count := 1102
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	for index in sample_count:
		var envelope := 1.0 - float(index) / float(sample_count)
		var sample := int(sin(TAU * 660.0 * float(index) / 22050.0) * 9000.0 * envelope)
		bytes[index * 2] = sample & 0xff
		bytes[index * 2 + 1] = (sample >> 8) & 0xff
	stream.data = bytes
	return stream

func _make_error_tone() -> AudioStreamWAV:
	var mix_rate := 22050
	var duration := 0.22
	var sample_count := int(float(mix_rate) * duration)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	for index in sample_count:
		var time := float(index) / float(mix_rate)
		var pulse_time := fmod(time, 0.11)
		var pulse_envelope := exp(-pulse_time * 24.0)
		var gap := 0.0 if pulse_time > 0.072 else 1.0
		var tone := sin(TAU * 250.0 * time) * 0.68 + sin(TAU * 390.0 * time) * 0.28
		var sample := clampf(tone * pulse_envelope * gap * 0.78, -1.0, 1.0)
		bytes.encode_s16(index * 2, int(sample * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix_rate
	stream.stereo = false
	stream.data = bytes
	return stream
