extends Node

const DATA_VERSION := 1

func read_json(file_name: String, defaults: Variant) -> Variant:
	var path := "user://" + file_name
	var candidates := [path, path + ".tmp", path + ".bak"]
	var found_candidate := false
	for candidate in candidates:
		if not FileAccess.file_exists(candidate):
			continue
		found_candidate = true
		var parsed: Variant = _read_candidate(candidate, defaults)
		if parsed == null:
			_backup_corrupt(candidate)
			continue
		if candidate != path:
			if write_json(file_name, parsed):
				EventBus.toast_requested.emit("检测到损坏的本地数据，已安全恢复")
		return parsed
	if found_candidate:
		EventBus.toast_requested.emit("检测到损坏的本地数据，已安全恢复")
	return _duplicate_default(defaults)

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
		if FileAccess.file_exists(path + ".bak") and not FileAccess.file_exists(path):
			DirAccess.rename_absolute(absolute_path + ".bak", absolute_path)
		if FileAccess.file_exists(temporary):
			DirAccess.remove_absolute(absolute_temporary)
		EventBus.toast_requested.emit("保存文件替换失败")
		return false
	return true

func remove_json(file_name: String) -> bool:
	var directory := DirAccess.open("user://")
	if directory == null:
		return false
	var removed_all := true
	for entry in directory.get_files():
		var should_remove := entry == file_name or entry == file_name + ".tmp" \
			or entry == file_name + ".bak" \
			or entry.begins_with(file_name + ".corrupt-") \
			or entry.begins_with(file_name + ".tmp.corrupt-") \
			or entry.begins_with(file_name + ".bak.corrupt-")
		if should_remove and directory.remove(entry) != OK:
			removed_all = false
	return removed_all

func remove_user_files_with_prefix(prefixes: Array[String]) -> bool:
	var directory := DirAccess.open("user://")
	if directory == null:
		return false
	var removed_all := true
	for entry in directory.get_files():
		for prefix in prefixes:
			if entry.begins_with(prefix):
				if directory.remove(entry) != OK:
					removed_all = false
				break
	return removed_all

func _read_candidate(path: String, defaults: Variant) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return null
	var parsed: Variant = json.data
	if defaults is Dictionary and not parsed is Dictionary:
		return null
	if defaults is Array and not parsed is Array:
		return null
	return parsed

func _duplicate_default(defaults: Variant) -> Variant:
	return defaults.duplicate(true) if defaults is Dictionary or defaults is Array else defaults

func _backup_corrupt(path: String) -> void:
	var absolute := ProjectSettings.globalize_path(path)
	var backup := absolute + ".corrupt-" + str(Time.get_ticks_usec())
	DirAccess.rename_absolute(absolute, backup)
