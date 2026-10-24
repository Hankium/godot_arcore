@tool
extends Node

# This is the autoload that is set up when enabling the plugin
# It also communicates between ARCore and Godot
# Untyped: ARCoreInterface only exists in Android builds, so this script must also parse on desktop.
var arcore_interface

func _enter_tree():
	if not ClassDB.class_exists("ARCoreInterface"):
		return
	arcore_interface = ClassDB.instantiate("ARCoreInterface")

	if arcore_interface:
		XRServer.add_interface(arcore_interface)

func _exit_tree():
	if arcore_interface:
		XRServer.remove_interface(arcore_interface)
		arcore_interface = null

func get_interface():
	return arcore_interface

func start() -> bool:
	# Godot 4.5+: feeds (including ours) are only handed out while monitoring.
	CameraServer.monitoring_feeds = true
	if arcore_interface and arcore_interface.initialize():
		get_viewport().use_xr = true
		return true
	return false

func get_last_error() -> String:
	return arcore_interface.get_last_error() if arcore_interface else "no interface"

func get_tracking_status():
	if arcore_interface:
		return arcore_interface.get_tracking_status()
	return XRInterface.XR_NOT_TRACKING

func enable_depth_estimation(toggled):
	if arcore_interface:
		arcore_interface.enable_depth_estimation(toggled)

func show_depth_map(toggled):
	if arcore_interface:
		arcore_interface.show_depth_map(toggled)

func set_max_depth_meters(value):
	if arcore_interface:
		arcore_interface.set_max_depth_meters(value)

func enable_vertical_plane_detection(toggled):
	if arcore_interface:
		arcore_interface.enable_vertical_plane_detection(toggled)

func enable_horizontal_plane_detection(toggled):
	if arcore_interface:
		arcore_interface.enable_horizontal_plane_detection(toggled)

func enable_images_detection(toggled):
	if arcore_interface:
		arcore_interface.enable_images_detection(toggled)

func enable_instant_placement(toggled):
	if arcore_interface:
		arcore_interface.enable_instant_placement(toggled)

func enable_light_estimation(toggled):
	if arcore_interface:
		arcore_interface.enable_light_estimation(toggled)

func enable_point_cloud_detection(toggled):
	if arcore_interface:
		arcore_interface.enable_light_estimation(toggled)

func switch_orientation(vertical):
	if arcore_interface:
		arcore_interface.switch_orientation(vertical)

func get_light_main_hdr_direction():
	if arcore_interface:
		return arcore_interface.get_light_main_hdr_direction()

func get_light_main_hdr_intensity():
	if arcore_interface:
		return arcore_interface.get_light_main_hdr_intensity()
