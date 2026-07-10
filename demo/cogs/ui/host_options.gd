class_name HostOptionsScreen
extends Control

# should probably make a real menu system for
# this or something
var previous_screen: Node

@onready var _back_button: Button = %BackButton
@onready var _engine: RPGMakerPlayer = %RPGMakerPlayer
@onready var _setup_screen: SetupScreen = %SetupScreen

func _ready() -> void:
	_back_button.pressed.connect(_back_button_pressed)

func _back_button_pressed() -> void:
	self.hide()
	if previous_screen:
		previous_screen.show()
		previous_screen = null


func _host_pressed() -> void:
	if _engine and not _engine.is_running():
		Transition.custom(_actually_launch_game, TransitionPresets.get_fast_fade())

func _actually_launch_game() -> void:
	EasyServerSteam.joinable = not %LbDisableJoining.button_pressed
	EasyServerSteam.max_players = %LbMaxPlayers.value
	_setup_screen._launch_game(true)
	self.hide()
	if previous_screen:
		previous_screen.show()
		previous_screen = null
