extends Node

var current_destination := "menu"
var history: Array[String] = []

func go(destination: String) -> void:
	if destination == current_destination:
		return
	history.append(current_destination)
	current_destination = destination
	EventBus.navigation_requested.emit(destination)

func back() -> void:
	if history.is_empty():
		go("menu")
		return
	current_destination = history.pop_back()
	EventBus.navigation_requested.emit(current_destination)

func reset(destination: String = "menu") -> void:
	history.clear()
	current_destination = destination
	EventBus.navigation_requested.emit(destination)
