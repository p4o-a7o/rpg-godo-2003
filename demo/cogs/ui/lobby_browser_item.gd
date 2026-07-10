class_name LobbyBrowserItem
extends PanelContainer

var lobby_owner_name: String
var lobby_owner_steam_id: int
var lobby_id: int

var player_count: int = -1
var lobby_size: int = -1

signal on_join_pressed(lobby_id: int, steam_id: int)

func set_lobby_owner_name(name: String) -> void:
	var label: RichTextLabel = self.get_node("MarginContainer/PlayerName")
	label.text = name
	lobby_owner_name = name

func set_lobby_owner_steam_id(steam_id: int) -> void:
	lobby_owner_steam_id = steam_id

func set_lobby_id(id: int) -> void:
	lobby_id = id

func set_lobby_playercounts(player_count: int, lobby_size: int) -> void:
	self.player_count = player_count
	self.lobby_size = lobby_size
	var label: RichTextLabel = self.get_node("MarginContainer/HBoxContainer/PlayerCount")
	label.text = "%d/%d" % [ player_count, lobby_size ]

func _on_join_button_pressed() -> void:
	%JoinButton.text = "Joining..."
	on_join_pressed.emit(lobby_id, lobby_owner_steam_id)
