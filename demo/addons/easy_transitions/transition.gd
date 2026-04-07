extends CanvasLayer


## The transition manager, handling smooth scene transitions using shaders.

signal intro_started
signal outro_started
signal intro_ended
signal outro_ended
signal scene_changed


## The UI element where the transition shader is applied.
@onready var transition_rect: TextureRect = %TransitionRect

var is_playing = false

## Starts the intro transition (fade-in or other effect).
## This function shouldn't be called directly. Use [method change_scene_to_file] or [method change_scene_to_packed] instead.
func intro(settings : TransitionSettings = TransitionPresets.get_fast_fade()) -> void:
	layer = settings.layer
	intro_started.emit()
	
	var tween_settings := settings.outro_tween
	var material: ShaderMaterial = transition_rect.material
	
	if settings.texture:
		transition_rect.texture = settings.texture
		transition_rect.visible = true
	
	material.set_shader_parameter(&"pixel_size", settings.pixel_size)
	material.set_shader_parameter(&"reversed", tween_settings.reverse)
	material.set_shader_parameter(&"type", tween_settings.type)
	material.set_shader_parameter(&"progress", 0.0)
	
	var screen_size: Vector2i = get_viewport().size
	material.set_shader_parameter(&"screen_size", screen_size)
	
	var tween: Tween = get_tree().create_tween().set_ease(tween_settings.ease).set_trans(tween_settings.tween_transition).set_ignore_time_scale(true)
	tween.tween_property(material, ^"shader_parameter/progress", 1.0, tween_settings.duration / Engine.time_scale)
	
	Log.debug("Playing intro animation...")
	
	await tween.finished
	intro_ended.emit()


## Starts the outro transition (fade-out or other effect).
## This function shouldn't be called directly. Use [method change_scene_to_file] or [method change_scene_to_packed] instead.
func outro(settings : TransitionSettings = TransitionPresets.get_fast_fade()) -> void:
	outro_started.emit()
	
	var tween_settings := settings.outro_tween
	var material: ShaderMaterial = transition_rect.material
	
	material.set_shader_parameter(&"reversed", tween_settings.reverse)
	material.set_shader_parameter(&"type", tween_settings.type)
	material.set_shader_parameter(&"progress", 1.0)
	
	var tween: Tween = get_tree().create_tween().set_ease(tween_settings.ease).set_trans(tween_settings.tween_transition).set_ignore_time_scale(true)
	tween.tween_property(material, ^"shader_parameter/progress", 0.0, tween_settings.duration)
	
	Log.debug("Playing outro animation...")
	
	await tween.finished
	outro_ended.emit()


func _intro_part(settings : TransitionSettings):
	#var input_state := InputState.current_mode
	#InputState.current_mode = InputState.InputMode.LOCKED
	
	is_playing = true
	layer = settings.layer
	await intro(settings)
	
	#InputState.current_mode = input_state


func _outro_part(settings : TransitionSettings):
	if settings.hold > 0.0:
		Log.debug("Holding transition for %s seconds." % settings.hold)
		await get_tree().create_timer(settings.hold, true, false, true).timeout
	
	await outro(settings)
	is_playing = false


func custom(callback: Callable, settings : TransitionSettings = TransitionPresets.get_fast_fade()) -> void:
	if is_playing == true:
		return
	await _intro_part(settings)
	callback.call()
	_outro_part(settings)


## Changes the scene using the file path [param scene_path] using the [class TransitionSettings] [param settings].
func change_scene(scene_path: String, settings : TransitionSettings = TransitionPresets.get_fast_fade()) -> void:
	if is_playing == true:
		return
	await _intro_part(settings)
	
	Log.debug("Changing scene to " + scene_path)
	get_tree().change_scene_to_file(scene_path)
	scene_changed.emit()
	
	_outro_part(settings)


func change_visibility(prev_node, cur_node, settings : TransitionSettings = TransitionPresets.get_fast_fade()) -> void:
	if is_playing == true:
		return
	await _intro_part(settings)
	
	Log.debug("Swapping nodes visibility")
	prev_node.visible = false
	cur_node.visible = true
	scene_changed.emit()
	
	_outro_part(settings)


func add_scene(parent_node : Node, packed_scene : PackedScene, settings : TransitionSettings = TransitionPresets.get_fast_fade()) -> void:
	if is_playing == true:
		return
	await _intro_part(settings)
	
	Log.debug("Adding scene")
	parent_node.add_child(packed_scene.instantiate())
	scene_changed.emit()
	
	_outro_part(settings)


func pop_node(node : Node, settings : TransitionSettings = TransitionPresets.get_fast_fade()) -> void:
	if is_playing == true:
		return
	await _intro_part(settings)
	
	Log.debug("Remove node")
	node.queue_free()
	scene_changed.emit()
	
	_outro_part(settings)
