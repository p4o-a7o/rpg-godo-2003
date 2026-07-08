class_name NotificationMan
extends Control

const NOTIFICATION_SCN := preload("res://scenes/notification.tscn")

@onready var _notification_vbox: VBoxContainer = %NotificationList

func create_notification() -> Notification:
	var notif: Notification = NOTIFICATION_SCN.instantiate()
	%NotificationList.add_child(notif)
	return notif

func pause_all_notifications() -> void:
	for child in %NotificationList.get_children():
		var notification := child as Notification
		notification.pause_timer()

func resume_all_notifications() -> void:
	for child in %NotificationList.get_children():
		var notification := child as Notification
		notification.start_timer()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
