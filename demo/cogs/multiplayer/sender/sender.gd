@abstract
class_name Sender
extends RefCounted

# p4o-a7o: This is an attempt at reducing some boilerplate

var _local_room_id: int = -1

var _sync_switches: Array = []
var _sync_vars: Array = []
var _sync_events: Array = []
var _sync_action_events: Array = []

var _frame_index: int = 0
var _last_flash_frame_index: int = -1
var _last_frame_flash: Array = []

# local player state (from RPGMakerPlayer signals)
var _local_x: int = 0
var _local_y: int = 0
var _local_speed: int = 4
var _local_sprite_name: String = ""
var _local_sprite_index: int = 0
var _local_facing: int = 2
var _local_hidden: bool = false
var _local_system_name: String = ""

var _player_name: String = ""

const PARAM_DELIM := "\uFFFF" # separates fields within one message

func _sanitize(s: String) -> String:
	return s.replace(PARAM_DELIM, "")

static func _build(type: String, args: Array = []) -> String:
	var s := type
	for a in args:
		s += PARAM_DELIM + str(a)
	return s

@abstract func _send_message(type: String, args: Array = [], flags: int = Steam.NETWORKING_SEND_UNRELIABLE_NO_DELAY)
@abstract func _switching_room(old_room_id: int, new_room_id: int)

func send_basic_data() -> void:
	Log.debug("[Sender] sending basic data pos=(%d,%d) spr='%s'[%d]" \
		% [_local_x, _local_y, _local_sprite_name, _local_sprite_index])
	_send_message("m", [str(_local_x), str(_local_y)], Steam.NETWORKING_SEND_RELIABLE_NO_NAGLE)
	_send_message("spd", [str(_local_speed)], Steam.NETWORKING_SEND_RELIABLE_NO_NAGLE)
	_send_message("spr", [_sanitize(_local_sprite_name), str(_local_sprite_index)], Steam.NETWORKING_SEND_RELIABLE_NO_NAGLE)
	_send_message("f", [str(_local_facing)], Steam.NETWORKING_SEND_RELIABLE_NO_NAGLE)
	_send_message("h", [str(1 if _local_hidden else 0)], Steam.NETWORKING_SEND_RELIABLE_NO_NAGLE)
	if _local_system_name != "":
		_send_message("sys", [_sanitize(_local_system_name)], Steam.NETWORKING_SEND_RELIABLE_NO_NAGLE)
	if _player_name != "":
		_send_message("name", [_sanitize(_player_name)], Steam.NETWORKING_SEND_RELIABLE_NO_NAGLE)

func _on_local_moved(x: int, y: int) -> void:
	_local_x = x
	_local_y = y
	_send_message("m", [str(x), str(y)])

func _on_local_facing(dir: int) -> void:
	_local_facing = dir
	_send_message("f", [str(dir)])

func _on_local_speed(spd: int) -> void:
	_local_speed = spd
	_send_message("spd", [str(spd)])

func _on_local_sprite(spr_name: String, index: int) -> void:
	_local_sprite_name = spr_name
	_local_sprite_index = index
	_send_message("spr", [_sanitize(spr_name), str(index)])

func _on_local_jumped(x: int, y: int) -> void:
	_send_message("jmp", [str(x), str(y)])

func _on_local_flashed(r: int, g: int, b: int, power: int, frames: int) -> void:
	var flash := [r, g, b, power, frames]
	var is_continuation := (
		_last_flash_frame_index > -1
		and _frame_index - _last_flash_frame_index <= 1
		and (_last_frame_flash.is_empty() or _last_frame_flash == flash)
	)
	if is_continuation:
		if _last_frame_flash.is_empty():
			_last_frame_flash = flash
			_send_message("rfl", [str(r), str(g), str(b), str(power), str(frames)])
	else:
		_send_message("fl", [str(r), str(g), str(b), str(power), str(frames)])
		_last_frame_flash = []
	_last_flash_frame_index = _frame_index

func _on_local_transparency(t: int) -> void:
	_send_message("tr", [str(t)])

func _on_local_hidden(hidden: bool) -> void:
	_local_hidden = hidden
	_send_message("h", [str(1 if hidden else 0)])

func _on_local_teleported(map_id: int, x: int, y: int) -> void:
	Log.debug("[Sender] local teleported map=%d (%d,%d)" % [map_id, x, y])
	_local_x = x
	_local_y = y
	_send_message("tp", [str(x), str(y)])

func _on_local_se(snd_name: String, volume: int, tempo: int, balance: int) -> void:
	_send_message("se", [_sanitize(snd_name), str(volume), str(tempo), str(balance)])

func _on_local_system(sys_name: String) -> void:
	_local_system_name = sys_name
	_send_message("sys", [_sanitize(sys_name)])

func _on_map_changed(map_id: int) -> void:
	var old_room_id = _local_room_id
	_local_room_id = map_id
	_switching_room(old_room_id, map_id)

func _on_switch_set(switch_id: int, value: int) -> void:
	if switch_id in _sync_switches:
		_send_message("ss", [str(switch_id), str(value)])

func _on_variable_set(var_id: int, value: int) -> void:
	if var_id in _sync_vars:
		_send_message("sv", [str(var_id), str(value)])

func _on_event_triggered(event_id: int, action: bool) -> void:
	if action:
		if event_id in _sync_action_events:
			_send_message("sev", [str(event_id), "1"])
	else:
		if event_id in _sync_events:
			_send_message("sev", [str(event_id), "0"])
