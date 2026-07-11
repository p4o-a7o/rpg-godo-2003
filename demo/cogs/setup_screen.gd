class_name SetupScreen
extends Control

@onready var godot_menu_layer: CanvasLayer = %GodotMenuLayer
@onready var engine_layer: CanvasLayer = %EngineLayer
@onready var game_path: LineEdit = %GamePath
@onready var game_path_button: Button = %GamePathButton
@onready var game_path_file_dialog: FileDialog = %GamePathFileDialog
@onready var audio_slider: HSlider = %AudioSlider
@onready var mp_name: LineEdit = %MpName
@onready var save_and_host: Button = %SaveAndHost
@onready var save_and_join: Button = %SaveAndJoin
@onready var enable_chat: CheckBox = %EnableChat
@onready var chat_ctrl: ChatOverlay = %ChatControl
@onready var chat_layer: CanvasLayer = %ChatOverlayLayer
@onready var chat_vbox: VBoxContainer = %MessageContainer
@onready var chat_field: LineEdit = %ChatField
@onready var window_scale: OptionButton = %WindowScale
@onready var lobby_browser: LobbyBrowser = %LobbyBrowser
@onready var host_options: HostOptionsScreen = %HostOptions
@onready var setup_controls: Node = %SetupControls

@export var engine: Node

const _SETTINGS_PATH := "user://main_settings.cfg"

var _watch_timer: Timer = null
var _steam_fails: int = 0

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
	mp_name.text = cfg.get_value("multiplayer", "name", "Minnatsuki")
	window_scale.selected = cfg.get_value("game", "window_scale", 0)
	enable_chat.button_pressed = cfg.get_value("multiplayer", "enable_chat", false)
	
	var window := get_window()
	var scale := window_scale.selected+1
	window.size = Vector2(640, 480) * scale
	
	game_path_button.pressed.connect(_on_browse_pressed)
	game_path_file_dialog.dir_selected.connect(_on_dir_selected)
	audio_slider.value_changed.connect(_on_audio_volume_changed)
	save_and_host.pressed.connect(_on_save_and_host)
	save_and_join.pressed.connect(_on_save_and_join)
	
	Steamworks.steam_connected.connect(func():
		var notif: Notification = %NotificationsControl.create_notification()
		notif.set_notification_body("Connected to Steam")
		notif.start_timer()
	)
	Steamworks.steam_connect_failed.connect(func():
		_steam_fails += 1
		if _steam_fails % 3 == 0:
			var notif: Notification = %NotificationsControl.create_notification()
			notif.set_notification_body("It looks like we can't connect to Steam! Open console with the \"`\" key for error details!")
			notif.set_notification_expires(false)
	)
	Steamworks._try_init_steam()
	UIThemeUpdater.game_path = game_path.text
	
	# TODO Why the fuck does the unique node path
	# just not work in these classes? why???
	EasyServerSteam.notif_manager = %NotificationsControl
	EasyClientSteam.notif_manager = %NotificationsControl
	EasyClientSteam.engine = engine
	EasyServerSteam.engine = engine
	#if args.has("--autorun") or run_on_start.button_pressed:
	#	_launch_game()

func _on_relay_status(available: bool, status_code: int, debug_message: String) -> void:
	if available:
		%MultiplayerOptions.visible = true
		%AvailabilityPanel.visible = false
	else:
		%AvailabilityText.text = "Multiplayer availability check failed with message: %s (Code: %s)" % [debug_message, status_code]

func _start_mp_server() -> void:
	if EasyServerSteam.is_running():
		EasyServerSteam.stop()
	EasyServerSteam.name = "MpServerNode"
	EasyServerSteam.engine = engine
	if not EasyServerSteam.start():
		Log.error("[setup_screen] Failed to start server for some reason")
	EasyServerSteam.chat_overlay = chat_ctrl
	# You are the host so theres no point in being able
	# to click the reload button, in fact, it would not do anything
	%ReconnectButton.disabled = true

func _start_mp_client() -> void:
	%ReconnectButton.disabled = false
	EasyClientSteam.engine = engine
	EasyClientSteam.enable_chat = enable_chat.button_pressed
	# nametag modes: 0=NONE, 1=CLASSIC (3-char), 2=COMPACT (full), 3=SLIM (full, small font)
	engine.mp_set_nametag_mode(3)
	
func _start_server_only() -> void:
	godot_menu_layer.visible = false
	"""var port := 42424
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--port="):
			port = int(arg.substr(7))"""
	_start_mp_server()
	

func _on_browse_pressed() -> void:
	game_path_file_dialog.popup_centered_ratio(0.75)

func _on_dir_selected(dir: String) -> void:
	game_path.text = dir
	UIThemeUpdater.game_path = dir

func _on_audio_volume_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(
		AudioServer.get_bus_index("Master"),
		linear_to_db(value / 100.0)
	)

# TODO: nudge game path box when its empty or invalid

func _on_save_and_host() -> void:
	_save_settings()
	%SetupControls.hide()
	host_options.previous_screen = %SetupControls
	host_options.show()

func _on_save_and_join() -> void:
	%SetupControls.hide()
	_save_settings()
	lobby_browser.previous_screen = %SetupControls
	lobby_browser.show()
	lobby_browser.refresh()
	

func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("game",        "path",         game_path.text.strip_edges())
	cfg.set_value("game",        "window_scale", window_scale.selected)
	cfg.set_value("audio",       "volume",       audio_slider.value)
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
	save_and_join.disabled = false
	save_and_host.disabled = false
	if EasyClientSteam.client_connected():
		EasyClientSteam.close_connection()
	if EasyServerSteam.is_running():
		EasyServerSteam.stop()
	chat_ctrl.disable_overlay()
	%ToolbarLayer.visible = false

func _launch_game(host: bool = false) -> void:
	var path := game_path.text.strip_edges()
	if path.is_empty():
		push_warning("[main] Game path is empty")
		return
	
	MultiplayerHandler.player_name = mp_name.text
	# TODO remove when better solution is made
	MultiplayerHandler._player_names.clear()
	
	engine.set_game_path(path)
	_on_audio_volume_changed(audio_slider.value)
	engine.start_game()
	
	%ToolbarLayer.visible = true
	# Toolbar hint
	%ToolbarRoot.reveal_toolbar()
	get_tree().create_timer(2).timeout.connect(func():
		if %ToolbarRoot._toolbar_in_use:
			return
		%ToolbarRoot.hide_toolbar()
	)
	%ChatToggle.button_pressed = enable_chat.button_pressed
	
	godot_menu_layer.visible = false
	engine_layer.visible     = true
	if enable_chat.button_pressed:
		chat_ctrl.enable_overlay()
		
	
	_start_engine_watcher()
	
	if host:
		if EasyClientSteam.client_connected():
			EasyClientSteam.close_connection()
		_start_mp_server()
	else:
		if EasyServerSteam.is_running():
			EasyServerSteam.stop()
		_start_mp_client()
	
	UIThemeUpdater.connect_to_engine(engine)


func _on_mp_enable_toggled(toggled_on: bool) -> void:
	mp_name.editable = toggled_on

# p4o-a7o: this is connected from the signals menu if that matters
func _on_window_scale_changed(index: int) -> void:
	var window := get_window()
	var scale := index+1
	window.size = Vector2(640, 480) * scale
