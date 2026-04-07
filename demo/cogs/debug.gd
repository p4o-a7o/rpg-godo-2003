extends Node

@export var engine: RPGMakerPlayer

@export var game_resolution: Vector2i = Vector2i(320, 240):
	set(value):
		game_resolution = value
		if engine != null and engine.is_running():
			engine.set_resolution(value.x, value.y)

@export var open_save_menu: bool = false:
	set(value):
		if value:
			open_save_menu = false
			do_open_save_menu()

@export var open_load_menu: bool = false:
	set(value):
		if value:
			open_load_menu = false
			do_open_load_menu()

@export var open_debug_menu: bool = false:
	set(value):
		if value:
			open_debug_menu = false
			do_open_debug_menu()

func do_open_save_menu() -> void:
	var e := get_node_or_null("%RPGMakerPlayer") as RPGMakerPlayer
	if e and e.is_running(): e.open_save_menu()
	else: Log.error("Engine is not running!")

func do_open_load_menu() -> void:
	var e := get_node_or_null("%RPGMakerPlayer") as RPGMakerPlayer
	if e and e.is_running(): e.open_load_menu()
	else: Log.error("Engine is not running!")

func do_open_debug_menu() -> void:
	var e := get_node_or_null("%RPGMakerPlayer") as RPGMakerPlayer
	if e and e.is_running(): e.open_debug_menu()
	else: Log.error("Engine is not running!")

func set_resolution_scale(scale: float) -> void:
	var e := get_node_or_null("%RPGMakerPlayer") as RPGMakerPlayer
	if scale < 0.1 or scale > 5.:
		Log.error("Keep scale in range of [0.1, 5.0]")
	if e and e.is_running():
		var x: int = floor(320. * scale)
		var y: int = floor(240. * scale)
		e.set_resolution(x, y)
		Log.info("Rendering %d x %d pixels" % [x, y])
	else: Log.error("Engine is not running!")

func _add_limbo_commands() -> void:
	LimboConsole.register_command(do_open_save_menu, "save", "Open save screen")
	LimboConsole.register_command(do_open_load_menu, "load", "Open load screen")
	LimboConsole.register_command(do_open_debug_menu, "debug", "Open debug screen")
	LimboConsole.register_command(set_resolution_scale, "rescale", "Scales resolution to a given multiplier")

func _ready() -> void:
	if OS.is_debug_build():
		_add_limbo_commands()
