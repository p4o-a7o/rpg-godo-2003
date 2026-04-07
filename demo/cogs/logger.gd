class_name Log extends Node

static func debug(message: String) -> void:
	if OS.is_debug_build():
		#LimboConsole.debug(message)  # too much logs causes lagging
		print("[Debug]: %s" % message)

static func info(message: String) -> void:
	LimboConsole.info(message)
	print("[Info]: %s" % message)

static func warn(message: String) -> void:
	LimboConsole.warn(message)
	print("[Warn]: %s" % message)

static func error(message: String) -> void:
	LimboConsole.error(message)
	push_error(message)
	printerr("[Error]: %s" % message)
