class_name InGameSettingsScreen
extends Control

var _opened: bool = false

func open() -> void:
	if _opened:
		return
	_opened = true
	show()
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1, 0.3) \
		.set_trans(Tween.TRANS_CUBIC) \
		.set_ease(Tween.EASE_OUT)

func close() -> void:
	if not _opened:
		return
	_opened = false
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0, 0.3) \
		.set_trans(Tween.TRANS_CUBIC) \
		.set_ease(Tween.EASE_OUT)
	tween.tween_callback(self.hide)

func _on_join_toggled(toggled_on: bool) -> void:
	if not EasyServerSteam.is_running():
		return
	EasyServerSteam.set_lobby_joinable(not toggled_on)

func _on_back_button_pressed() -> void:
	close()
