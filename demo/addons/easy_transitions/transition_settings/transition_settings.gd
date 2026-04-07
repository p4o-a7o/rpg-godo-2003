@tool
@icon("res://addons/easy_transitions/transition_settings/settings_icon.png")
class_name TransitionSettings extends Resource


## Stores settings related to scene transitions.
##
## This resource can store information used in transitions like
## intro tweens, outro tweens, textures, etc.


## General transition settings.
@export_group("Settings")
@export var layer : int = 10
@export var texture: Texture2D = null
@export var hold := 1.0
@export var pixel_size := 16


## Tween settings for intro and outro animations.
@export_group("Tweening")
@export var intro_tween: TransitionTween = TransitionTween.new()
@export var outro_tween: TransitionTween = TransitionTween.new()

func set_duration(value : float):
	intro_tween.duration = value
	outro_tween.duration = value

func set_tween_transition(value : Tween.TransitionType):
	intro_tween.tween_transition = value
	outro_tween.tween_transition = value

func set_ease(value : Tween.EaseType):
	intro_tween.ease = value
	outro_tween.ease = value

func set_type(value : TransitionTween.Types):
	intro_tween.type = value
	outro_tween.type = value
