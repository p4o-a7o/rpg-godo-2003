extends Node

var game_path: String
var connected_to_game: bool = false

const main_theme := preload("res://resources/theme.tres")
const main_theme_2 := preload("res://resources/theme_outlined_panel.tres")

# This is needed so I can read the color palette of the PNG file
# so I can reliably determine which color is the transparent color
const PNG_HEADER_BYTES: int = 727905341920923785

func is_palette_chunk(chunk_type_bytes: PackedByteArray) -> bool:
	# "PLTE"
	return \
		chunk_type_bytes[0] == 0x50 and \
		chunk_type_bytes[1] == 0x4C and \
		chunk_type_bytes[2] == 0x54 and \
		chunk_type_bytes[3] == 0x45

func _read_system_graphic(file_path: String) -> ImageTexture:
	var sys_blob: PackedByteArray = FileAccess.get_file_as_bytes(file_path)
	var open_err := FileAccess.get_open_error()
	if open_err != OK:
		Log.error("[UIThemeUpdater] Couldn't load system graphic from file: %s" % error_string(open_err))
		return null

	var is_valid_png := sys_blob.decode_u64(0) == PNG_HEADER_BYTES
	if not is_valid_png:
		Log.error("[UIThemeUpdater]: Not a valid PNG file")
		return null
	
	var transparent_color: Color
	var found_palette: bool = false
	
	var cursor: int = 8
	var eof: int = sys_blob.size()
	while cursor < eof:
		sys_blob.bswap32(cursor, 1)
		var chunk_size := sys_blob.decode_u32(cursor)
		cursor += 4
		var chunk_type_bytes := sys_blob.slice(cursor, cursor + 4)
		cursor += 4
		Log.debug("Chunk size: %d bytes, Chunk type code: %s" % [chunk_size, chunk_type_bytes.get_string_from_ascii()])
		var chunk_data := sys_blob.slice(cursor, cursor + chunk_size)
		if is_palette_chunk(chunk_type_bytes):
			found_palette = true
			Log.debug("Found palette chunk")
			var r := chunk_data.decode_u8(0)
			var g := chunk_data.decode_u8(1)
			var b := chunk_data.decode_u8(2)
			Log.debug("First color in palette: %d %d %d" % [r,g,b])
			transparent_color = Color.from_rgba8(r, g, b)
			break
		cursor += chunk_size
		cursor += 4 # skip CRC chunk
	
	if not found_palette:
		Log.error("[UIThemeUpdater]: System graphic does not contain a palette")
		return null
	
	var img := Image.new()
	var err := img.load(file_path)
	if err != OK:
		Log.error("[UIThemeUpdater] Couldn't load system graphic from file: %s" % error_string(err))
		return
	
	# ENSURE IT HAS AN ALPHA CHANNEL
	img.convert(Image.FORMAT_RGBA8)
	
	# now we make the transparent colors actually transparent
	var dim := img.get_size()
	for x in range(dim.x):
		for y in range(dim.y):
			var col := img.get_pixel(x, y)
			if col == transparent_color:
				img.set_pixel(x, y, Color.TRANSPARENT)
	
	# finally we can create the texture and be on our merry way
	return ImageTexture.create_from_image(img)

func update_menu_theme(system_name: String) -> void:
	var file_path: String = game_path + "/System/" + system_name + ".png"
	Log.info("[UIThemeUpdater] System graphic path: %s" % file_path)
	var tex := _read_system_graphic(file_path)
	if not tex:
		Log.error("[UIThemeUpdater] Failed to update menu theme")
		return
	
	for ctrl_type in main_theme.get_type_list():
		for stylebox_name in main_theme.get_stylebox_list(ctrl_type):
			var stylebox := main_theme.get_stylebox(stylebox_name, ctrl_type)
			if stylebox is StyleBoxTexture:
				var tex_stylebox := stylebox as StyleBoxTexture
				tex_stylebox.texture = tex


func connect_to_engine(engine: RPGMakerPlayer) -> void:
	if connected_to_game:
		return
	engine.player_system_changed.connect(update_menu_theme)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
