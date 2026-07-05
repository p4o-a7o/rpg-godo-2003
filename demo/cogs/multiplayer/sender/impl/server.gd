class_name ServerSender
extends Sender

var _server: EasyServerSteam

func _send_message(type: String, args: Array = [], flags: int = Steam.NETWORKING_SEND_UNRELIABLE_NO_DELAY):
	if not _server.is_running():
		return
	args.push_front("0") # PID of P2P host is 0
	_server._broadcast_to_room(_local_room_id, _build(type, args).to_ascii_buffer())
	
func _switching_room(old_room_id: int, new_room_id: int):
	if not _server.is_running():
		return
	var peers := _server._peers
	var disconnect_msg := _build("d", ["0"]).to_ascii_buffer()
	for pid in peers:
		var cur_peer := peers[pid]
		if cur_peer.room_id == old_room_id:
			Steam.sendMessageToConnection(cur_peer.steam_conn_handle, disconnect_msg, Steam.NETWORKING_SEND_RELIABLE_NO_NAGLE)
	send_basic_data()
