extends Control

@onready var godot_menu_layer: CanvasLayer = %GodotMenuLayer
@onready var engine_layer: CanvasLayer = %EngineLayer
@onready var game_path: LineEdit = %GamePath
@onready var game_path_button: Button = %GamePathButton
@onready var game_path_file_dialog: FileDialog = %GamePathFileDialog
@onready var audio_slider: HSlider = %AudioSlider
@onready var mp_enable: CheckBox = %MpEnable
@onready var mp_name: LineEdit = %MpName
@onready var mp_host_lobby: CheckBox = %MpHostLobby
@onready var save_and_run: Button = %SaveAndRun
@onready var enable_chat: CheckBox = %EnableChat
@onready var chat_ctrl: ChatOverlay = %ChatControl
@onready var chat_layer: CanvasLayer = %ChatOverlayLayer
@onready var chat_vbox: VBoxContainer = %MessageContainer
@onready var chat_field: LineEdit = %ChatField
@onready var window_scale: OptionButton = %WindowScale

@export var engine: Node

const _SETTINGS_PATH := "user://main_settings.cfg"

var client_node: EasyClientSteam = null
var server_node: EasyServerSteam = null
var _watch_timer: Timer = null

func _ready() -> void:
	var args := OS.get_cmdline_args()
	if args.has("--server-only"):
		_start_server_only()
		return
	
	var cfg := ConfigFile.new()
	var err := cfg.load(_SETTINGS_PATH)
	
	game_path.text = cfg.get_value("game", "path", engine.get_game_path()) \
		if err == OK else engine.get_game_path()
	
	audio_slider.min_value = 0.0
	audio_slider.max_value = 100.0
	audio_slider.step = 5.0
	audio_slider.value = cfg.get_value("audio", "volume", 80.0)
	mp_enable.button_pressed = cfg.get_value("multiplayer", "enabled", false)
	mp_name.text = cfg.get_value("multiplayer", "name", "Minnatsuki")
	window_scale.selected = cfg.get_value("game", "window_scale", 0)
	enable_chat.button_pressed = cfg.get_value("multiplayer", "enable_chat", false)
	
	var window := get_window()
	var scale := window_scale.selected+1
	window.size = Vector2(640, 480) * scale
	
	game_path_button.pressed.connect(_on_browse_pressed)
	game_path_file_dialog.dir_selected.connect(_on_dir_selected)
	audio_slider.value_changed.connect(_on_audio_volume_changed)
	save_and_run.pressed.connect(_on_save_and_run)
	
	#if args.has("--autorun") or run_on_start.button_pressed:
	#	_launch_game()

func _on_relay_status(available: bool, status_code: int, debug_message: String) -> void:
	if available:
		%MultiplayerOptions.visible = true
		%AvailabilityPanel.visible = false
	else:
		%AvailabilityText.text = "Multiplayer availability check failed with message: %s (Code: %s)" % [debug_message, status_code]

func _start_mp_server(parent: Node) -> void:
	if server_node:
		server_node.stop()
		server_node.queue_free()
		server_node = null
	server_node = EasyServerSteam.new()
	server_node.name = "MpServerNode"
	server_node.engine = engine
	parent.add_child(server_node)
	if not server_node.start():
		Log.error("[setup_screen] Failed to start server for some reason")
		server_node.queue_free()
		server_node = null
	server_node.sender._player_name = mp_name.text # lol
	server_node.chat_overlay = chat_ctrl
	# You are the host so theres no point in being able
	# to click the reload button, in fact, it would not do anything
	%ReconnectButton.disabled = true

func _start_mp_client(parent: Node) -> void:
	%ReconnectButton.disabled = false
	client_node = EasyClientSteam.new()
	client_node.name = "MpNode"
	client_node.engine = engine
	client_node.sender._player_name = mp_name.text # lol
	parent.add_child(client_node)
	# nametag modes: 0=NONE, 1=CLASSIC (3-char), 2=COMPACT (full), 3=SLIM (full, small font)
	engine.mp_set_nametag_mode(3)
	
func _start_server_only() -> void:
	godot_menu_layer.visible = false
	"""var port := 42424
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--port="):
			port = int(arg.substr(7))"""
	_start_mp_server(self)
	

func _on_browse_pressed() -> void:
	game_path_file_dialog.popup_centered_ratio(0.75)

func _on_dir_selected(dir: String) -> void:
	game_path.text = dir

func _on_audio_volume_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(
		AudioServer.get_bus_index("Master"),
		linear_to_db(value / 100.0)
	)

func _on_save_and_run() -> void:
	save_and_run.disabled = true
	_save_settings()
	Transition.custom(_launch_game, TransitionPresets.get_slow_fade())

func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("game",        "path",         game_path.text.strip_edges())
	cfg.set_value("game",        "window_scale", window_scale.selected)
	cfg.set_value("audio",       "volume",       audio_slider.value)
	cfg.set_value("multiplayer", "enabled",      mp_enable.button_pressed)
	cfg.set_value("multiplayer", "name",         mp_name.text.strip_edges())
	cfg.set_value("multiplayer", "enable_chat",  enable_chat.button_pressed)
	cfg.save(_SETTINGS_PATH)

func _start_engine_watcher() -> void:
	if _watch_timer:
		_watch_timer.stop()
		_watch_timer.queue_free()
	_watch_timer = Timer.new()
	_watch_timer.wait_time = 0.5
	_watch_timer.one_shot = false
	_watch_timer.timeout.connect(_on_watch_timer_timeout)
	add_child(_watch_timer)
	_watch_timer.start()

func _on_watch_timer_timeout() -> void:
	if engine.is_running():
		return
	_watch_timer.stop()
	_watch_timer.queue_free()
	_watch_timer = null
	_on_engine_stopped()

func _on_engine_stopped() -> void:
	Transition.outro()
	godot_menu_layer.visible = true
	engine_layer.visible     = false
	save_and_run.disabled = false
	if client_node:
		client_node.close_connection()
		client_node.queue_free()
		client_node = null
	if server_node:
		server_node.stop()
		server_node.queue_free()
		server_node = null
	chat_ctrl.disable_overlay()
	%ToolbarLayer.visible = false

func _launch_game() -> void:
	var path := game_path.text.strip_edges()
	if path.is_empty():
		push_warning("[main] Game path is empty")
		return
	
	engine.set_game_path(path)
	_on_audio_volume_changed(audio_slider.value)
	engine.start_game()
	
	%ToolbarLayer.visible = true
	%ChatToggle.button_pressed = enable_chat.button_pressed
	if %ChatToggle.button_pressed:
		%ChatToggle.icon = preload("res://resources/chat-on.png")
	else:
		%ChatToggle.icon = preload("res://resources/chat-off.png")
	
	godot_menu_layer.visible = false
	engine_layer.visible     = true
	if enable_chat.button_pressed:
		chat_ctrl.enable_overlay()
		
	
	_start_engine_watcher()
	
	if mp_enable.button_pressed:
		if client_node:
			client_node.close_connection()
			client_node.queue_free()
		if server_node:
			server_node.stop()
			server_node.queue_free()
			server_node = null
		
		if mp_host_lobby.button_pressed:
			_start_mp_server(self)
		else:
			_start_mp_client(engine)


func _on_mp_enable_toggled(toggled_on: bool) -> void:
	mp_name.editable = toggled_on

# p4o-a7o: this is connected from the signals menu if that matters
func _on_window_scale_changed(index: int) -> void:
	var window := get_window()
	var scale := index+1
	window.size = Vector2(640, 480) * scale
