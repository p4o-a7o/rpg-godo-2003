class_name ClientSender
extends Sender

func _send_message(type: String, args: Array = [], flags: int = Steam.NETWORKING_SEND_UNRELIABLE_NO_DELAY):
	if not EasyClientSteam.client_connected() and not EasyClientSteam._room_ready:
		return
	EasyClientSteam.send_message(type, args, flags)
	
func _switching_room(old_room_id: int, new_room_id: int):
	if not EasyClientSteam.client_connected():
		return
	EasyClientSteam.switch_room(new_room_id)
