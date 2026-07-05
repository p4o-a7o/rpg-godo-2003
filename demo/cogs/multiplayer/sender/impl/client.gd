class_name ClientSender
extends Sender

var _client: EasyClientSteam

func _send_message(type: String, args: Array = [], flags: int = Steam.NETWORKING_SEND_UNRELIABLE_NO_DELAY):
	_client.send_message(type, args, flags)
	
func _switching_room(old_room_id: int, new_room_id: int):
	_client.switch_room(new_room_id)
