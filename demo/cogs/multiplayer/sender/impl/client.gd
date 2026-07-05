class_name ClientSender
extends Sender

var _client: EasyClientSteam

func _send_message(type: String, args: Array = [], flags: int = Steam.NETWORKING_SEND_UNRELIABLE_NO_DELAY):
	pass
	
func _switching_room(old_room_id: int, new_room_id: int):
	pass
