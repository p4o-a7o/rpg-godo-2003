@tool
@icon("res://addons/easy_transitions/icon.png")
class_name TransitionTween extends Resource


## TransitionTweenSettings stores tweening properties for transition effects.
##
## The TransitionTweenSettings allows  consistent transition effects across
## different transition effects.
## It can store the same information a Tween can.

@export var tween_transition := Tween.TransitionType.TRANS_SINE
@export var ease := Tween.EaseType.EASE_IN_OUT
@export var type := Types.DIAMOND
@export var duration := 1.0
@export var reverse := false

enum Types {
	DIAMOND,
	CIRCLE,
	VERTICAL_SLICE,
	HORIZONTAL_SLICE,
	FADE,
	PIXELIZE,
	PUSH_UP,
	SWIPE
}
