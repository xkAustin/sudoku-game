class_name RuntimeAudioLoader
extends RefCounted

const SUPPORTED_EXTENSIONS := ["mp3", "wav", "ogg"]

static func is_supported_path(path: String) -> bool:
	return path.get_extension().to_lower() in SUPPORTED_EXTENSIONS

static func load_file(path: String) -> AudioStream:
	if path.is_empty() or not FileAccess.file_exists(path) or not is_supported_path(path):
		return null
	match path.get_extension().to_lower():
		"mp3":
			return AudioStreamMP3.load_from_file(path)
		"wav":
			return AudioStreamWAV.load_from_file(path)
		"ogg":
			return AudioStreamOggVorbis.load_from_file(path)
	return null
