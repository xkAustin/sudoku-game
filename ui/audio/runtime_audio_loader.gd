class_name RuntimeAudioLoader
extends RefCounted

const SUPPORTED_EXTENSIONS := ["mp3", "wav", "ogg"]
const MAX_FILE_SIZE := 10 * 1024 * 1024

static func is_supported_path(path: String) -> bool:
	return path.get_extension().to_lower() in SUPPORTED_EXTENSIONS

static func load_file(path: String) -> AudioStream:
	if path.is_empty() or not FileAccess.file_exists(path) or not is_supported_path(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() <= 0 or file.get_length() > MAX_FILE_SIZE:
		if file != null:
			file.close()
		return null
	file.close()
	match path.get_extension().to_lower():
		"mp3":
			return AudioStreamMP3.load_from_file(path)
		"wav":
			return AudioStreamWAV.load_from_file(path)
		"ogg":
			return AudioStreamOggVorbis.load_from_file(path)
	return null
