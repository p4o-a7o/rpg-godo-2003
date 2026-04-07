class_name AudioOutput
extends Node

@export var engine: Node = null

var _stream_player: AudioStreamPlayer = null
var _playback: AudioStreamGeneratorPlayback = null
var _connected_engine: Node = null

func _ready() -> void:
	if engine != null:
		attach(engine)

func _process(_delta: float) -> void:
	if _playback == null or _connected_engine == null:
		return
	var available: int = _playback.get_frames_available()
	if available <= 0:
		return
	var frames: PackedFloat32Array = _connected_engine.audio_pull_frames(available)
	if frames.is_empty():
		return
	
	var frame_count: int = frames.size() / 2
	for i in range(frame_count):
		_playback.push_frame(Vector2(frames[i * 2], frames[i * 2 + 1]))

func _exit_tree() -> void:
	detach()

func attach(e: Node) -> void:
	detach()
	
	_connected_engine = e
	var sample_rate: int = e.get_audio_sample_rate()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = float(sample_rate)
	gen.buffer_length = 0.1
	
	_stream_player = AudioStreamPlayer.new()
	_stream_player.stream = gen
	_stream_player.autoplay = true
	add_child(_stream_player)
	_stream_player.play()
	_playback = _stream_player.get_stream_playback() as AudioStreamGeneratorPlayback
	Log.info("AudioOutput: attached to %s (sample_rate=%d)" % [e.name, sample_rate])

func detach() -> void:
	_connected_engine = null
	if _stream_player != null and is_instance_valid(_stream_player):
		_stream_player.stop()
		_stream_player.queue_free()
	_stream_player = null
	_playback = null
