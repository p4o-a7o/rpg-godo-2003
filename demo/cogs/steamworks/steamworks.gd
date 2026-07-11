extends Node

const APP_ID: int = 650700

signal steam_connected()
signal steam_connect_failed()
signal steam_relay_status(ready: bool, status_code: int, debug_message: String)

var _initialized = false
var _status_code: int = -1
var _status_verbal: String = "No status"
var _retry_timer: SceneTreeTimer

var _sdr_network_code: int = -1

func is_initialized() -> bool:
	return _initialized

func get_status_code() -> int:
	return _status_code
	
func get_verbal_status() -> String:
	return _status_verbal

func is_sdr_available() -> bool:
	return _sdr_network_code == Steam.NETWORKING_AVAILABILITY_CURRENT

func get_sdr_availability() -> int:
	return _sdr_network_code

func _ready():
	Steam.relay_network_status.connect(_on_relay_network_status)

func force_retry():
	if _initialized:
		return
	_retry_timer.time_left = 5
	_try_init_steam()

func _try_init_steam():
	# YN steam app ID is 650700
	# testing app ID is 480
	var res := Steam.steamInitEx(APP_ID)
	_status_code = res.status
	_status_verbal = res.verbal
	if not res.verbal:
		_status_verbal = "No status" 
	print("steamInitEx:", res)
	if res.status != 0:
		Log.warn("[Steamworks] Couldn't init steam: " + _status_verbal)
		print("Trying again in 5 seconds")
		steam_connect_failed.emit()
		_retry_timer = get_tree().create_timer(5)
		await _retry_timer.timeout
		_try_init_steam()
	if res.status == 0:
		print("steam init OK")
		_initialized = true
		steam_connected.emit()
		Steam.initRelayNetworkAccess()

func _process(_delta: float):
	Steam.run_callbacks()

func _on_relay_network_status(available: int, ping_measurement: int, \
								available_config: int, available_relay: int, \
								debug_message: String) -> void:
	_sdr_network_code = available_relay
	steam_relay_status.emit(available_relay == Steam.NETWORKING_AVAILABILITY_CURRENT, _sdr_network_code, debug_message)
	if available_relay == Steam.NETWORKING_AVAILABILITY_CURRENT:
		print("SDR: network availability OK: %s" % debug_message)
	elif available_relay == Steam.NETWORKING_AVAILABILITY_WAITING:
		print("SDR: waiting!!!")
	elif available_relay == Steam.NETWORKING_AVAILABILITY_ATTEMPTING:
		print("SDR: attempting")
	elif available_relay < 0:
		print("SDR: network not available: %s (code: %s)" % [debug_message, available_relay])
