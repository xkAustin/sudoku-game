extends Node

const DATA_VERSION := 1

func read_json(file_name: String, defaults: Variant) -> Variant:
	var path := "user://" + file_name
	if not FileAccess.file_exists(path):
		return defaults.duplicate(true) if defaults is Dictionary or defaults is Array else defaults
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		EventBus.toast_requested.emit("无法读取本地数据，已使用默认设置")
		return defaults
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or not (parsed is Dictionary or parsed is Array):
		_backup_corrupt(path)
		EventBus.toast_requested.emit("检测到损坏的本地数据，已安全恢复")
		return defaults
	return parsed

func write_json(file_name: String, value: Variant) -> bool:
	var path := "user://" + file_name
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		EventBus.toast_requested.emit("保存失败，请检查可用存储空间")
		return false
	file.store_string(JSON.stringify(value))
	file.flush()
	file.close()
	var absolute_path := ProjectSettings.globalize_path(path)
	var absolute_temporary := ProjectSettings.globalize_path(temporary)
	if FileAccess.file_exists(path):
		var backup := absolute_path + ".bak"
		if FileAccess.file_exists(path + ".bak"):
			DirAccess.remove_absolute(backup)
		if DirAccess.rename_absolute(absolute_path, backup) != OK:
			DirAccess.remove_absolute(absolute_temporary)
			return false
	var error := DirAccess.rename_absolute(absolute_temporary, absolute_path)
	if error != OK:
		EventBus.toast_requested.emit("保存文件替换失败")
		return false
	return true

func _backup_corrupt(path: String) -> void:
	var absolute := ProjectSettings.globalize_path(path)
	var backup := absolute + ".corrupt-" + str(Time.get_unix_time_from_system())
	DirAccess.rename_absolute(absolute, backup)
