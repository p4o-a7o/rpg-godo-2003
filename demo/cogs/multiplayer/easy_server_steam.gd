class_name EasyServerSteam
extends Node

@export var auto_start: bool = false

const PARAM_DELIM := "\uFFFF" # separates fields within one message

class PeerEntry:
	var steam_id: int = -1
	var steam_conn_handle: int = -1
	# no more steam properties below this line
	
	var id: int = 0
	var room_id: int = 0
	var x: int = 0
	var y: int = 0
	var facing: int = 2
	var speed: int = 4
	var sprite_name: String = ""
	var sprite_idx: int = 0
	var hidden: bool = false
	var transparency: int = 0
	var sys_name: String = ""
	var display_name: String = ""
	var chat_enabled: bool = false # p4o-a7o: off by default
	
var engine: RPGMakerPlayer
var sender: ServerSender = ServerSender.new()

# PID 0 is reserved for the P2P host
var _next_pid: int = 1

var _started: bool = false
var _poll_group: int = -1
var _listen_handle: int = -1
var _lobby_id: int = -1

# Keys = handle to steam connection
var _peers: Dictionary[int, PeerEntry] = {}

# for reading and writing
var _work_buffer: StreamPeerBuffer = StreamPeerBuffer.new()

func _ready() -> void:
	_work_buffer.resize(16)
	Steam.network_connection_status_changed.connect(_on_net_connection_status_changed)
	Steam.lobby_created.connect(_on_lobby_created)
	if auto_start:
		start()
	sender._server = self
	_wire_player_signals()

# p4o-a7o: since you are the P2P host, the host
# will also need to broadcast itself to all other
# peers in the same room id as the host
func _wire_player_signals() -> void:
	var engine: RPGMakerPlayer =  %RPGMakerPlayer
	engine.player_moved.connect(sender._on_local_moved)
	engine.player_facing_changed.connect(sender._on_local_facing)
	engine.player_speed_changed.connect(sender._on_local_speed)
	engine.player_sprite_changed.connect(sender._on_local_sprite)
	engine.player_jumped.connect(sender._on_local_jumped)
	engine.player_flashed.connect(sender._on_local_flashed)
	engine.player_transparency_changed.connect(sender._on_local_transparency)
	engine.player_hidden_changed.connect(sender._on_local_hidden)
	engine.player_teleported.connect(sender._on_local_teleported)
	engine.player_se_played.connect(sender._on_local_se)
	engine.player_system_changed.connect(sender._on_local_system)
	engine.map_changed.connect(sender._on_map_changed)
	engine.switch_set.connect(sender._on_switch_set)
	engine.variable_set.connect(sender._on_variable_set)
	engine.event_triggered.connect(sender._on_event_triggered)

func start() -> bool:
	Log.debug("[EasyServer] start()")
	if _started:
		return true
	Steam.createLobby(Steam.LOBBY_TYPE_FRIENDS_ONLY, 10)
	_started = true
	return true
	
func stop() -> void:
	if not _started:
		return
	# TODO gracefully close connections?
	if _listen_handle > 0:
		Steam.closeListenSocket(_listen_handle)
	if _lobby_id > 0:
		Steam.leaveLobby(_lobby_id)

func is_running() -> bool:
	return _started

func _process(_delta: float):
	if _lobby_id > 0 and _listen_handle > 0:
		_receive_messages()

func _maybe_grow_buffer(buf: StreamPeerBuffer, num_bytes: int):
	var cursor: int = buf.get_position()
	if cursor+num_bytes > buf.get_size():
		if num_bytes+4 > 16:
			buf.resize(buf.get_size()+num_bytes+16+4)
		else:
			buf.resize(buf.get_size()+16)

func _slice_buf_to_cursor() -> PackedByteArray:
	return _work_buffer.data_array.slice(0, _work_buffer.get_position())

func _build(msg: String, args: Array = []) -> PackedByteArray:
	_work_buffer.clear()
	var s := msg
	for a in args:
		s += PARAM_DELIM + str(a)
	var s_buf := s.to_ascii_buffer()
	_maybe_grow_buffer(_work_buffer, s_buf.size())
	return _slice_buf_to_cursor()

func _send_to(entry: PeerEntry, msg: PackedByteArray, flags: int = Steam.NETWORKING_SEND_UNRELIABLE_NO_DELAY) -> void:
	Log.debug("[EasyServer] TX -> peer=%d, %d bytes" % [ entry.steam_id, msg.size() ])
	Steam.sendMessageToConnection(entry.steam_conn_handle, msg, flags)

func _broadcast_to_room(room_id: int, msg: PackedByteArray, exclude_pid: int = -1) -> void:
	for pid in _peers.keys():
		if pid == exclude_pid:
			continue
		if (_peers[pid] as PeerEntry).room_id == room_id:
			_send_to(pid, msg)

func _handle_relay(pid: int, entry: PeerEntry, pkt_name: String, args: Array) -> void:
	_broadcast_to_room(entry.room_id, _build(pkt_name, [str(entry.id)] + args), pid)

func _send_peer_state_to(target: PeerEntry, other: PeerEntry) -> void:
	_send_to(target, _build("m", [str(other.id), str(other.x), str(other.y)]))
	_send_to(target, _build("spr", [str(other.id), other.sprite_name, str(other.sprite_idx)]))
	_send_to(target, _build("f", [str(other.id), str(other.facing)]))
	_send_to(target, _build("spd", [str(other.id), str(other.speed)]))
	if other.hidden:
		_send_to(target, _build("h", [str(other.id), "1"]))
	if other.transparency > 0:
		_send_to(target, _build("tr", [str(other.id), str(other.transparency)]))
	if other.sys_name != "":
		_send_to(target, _build("sys", [str(other.id), other.sys_name]))
	if other.display_name != "":
		_send_to(target, _build("name", [str(other.id), other.display_name]))

###########################################################################################

func _handle_sr(pid: int, entry: PeerEntry, args: Array) -> void:
	var new_room := int(args[0]) if args.size() > 0 else 0
	var old_room := entry.room_id
	if old_room >= 0:
		_broadcast_to_room(old_room, _build("d", [str(entry.id)]), pid)
	entry.room_id = new_room
	Log.info("[EasyServer] peer %d joined room %d" % [pid, new_room])
	_send_to(entry, _build("ri", [str(new_room)]))
	for other_pid in _peers.keys():
		if other_pid == pid:
			continue
		var other: PeerEntry = _peers[other_pid]
		if other.room_id != new_room:
			continue
		_send_peer_state_to(entry, other)
	
	# order is important
	_broadcast_to_room(new_room, _build("m", [str(entry.id), str(entry.x), str(entry.y)]), pid)
	_broadcast_to_room(new_room, _build("spr", [str(entry.id), entry.sprite_name, str(entry.sprite_idx)]), pid)
	_broadcast_to_room(new_room, _build("f", [str(entry.id), str(entry.facing)]), pid)
	_broadcast_to_room(new_room, _build("spd", [str(entry.id), str(entry.speed)]), pid)
	if entry.hidden:
		_broadcast_to_room(new_room, _build("h", [str(entry.id), "1"]), pid)
	if entry.transparency > 0:
		_broadcast_to_room(new_room, _build("tr", [str(entry.id), str(entry.transparency)]), pid)
	if entry.sys_name != "":
		_broadcast_to_room(new_room, _build("sys", [str(entry.id), entry.sys_name]), pid)
	if entry.display_name != "":
		_broadcast_to_room(new_room, _build("name", [str(entry.id), entry.display_name]), pid)

func _handle_move(pid: int, entry: PeerEntry, args: Array) -> void:
	if args.size() < 2:
		return
	entry.x = int(args[0])
	entry.y = int(args[1])
	_broadcast_to_room(entry.room_id, _build("m", [str(entry.id)] + args), pid)

func _handle_jump(pid: int, entry: PeerEntry, args: Array) -> void:
	if args.size() < 2:
		return
	entry.x = int(args[0])
	entry.y = int(args[1])
	_broadcast_to_room(entry.room_id, _build("jmp", [str(entry.id)] + args), pid)

func _handle_facing(pid: int, entry: PeerEntry, args: Array) -> void:
	if args.is_empty():
		return
	entry.facing = int(args[0])
	_broadcast_to_room(entry.room_id, _build("f", [str(entry.id)] + args), pid)

func _handle_speed(pid: int, entry: PeerEntry, args: Array) -> void:
	if args.is_empty():
		return
	entry.speed = int(args[0])
	_broadcast_to_room(entry.room_id, _build("spd", [str(entry.id)] + args), pid)

func _handle_sprite(pid: int, entry: PeerEntry, args: Array) -> void:
	if args.size() < 2:
		return
	entry.sprite_name = args[0]
	entry.sprite_idx = int(args[1])
	_broadcast_to_room(entry.room_id, _build("spr", [str(entry.id)] + args), pid)

func _handle_transparency(pid: int, entry: PeerEntry, args: Array) -> void:
	if args.is_empty():
		return
	entry.transparency = int(args[0])
	_broadcast_to_room(entry.room_id, _build("tr", [str(entry.id)] + args), pid)

func _handle_hidden(pid: int, entry: PeerEntry, args: Array) -> void:
	if args.is_empty():
		return
	entry.hidden = int(args[0]) == 1
	_broadcast_to_room(entry.room_id, _build("h", [str(entry.id)] + args), pid)

func _handle_sys(pid: int, entry: PeerEntry, args: Array) -> void:
	if args.is_empty():
		return
	entry.sys_name = args[0]
	_broadcast_to_room(entry.room_id, _build("sys", [str(entry.id)] + args), pid)

func _handle_name_pkt(pid: int, entry: PeerEntry, args: Array) -> void:
	if args.is_empty():
		return
	entry.display_name = args[0]
	_broadcast_to_room(entry.room_id, _build("name", [str(entry.id)] + args), pid)

func _handle_chat(pid: int, entry: PeerEntry, args: Array) -> void:
	if args.is_empty():
		return
	if not entry.chat_enabled:
		Log.warn("[EasyServer] Attempt to send chat message without chat enabled from PID %d" % pid)
		return
	# nameless players should probably not be able to talk...
	if entry.display_name == "" or entry.display_name.length() == 0:
		return
	var msg := args[0] as String
	if msg.length() > 100:
		return
	# basically _broadcast_to_room, but skips over
	# peers that have chat disabled, and also
	# broadcasts sender's message back to the sender
	for other_pid in _peers.keys():
		var cur_peer := _peers[other_pid] as PeerEntry
		if not cur_peer.chat_enabled:
			continue
		if cur_peer.room_id == entry.room_id:
			_send_to(other_pid, _build("chat", [str(pid), msg]))

func _handle_chaton(pid: int, entry: PeerEntry, args: Array) -> void:
	if args.size() < 1:
		return
	Log.debug("[EasyServer] chaton from PID %d: %s" % [pid, args[0]])
	entry.chat_enabled = args[0] == "1" # yeah

func _on_peer_connected(conn_handle: int, steam_id: int) -> void:
	var peer_obj := PeerEntry.new()
	peer_obj.id = _next_pid
	peer_obj.steam_conn_handle = conn_handle
	peer_obj.steam_id = steam_id
	_next_pid += 1
	_peers[peer_obj.id] = peer_obj
	
	Log.debug("[EasyServer] peer %d connected, sending hello" % steam_id)
	# p4o-a7o: added PID to message for identifying self in chat messages
	_send_to(peer_obj, _build("s", ["0", str(peer_obj.id)]), Steam.NETWORKING_SEND_RELIABLE_NO_NAGLE)
	
func _on_peer_disconnected(peer: PeerEntry) -> void:
	var pid := peer.id
	Log.info("[EasyServer] peer %d closed connection (room %d)" % [pid, peer.room_id])
	_broadcast_to_room(peer.room_id, _build("d", [str(peer.id)]), pid)
	_peers.erase(pid)

func _receive_messages():
	var messages := Steam.receiveMessagesOnPollGroup(_poll_group, 256)
	if messages.size() == 0:
		return
	Log.debug("[EasyServer]: %d messages to read" % messages.size())
	
	_work_buffer.clear()
	
	for msg in messages:
		var data: PackedByteArray = msg["payload"]
		var conn_handle: int = msg["connection"]
		var peer: PeerEntry = _peers[conn_handle]
		var pid: int = peer.id
		var msg_str := data.get_string_from_ascii()
		# ajgoiaejriogaejiorg
		var p := msg_str.find(PARAM_DELIM)
		var type: String
		var args: Array
		if p == -1:
			type = msg
			args = []
		else:
			type = msg.substr(0, p)
			args = Array(msg.substr(p + PARAM_DELIM.length()).split(PARAM_DELIM, false))
		Log.debug("[EasyServer] RX peer=%d '%s' args=%s" % [pid, type, str(args)])
		
		match type:
			"sr": _handle_sr(pid, peer, args)
			"m", "tp": _handle_move(pid, peer, args)
			"jmp": _handle_jump(pid, peer, args)
			"f": _handle_facing(pid, peer, args)
			"spd": _handle_speed(pid, peer, args)
			"spr": _handle_sprite(pid, peer, args)
			"tr": _handle_transparency(pid, peer, args)
			"h": _handle_hidden(pid, peer, args)
			"sys": _handle_sys(pid, peer, args)
			"name": _handle_name_pkt(pid, peer, args)
			"chat": _handle_chat(pid, peer, args)
			"chaton": _handle_chaton(pid, peer, args)
			"fl","rfl","rrfl","se","ba","ap","mp","rp","ss","sv","sev":
				_handle_relay(pid, peer, type, args)
			_:
				Log.warn("[EasyServer] unknown packet '%s' from peer %d" % [type, pid])
	
	_work_buffer.clear() # final clear for good measure i guess

func _on_lobby_created(status: Steam.Result, lobby_id: int):
	if status != Steam.Result.RESULT_OK:
		Log.error("[EasyServer] Failed to create Steam lobby: code %s" % status)
		return
	Log.info("[EasyServer] Created lobby")
	_listen_handle = Steam.createListenSocketP2P(0, {})
	_poll_group = Steam.createPollGroup()
	_lobby_id = lobby_id

func _on_net_connection_status_changed(conn_handle: int, connection: Dictionary, old_state: int):
	var new_state: int = connection["connection_state"]
	var identity: int = connection["identity"]
	if old_state == Steam.CONNECTION_STATE_CONNECTED:
		if new_state == Steam.CONNECTION_STATE_CLOSED_BY_PEER:
			# Erase him
			# TODO
			_on_peer_disconnected(_peers[conn_handle])
			_peers.erase(conn_handle)
	if old_state == Steam.CONNECTION_STATE_NONE:
		if new_state == Steam.CONNECTION_STATE_CONNECTING:
			print("Server: Accepting connection from %s" % identity)
			Steam.acceptConnection(conn_handle)
			Steam.setConnectionPollGroup(conn_handle, _poll_group)
			_on_peer_connected(conn_handle, identity)
