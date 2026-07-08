class_name EasyClientSteam
extends Node

const PARAM_DELIM := "\uFFFF" # separates fields within one message

var engine: RPGMakerPlayer:
	set(value):
		engine = value
		mp_handler.engine = value
var sender: ClientSender = ClientSender.new()
var mp_handler: MultiplayerHandler = MultiplayerHandler.new()
var notif_manager: NotificationMan
var player_name: String = ""

@export var enable_sounds: bool = true:
	set(value):
		enable_sounds = value
		mp_handler.enable_sounds = value
@export var enable_chat: bool = false
@export var mute_audio: bool = false:
	set(value):
		mute_audio = value
		mp_handler.mute_audio = value
@export var moving_queue_limit: int = 4

# Steam stuff
var _lobby_id: int = -1
var _lobby_owner_id: int = -1
var _connection_handle: int = -1
var _connection_state: int = -1

var _room_id: int = -1
var _my_pid: int = -1
var _room_ready: bool = false
var _reconnecting: bool = false

func _ready() -> void:
	sender._client = self
	mp_handler.sender = sender
	mp_handler.client = self
	self.add_child(mp_handler)
	_wire_player_signals()
	Steam.lobby_joined.connect(_on_lobby_joined)
	Steam.join_requested.connect(_on_join_request)
	Steam.network_connection_status_changed.connect(_on_net_connection_status_changed)
	MpEvents.on_chat_message_submitted.connect(_send_chat_message)

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

func _sanitize(s: String) -> String:
	return s.replace(PARAM_DELIM, "")

static func _build(type: String, args: Array = []) -> String:
	var s := type
	for a in args:
		s += PARAM_DELIM + str(a)
	return s

func send_message(type: String, args: Array = [], flags: int = Steam.NETWORKING_SEND_UNRELIABLE_NO_DELAY) -> void:
	if _connection_handle <= 0:
		return
	Steam.sendMessageToConnection(_connection_handle, _build(type, args).to_utf8_buffer(), flags)

func switch_room(map_id: int) -> void:
	Log.info("[EasyClient] switch_room id=%d" % map_id)
	_room_ready = false
	mp_handler.reset()
	_room_id = map_id
	
	if engine and engine.is_running():
		engine.mp_set_session_active(true)
		engine.mp_set_room_id(map_id)
	
	if _connection_state == Steam.CONNECTION_STATE_CONNECTED:
		Log.debug("[EasyClient] already connected - sending sr request")
		if engine and engine.is_running():
			engine.mp_sync_local_player()
		send_message("sr", [str(map_id)])
	else:
		Log.debug("[EasyClient] switch_room: Not connected.")

func set_enable_chat(enabled: bool) -> void:
	send_message("chaton", ["1" if enabled else "0"], Steam.NETWORKING_SEND_RELIABLE_NO_NAGLE)

func _send_chat_message(text: String) -> void:
	send_message("chat", [text], Steam.NETWORKING_SEND_RELIABLE_NO_NAGLE)

func reconnect() -> void:
	Steam.closeConnection(_connection_handle, Steam.CONNECTION_END_APP_GENERIC, "Reconnecting", false)
	mp_handler.reset()
	_room_ready = false
	await get_tree().create_timer(0.5).timeout
	_connection_handle = Steam.connectP2P(_lobby_owner_id, 0, {})

func _process(delta: float) -> void:
	if _lobby_id > 0 and _connection_handle > 0:
		_receive_messages()

func _receive_messages():
	var res := Steam.receiveMessagesOnConnection(_connection_handle, 128)
	if res.size() > 0:
		Log.debug("[EasyClient] %d messages to read" % res.size())
	
	for msg in res:
		var data: PackedByteArray = msg["payload"]
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
		Log.debug("[EasyClient] RX '%s' args=%s" % [type, str(args)])
		
		match type:
			"ri": 
				_handle_room_info(args)
				continue
			"s": 
				_handle_sync_player_data(args)
				continue
		
		mp_handler._on_packet(type, args)

# Client (non-host) only
func _handle_room_info(args: Array) -> void:
	if args.is_empty():
		return
	var room_id := int(args[0])
	if room_id != sender._local_room_id:
		# TODO
		Log.warn("[EasyClient] wrong room %d (expected %d), reconnecting" % [room_id, sender._local_room_id])
		reconnect()
		return
	Log.info("[EasyClient] room %d confirmed" % room_id)
	_room_ready = true
	if engine and engine.is_running():
		engine.mp_notify_room_ready()
	sender.send_basic_data()

# Client (non-host) only
func _handle_sync_player_data(_args: Array) -> void:
	Log.info("[EasyClient] session ready")
	_my_pid = int(_args[1])
	if engine and engine.is_running():
		engine.mp_sync_local_player()
	_room_ready = false
	#sender._send_message("sr", [str(sender._local_room_id)])
	#sender._send_message("chaton", ["1" if enable_chat else "0"])

func _on_join_request(lobby_id: int, steam_id: int):
	if lobby_id == _lobby_id:
		Log.info("[EasyClient]: join_requested: Already in lobby %s" % lobby_id)
		return
	
	if _lobby_id > 0:
		Log.info("[EasyClient]: Joining new lobby %s, leaving and disconnecting from old lobby" % lobby_id)
		Steam.leaveLobby(_lobby_id)
		Steam.closeConnection(_connection_handle, Steam.CONNECTION_END_APP_GENERIC, "Disconnecting", false)
		mp_handler.reset()
		_room_ready = false
		MpEvents.on_disconnected.emit()
	
	var friend_name := Steam.getFriendPersonaName(steam_id)
	_lobby_id = lobby_id
	_lobby_owner_id = steam_id
	Log.debug("[EasyClient]: Joining %s's lobby" % friend_name)
	Steam.joinLobby(lobby_id)

func _on_lobby_joined(lobby_id: int, permissions: int, locked: bool, response: int):
	Log.debug("[EasyClient] Joined lobby, initiating P2P sockets connection")
	_connection_handle = Steam.connectP2P(_lobby_owner_id, 0, {})

func _on_net_connection_status_changed(conn_handle: int, connection: Dictionary, old_state: int):
	var new_state: int = connection["connection_state"]
	var identity: int = connection["identity"]
	_connection_state = new_state
	Log.debug("[EasyClient] connection state: %s" % new_state)
	if new_state == Steam.CONNECTION_STATE_CONNECTED:
		Log.debug("[EasyClient] Server accepted connection, fully connected")
		var steam_name := Steam.getFriendPersonaName(identity)
		notif_manager.create_notification() \
			.set_notification_body("Joined %s's game" % steam_name) \
			.start_timer()
		MpEvents.on_connected.emit()
		mp_handler.mp_ready()
		send_message("sr", [sender._local_room_id], Steam.NETWORKING_SEND_RELIABLE_NO_NAGLE)
		send_message("chaton", ["1" if enable_chat else "0"], Steam.NETWORKING_SEND_RELIABLE_NO_NAGLE)
		
	if old_state == Steam.CONNECTION_STATE_CONNECTED:
		if new_state == Steam.CONNECTION_STATE_CLOSED_BY_PEER:
			Log.debug("[EasyClient] Connection closed by peer")
			var steam_name := Steam.getFriendPersonaName(identity)
			notif_manager.create_notification() \
				.set_notification_body("You were disconnected from %s's game" % steam_name) \
				.start_timer()
			Steam.closeConnection(conn_handle, Steam.CONNECTION_END_APP_GENERIC, "", false)
			MpEvents.on_disconnected.emit()
			mp_handler.reset()
	if old_state == Steam.CONNECTION_STATE_NONE:
		if new_state == Steam.CONNECTION_STATE_CONNECTING:
			Log.debug("[EasyClient] Connecting with server")
			# TODO (?)
