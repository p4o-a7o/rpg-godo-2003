class_name EasyConnection
extends RefCounted

const PARAM_DELIM := "\uFFFF" # separates fields within one message
const MSG_DELIM := "\uFFFE" # separates multiple messages in one ws frame
const MAX_QUEUE_SIZE := 4088

signal connected()
signal disconnected(code: int)
signal packet_received(name: String, args: Array)

var _ws: WebSocketPeer = null
var _is_open: bool = false
var _queue: Array = []
var _url: String = ""

func open(uri: String) -> void:
	if _ws != null:
		close()
	_url = uri
	_ws = WebSocketPeer.new()
	_ws.supported_protocols = PackedStringArray(["binary"])
	Log.info("[EasyConnection] connecting to %s" % uri)
	var err := _ws.connect_to_url(uri)
	if err != OK:
		Log.error("[EasyConnection] connect_to_url failed (%s): %s" % [uri, error_string(err)])
		_ws = null
		return
	_is_open = false

func close() -> void:
	Log.debug("[EasyConnection] closing")
	_queue.clear()
	_is_open = false
	if _ws != null:
		_ws.close()
		_ws = null

func is_connected_to_server() -> bool:
	return _is_open

func poll() -> void:
	if _ws == null:
		return
	_ws.poll()
	match _ws.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			if not _is_open:
				_is_open = true
				Log.info("[EasyConnection] OPEN %s" % _url)
				connected.emit()
			_receive_all()
		WebSocketPeer.STATE_CLOSED:
			var code := _ws.get_close_code()
			Log.info("[EasyConnection] CLOSED code=%d reason='%s'" % [code, _ws.get_close_reason()])
			_is_open = false
			_ws = null
			disconnected.emit(code)
		_:
			pass

func send_packet(name: String, args: Array = []) -> void:
	_queue.append(_build_message(name, args))

func clear_queue() -> void:
	_queue.clear()

func flush_queue() -> void:
	if not _is_open or _ws == null:
		return
	if _ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	
	var include_sr := false
	while not _queue.is_empty():
		var prev_size := _queue.size()
		var bulk := ""
		var remaining: Array = []
		
		for msg in _queue:
			var is_sr: bool = msg.begins_with("sr")
			if is_sr == include_sr:
				var candidate: String = (bulk + MSG_DELIM if bulk != "" else "") + msg
				if candidate.length() > MAX_QUEUE_SIZE:
					_send_raw(bulk)
					bulk = msg
				else:
					bulk = candidate
			else:
				remaining.append(msg)
		
		if bulk != "":
			_send_raw(bulk)
		_queue = remaining
		include_sr = not include_sr
		
		if _queue.size() == prev_size:
			break

func _build_message(name: String, args: Array) -> String:
	var s := name
	for a in args:
		s += PARAM_DELIM + str(a)
	return s

func _send_raw(data: String) -> void:
	if _ws == null or _ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	var data_bytes := data.to_utf8_buffer()
	Log.debug("[EasyConnection] TX bytes=%d" % data_bytes.size())
	_ws.send(data_bytes, WebSocketPeer.WRITE_MODE_BINARY)

func _receive_all() -> void:
	while _ws != null and _ws.get_available_packet_count() > 0:
		var raw := _ws.get_packet()
		Log.debug("[EasyConnection] RX bytes=%d" % raw.size())
		_dispatch_frame(raw)

func _dispatch_frame(raw: PackedByteArray) -> void:
	var text := raw.get_string_from_utf8()
	for msg in text.split(MSG_DELIM, false):
		_dispatch_message(msg)

func _dispatch_message(msg: String) -> void:
	var p := msg.find(PARAM_DELIM)
	if p == -1:
		Log.debug("[EasyConnection] S2C '%s'" % msg)
		packet_received.emit(msg, [])
	else:
		var name := msg.substr(0, p)
		var rest := msg.substr(p + PARAM_DELIM.length())
		var args := Array(rest.split(PARAM_DELIM, false))
		Log.debug("[EasyConnection] S2C '%s' args=%s" % [name, str(args)])
		packet_received.emit(name, args)
