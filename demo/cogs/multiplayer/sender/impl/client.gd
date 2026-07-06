class_name ClientSender
extends Sender

var _client: EasyClientSteam

func _send_message(type: String, args: Array = [], flags: int = Steam.NETWORKING_SEND_UNRELIABLE_NO_DELAY):
	if not _client._room_ready:
		return
	_client.send_message(type, args, flags)
	
func _switching_room(old_room_id: int, new_room_id: int):
	_client.switch_room(new_room_id)

# TODO i should probably reorganize this stuff so i dont have to hack these parts in lol
func _on_local_moved(x: int, y: int) -> void:
	super._on_local_moved(x, y)
	_client.mp_handler.local_x = x
	_client.mp_handler.local_y = y
