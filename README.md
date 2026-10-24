# godot_arcore (Godot 4.7 fork)

ARCore plugin for **Godot 4.7** on Android, built as a GDExtension.
It gives you the camera feed as the scene background, 6DoF phone tracking,
plane detection, and hit tests that return persistent ARCore anchors.

This is a fork of [GodotVR/godot_arcore](https://github.com/GodotVR/godot_arcore).
Upstream targets Godot 4.2–4.4 and shows a black screen on Godot 4.5+.
This fork fixes that and adds a working hit test and anchor API.

| | |
|---|---|
| **Godot** | 4.7.2 (Compatibility renderer) |
| **Platform** | Android, arm64-v8a |
| **ARCore SDK** | 1.44 |
| **Tested on** | Samsung Galaxy Note 10+ (SM-N975F) |
| **License** | MIT (same as upstream) |

> iOS / ARKit is out of scope for this repo.

## Features

- **Camera passthrough:** the ARCore camera image is the 3D scene's background.
- **Tracking:** the phone's position and rotation drive the XR camera.
- **Plane detection:** horizontal and/or vertical planes, drawn as debug meshes.
- **Hit test + anchors:** tap the screen to find a point on a detected plane and get an ARCore anchor that ARCore keeps correcting as it learns more about the room.
- **Light estimation:** main light direction and intensity.
- Instant placement, point cloud and image detection flags from upstream are kept, but are untested in this fork.

Measured on the Note 10+: steady 30 FPS (the camera rate), and anchors stay within 2.5–3.5 cm after a full lap of a room.

## Quick start (use the prebuilt demo as a template)

1. Build the plugin (see [Building](#building)). The output lands in `plugin/demo/addons/ARCorePlugin/`.
2. Copy `plugin/demo/addons/ARCorePlugin/` into your project's `addons/` folder.
3. In Godot:
   - **Project → Project Settings → Plugins**: enable *ARCorePlugin*. This adds the `ARCoreInterfaceInstance` autoload.
   - **Project Settings → Rendering**: set the renderer to *Compatibility*.
   - **Project → Install Android Build Template**.
   - **Export → Android preset**:
     - enable *Use Gradle Build*
     - set *XR Mode* to *Regular*
     - enable the *Camera* permission
     - target only *arm64-v8a*
4. Add a `Camera3D` with an `Environment` whose background mode is *Camera Feed*, then start AR (below).

## Usage

### Start AR

```gdscript
extends Node3D

@onready var camera: Camera3D = $Camera3D
var _ar_started := false
var _retry := 0.0

func _ready() -> void:
	Engine.get_singleton("ARCorePlugin").initializeEnvironment()
	_try_start()

func _process(delta: float) -> void:
	# On first launch ARCore waits for the camera permission, so keep retrying.
	if not _ar_started:
		_retry += delta
		if _retry > 1.0:
			_retry = 0.0
			_try_start()

func _try_start() -> void:
	_ar_started = ARCoreInterfaceInstance.start()
	if _ar_started:
		var ar = ARCoreInterfaceInstance.get_interface()
		camera.environment.background_camera_feed_id = ar.get_camera_feed_id()
	else:
		print("AR not started: ", ARCoreInterfaceInstance.get_last_error())
```

`ARCoreInterfaceInstance.start()` turns on `CameraServer.monitoring_feeds` and sets `use_xr` on the viewport for you.

### Place an anchored object on a plane

```gdscript
func _ready() -> void:
	ARCoreInterfaceInstance.enable_horizontal_plane_detection(true)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		var ar = ARCoreInterfaceInstance.get_interface()
		var hit: Dictionary = ar.hit_test_plane(event.position.x, event.position.y)
		if hit.hit:
			var marker := preload("res://marker.tscn").instantiate()
			marker.transform = hit.transform
			marker.set_meta("anchor_id", hit.anchor_id)
			marker.add_to_group("markers")
			add_child(marker)

func _process(_delta: float) -> void:
	var ar = ARCoreInterfaceInstance.get_interface()
	for marker in get_tree().get_nodes_in_group("markers"):
		var id: int = marker.get_meta("anchor_id")
		if ar.is_anchor_tracking(id):
			marker.transform = ar.get_anchor_transform(id)  # follow ARCore's corrections
```

## API

Methods on the `ARCoreInterface` object, from `ARCoreInterfaceInstance.get_interface()`:

| Method | Description |
|---|---|
| `get_camera_feed_id() -> int` | Id of the ARCore `CameraFeed`. Assign it to `Environment.background_camera_feed_id`. |
| `get_last_error() -> String` | Last ARCore failure, e.g. `ArSession_create failed: -100`. |
| `hit_test_plane(x, y) -> Dictionary` | Hit test against detected planes at a screen position. Returns `{hit: bool, transform: Transform3D, anchor_id: int}`. |
| `get_anchor_transform(anchor_id) -> Transform3D` | Current pose of an anchor in world space. |
| `is_anchor_tracking(anchor_id) -> bool` | Whether ARCore is currently tracking the anchor. |
| `remove_anchor(anchor_id)` | Detaches and frees the anchor. |
| `enable_horizontal_plane_detection(bool)` / `enable_vertical_plane_detection(bool)` | Plane finding mode. |
| `enable_light_estimation(bool)`, `get_light_main_hdr_direction()`, `get_light_main_hdr_intensity()` | Environmental HDR light estimate. |
| `enable_depth_estimation(bool)`, `is_depth_supported()` | Depth API toggle (depth image is not yet exposed). |

The upstream `getHitPose` / `getHitRayPose` methods are still bound but are **broken**: they use unallocated ARCore objects. Use `hit_test_plane` instead.

## Building

### Requirements

- Android Studio (for the SDK and its bundled JDK 21)
- Android NDK **27.0.12077973**, SDK platform 33, build-tools 35
- Python 3 + SCons (`pip install scons`)

### 1. Clone with submodules

```sh
git clone --recurse-submodules https://github.com/Hankium/godot_arcore.git
cd godot_arcore
```

### 2. Build godot-cpp for Android

`godot-cpp` hardcodes NDK 23. To use NDK 27, leave `ANDROID_HOME` empty and point `ANDROID_NDK_ROOT` at it:

```sh
cd godot-cpp
export ANDROID_NDK_ROOT=$ANDROID_SDK/ndk/27.0.12077973
scons platform=android arch=arm64 target=template_debug   ANDROID_HOME= custom_api_file=../thirdparty/godot_cpp_extension_api/extension_api.json -j8
scons platform=android arch=arm64 target=template_release ANDROID_HOME= custom_api_file=../thirdparty/godot_cpp_extension_api/extension_api.json -j8
cd ..
```

<details><summary>Windows (PowerShell)</summary>

```powershell
cd godot-cpp
$env:ANDROID_NDK_ROOT = "$env:LOCALAPPDATA\Android\Sdk\ndk\27.0.12077973"
python -m SCons platform=android arch=arm64 target=template_debug   "ANDROID_HOME=" custom_api_file=../thirdparty/godot_cpp_extension_api/extension_api.json -j8
python -m SCons platform=android arch=arm64 target=template_release "ANDROID_HOME=" custom_api_file=../thirdparty/godot_cpp_extension_api/extension_api.json -j8
cd ..
```
</details>

### 3. Build the plugin

Create `local.properties` in the repo root with `sdk.dir=<path to Android SDK>`, then:

```sh
JAVA_HOME="<Android Studio>/jbr" ./gradlew assemble
```

The AARs are copied to `plugin/demo/addons/ARCorePlugin/bin/`.

> On Linux, if `./gradlew` fails to start, convert its line endings with `dos2unix ./gradlew`.

### 4. Run the demo

Open `plugin/demo/project.godot` in Godot 4.7 and export to an ARCore-capable phone. The demo includes:

- the upstream feature toggles (left)
- a yellow **diagnostics overlay**: XR interface state, camera feeds, permissions, tracking status and the log tail. Useful without adb.
- **tap-to-place markers** anchored to planes, with a live "anchor shift" readout
- a **darkness post-process** test (flashlight cone, grain, vignette) over the camera feed

On desktop the editor reports `ARCoreInterface` parse errors. That's expected: the class only exists in the Android build.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| Black background, objects drawn | The Environment isn't bound to the ARCore feed, or feed monitoring is off. Use `ARCoreInterfaceInstance.start()` and set `background_camera_feed_id` as shown above. |
| Background smears / trails | Same as above: nothing clears the frame because no feed is drawn. |
| `ARCore(init=false)` | Check `get_last_error()`. Common causes: the camera permission isn't granted yet (keep retrying), or *Google Play Services for AR* is missing or outdated. |
| `jlink` error during Gradle build | You're on AGP < 8.2 with JDK 21. This fork uses AGP 8.5.2. |
| Crash once planes appear after editing `plane_renderer.cpp` | Keep the `CSGPolygon3D` depth at 0.01 or more; 0.002 crashes. |
| `CameraServer is not actively monitoring feeds` | Set `CameraServer.monitoring_feeds = true` before reading feeds (`start()` does this). |

## Known limitations

- arm64 only by default. x86/x86_64 for the emulator needs extra godot-cpp builds and ABI filters (see the upstream README history).
- Plane debug meshes are rebuilt every frame and use CSG. Fine for debugging; use your own visuals for production.
- Display rotation is fixed to landscape.
- Depth images, image tracking and point clouds are not exposed beyond the upstream toggles.

## Credits

Original plugin by the [GodotVR](https://github.com/GodotVR) contributors (see [CONTRIBUTORS.md](CONTRIBUTORS.md)).
Godot 4.7 fixes and the anchor API by [Hankium](https://github.com/Hankium).
