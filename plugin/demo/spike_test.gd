extends Node3D

# Spike checks: tap-to-place anchored floor markers, anchor drift readout,
# and the darkness VFX over the camera feed.
var _markers: Array[Dictionary] = []
var _dark_rect: ColorRect
var _ghost_on := false
var _status: Label
var _planes_visible := true
var _plane_material := _make_plane_material()

# Translucent so the real surface stays visible underneath.
static func _make_plane_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(0.2, 0.8, 1.0, 0.25)
	return m

func _ready() -> void:
	var dark_layer := CanvasLayer.new()
	dark_layer.layer = 5
	add_child(dark_layer)
	_dark_rect = ColorRect.new()
	_dark_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dark_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://darkness.gdshader")
	_dark_rect.material = mat
	_dark_rect.visible = false
	dark_layer.add_child(_dark_rect)

	var ui_layer := CanvasLayer.new()
	ui_layer.layer = 110
	add_child(ui_layer)
	var box := VBoxContainer.new()
	box.position = Vector2(1900, 150)
	box.add_theme_constant_override("separation", 20)
	ui_layer.add_child(box)
	_add_button(box, "Dark", func(): _dark_rect.visible = not _dark_rect.visible)
	_add_button(box, "Ghost", func(): _ghost_on = not _ghost_on)
	_add_button(box, "Clear", _clear_markers)
	_add_button(box, "Planes", func(): _planes_visible = not _planes_visible)
	_add_button(box, "Diag", func(): DebugOverlay.visible = not DebugOverlay.visible)

	_status = Label.new()
	_status.position = Vector2(700, 860)
	_status.add_theme_font_size_override("font_size", 32)
	_status.add_theme_color_override("font_color", Color.CYAN)
	_status.add_theme_color_override("font_outline_color", Color.BLACK)
	_status.add_theme_constant_override("outline_size", 8)
	ui_layer.add_child(_status)

func _add_button(parent: Control, text: String, action: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(300, 110)
	b.add_theme_font_size_override("font_size", 44)
	b.pressed.connect(action)
	parent.add_child(b)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_place_marker(event.position)

func _place_marker(screen_pos: Vector2) -> void:
	var ar = ARCoreInterfaceInstance.get_interface()
	if ar == null:
		return
	var hit: Dictionary = ar.hit_test_plane(screen_pos.x, screen_pos.y)
	if not hit.get("hit", false):
		_status.text = "No plane under tap"
		return
	var marker := _make_marker_mesh()
	marker.transform = hit["transform"]
	add_child(marker)
	_markers.append({
		"node": marker,
		"anchor_id": hit.get("anchor_id", -1),
		"start": hit["transform"].origin,
	})

func _make_marker_mesh() -> Node3D:
	var root := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.25, 0.1)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.06
	cyl.bottom_radius = 0.06
	cyl.height = 0.01
	disc.mesh = cyl
	disc.material_override = mat
	root.add_child(disc)
	var pole := MeshInstance3D.new()
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.005
	pole_mesh.bottom_radius = 0.005
	pole_mesh.height = 0.3
	pole.mesh = pole_mesh
	pole.position.y = 0.15
	pole.material_override = mat
	root.add_child(pole)
	return root

func _clear_markers() -> void:
	var ar = ARCoreInterfaceInstance.get_interface()
	for m in _markers:
		if ar and m["anchor_id"] >= 0:
			ar.remove_anchor(m["anchor_id"])
		m["node"].queue_free()
	_markers.clear()

func _process(_delta: float) -> void:
	if _dark_rect.visible:
		var proximity := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 1.3) if _ghost_on else 0.0
		(_dark_rect.material as ShaderMaterial).set_shader_parameter("ghost_proximity", proximity)

	var ar = ARCoreInterfaceInstance.get_interface()
	var max_shift := 0.0
	var tracking := 0
	for m in _markers:
		if ar and m["anchor_id"] >= 0 and ar.is_anchor_tracking(m["anchor_id"]):
			tracking += 1
			var t: Transform3D = ar.get_anchor_transform(m["anchor_id"])
			m["node"].transform = t
			max_shift = maxf(max_shift, t.origin.distance_to(m["start"]))
	var lines := PackedStringArray()
	lines.append(_planes_summary())
	if not _markers.is_empty():
		lines.append("Markers %d (tracking %d)  max anchor shift %.1f cm" % [
			_markers.size(), tracking, max_shift * 100.0])
	lines.append("FPS %d" % Engine.get_frames_per_second())
	_status.text = "\n".join(lines)

# Plane nodes are recreated by the plugin every frame, so visibility is reapplied each frame.
func _planes_summary() -> String:
	var planes := get_tree().current_scene.get_node_or_null("ARPlanes_node")
	if planes == null:
		return "Planes: none"
	var head_y := 0.0
	var head := XRServer.get_tracker("head") as XRPositionalTracker
	if head and head.has_pose("default"):
		head_y = head.get_pose("default").transform.origin.y
	var heights := PackedStringArray()
	for p in planes.get_children():
		p.visible = _planes_visible
		p.material_override = _plane_material
		heights.append("%.2f" % (head_y - p.global_position.y))
	return "Planes %d, metres below phone: %s" % [heights.size(), ", ".join(heights)]
