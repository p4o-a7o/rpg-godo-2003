extends Node

var game_path: String
var connected_to_game: bool = false

const main_theme := preload("res://resources/theme.tres")
const main_theme_2 := preload("res://resources/theme_outlined_panel.tres")
const sys_gradient := preload("res://resources/sys_gradient.tres")

# This is needed so I can read the color palette of the PNG file
# so I can reliably determine which color is the transparent color
#
# addendum: heres hoping this isnt subject to endianness or 
# native platform integer width or some nonsense i guess lol
# maybe i should take a look at godot and see if its fixed width or not
const PNG_HEADER_BYTES: int = 727905341920923785

func is_palette_chunk(chunk_type_bytes: PackedByteArray) -> bool:
	# "PLTE"
	return \
		chunk_type_bytes[0] == 0x50 and \
		chunk_type_bytes[1] == 0x4C and \
		chunk_type_bytes[2] == 0x54 and \
		chunk_type_bytes[3] == 0x45

func is_transparency_chunk(chunk_type_bytes: PackedByteArray) -> bool:
	# "tRNS"
	return \
		chunk_type_bytes[0] == 0x74 and \
		chunk_type_bytes[1] == 0x52 and \
		chunk_type_bytes[2] == 0x4E and \
		chunk_type_bytes[3] == 0x53

func is_srgb_chunk(chunk_type_bytes: PackedByteArray) -> bool:
	# "sRGB"
	return \
		chunk_type_bytes[0] == 0x73 and \
		chunk_type_bytes[1] == 0x52 and \
		chunk_type_bytes[2] == 0x47 and \
		chunk_type_bytes[3] == 0x42

func is_header_chunk(chunk_type_bytes: PackedByteArray) -> bool:
	# "IHDR"
	return \
		chunk_type_bytes[0] == 0x49 and \
		chunk_type_bytes[1] == 0x48 and \
		chunk_type_bytes[2] == 0x44 and \
		chunk_type_bytes[3] == 0x52

# TODO this is slow as hell i think
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
	var has_transparency: bool = false
	#var is_srgb: bool = false
	
	# See https://www.libpng.org/pub/png/spec/1.2/PNG-Chunks.html
	var cursor: int = 8
	var eof: int = sys_blob.size()
	while cursor < eof:
		sys_blob.bswap32(cursor, 1)
		var chunk_size := sys_blob.decode_u32(cursor)
		cursor += 4
		var chunk_type_bytes := sys_blob.slice(cursor, cursor + 4)
		cursor += 4
		#Log.debug("Chunk size: %d bytes, Chunk type code: %s" % [chunk_size, chunk_type_bytes.get_string_from_ascii()])
		var chunk_data := sys_blob.slice(cursor, cursor + chunk_size)
		if is_header_chunk(chunk_type_bytes):
			var color_type: int = chunk_data.decode_u8(9)
			if color_type == 6: # 2 + 4 = 6, 2 = color used, 4 = alpha channel used
				Log.debug("System graphic color mode = 6, has alpha channel")
				has_transparency = true
				# we can just stop here immediately because
				# its clear it has an alpha channel so we
				# don't need to edit the image at all
				break
		elif is_palette_chunk(chunk_type_bytes):
			found_palette = true
			#Log.debug("Found palette chunk")
			var r := chunk_data.decode_u8(0)
			var g := chunk_data.decode_u8(1)
			var b := chunk_data.decode_u8(2)
			#Log.debug("First color in palette: %d %d %d" % [r,g,b])
			transparent_color = Color.from_rgba8(r, g, b)
		elif is_transparency_chunk(chunk_type_bytes):
			has_transparency = true
			Log.info("[UIThemeUpdater] Found transparency chunk")
		# should i even check for this?
		"""elif is_srgb_chunk(chunk_type_bytes):
			is_srgb = true
			Log.info("[UIThemeUpdater] Found sRGB chunk")"""
		cursor += chunk_size
		cursor += 4 # skip CRC chunk
	
	if not has_transparency and not found_palette:
		Log.error("[UIThemeUpdater]: Non-transparent system graphic with no color palette. Weird system graphic")
		return null
	
	var img := Image.new()
	var err := img.load(file_path)
	if err != OK:
		Log.error("[UIThemeUpdater] Couldn't load system graphic from file: %s" % error_string(err))
		return
	
	if not has_transparency:
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

# TODO .bmp, .xyz
func update_menu_theme(system_name: String) -> void:
	var file_path: String = game_path + "/System/" + system_name + ".png"
	Log.info("[UIThemeUpdater] System graphic path: %s" % file_path)
	var tex := _read_system_graphic(file_path)
	if not tex:
		Log.error("[UIThemeUpdater] Failed to update menu theme")
		return
	
	change_all_textures(main_theme, tex)
	change_all_textures(main_theme_2, tex)
	# p4o-a7o: special case just for the system gradient
	# since its an AtlasTexture
	# probably need to do this for some of the
	# others as well
	var gradient_atlas := AtlasTexture.new()
	gradient_atlas.atlas = tex
	gradient_atlas.region = Rect2(0.0, 48.0, 16.0, 16.0) # same region
	change_all_textures(sys_gradient, gradient_atlas)


func change_all_textures(theme: Theme, new_texture: Texture2D) -> void:
	# p4o-a7o: There absolutely has to be a better way to do this lol
	# if anyone finds a way please slunge this garbage ass code!
	# i just wanted to get this done any way possible when i wrote this
	# as i had already been working on some of this for days at that point
	for ctrl_type in theme.get_type_list():
		for stylebox_name in theme.get_stylebox_list(ctrl_type):
			var stylebox := theme.get_stylebox(stylebox_name, ctrl_type)
			if stylebox is StyleBoxTexture:
				var tex_stylebox := stylebox as StyleBoxTexture
				tex_stylebox.texture = new_texture

func connect_to_engine(engine: RPGMakerPlayer) -> void:
	if connected_to_game:
		return
	engine.player_system_changed.connect(update_menu_theme)
