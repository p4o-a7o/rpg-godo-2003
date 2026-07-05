class_name MultiplayerHandler
extends Node

var sender: Sender
var client: EasyClientSteam
var engine: RPGMakerPlayer

var enable_sounds: bool = true
var enable_chat: bool = false
var mute_audio: bool = false
var moving_queue_limit: int = 4

# TODO set these values
var local_x: int = 0
var local_y: int = 0

class OtherPlayer:
	var id: int = -1
	var display_name: String = ""
	var sprite_name: String = ""
	var sprite_index: int = 0
	var facing: int = 2 # DOWN (RPGMaker default)
	var speed: int = 4 # normal speed
	var transparency: int = 0
	var hidden: bool = false
	var system_name: String = ""
	var x: int = 0
	var y: int = 0

# every sound from this list has reduced distance attenuation
const _INST_SET: Dictionary = {
	"kalimba_c3": true, "kalimba_c#3": true, "kalimba_d3": true,
	"kalimba_d#3": true, "kalimba_e3": true, "kalimba_f3": true,
	"kalimba_f#3": true, "kalimba_g3": true, "kalimba_g#3": true,
	"kalimba_a3": true, "kalimba_a#3": true, "kalimba_b3": true,
	"kalimba_c4": true, "kalimba_c#4": true, "kalimba_d4": true,
	"kalimba_d#4": true, "kalimba_e4": true, "kalimba_f4": true,
	"kalimba_f#4": true, "kalimba_g4": true, "kalimba_g#4": true,
	"kalimba_a4": true, "kalimba_a#4": true, "kalimba_b4": true,
	"kalimba_c5": true, "kalimba_c#5": true, "kalimba_d5": true,
	"kalimba_d#5": true, "kalimba_e5": true,
}

var _players: Dictionary = {}
var _dc_players: Array = []
var _pending_spawn: Array = []

var _sync_switches: Array = []
var _sync_vars: Array = []
var _sync_events: Array = []
var _sync_action_events: Array = []
var _sync_picture_names: Array = []
var _global_sync_pic_names: Array = []
var _global_sync_pic_pfx: Array = []
var _sync_battle_anim_ids: Array = []
var _sync_picture_cache: Dictionary = {}

var _frame_index: int = 0
var _last_flash_frame_index: int = -1
var _last_frame_flash: Array = []
var _repeating_flashes: Dictionary = {}

func mp_ready() -> void:
	engine.mp_notify_room_ready()
	engine.mp_set_session_active(true)
	engine.mp_sync_local_player()
	pass

func reset() -> void:
	if engine and engine.is_running():
		for id in _players.keys():
			engine.mp_remove_player(id)
	_players.clear()
	_dc_players.clear()
	_pending_spawn.clear()
	_sync_switches.clear()
	_sync_vars.clear()
	_sync_events.clear()
	_sync_action_events.clear()
	_sync_picture_names.clear()
	_sync_picture_cache.clear()
	_repeating_flashes.clear()
	_frame_index = 0
	_last_flash_frame_index = -1
	_last_frame_flash = []

func _on_packet(type: String, args: Array) -> void:
	match type:
		"s": _handle_sync_player_data(args)
		"ri": _handle_room_info(args)
		"d": _handle_disconnect(args)
		"m": _handle_move(args)
		"jmp": _handle_jump(args)
		"f": _handle_facing(args)
		"spd": _handle_speed(args)
		"spr": _handle_sprite(args)
		"fl": _handle_flash(args)
		"rfl": _handle_repeating_flash(args)
		"rrfl": _handle_remove_repeating_flash(args)
		"tr": _handle_transparency(args)
		"h": _handle_hidden(args)
		"sys": _handle_system(args)
		"se": _handle_se(args)
		"ss": _handle_sync_switch(args)
		"sv": _handle_sync_variable(args)
		"sev": _handle_sync_event(args)
		"sp": _handle_sync_picture(args)
		"pns": _handle_name_list_sync(args)
		"bas": _handle_battle_anim_id_list(args)
		"name": _handle_name(args)
		"chat": _handle_chat(args)
		
		# server-only packets below this line
		"sr": _handle_sr(args)
		"chaton": pass # stub because we dont handle chaton here
		
		_:
			Log.warn("[MultiplayerHandler] unknown packet '%s' args=%s" % [type, str(args)])

func _is_pending(id: int) -> bool:
	return id in _pending_spawn

func _process(delta: float) -> void:
	_do_pending_spawns()
	_update_frame()

func _update_frame() -> void:
	_frame_index += 1
	
	for id in _repeating_flashes:
		if _players.has(id) and engine:
			var f: Array = _repeating_flashes[id]
			engine.mp_flash_player(id, f[0], f[1], f[2], f[3], f[4])

func _do_mp_add_player(id: int) -> bool:
	if not _players.has(id):
		return true
	if engine == null or not engine.is_running():
		return false
	if not engine.is_map_ready():
		return false
	var p: OtherPlayer = _players[id]
	Log.info("[MultiplayerHandler] spawning id=%d pos=(%d,%d) spr='%s'[%d]" \
		% [id, p.x, p.y, p.sprite_name, p.sprite_index])
	engine.mp_add_player(id, p.x, p.y, p.sprite_name, p.sprite_index, p.facing, p.speed)
	if p.transparency > 0:
		engine.mp_set_player_transparency(id, p.transparency)
	if p.hidden:
		engine.mp_set_player_hidden(id, true)
	if p.display_name != "":
		engine.mp_set_player_name(id, p.display_name)
	if p.system_name != "":
		engine.mp_set_player_system_graphic(id, p.system_name)
	return true

func _do_pending_spawns() -> void:
	if _pending_spawn.is_empty() or engine == null or not engine.is_running():
		return
	var r: int = 0
	for i in range(_pending_spawn.size()):
		var id: int = _pending_spawn[i-r]
		if _players.has(id):
			if _do_mp_add_player(id):
				print("Okay bro")
				_pending_spawn.pop_at(i-r)
				r += 1

func _spawn_player(id: int) -> void:
	Log.debug("[MultiplayerHandler] queuing spawn for id=%d" % id)
	var p := OtherPlayer.new()
	p.id = id
	_players[id] = p
	if id not in _pending_spawn:
		_pending_spawn.append(id)

func _remove_player(id: int) -> void:
	if not _players.has(id):
		return
	_dc_players.append(_players[id])
	_players.erase(id)
	_repeating_flashes.erase(id)
	if engine:
		engine.mp_remove_player(id)

# Client (non-host) only
func _handle_room_info(args: Array) -> void:
	if args.is_empty():
		return
	var room_id := int(args[0])
	if room_id != sender._local_room_id:
		# TODO
		Log.warn("[MultiplayerHandler] wrong room %d (expected %d)" % [room_id, sender._local_room_id])
		#connect_to_room(_room_id)
		return
	Log.info("[MultiplayerHandler] room %d confirmed" % room_id)
	if engine and engine.is_running():
		engine.mp_notify_room_ready()

# Client (non-host) only
func _handle_sync_player_data(_args: Array) -> void:
	Log.info("[MultiplayerHandler] session ready")
	if not client:
		Log.error("[MultiplayerHandler] Received player data sync, but client is null!")
		return
	client._my_pid = int(_args[1])
	if engine and engine.is_running():
		engine.mp_sync_local_player()
	sender.send_basic_data()
	sender._send_message("sr", [str(sender._local_room_id)])
	sender._send_message("chaton", ["1" if enable_chat else "0"])

# Server host only
func _handle_sr(_args: Array) -> void:
	var pid := int(_args[0])
	var new_room_id := int(_args[1])
	if new_room_id != sender._local_room_id:
		_remove_player(pid)

func _handle_disconnect(args: Array) -> void:
	if args.is_empty():
		return
	var id := int(args[0])
	Log.info("[MultiplayerHandler] player DISCONNECT id=%d" % id)
	_remove_player(id)

func _handle_move(args: Array) -> void:
	if args.size() < 3:
		return
	var id := int(args[0])
	var x := int(args[1])
	var y := int(args[2])
	if not _players.has(id):
		Log.debug("[MultiplayerHandler] late spawn for id=%d on first move" % id)
		_spawn_player(id)
	_players[id].x = x
	_players[id].y = y
	if _is_pending(id):
		return
	if engine and engine.is_running():
		engine.mp_move_player(id, x, y)

func _handle_jump(args: Array) -> void:
	if args.size() < 3:
		return
	var id := int(args[0])
	if not _players.has(id):
		return
	if engine:
		engine.mp_move_player(id, int(args[1]), int(args[2]))

func _handle_facing(args: Array) -> void:
	if args.size() < 2:
		return
	var id := int(args[0])
	var facing := clampi(int(args[1]), 0, 3)
	if not _players.has(id):
		return
	_players[id].facing = facing
	if _is_pending(id):
		return
	if engine:
		engine.mp_set_player_facing(id, facing)

func _handle_speed(args: Array) -> void:
	if args.size() < 2:
		return
	var id := int(args[0])
	var speed := clampi(int(args[1]), 1, 6)
	if not _players.has(id):
		return
	_players[id].speed = speed
	if _is_pending(id):
		return
	if engine:
		engine.mp_set_player_speed(id, speed)

func _handle_sprite(args: Array) -> void:
	if args.size() < 3:
		return
	var id := int(args[0])
	var spr_name := args[1] as String
	var index := clampi(int(args[2]), 0, 7)
	if not _players.has(id):
		return
	_players[id].sprite_name = spr_name
	_players[id].sprite_index = index
	if _is_pending(id):
		return
	if engine:
		engine.mp_set_player_sprite(id, spr_name, index)

func _handle_flash(args: Array) -> void:
	if args.size() < 6:
		return
	var id := int(args[0])
	if not _players.has(id) or _is_pending(id):
		return
	if engine:
		engine.mp_flash_player(id,
			int(args[1]), int(args[2]), int(args[3]), int(args[4]), int(args[5]))

func _handle_repeating_flash(args: Array) -> void:
	if args.size() < 6:
		return
	var id := int(args[0])
	var flash := [int(args[1]), int(args[2]), int(args[3]), int(args[4]), int(args[5])]
	if not _players.has(id):
		return
	_repeating_flashes[id] = flash
	if _is_pending(id):
		return
	if engine:
		engine.mp_flash_player(id, flash[0], flash[1], flash[2], flash[3], flash[4])

func _handle_remove_repeating_flash(args: Array) -> void:
	if args.is_empty():
		return
	_repeating_flashes.erase(int(args[0]))

func _handle_transparency(args: Array) -> void:
	if args.size() < 2:
		return
	var id := int(args[0])
	var t := clampi(int(args[1]), 0, 7)
	if not _players.has(id):
		return
	_players[id].transparency = t
	if _is_pending(id):
		return
	if engine:
		engine.mp_set_player_transparency(id, t)

func _handle_hidden(args: Array) -> void:
	if args.size() < 2:
		return
	var id := int(args[0])
	var hidden := int(args[1]) == 1
	if not _players.has(id):
		return
	_players[id].hidden = hidden
	if _is_pending(id):
		return
	if engine:
		engine.mp_set_player_hidden(id, hidden)

func _handle_system(args: Array) -> void:
	if args.size() < 2:
		return
	var id := int(args[0])
	var sys_name := args[1] as String
	if _players.has(id):
		_players[id].system_name = sys_name
	if engine and engine.is_running() and engine.is_map_ready():
		engine.mp_set_player_system_graphic(id, sys_name)

func _handle_se(args: Array) -> void:
	if args.size() < 5:
		return
	if not enable_sounds or mute_audio:
		return
	if engine == null or not engine.is_running():
		return
	
	var id := int(args[0])
	var snd_name := args[1] as String
	var snd_volume := int(args[2])
	var snd_tempo := int(args[3])
	var snd_balance := int(args[4])
	
	if not _players.has(id):
		return
	var p: OtherPlayer = _players[id]
	
	var px := local_x
	var py := local_y
	var ox := p.x
	var oy := p.y
	var rx := px - ox
	var ry := py - oy
	var dist := sqrt(float(rx * rx + ry * ry))
	if _INST_SET.has(snd_name):
		dist = maxf(0.0, dist - 7.0)
	
	var dist_volume := 75.0 - dist * 10.0
	var real_volume := maxi(int(dist_volume * float(snd_volume) / 100.0), 0)
	if real_volume <= 0:
		return
	
	engine.mp_play_se(snd_name, real_volume, snd_tempo, snd_balance)

func _handle_sync_switch(args: Array) -> void:
	if args.size() < 2:
		return
	var sw_id := int(args[0])
	var sync_type := int(args[1])
	if sync_type >= 1 and sw_id not in _sync_switches:
		_sync_switches.append(sw_id)

func _handle_sync_variable(args: Array) -> void:
	if args.size() < 2:
		return
	var var_id := int(args[0])
	var sync_type := int(args[1])
	if sync_type >= 1 and var_id not in _sync_vars:
		_sync_vars.append(var_id)

func _handle_sync_event(args: Array) -> void:
	if args.size() < 2:
		return
	var ev_id := int(args[0])
	var trig_type := int(args[1])
	if trig_type != 1 and ev_id not in _sync_events:
		_sync_events.append(ev_id)
	if trig_type >= 1 and ev_id not in _sync_action_events:
		_sync_action_events.append(ev_id)

func _handle_sync_picture(args: Array) -> void:
	if args.is_empty():
		return
	var pic_name := args[0] as String
	if pic_name not in _sync_picture_names:
		_sync_picture_names.append(pic_name)

func _handle_name_list_sync(args: Array) -> void:
	if args.is_empty():
		return
	match int(args[0]):
		0: _global_sync_pic_names = args.slice(1)
		1: _global_sync_pic_pfx = args.slice(1)

func _handle_battle_anim_id_list(args: Array) -> void:
	_sync_battle_anim_ids = args.map(func(s): return int(s))

func _handle_name(args: Array) -> void:
	if args.size() < 2:
		return
	var id := int(args[0])
	var n := args[1] as String
	if _players.has(id):
		_players[id].display_name = n
		Log.debug("[MultiplayerHandler] player %d name='%s'" % [id, n])
	if engine and engine.is_running() and engine.is_map_ready():
		engine.mp_set_player_name(id, n)

func _handle_chat(args: Array) -> void:
	if args.size() < 2:
		return
	var id := int(args[0])
	var msg := args[1] as String
	if msg.length() > 100:
		Log.warn("[MultiplayerHandler] Attempt to send message over 100 characters from PID %d" % id)
		return
	var display_name := "Unnamed"
	if not _players.has(id):
		if id != 0: # FIXME
			Log.warn("[MultiplayerHandler] got chat message from unknown PID: %d" % id)
			return
	else:
		display_name = _players[id].display_name
	MpEvents.on_chat_message.emit(display_name, msg)
