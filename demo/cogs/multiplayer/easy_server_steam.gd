class_name EasyServerSteam
extends Node

@export var auto_start: bool = false

var chat_overlay: ChatOverlay
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
	
var engine: RPGMakerPlayer:
	set(value):
		engine = value
		mp_handler.engine = value
var sender: ServerSender = ServerSender.new()
var mp_handler: MultiplayerHandler = MultiplayerHandler.new()

# PID 0 is reserved for the P2P host
var _next_pid: int = 1

var _started: bool = false
var _poll_group: int = -1
var _listen_handle: int = -1
var _lobby_id: int = -1

# Keys = handle to steam connection
var _peers: Dictionary[int, PeerEntry] = {}
var _peers_by_handle: Dictionary[int, PeerEntry] = {}

func _ready() -> void:
	Steam.network_connection_status_changed.connect(_on_net_connection_status_changed)
	Steam.lobby_created.connect(_on_lobby_created)
	if auto_start:
		start()
	sender._server = self
	mp_handler.sender = sender
	self.add_child(mp_handler)
	_wire_player_signals()
	engine.mp_notify_room_ready()
	engine.mp_set_session_active(true)
	engine.mp_sync_local_player()
	
	MpEvents.on_chat_message_submitted.connect(_broadcast_local_chat_message)

# p4o-a7o: since you are the P2P host, the host
# will also need to broadcast itself to all other
# peers in the same room id as the host
func _wire_player_signals() -> void:
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

func _build(msg: String, args: Array = []) -> String:
	var s := msg
	for a in args:
		s += PARAM_DELIM + str(a)
	return s

func _send_to(entry: PeerEntry, msg: PackedByteArray, flags: int = Steam.NETWORKING_SEND_UNRELIABLE_NO_DELAY) -> void:
	Log.debug("[EasyServer] TX -> peer=%d, %d bytes" % [ entry.steam_id, msg.size() ])
	Steam.sendMessageToConnection(entry.steam_conn_handle, msg, flags)

func _broadcast_to_room(room_id: int, msg: String, exclude_pid: int = -1) -> void:
	for pid in _peers.keys():
		if pid == exclude_pid:
			continue
		if (_peers[pid] as PeerEntry).room_id == room_id:
			_send_to(_peers[pid], msg.to_utf8_buffer())

func _broadcast_local_chat_message(text: String) -> void:
	chat_overlay.add_chat_message(sender._player_name, text)
	
	var msg := _build("chat", ["0", text]).to_utf8_buffer()
	for other_pid in _peers.keys():
		var cur_peer := _peers[other_pid] as PeerEntry
		if not cur_peer.chat_enabled:
			continue
		if cur_peer.room_id == sender._local_room_id:
			_send_to(cur_peer, msg, Steam.NETWORKING_SEND_RELIABLE_NO_NAGLE)

func _host_spawn_other_player(peer: PeerEntry) -> void:
	Log.debug("[EasyServer] spawning other player %s" % peer.id)
	mp_handler._spawn_player(peer.id, true)
	mp_handler._do_mp_add_player(peer.id)
	mp_handler._mp_move_player(peer.id, peer.x, peer.y)
	if peer.sprite_name != "":
		mp_handler._mp_set_player_sprite(peer.id, peer.sprite_name, peer.sprite_idx)
	mp_handler._mp_set_player_facing(peer.id, peer.facing)
	mp_handler._mp_set_player_speed(peer.id, peer.speed)
	
	if peer.hidden:
		mp_handler._mp_set_player_hidden(peer.id, peer.hidden)
	if peer.transparency > 0:
		mp_handler._mp_set_player_transparency(peer.id, peer.transparency)
	if peer.sys_name != "":
		mp_handler._mp_set_player_system_graphic(peer.id, peer.sys_name)
	if peer.display_name != "":
		mp_handler._mp_set_player_name(peer.id, peer.display_name)

func _host_switching_room(old_room_id: int, new_room_id: int) -> void:
	# resets the mp_handler to purge all the players from the
	# previous room and then spawns all the ones in the new room
	mp_handler.reset()
	for pid in _peers.keys():
		var cur_peer := _peers[pid]
		if cur_peer.room_id == new_room_id:
			_host_spawn_other_player(cur_peer)

func _handle_relay(pid: int, entry: PeerEntry, pkt_name: String, args: Array) -> void:
	_broadcast_to_room(entry.room_id, _build(pkt_name, [str(entry.id)] + args), pid)

func _send_peer_state_to(target: PeerEntry, other: PeerEntry) -> void:
	_send_to(target, _build("m", [str(other.id), str(other.x), str(other.y)]).to_utf8_buffer(), Steam.NETWORKING_SEND_RELIABLE_NO_NAGLE)
	_send_to(target, _build("spr", [str(other.id), other.sprite_name, str(other.sprite_idx)]).to_utf8_buffer(), Steam.NETWORKING_SEND_RELIABLE_NO_NAGLE)
	_send_to(target, _build("f", [str(other.id), str(other.facing)]).to_utf8_buffer(), Steam.NETWORKING_SEND_RELIABLE_NO_NAGLE)
	_send_to(target, _build("spd", [str(other.id), str(other.speed)]).to_utf8_buffer(), Steam.NETWORKING_SEND_RELIABLE_NO_NAGLE)
	if other.hidden:
		_send_to(target, _build("h", [str(other.id), "1"]).to_utf8_buffer(), Steam.NETWORKING_SEND_RELIABLE_NO_NAGLE)
	if other.transparency > 0:
		_send_to(target, _build("tr", [str(other.id), str(other.transparency)]).to_utf8_buffer(), Steam.NETWORKING_SEND_RELIABLE_NO_NAGLE)
	if other.sys_name != "":
		_send_to(target, _build("sys", [str(other.id), other.sys_name]).to_utf8_buffer(), Steam.NETWORKING_SEND_RELIABLE_NO_NAGLE)
	if other.display_name != "":
		_send_to(target, _build("name", [str(other.id), other.display_name]).to_utf8_buffer(), Steam.NETWORKING_SEND_RELIABLE_NO_NAGLE)

###########################################################################################

func _handle_sr(pid: int, entry: PeerEntry, args: Array) -> void:
	var new_room := int(args[0]) if args.size() > 0 else 0
	var old_room := entry.room_id
	if old_room >= 0:
		_broadcast_to_room(old_room, _build("d", [str(entry.id)]), pid)
		if new_room != sender._local_room_id:
			mp_handler._remove_player(pid)
		else:
			# queue spawn
			mp_handler._spawn_player(pid)
			#_host_spawn_other_player(entry)

	entry.room_id = new_room
	Log.info("[EasyServer] peer %d joined room %d" % [pid, new_room])
	_send_to(entry, _build("ri", [str(new_room)]).to_utf8_buffer())
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
	
	# send basic data of own host
	# TODO make it so that it only sends it
	# to the client that needs to have it
	# since this will broadcast to the whole room
	if new_room == sender._local_room_id:
		sender.send_basic_data()

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
		Log.warn("[EasyServer] Attempt to send chat message with no name provided")
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
			_send_to(cur_peer, _build("chat", [str(pid), msg]).to_utf8_buffer(), Steam.NETWORKING_SEND_RELIABLE_NO_NAGLE)
	
	if sender._local_room_id != entry.room_id:
		return
	MpEvents.on_chat_message_received.emit(entry.display_name, msg)

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
	_peers_by_handle[conn_handle] = peer_obj
	
	Log.debug("[EasyServer] peer %d connected, sending hello" % steam_id)
	# p4o-a7o: added PID to message for identifying self in chat messages
	_send_to(peer_obj, _build("s", ["0", str(peer_obj.id)]).to_utf8_buffer(), Steam.NETWORKING_SEND_RELIABLE_NO_NAGLE)
	
func _on_peer_disconnected(peer: PeerEntry) -> void:
	var pid := peer.id
	Log.info("[EasyServer] peer %d closed connection (room %d)" % [pid, peer.room_id])
	_broadcast_to_room(peer.room_id, _build("d", [str(peer.id)]), pid)
	mp_handler._remove_player(peer.id)
	_peers.erase(pid)
	_peers_by_handle.erase(peer.steam_conn_handle)

func _receive_messages():
	var messages := Steam.receiveMessagesOnPollGroup(_poll_group, 256)
	if messages.size() == 0:
		return
	Log.debug("[EasyServer]: %d messages to read" % messages.size())
	
	for msg in messages:
		var data: PackedByteArray = msg["payload"]
		var conn_handle: int = msg["connection"]
		var peer: PeerEntry = _peers_by_handle[conn_handle]
		var pid: int = peer.id
		var msg_str := data.get_string_from_utf8()
		# ajgoiaejriogaejiorg
		var p := msg_str.find(PARAM_DELIM)
		var type: String
		var args: Array
		if p == -1:
			type = msg_str
			args = []
		else:
			type = msg_str.substr(0, p)
			args = Array(msg_str.substr(p + PARAM_DELIM.length()).split(PARAM_DELIM, false))
		Log.debug("[EasyServer] RX peer=%d '%s' args=%s" % [pid, type, str(args)])
		
		# TODO maybe remove at a later date, this is
		# somewhat unnecessary
		var packet_ok := true
		var skip_mp_handling := false
		match type:
			"sr": _handle_sr(pid, peer, args)
			"m", "tp":
				# special case for making sure peer
				# doesnt get spawned on screen even when
				# they are not in the same room as the host
				if peer.room_id != sender._local_room_id:
					skip_mp_handling = true
				_handle_move(pid, peer, args)
			"jmp": _handle_jump(pid, peer, args)
			"f": _handle_facing(pid, peer, args)
			"spd": _handle_speed(pid, peer, args)
			"spr": _handle_sprite(pid, peer, args)
			"tr": _handle_transparency(pid, peer, args)
			"h": _handle_hidden(pid, peer, args)
			"sys": _handle_sys(pid, peer, args)
			"name": _handle_name_pkt(pid, peer, args)
			"chat":
				_handle_chat(pid, peer, args)
				skip_mp_handling = true
			"chaton": _handle_chaton(pid, peer, args)
			"fl","rfl","rrfl","se","ba","ap","mp","rp","ss","sv","sev":
				_handle_relay(pid, peer, type, args)
			_:
				Log.warn("[EasyServer] unknown packet '%s' from peer %d" % [type, pid])
				packet_ok = false
		
		if packet_ok and not skip_mp_handling:
			var handler_args := [ str(pid) ]
			handler_args.append_array(args)
			mp_handler._on_packet(type, handler_args)

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
	Log.info("[EasyServer]: Peer %s connection state changed: %s" % [identity, new_state])
	# TODO: handle CONNECTION_STATE_PROBLEM_DETECTED_LOCALLY
	if old_state == Steam.CONNECTION_STATE_CONNECTED:
		if new_state == Steam.CONNECTION_STATE_CLOSED_BY_PEER:
			# Erase him
			# TODO
			_on_peer_disconnected(_peers_by_handle[conn_handle])
			Steam.closeConnection(conn_handle, Steam.CONNECTION_END_APP_GENERIC, "", false)
	if new_state == Steam.CONNECTION_STATE_CONNECTED:
		# i just read the docs and realizing i should probably
		# do _on_peer_connected when the peer has actually CONNECTED...
		Log.info("[EasyServer]: Peer %s fully connected" % identity)
		_on_peer_connected(conn_handle, identity)
	if old_state == Steam.CONNECTION_STATE_NONE:
		if new_state == Steam.CONNECTION_STATE_CONNECTING:
			Log.info("[EasyServer]: Accepting connection from %s" % identity)
			Steam.acceptConnection(conn_handle)
			Steam.setConnectionPollGroup(conn_handle, _poll_group)
