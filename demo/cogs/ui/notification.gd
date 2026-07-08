class_name Notification
extends Control

# TODO fading and tweening, couldn't get it to work
# because i do not understand godot ui, and frankly
# its kind of frustrating sometimes

@export var _close_button: Button
@export var _notification_body_label: RichTextLabel
@export var _progress_bar: TextureRect

@export var notification_body: String

var timeout: float = 5
var text: String:
	set(text):
		_notification_body_label.text = text
var expires: bool = true
var _notification_timer: Timer = Timer.new()

signal close_button_pressed()
signal expired()

func set_notification_timeout(timeout: float) -> Notification:
	timeout = timeout
	return self

func set_notification_expires(does_expire: bool) -> Notification:
	expires = does_expire
	return self

func set_notification_body(text: String) -> Notification:
	_notification_body_label.text = text
	notification_body = text
	return self

func start_timer() -> void:
	if _notification_timer.paused:
		_notification_timer.paused = false
		return
	self.add_child(_notification_timer)
	_notification_timer.start(timeout)
	# TODO this is a bit jinky-janky
	Log.info("[Notifications] Notification shown: %s" % notification_body)

func pause_timer() -> void:
	_notification_timer.paused = true

func _ready() -> void:
	self.modulate.a = 0
	if not expires:
		_progress_bar.hide()
	self.create_tween().tween_property(self, "modulate:a", 1, 0.5) \
		.set_trans(Tween.TRANS_CUBIC) \
		.set_ease(Tween.EASE_OUT)
	_close_button.pressed.connect(_on_close_button_pressed)
	self.pressed.connect(_on_notification_clicked)
	_notification_timer.timeout.connect(_on_notification_expire)
	self.mouse_entered.connect(_on_mouse_entered)
	self.mouse_exited.connect(_on_mouse_exited)
	_notification_timer.one_shot = true

func _process(delta: float) -> void:
	if not expires:
		return
	if _notification_timer.paused:
		return
	_progress_bar.scale.x = _notification_timer.time_left / _notification_timer.wait_time

# honestly why not just make it close when you click
# on the notification period, probably less annoying
# to have to snipe the X button
func _on_notification_clicked() -> void:
	_on_close_button_pressed()

func _on_close_button_pressed() -> void:
	Log.debug("[Notification] Close button pressed")
	close_button_pressed.emit()
	self.queue_free()

func _on_notification_expire() -> void:
	Log.debug("[Notification] Notification expired")
	expired.emit()
	self.queue_free()

func _on_mouse_entered() -> void:
	_notification_timer.paused = true
	Log.debug("[Notification] Pausing timer on hover with %.2f seconds left" % _notification_timer.time_left)

func _on_mouse_exited() -> void:
	_notification_timer.paused = false
	Log.debug("[Notification] Resuming timer")
