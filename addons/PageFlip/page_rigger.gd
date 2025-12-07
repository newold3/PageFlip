@tool
extends Polygon2D

# ==============================================================================
# ENUMS & CONSTANTS
# ==============================================================================

## Defines the material physical properties for the page simulation.
enum PagePreset {
	## Manual configuration. Allows tweaking specific exports.
	CUSTOM,
	## The default balanced configuration.
	DEFAULT,
	## Standard book paper. Balanced weight and flexibility.
	STANDARD_PAPER,
	## Thick, heavy paper like a magic tome or leather.
	HEAVY_GRIMOIRE,
	## Glossy, thin paper. High flexibility and air resistance.
	LIGHT_MAGAZINE,
	## Ancient dry paper. Rolls from the top corner.
	OLD_SCROLL,
	## Solid wood or slate. No bending, linear movement.
	RIGID_BOARD,
	## Heavy fabric feel. High drag, very flexible, slow movement.
	WET_CLOTH,
	## Synthetic material. Springy, snaps back quickly, resists bending.
	PLASTIC_SHEET,
	## Extremely heavy. Slowest movement, almost zero bend.
	METAL_PLATE
}

## Determines the direction of the page turn curve.
enum CurlMode {
	## The entire edge lifts simultaneously.
	STRAIGHT,
	## The top corner lifts first (Hand pulling from top).
	TOP_CORNER_FIRST,
	## The bottom corner lifts first (Hand pulling from bottom).
	BOTTOM_CORNER_FIRST
}

const SKELETON_NAME = "AutoSkeleton"
const SHADOW_NAME = "AutoShadow"


# ==============================================================================
# SIGNALS
# ==============================================================================

signal change_page_requested
signal end_animation


# ==============================================================================
# INTERNAL CACHE (UX)
# ==============================================================================

# Stores custom user settings to prevent data loss when switching presets.
var _custom_cache: Dictionary = {}


# ==============================================================================
# RIG CONFIGURATION
# ==============================================================================

@export_category("Rig Generator")

@export_range(1, 20) var subdivision_x: int = 8
## Vertical subdivisions. Must be > 1 to see the Curl Effect properly.
@export_range(1, 10) var subdivision_y: int = 5
@export var generate_rig_btn: bool = false : set = _on_generate_pressed
@export var clear_rig_btn: bool = false : set = _on_clear_pressed


# ==============================================================================
# ANIMATION CONFIGURATION
# ==============================================================================

@export_category("Animation Generator")

@export_group("Quick Presets")
## Select a material style to auto-configure physics.
@export var animation_preset: PagePreset = PagePreset.CUSTOM : set = _on_preset_changed

@export_group("Manual Configuration")
@export var anim_player: AnimationPlayer
@export var anim_duration: float = 0.75

@export_subgroup("Paper Physics")
## Stiffness of the material. 0.5 = Rubber, 5.0 = Wood.
@export_range(0.5, 5.0, 0.1) var paper_stiffness: float = 2.0
## Bend angle during the lift phase (Negative = Tip drags down).
@export_range(-180.0, 180.0) var lift_bend: float = -10.0
## Bend angle during the landing phase (Negative = Tip floats up).
@export_range(-180.0, 180.0) var land_bend: float = -8.0

@export_subgroup("Curl Effect")
## Which part of the page initiates the movement.
@export var curl_mode: CurlMode = CurlMode.TOP_CORNER_FIRST
## Time delay for the trailing corner (0.0 = None, 1.0 = High lag).
@export_range(0.0, 1.0, 0.05) var curl_lag: float = 0.8

@export_subgroup("Shadow FX")
## Create a dynamic shadow behind the page.
@export var enable_shadow: bool = true
## Color and alpha of the shadow.
@export var shadow_color: Color = Color(0, 0, 0, 0.3)

@export_subgroup("Fine Timing")
## Normalized time (0.0 - 1.0) for the peak lift position.
@export_range(0.05, 0.45, 0.01) var timing_peak_lift: float = 0.15
## Normalized time (0.0 - 1.0) for the landing contact.
@export_range(0.55, 0.95, 0.01) var timing_peak_land: float = 0.85

@export var generate_anims_btn: bool = false : set = _on_anim_pressed


# ==============================================================================
# RUNTIME INITIALIZATION
# ==============================================================================

func _ready():
	# Forces this page (and its children shadows) to draw above the static book (Z=0).
	self.z_index = 10
	
	if animation_preset == PagePreset.CUSTOM:
		_save_state_to_cache()


func rebuild(current_page_size: Vector2 = Vector2.ZERO) -> void:
	if not anim_player: return
	_clean_previous_rig()
	_create_rig_logic(current_page_size)
	_generate_animations_logic()


# ==============================================================================
# PRESET LOGIC & CACHING
# ==============================================================================

func _on_preset_changed(val):
	if animation_preset == PagePreset.CUSTOM:
		_save_state_to_cache()
	
	animation_preset = val
	
	if val == PagePreset.CUSTOM:
		if not _custom_cache.is_empty():
			_load_state_from_cache()
			print("[PageRigger] Restored Custom Settings from Cache.")
		notify_property_list_changed()
		return
	
	# Default Reset values
	curl_mode = CurlMode.BOTTOM_CORNER_FIRST
	curl_lag = 0.3
	enable_shadow = true
	anim_duration = 0.75
	
	match val:
		PagePreset.DEFAULT:
			paper_stiffness = 2.0; lift_bend = -10.0; land_bend = -8.0
			curl_mode = CurlMode.TOP_CORNER_FIRST; curl_lag = 0.8
			timing_peak_lift = 0.15; timing_peak_land = 0.85
			anim_duration = 0.75
			enable_shadow = true
			
		PagePreset.STANDARD_PAPER:
			paper_stiffness = 1.8; lift_bend = -12.0; land_bend = -10.0
			timing_peak_lift = 0.15; timing_peak_land = 0.85
			curl_mode = CurlMode.TOP_CORNER_FIRST; curl_lag = 0.6
			anim_duration = 0.7
			
		PagePreset.HEAVY_GRIMOIRE:
			paper_stiffness = 3.5; lift_bend = -4.0; land_bend = -2.0
			timing_peak_lift = 0.25; timing_peak_land = 0.75
			curl_mode = CurlMode.STRAIGHT; curl_lag = 0.1
			anim_duration = 0.9
			
		PagePreset.LIGHT_MAGAZINE:
			paper_stiffness = 0.8; lift_bend = -15.0; land_bend = -12.0
			timing_peak_lift = 0.10; timing_peak_land = 0.90
			curl_lag = 0.5
			anim_duration = 0.7
			
		PagePreset.OLD_SCROLL:
			paper_stiffness = 2.2; lift_bend = -8.0; land_bend = -12.0
			timing_peak_lift = 0.20; timing_peak_land = 0.80
			curl_mode = CurlMode.TOP_CORNER_FIRST; curl_lag = 0.4
			anim_duration = 0.8
			
		PagePreset.RIGID_BOARD:
			paper_stiffness = 5.0; lift_bend = 0.0; land_bend = 0.0
			timing_peak_lift = 0.5; timing_peak_land = 0.5
			curl_mode = CurlMode.STRAIGHT; curl_lag = 0.0
			anim_duration = 0.8
			
		PagePreset.WET_CLOTH:
			# Slightly higher bends to simulate heavy drooping, but kept within reasonable limits
			paper_stiffness = 0.5; lift_bend = -20.0; land_bend = -15.0
			timing_peak_lift = 0.20; timing_peak_land = 0.85
			curl_mode = CurlMode.BOTTOM_CORNER_FIRST; curl_lag = 0.6
			anim_duration = 0.9
			
		PagePreset.PLASTIC_SHEET:
			paper_stiffness = 3.0; lift_bend = -8.0; land_bend = -15.0
			timing_peak_lift = 0.10; timing_peak_land = 0.60
			curl_mode = CurlMode.TOP_CORNER_FIRST; curl_lag = 0.1
			anim_duration = 0.75
			
		PagePreset.METAL_PLATE:
			paper_stiffness = 5.0; lift_bend = -1.0; land_bend = -0.5
			timing_peak_lift = 0.40; timing_peak_land = 0.60
			curl_mode = CurlMode.STRAIGHT; curl_lag = 0.0
			anim_duration = 0.9
	
	notify_property_list_changed()
	
	if anim_player and skeleton != NodePath(""):
		_generate_animations_logic()
		print("[PageRigger] Preset Applied: ", PagePreset.keys()[val])


func _save_state_to_cache():
	_custom_cache = {
		"stiffness": paper_stiffness, "lift": lift_bend, "land": land_bend,
		"curl_m": curl_mode, "curl_l": curl_lag,
		"t_lift": timing_peak_lift, "t_land": timing_peak_land,
		"dur": anim_duration, "shadow": enable_shadow
	}


func _load_state_from_cache():
	paper_stiffness = _custom_cache.get("stiffness", 1.5)
	lift_bend = _custom_cache.get("lift", -30.0)
	land_bend = _custom_cache.get("land", -15.0)
	curl_mode = _custom_cache.get("curl_m", CurlMode.BOTTOM_CORNER_FIRST)
	curl_lag = _custom_cache.get("curl_l", 0.3)
	timing_peak_lift = _custom_cache.get("t_lift", 0.15)
	timing_peak_land = _custom_cache.get("t_land", 0.85)
	anim_duration = _custom_cache.get("dur", 1.0)
	enable_shadow = _custom_cache.get("shadow", true)


# ==============================================================================
# RIGGING LOGIC
# ==============================================================================

func _create_rig_logic(current_page_size: Vector2 = Vector2.ZERO):
	self.z_index = 10
	
	var original_size = Vector2(512, 820)
	var tex_size: Vector2 = Vector2.ZERO
	if current_page_size != Vector2.ZERO:
		tex_size = current_page_size
	elif texture:
		tex_size = texture.get_size()
	
	if tex_size == Vector2.ZERO:
		tex_size = original_size
	
	var step_x = tex_size.x / subdivision_x
	var step_y = tex_size.y / subdivision_y
	
	# --- 0. SHADOW GENERATION ---
	if enable_shadow:
		var shadow = Polygon2D.new()
		shadow.name = SHADOW_NAME
		shadow.z_index = -1
		shadow.color = shadow_color
		
		shadow.polygon = PackedVector2Array([
			Vector2(0, 0), Vector2(tex_size.x, 0),
			Vector2(tex_size.x, tex_size.y), Vector2(0, tex_size.y)
		])
		shadow.uv = shadow.polygon
		add_child(shadow)
		
		if Engine.is_editor_hint() and get_tree().edited_scene_root:
			shadow.owner = get_tree().edited_scene_root

	# --- 1. MESH GENERATION ---
	var new_uvs = PackedVector2Array()
	for y in range(subdivision_y + 1):
		for x in range(subdivision_x + 1):
			new_uvs.append(Vector2(x * step_x, y * step_y))
	self.uv = new_uvs
	self.polygon = new_uvs
	
	var new_polygons = []
	var rc = subdivision_x + 1
	for y in range(subdivision_y):
		for x in range(subdivision_x):
			var i = y * rc + x
			new_polygons.append(PackedInt32Array([i, i + 1, i + rc + 1, i + rc]))
	self.polygons = new_polygons
	
	# --- 2. SKELETON GENERATION ---
	var sk = Skeleton2D.new()
	sk.name = SKELETON_NAME
	add_child(sk)
	if Engine.is_editor_hint() and get_tree().edited_scene_root:
		sk.owner = get_tree().edited_scene_root
	self.skeleton = NodePath(SKELETON_NAME)
	
	# --- 3. BONES GENERATION ---
	for y in range(subdivision_y + 1):
		var pb = null
		for x in range(subdivision_x + 1):
			var b = Bone2D.new()
			b.name = "Bone_%d_%d" % [x, y]
			
			b.set_autocalculate_length_and_angle(false)
			b.set_length(step_x)
			
			if x == 0:
				sk.add_child(b); b.position = Vector2(0, y * step_y)
			else:
				pb.add_child(b); b.position = Vector2(step_x, 0)
			
			if Engine.is_editor_hint() and get_tree().edited_scene_root:
				b.owner = get_tree().edited_scene_root
				
			b.set_rest(b.transform)
			pb = b
	
	# --- 4. WEIGHTS ---
	self.clear_bones()
	var bi = 0
	for y in range(subdivision_y + 1):
		for x in range(subdivision_x + 1):
			var bone_name = "Bone_%d_%d" % [x, y]
			var ab = sk.find_child(bone_name, true, false)
			if ab:
				var w = PackedFloat32Array(); w.resize(new_uvs.size()); w.fill(0.0)
				w[bi] = 1.0
				self.add_bone(ab.get_path(), w)
			bi += 1
	queue_redraw()


# ==============================================================================
# ANIMATION LOGIC
# ==============================================================================

func _generate_animations_logic():
	var library: AnimationLibrary
	if anim_player.has_animation_library(""): library = anim_player.get_animation_library("")
	else: library = AnimationLibrary.new(); anim_player.add_animation_library("", library)
	
	# 1. Standard: Right to Left (0 -> -180)
	_create_single_anim(library, "turn_flexible_page", false, false)
	_create_single_anim(library, "turn_rigid_page", true, false)
	
	# 2. Mirror: Left to Right (-180 -> 0)
	_create_single_anim(library, "turn_flexible_page_mirror", false, true)
	_create_single_anim(library, "turn_rigid_page_mirror", true, true)


func _create_single_anim(library: AnimationLibrary, anim_name: String, is_rigid: bool, is_mirror: bool):
	var anim = Animation.new()
	anim.length = anim_duration
	anim.step = 0.01
	
	if library.has_animation(anim_name): library.remove_animation(anim_name)
	library.add_animation(anim_name, anim)
	
	var sk_node = find_child(SKELETON_NAME, true, false)
	if not sk_node: return
	
	# --- Z-INDEX ANIMATION ---
	var z_track = anim.add_track(Animation.TYPE_VALUE)
	var my_path = anim_player.get_node(anim_player.root_node).get_path_to(self)
	anim.track_set_path(z_track, str(my_path) + ":z_index")
	
	anim.track_insert_key(z_track, 0.0, 10)
	anim.track_insert_key(z_track, anim_duration * 0.5, 25)
	anim.track_insert_key(z_track, anim_duration * 0.65, 10)
	
	# --- SHADOW ANIMATION ---
	var shadow_node = find_child(SHADOW_NAME, true, false)
	if shadow_node and enable_shadow:
		var shadow_path = anim_player.get_node(anim_player.root_node).get_path_to(shadow_node)
		
		var t_scale = anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(t_scale, str(shadow_path) + ":scale")
		anim.track_set_interpolation_type(t_scale, Animation.INTERPOLATION_CUBIC)
		
		var t_mod = anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(t_mod, str(shadow_path) + ":modulate")
		
		var start_col = shadow_color
		var invisible_col = shadow_color; invisible_col.a = 0.0
		var faded_col = shadow_color; faded_col.a *= 0.5
		
		var safe_delay = 0.15
		
		# Define visual flow for ScaleX:
		# Standard (R->L): 1.0 -> 0.0 -> -1.0
		# Mirror (L->R):  -1.0 -> 0.0 -> 1.0
		var s_start_val = Vector2(-1.0, 1.0) if is_mirror else Vector2(1.0, 1.0)
		var s_end_val = Vector2(1.0, 1.0) if is_mirror else Vector2(-1.0, 1.0)
		
		anim.track_insert_key(t_scale, 0.0, s_start_val)
		anim.track_insert_key(t_mod, 0.0, invisible_col)
		anim.track_insert_key(t_mod, safe_delay, start_col)
		
		anim.track_insert_key(t_scale, anim_duration * 0.5, Vector2(0.01, 1.0))
		anim.track_insert_key(t_mod, anim_duration * 0.5, faded_col)
		
		anim.track_insert_key(t_scale, anim_duration, s_end_val)
		anim.track_insert_key(t_mod, anim_duration * 0.99, invisible_col)

	# --- PAGE BONE ANIMATION ---
	for y in range(subdivision_y + 1):
		var row_factor = 1.0
		
		# Calculate Curl Factor
		if not is_rigid and curl_mode != CurlMode.STRAIGHT:
			var y_ratio = float(y) / float(max(1, subdivision_y))
			if curl_mode == CurlMode.TOP_CORNER_FIRST:
				# Even if mirroring, we usually want top corner to move first relative to user
				row_factor = lerp(1.0, 1.0 - curl_lag, y_ratio)
			elif curl_mode == CurlMode.BOTTOM_CORNER_FIRST:
				row_factor = lerp(1.0 - curl_lag, 1.0, y_ratio)
		
		var time_offset = (1.0 - row_factor) * (anim_duration * 0.1)
		
		for x in range(subdivision_x + 1):
			var bone_name = "Bone_%d_%d" % [x, y]
			var bone = sk_node.find_child(bone_name, true, false)
			if not bone: continue
			
			var t_idx = anim.add_track(Animation.TYPE_VALUE)
			var path = anim_player.get_node(anim_player.root_node).get_path_to(bone)
			anim.track_set_path(t_idx, str(path) + ":rotation_degrees")
			anim.track_set_interpolation_type(t_idx, Animation.INTERPOLATION_CUBIC)
			
			# Determine Key Values based on Direction (Mirror vs Standard)
			var deg_flat_right = 0.0
			var deg_flat_left = -179.9 # Avoid -180 flipping issues
			var deg_mid = -90.0
			
			if is_rigid:
				if x == 0:
					# Standard: 0 -> -90 -> -180
					# Mirror: -180 -> -90 -> 0
					var start_rot = deg_flat_left if is_mirror else deg_flat_right
					var end_rot = deg_flat_right if is_mirror else deg_flat_left
					
					anim.track_insert_key(t_idx, 0.0, start_rot)
					anim.track_insert_key(t_idx, anim_duration * 0.5, deg_mid)
					anim.track_insert_key(t_idx, anim_duration, end_rot)
				else:
					anim.track_insert_key(t_idx, 0.0, 0.0)
					anim.track_insert_key(t_idx, anim_duration, 0.0)
			else:
				var x_ratio = float(x) / float(subdivision_x)
				var influence = pow(x_ratio, paper_stiffness)
				
				var t_lift = clamp((anim_duration * timing_peak_lift) + time_offset, 0.0, (anim_duration * 0.5) - 0.05)
				var t_mid = anim_duration * 0.5
				var t_land = clamp((anim_duration * timing_peak_land) - time_offset, t_mid + 0.05, anim_duration)
				
				# --- Rotation Logic ---
				if x == 0:
					# Spine Bone (Main Rotation)
					var start_rot = deg_flat_left if is_mirror else deg_flat_right
					var end_rot = deg_flat_right if is_mirror else deg_flat_left
					
					# Lift Phase (Spine)
					# Standard: 0 -> -15
					# Mirror: -180 -> -165
					var spine_lift_val = -15.0 * row_factor
					if is_mirror: spine_lift_val = deg_flat_left - spine_lift_val 
					
					# Land Phase (Spine)
					# Standard: -90 -> -180 (Smoothed)
					# Mirror: -90 -> 0 (Smoothed)
					var spine_land_target = lerp(-90.0, -180.0, timing_peak_land)
					if is_mirror: spine_land_target = lerp(-90.0, 0.0, timing_peak_land)
					
					anim.track_insert_key(t_idx, 0.0, start_rot)
					anim.track_insert_key(t_idx, t_lift, spine_lift_val)
					anim.track_insert_key(t_idx, t_mid, deg_mid)
					anim.track_insert_key(t_idx, t_land, spine_land_target)
					anim.track_insert_key(t_idx, anim_duration, end_rot)
				else:
					# Paper Bones (Bending)
					# The bending is relative to the parent bone.
					var bend_multiplier = -1.0 if is_mirror else 1.0
					
					var current_lift_bend = lift_bend * row_factor * bend_multiplier
					var current_land_bend = land_bend * row_factor * bend_multiplier
					
					anim.track_insert_key(t_idx, 0.0, 0.0)
					anim.track_insert_key(t_idx, t_lift, current_lift_bend * influence)
					anim.track_insert_key(t_idx, t_mid, 0.0)
					anim.track_insert_key(t_idx, t_land, current_land_bend * influence)
					anim.track_insert_key(t_idx, anim_duration, 0.0)

	var method_track = anim.add_track(Animation.TYPE_METHOD)
	anim.track_set_path(method_track, str(my_path))
	anim.track_insert_key(method_track, anim_duration * 0.5, {"method": "_trigger_midpoint", "args": []})
	anim.track_insert_key(method_track, anim_duration, {"method": "_trigger_end", "args": []})


# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

func _trigger_midpoint(): emit_signal("change_page_requested")
func _trigger_end(): emit_signal("end_animation")


func _on_generate_pressed(val):
	if val:
		generate_rig_btn=false
		_clean_previous_rig()
		_create_rig_logic()


func _on_clear_pressed(val):
	if val:
		clear_rig_btn=false
		_clean_previous_rig()


func _on_anim_pressed(val):
	if val:
		generate_anims_btn=false
		if anim_player and skeleton!=NodePath(""):
			_generate_animations_logic()


func _clean_previous_rig():
	for c in get_children():
		remove_child(c)
		c.free()
	
	var old_shadow = find_child(SHADOW_NAME, true, false)
	if old_shadow: old_shadow.free()
	
	clear_bones()
	skeleton = NodePath("")
