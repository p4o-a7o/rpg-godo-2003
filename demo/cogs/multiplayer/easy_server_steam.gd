class_name EasyServerSteam
extends Node

@export var auto_start: bool = false

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

# PID 0 is reserved for the P2P host
var _next_pid: int = 1

var _started: bool = false
var _poll_group: int = -1
var _listen_handle: int = -1
var _lobby_id: int = -1

var _peers: Dictionary[int, PeerEntry] = {}

var _work_buffer: StreamPeerBuffer = StreamPeerBuffer.new()

func _ready() -> void:
	_work_buffer.resize(16)
	Steam.network_connection_status_changed.connect(_on_net_connection_status_changed)
	Steam.lobby_created.connect(_on_lobby_created)
	if auto_start:
		start()

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
		
func _slice_buf_to_cursor() -> PackedByteArray:
	return _work_buffer.data_array.slice(0, _work_buffer.get_position())

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
		_work_buffer.data_array = data
		# TODO
	_work_buffer.clear()
	# final clear() for good measure i suppose
	
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
			#_on_peer_disconnected(conn_handle)
			_peers.erase(conn_handle)
	if old_state == Steam.CONNECTION_STATE_NONE:
		if new_state == Steam.CONNECTION_STATE_CONNECTING:
			print("Server: Accepting connection from %s" % identity)
			Steam.acceptConnection(conn_handle)
			Steam.setConnectionPollGroup(conn_handle, _poll_group)
			#_on_peer_connected(conn_handle, identity)
