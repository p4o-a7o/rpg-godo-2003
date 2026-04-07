class_name TransitionPresets
extends Resource

static func get_fast_fade() -> TransitionSettings:
	var settings := TransitionSettings.new()
	settings.set_duration(0.15)
	settings.set_type(TransitionTween.Types.FADE)
	settings.hold = 0.1
	return settings

static func get_slow_fade() -> TransitionSettings:
	var settings := TransitionSettings.new()
	settings.set_duration(1.)
	settings.set_type(TransitionTween.Types.FADE)
	settings.hold = 0.5
	return settings

static func get_diamond() -> TransitionSettings:
	var settings := TransitionSettings.new()
	settings.set_duration(1.)
	settings.set_type(TransitionTween.Types.DIAMOND)
	settings.hold = 0.3
	return settings

static func get_pixelated() -> TransitionSettings:
	var settings := TransitionSettings.new()
	settings.set_duration(1.)
	settings.set_type(TransitionTween.Types.PIXELIZE)
	settings.hold = 0.3
	return settings
