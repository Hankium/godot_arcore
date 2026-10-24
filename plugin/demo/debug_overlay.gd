extends CanvasLayer

# On-screen diagnostics for the AR spike (no adb available).
var _label: Label
var _log_lines: PackedStringArray = []

func _ready() -> void:
	layer = 100
	_label = Label.new()
	_label.position = Vector2(700, 150)
	_label.add_theme_font_size_override("font_size", 26)
	_label.add_theme_color_override("font_color", Color.YELLOW)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 6)
	add_child(_label)

func _process(_delta: float) -> void:
	var t := PackedStringArray()
	t.append("Godot %s" % Engine.get_version_info().string)
	t.append("Plugin singleton: %s" % Engine.has_singleton("ARCorePlugin"))
	t.append("Granted perms: %s" % ", ".join(OS.get_granted_permissions()))
	var names := PackedStringArray()
	for i in XRServer.get_interface_count():
		var iface := XRServer.get_interface(i)
		names.append("%s(init=%s)" % [iface.get_name(), iface.is_initialized()])
	t.append("XR interfaces: %s" % ", ".join(names))
	var ar = XRServer.find_interface("ARCoreInterface")
	if ar:
		t.append("Last AR error: %s" % ar.get_last_error())
		t.append("Tracking status: %s" % ar.get_tracking_status())
		t.append("Camera feed id: %s" % ar.get_camera_feed_id())
	for feed in (CameraServer.feeds() if CameraServer.monitoring_feeds else []):
		t.append("Feed %d '%s' active=%s type=%s" % [feed.get_id(), feed.get_name(), feed.feed_is_active, feed.get_datatype()])
	var cam_env := get_viewport().get_camera_3d().environment if get_viewport().get_camera_3d() else null
	if cam_env:
		t.append("Env bg=%d feed_id=%d" % [cam_env.background_mode, cam_env.background_camera_feed_id])
	t.append("Viewport use_xr: %s" % get_viewport().use_xr)
	var cam := get_viewport().get_camera_3d()
	if cam:
		t.append("Camera: %s pos=%s" % [cam.get_class(), cam.global_position.snapped(Vector3.ONE * 0.01)])
	t.append("FPS: %d" % Engine.get_frames_per_second())
	t.append("--- log ---")
	t.append_array(_tail_log())
	_label.text = "\n".join(t)

func _tail_log() -> PackedStringArray:
	var f := FileAccess.open("user://logs/godot.log", FileAccess.READ)
	if f == null:
		return PackedStringArray(["(no log file)"])
	var lines := f.get_as_text().split("\n")
	return lines.slice(maxi(0, lines.size() - 12))
