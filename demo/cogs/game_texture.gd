extends TextureRect

@export var engine: RPGMakerPlayer

## should i put it inside gdextention cpp code?

func _process(_delta: float) -> void:
	if engine.is_running():
		self.texture = engine.get_frame_texture()
