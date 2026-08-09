extends Node

signal toast_requested(message: String)
signal session_changed
signal settings_changed(changed_keys: PackedStringArray)
signal network_changed(online: bool)
signal pending_count_changed(count: int)
signal navigation_requested(destination: String)
