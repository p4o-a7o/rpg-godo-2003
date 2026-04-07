@tool extends EditorPlugin


const AUTOLOAD_NAME := "Transition"
const FOLDER_NAME := "easy_transitions"


func _enter_tree() -> void:
	add_autoload_singleton(AUTOLOAD_NAME, "res://addons/" + FOLDER_NAME + "/transition.tscn")


func _exit_tree() -> void:
	remove_autoload_singleton(AUTOLOAD_NAME)
