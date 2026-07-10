extends Node

# p4o-a7o: yes this is probably sloppy as hell but oh well Lol
signal on_chat_message_received(display_name: String, text: String)
signal on_chat_message_submitted(text: String)

signal on_connected()
signal on_disconnected()
signal on_server_started()
