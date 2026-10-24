extends Node3D

var _plugin_name = "ARCorePlugin"
var _android_plugin

var is_estimating_light = false
var original_light_trsf: Transform3D;

# Called when the node enters the scene tree for the first time.
func _ready():
	for s in Engine.get_singleton_list():
		print("MCT " + s.get_basename())
	if Engine.has_singleton(_plugin_name):
		print("MCT found plugin")
		_android_plugin = Engine.get_singleton(_plugin_name)
	else:
		printerr("MCT Couldn't find plugin " + _plugin_name)

	print("MCT before initialize_wrapper")
	_android_plugin.initializeEnvironment()

	print("MCT called initialize_wrapper")

	var ar_interface = ARCoreInterfaceInstance.get_interface()
	var interface_name = ar_interface.get_name()
	print("MCT " + interface_name)

	original_light_trsf = $DirectionalLight3D.transform
	add_child(preload("res://spike_test.gd").new())
	_try_start_ar()

var _ar_started := false
var _retry_timer := 0.0

func _try_start_ar():
	_ar_started = ARCoreInterfaceInstance.start()
	if _ar_started:
		# Godot 4.5+ registers the device cameras as feeds too, so the
		# Environment's default feed id (1) is not the ARCore feed.
		var feed_id = ARCoreInterfaceInstance.get_interface().get_camera_feed_id()
		$Origin3D/Camera3D.environment.background_camera_feed_id = feed_id
	else:
		print("AR start failed: " + ARCoreInterfaceInstance.get_last_error())

func _exit_tree():
	_android_plugin.uninitializeEnvironment()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	# Retry until ARCore starts (first launch waits on camera permission).
	if not _ar_started:
		_retry_timer += delta
		if _retry_timer > 1.0:
			_retry_timer = 0.0
			_try_start_ar()

	if (is_estimating_light):
		var light_dir = ARCoreInterfaceInstance.get_light_main_hdr_direction()
		$DirectionalLight3D.rotation = light_dir
		var intensity = ARCoreInterfaceInstance.get_light_main_hdr_intensity()
		$DirectionalLight3D.light_intensity_lumens = intensity.x;
	else:
		$DirectionalLight3D.transform = original_light_trsf


func _on_node_2d_estimate_depthmap_toggled(toggled):
	ARCoreInterfaceInstance.enable_depth_estimation(toggled)

func _on_node_2d_show_depthmap_toggled(toggled):
	ARCoreInterfaceInstance.show_depth_map(toggled)

func _on_node_2d_far_changed(value):
	ARCoreInterfaceInstance.set_max_depth_meters(value)

func _on_node_2d_vertical_planes_toggled(toggled):
	ARCoreInterfaceInstance.enable_vertical_plane_detection(toggled)

func _on_node_2d_horizontal_planes_toggled(toggled):
	ARCoreInterfaceInstance.enable_horizontal_plane_detection(toggled)

func _on_node_2d_images_detection_toggled(toggled):
	ARCoreInterfaceInstance.enable_images_detection(toggled)

func _on_node_2d_instant_placement_toggled(toggled):
	ARCoreInterfaceInstance.enable_instant_placement(toggled)

func _on_node_2d_light_estimation_toggled(toggled):
	is_estimating_light = toggled
	ARCoreInterfaceInstance.enable_light_estimation(toggled)

func _on_node_2d_point_cloud_detection_toggled(toggled):
	ARCoreInterfaceInstance.enable_point_cloud_detection(toggled)

func _on_node_2d_switch_orientation(vertical):
	ARCoreInterfaceInstance.switch_orientation(vertical)
