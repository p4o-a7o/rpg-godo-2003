class_name LobbyBrowser
extends Control

# should probably make a real menu system for
# this or something
var previous_screen: Node

enum Tab {
	FRIENDS,
	PUBLIC,
}

@onready var _back_button: Button = %BackButton
@onready var _engine: RPGMakerPlayer = %RPGMakerPlayer
@onready var _setup_screen: SetupScreen = %SetupScreen

const LOBBY_ITEM = preload("res://scenes/lobby_browser_item.tscn")

var _joining_lobby: bool = false
var _lobby_items: Dictionary[int, LobbyBrowserItem] = {}

func _ready() -> void:
	_back_button.pressed.connect(_back_button_pressed)
	%LobbyListContainer.hide()
	%PleaseWait.show()
	MpEvents.on_connected.connect(_on_connected)
	Steam.lobby_data_update.connect(_on_lobby_data_updated)
	
func _back_button_pressed() -> void:
	self.hide()
	if previous_screen:
		previous_screen.show()
		previous_screen = null

func refresh() -> void:
	#%LobbyListContainer.hide()
	#%PleaseWait.show()
	_lobby_items.clear()
	for child in %PlayerLobbyList.get_children():
		child.queue_free()
	
	var num := Steam.getFriendCount(Steam.FRIEND_FLAG_IMMEDIATE)
	Log.info("Num friends: %s" % num)
	if num < 0:
		return
	
	for i in range(num):
		var steam_id := Steam.getFriendByIndex(i, Steam.FRIEND_FLAG_IMMEDIATE)
		var activity_data := Steam.getFriendGamePlayed(steam_id)
		if activity_data:
			var owner_name: String = Steam.getFriendPersonaName(steam_id)
			print(owner_name, activity_data)
			var id: int = activity_data.get("id", -1)
			if id < 0 or id != Steamworks.APP_ID:
				continue
			var lobby_id: int = activity_data.get("lobby", -1)
			if lobby_id <= 0:
				continue
			var new_lobby_item: LobbyBrowserItem = LOBBY_ITEM.instantiate()
			new_lobby_item.set_lobby_owner_name(owner_name)
			new_lobby_item.set_lobby_owner_steam_id(steam_id)
			new_lobby_item.set_lobby_id(lobby_id)
			new_lobby_item.on_join_pressed.connect(_join_lobby)
			%PlayerLobbyList.add_child(new_lobby_item)
			_lobby_items[lobby_id] = new_lobby_item
			# TODO do i need to rate limit him?
			Steam.requestLobbyData(lobby_id)
	
	%LobbyListContainer.show()
	%PleaseWait.hide()

func _join_lobby(lobby_id: int, steam_id: int) -> void:
	if _joining_lobby:
		Log.warn("[LobbyBrowser] Already trying to join a lobby")
		return
	_joining_lobby = true
	# TODO timeout
	EasyClientSteam.join_lobby(lobby_id, steam_id)

func _on_browser_tab_changed(tab: int) -> void:
	match tab:
		Tab.FRIENDS:
			Log.info("[LobbyBrowser] Show friends lobbies")
			pass
		Tab.PUBLIC:
			# TODO, maybe
			Log.info("[LobbyBrowser] Show public lobbies")
			pass

func _on_lobby_data_updated(success: bool, lobby_id: int, member_id: int) -> void:
	if not success:
		Log.error("[LobbyBrowser] failed to get lobby data (??)")
	var item: LobbyBrowserItem = _lobby_items.get(lobby_id)
	if not item:
		Log.warn("[LobbyBrowser] No lobby browser item found for lobby ID %d when getting update" % lobby_id)
		return
	item.set_lobby_playercounts(Steam.getNumLobbyMembers(lobby_id), Steam.getLobbyMemberLimit(lobby_id))

func _on_connected() -> void:
	if _engine and not _engine.is_running():
		Transition.custom(_actually_launch_game, TransitionPresets.get_fast_fade())

func _actually_launch_game() -> void:
	_setup_screen._launch_game(false)
	_joining_lobby = false
	self.hide()
	if previous_screen:
		previous_screen.show()
		previous_screen = null

func _on_refresh_requested() -> void:
	Log.info("[LobbyBrowser] Refresh of lobby list requested")
	refresh()
