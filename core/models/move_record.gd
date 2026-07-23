class_name MoveRecord
extends RefCounted

var changes: Array[Dictionary] = []
var move_type := "input"
var timestamp_ms := 0
var sequence_number := 0

func _init(type: String = "input", sequence: int = 0) -> void:
	move_type = type
	sequence_number = sequence
	timestamp_ms = Time.get_ticks_msec()

func add_change(cell_index: int, old_value: int, new_value: int, old_notes: int, new_notes: int) -> void:
	changes.append({
		"cell_index": cell_index, "old_value": old_value, "new_value": new_value,
		"old_notes": old_notes, "new_notes": new_notes
	})

func to_dict() -> Dictionary:
	return {"changes": changes, "move_type": move_type, "timestamp_ms": timestamp_ms, "sequence_number": sequence_number}

static func from_dict(data: Dictionary) -> MoveRecord:
	var record := MoveRecord.new(str(data.get("move_type", "input")), int(data.get("sequence_number", 0)))
	record.timestamp_ms = int(data.get("timestamp_ms", 0))
	for change in data.get("changes", []):
		record.changes.append(change)
	return record
