@tool
class_name PageFlip2D
extends Node2D

## Main controller for the Book system. Handles animations, volume logic, and interactive scenes.
##
## [b]ADVANCED FEATURE: INTERACTIVE PAGE SCENES (INPUT HANDSHAKE)[/b][br]
## This script supports fully interactive scenes (UI, puzzles, maps) embedded as pages.[br]
## It automatically manages an "Input Handshake" to prevent conflicts between[br]
## the Book (turning pages) and the Scene (interaction).[br]
## [br]
## [b]LOGIC FLOW:[/b][br]
## - Uses 4 internal Viewport Slots.[br]
## - Slot 1: Static Left Page.[br]
## - Slot 2: Static Right Page.[br]
## - Slot 3: Dynamic Page Face A.[br]
## - Slot 4: Dynamic Page Face B.[br]
## - Content is instantiated (Scenes) or placed in TextureRects (Images) automatically.

## Defines how textures are stretched within the page boundaries.
enum PageStretchOption {
	## Scales the texture to fit the page rect, potentially distorting aspect ratio.
	SCALE = TextureRect.STRETCH_SCALE,
	## Keeps the aspect ratio and centers the texture, leaving blank space if necessary.
	KEEP_ASPECT_CENTERED = TextureRect.STRETCH_KEEP_ASPECT_CENTERED,
	## Keeps the aspect ratio but covers the entire page, potentially cropping the image.
	KEEP_ASPECT_COVERED = TextureRect.STRETCH_KEEP_ASPECT_COVERED
}

## Defines the condition required to trigger the book closing sequence.
enum CloseCondition {
	## The book will never close automatically.
	NEVER,
	## The book closes only when finishing the animation that shuts the back cover (Right to Left).
	CLOSE_FROM_BACK,
	## The book closes only when finishing the animation that shuts the front cover (Left to Right).
	CLOSE_FROM_FRONT,
	## The book closes when shutting either the front or the back cover.
	ANY_CLOSE,
	## The book closes immediately when the 'ui_cancel' action (e.g., ESC) is pressed.
	ON_CANCEL_INPUT,
	## The book closing logic is handled manually by an interactive scene (calling force_close_book).
	DELEGATED
}

## Defines what happens to the Book node after it closes.
enum CloseBehavior {
	## The Book node is deleted from the scene tree (queue_free).
	DESTROY_BOOK,
	## The game changes to a specific scene defined in 'target_scene_on_close'.
	CHANGE_SCENE
}

@export_category("Newold Config")
## Apply the custom configuration defined by Newold (Size, Physics, Layers).
## Clicking this will overwrite current physics and sizing settings with the recommended preset.
@export var apply_newold_preset: bool = false : set = _apply_newold_config

# ==============================================================================
# 1. REFERENCES & CONFIGURATION
# ==============================================================================
@export_category("Structure References")
## Container for all book visuals (Pages, Covers, Spine).
@export var visuals_container: Node2D
## Static polygon representing the left page (Slot 1).
@export var static_left: Polygon2D
## Static polygon representing the right page (Slot 2).
@export var static_right: Polygon2D
## Dynamic polygon used for the turning page animation (Slot 3 & 4).
@export var dynamic_poly: Polygon2D
## Animation player handling the page flip sequences.
@export var anim_player: AnimationPlayer

@export_category("Compositor (Dynamic Texture)")
## SubViewport used to render the page content dynamically before applying it to the mesh.
@export var vp_compositor: SubViewport
## Sprite inside the viewport showing the current page content.
@export var compositor_sprite: Sprite2D

@export_category("Book Logic & Closing")
## Determines when the book should perform the close action (e.g., destroy or change scene).
@export var close_condition: CloseCondition = CloseCondition.NEVER
## Determines what happens when the book closes (Destroy or Change Scene).
@export var close_behavior: CloseBehavior = CloseBehavior.DESTROY_BOOK : set = _set_close_behavior
## The file path to the scene to load if 'Change Scene' is selected as behavior.
@export_file("*.tscn") var target_scene_on_close: String
## If true, pages with transparency will be composited over the 'Blank Page' texture/color.
## Useful for PNG notes or decals that need a paper background.
@export var enable_composite_pages: bool = false

@export_category("Styling & Spine")
## Base color for pages without texture content or the background of composite pages.
@export var blank_page_color: Color = Color.WHITE
## Texture used when a page path is invalid, empty, or for the background of composite pages.
@export var blank_page_texture: Texture2D
## Color tint for the central spine of the book.
@export var spine_color: Color = Color(1, 1, 1) : set = _set_spine_color
## Texture for the central spine of the book.
@export var spine_texture: Texture2D : set = _set_spine_texture
## Width of the central spine in pixels.
@export var spine_width: float = 40.0
## Determines if the front and back covers behave as rigid bodies (hard cover) or flexible (soft cover).
@export var covers_are_rigid: bool = true

# ==============================================================================
# FAKE 3D TRANSFORM SETTINGS
# ==============================================================================
@export_category("Fake 3D (Transform)")
@export_group("Closed State")
## Scale of the book container when fully closed.
@export var closed_scale: Vector2 = Vector2(1.0, 0.85)
## Skew (shear) applied when closed to simulate perspective or isometric view.
@export_range(-1.0, 1.0) var closed_skew: float = 0.0
## Rotation (degrees) of the book when closed.
@export_range(-360.0, 360.0) var closed_rotation: float = 0.0

@export_group("Open State")
## Scale of the book container when fully open.
@export var open_scale: Vector2 = Vector2(1.0, 1.0)
## Skew (shear) applied when open.
@export var open_skew: float = 0.0
## Rotation (degrees) of the book when open.
@export var open_rotation: float = 0.0

# ==============================================================================
# FAKE 3D VOLUME (PAGES)
# ==============================================================================
@export_category("Fake 3D Volume (Pages)")
## Minimum number of layers to generate for the page stack (visual thickness floor).
@export_range(1, 20) var min_layers: int = 3
## Maximum number of layers to generate for the page stack (visual thickness ceiling).
@export_range(1, 100) var max_layers: int = 15
## If true, the stack grows upwards (negative Y). If false, downwards (positive Y).
@export var invert_stack_direction: bool = false
## Offset between layers when the book is closed (max compression).
@export var layer_offset_closed: Vector2 = Vector2(0, 1.5)
## Offset between layers when the book is open (relaxed compression).
@export var layer_offset_open: Vector2 = Vector2(0, 0.2)
## Base color tint for the volume layers (paper edges).
@export var volume_color: Color = Color(0.8, 0.75, 0.6)
## Darkening factor for alternating layers to create a paper texture effect.
@export_range(0.0, 1.0) var stripe_darken_ratio: float = 0.85
## Global positional offset for the entire volume stack.
@export var volume_stack_offset: Vector2 = Vector2.ZERO
## Time in seconds before the animation ends to "land" the page on the stack visually.
@export var landing_overlap: float = 0.15

@export_category("Audio")
## Sound played when a rigid cover slams shut.
@export var sfx_book_impact: AudioStream
## Sound played when a flexible page turns.
@export var sfx_page_flip: AudioStream
## Time offset to sync the impact sound with the visual contact frame.
@export var impact_sync_offset: float = 0.15
## AudioStreamPlayer node used for feedback.
@export var audio_player: AudioStreamPlayer

@export_category("Book Size Control")
## Target size (Resolution) for the book pages. Affects Viewports and Meshes.
@export var target_page_size: Vector2 = Vector2(512, 820)
## Button to apply size changes in the editor.
@export var apply_size_change: bool = false : set = _on_apply_size_pressed

@export_category("Content Source")
## List of paths to textures (*.png, *.jpg) or PackedScenes (*.tscn) for pages.
@export_file("*.png", "*.jpg", "*.jpeg", "*.tscn") var pages_paths: Array[String] = []
## Determines how standard images (textures) are stretched within the page boundaries.
@export var page_stretch_mode: PageStretchOption = PageStretchOption.SCALE
## External front cover texture.
@export var tex_cover_front_out: Texture2D
## Internal front cover texture.
@export var tex_cover_front_in: Texture2D
## Internal back cover texture.
@export var tex_cover_back_in: Texture2D
## External back cover texture.
@export var tex_cover_back_out: Texture2D

# ==============================================================================
# 2. INTERNAL STATE
# ==============================================================================
var current_spread: int = -1
var total_spreads: int = 0
var is_animating: bool = false
var going_forward: bool = true
var page_width: float
var is_book_open: bool = false

var _runtime_pages: Array[String] = []
var _spine_poly: Polygon2D

# Slot References (Viewports)
var _slot_1: SubViewport # Left Page
var _slot_2: SubViewport # Right Page
var _slot_3: SubViewport # Animation Face A
var _slot_4: SubViewport # Animation Face B

var _active_interactive_is_left: bool = false
var _active_interactive_is_right: bool = false
var _scene_cache = {}

# Internal references for volume generation
var _volume_root: Node2D
var _current_expansion_factor: float = 0.0
var _visual_spread_index: float = -1.0
var _stack_scale_left: float = 1.0
var _stack_scale_right: float = 1.0

# Animation flags
var _is_page_flying: bool = false
var _flying_from_right: bool = false
var _force_hide_vol_left: bool = false
var _force_hide_vol_right: bool = false
var _pending_target_spread_idx: int = 0

# Flag to handle forced closing animation state (API force_close_book)
var _is_force_closing: bool = false


func _validate_property(property: Dictionary) -> void:
	if property.name == "target_scene_on_close":
		if close_behavior != CloseBehavior.CHANGE_SCENE:
			property.usage = PROPERTY_USAGE_NO_EDITOR

func _set_close_behavior(value):
	close_behavior = value
	notify_property_list_changed()

func _apply_newold_config(val):
	if not val: return
	apply_newold_preset = false
	print("[BookController] Applying 'Newold' configuration...")
	blank_page_color = Color.WHITE
	blank_page_texture = preload("uid://cen51wqc15b14")
	spine_color = Color.WHITE
	spine_texture = preload("uid://cit41jypw2sy1")
	spine_width = 12.0
	covers_are_rigid = true
	closed_scale = Vector2(0.815, 0.23)
	closed_skew = 0.2
	closed_rotation = 0.1
	open_scale = Vector2(1.0, 1.0)
	open_skew = 0.0
	open_rotation = 0.0
	min_layers = 1
	max_layers = 15
	invert_stack_direction = false
	layer_offset_closed = Vector2(0.7, 12.0)
	layer_offset_open = Vector2(0.6, 2.0)
	volume_color = Color("#a6978f")
	stripe_darken_ratio = 0.848
	volume_stack_offset = Vector2(0, 0)
	landing_overlap = 0.15
	sfx_book_impact = preload("uid://bhitebdghyhua")
	sfx_page_flip = preload("uid://bylfc3b5pmbij")
	impact_sync_offset = 0.15
	target_page_size = Vector2(512, 820)
	page_stretch_mode = PageStretchOption.SCALE
	tex_cover_front_out = preload("uid://dbdwbowx32d3v")
	tex_cover_front_in = preload("uid://dt1tiecgw5rip")
	tex_cover_back_in = preload("uid://dt1tiecgw5rip")
	tex_cover_back_out = preload("uid://bjowpx1ap4uxt")
	_apply_new_size()
	notify_property_list_changed()

# ==============================================================================
# BUILD & INIT
# ==============================================================================
func __init():
	var viewports_cont = __ensure_node("Viewports", Node, self)
	var slots_cont = __ensure_node("Slots", Node, viewports_cont)
	var visual_cont = __ensure_node("Visual", Node2D, self) 

	_slot_1 = __ensure_node("Slot1", SubViewport, slots_cont)
	_slot_2 = __ensure_node("Slot2", SubViewport, slots_cont)
	_slot_3 = __ensure_node("Slot3", SubViewport, slots_cont)
	_slot_4 = __ensure_node("Slot4", SubViewport, slots_cont)
	
	for slot in [_slot_1, _slot_2, _slot_3, _slot_4]:
		slot.transparent_bg = true
		slot.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		slot.size = target_page_size

	var comp_vp = __ensure_node("Compositor", SubViewport, slots_cont)
	var comp_sprite = __ensure_node("CompositorTexture", Sprite2D, comp_vp)
	comp_sprite.centered = false

	var s_left = __ensure_node("StaticPageLeft", Polygon2D, visual_cont)
	s_left.z_index = 1
	var s_right = __ensure_node("StaticPageRight", Polygon2D, visual_cont)
	s_right.z_index = 1
	var d_poly = __ensure_node("DynamicFlipPoly", Polygon2D, visual_cont)
	d_poly.z_index = 10
	
	if d_poly.get_script() == null:
		d_poly.set_script(load("res://addons/PageFlip/page_rigger.gd"))

	var anim = __ensure_node("AnimationPlayer", AnimationPlayer, self)
	__ensure_node("Camera2D", Camera2D, self)
	var stream_player = __ensure_node("AudioStreamPlayer", AudioStreamPlayer, self)

	if not visuals_container: visuals_container = visual_cont
	if not static_left: static_left = s_left
	if not static_right: static_right = s_right
	if not dynamic_poly: dynamic_poly = d_poly
	if not anim_player: anim_player = anim
	if not vp_compositor: vp_compositor = comp_vp
	if not compositor_sprite: compositor_sprite = comp_sprite
	if not audio_player: audio_player = stream_player
	
	if dynamic_poly and anim_player:
		if dynamic_poly.get("anim_player") == null:
			dynamic_poly.set("anim_player", anim_player)
	
	__ensure_node("RuntimeSpine", Polygon2D, visual_cont)
	
	if Vector2(_slot_1.size) != target_page_size:
		_apply_new_size()

func __ensure_node(target_name: String, type: Variant, parent_node: Node) -> Node:
	var node = parent_node.get_node_or_null(target_name)
	if node: return node
	node = type.new()
	node.name = target_name
	if node is SubViewport: node.transparent_bg = true
	parent_node.add_child(node)
	if Engine.is_editor_hint(): node.owner = parent_node.owner if parent_node.owner else self
	return node

func _ready():
	if not _slot_1: _slot_1 = find_child("Slot1", true, false)
	if not _slot_2: _slot_2 = find_child("Slot2", true, false)
	if not _slot_3: _slot_3 = find_child("Slot3", true, false)
	if not _slot_4: _slot_4 = find_child("Slot4", true, false)

	if Engine.is_editor_hint():
		__init()
		if dynamic_poly: dynamic_poly.rebuild(target_page_size)
		return
	elif Vector2(_slot_1.size) != target_page_size:
		_apply_new_size()
	
	if dynamic_poly: dynamic_poly.rebuild(target_page_size)
	#if vp_compositor: target_page_size = vp_compositor.size
	
	if not blank_page_texture:
		var w = int(target_page_size.x)
		var h = int(target_page_size.y)
		if w > 0 and h > 0:
			var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
			img.fill(blank_page_color)
			blank_page_texture = ImageTexture.create_from_image(img)

	_prepare_book_content()
	
	if dynamic_poly and not dynamic_poly.is_connected("change_page_requested", _on_midpoint_signal):
		dynamic_poly.connect("change_page_requested", _on_midpoint_signal)
	
	if anim_player and not anim_player.is_connected("animation_finished", _on_animation_finished):
		anim_player.animation_finished.connect(_on_animation_finished)

	await get_tree().process_frame
	if vp_compositor and dynamic_poly:
		dynamic_poly.texture = vp_compositor.get_texture()
	
	_initial_config()

func _set_spine_color(color: Color) -> void:
	spine_color = color
	var node = find_child("RuntimeSpine")
	if node: node.color = spine_color

func _set_spine_texture(texture: Texture2D) -> void:
	spine_texture = texture
	var node = find_child("RuntimeSpine")
	if node: node.texture = spine_texture

func _initial_config():
	if vp_compositor: page_width = float(vp_compositor.size.x)
	else: page_width = target_page_size.x
	var screen_center = get_viewport().get_camera_2d().get_screen_center_position()
	_set_page_visible(static_left, false)
	_set_page_visible(dynamic_poly, false)
	_set_page_visible(static_right, true)
	_build_spine()
	_generate_volume_layers()
	_visual_spread_index = float(current_spread)
	
	if current_spread == -1:
		var offset = _get_compensation_offset(true, false)
		visuals_container.global_position = screen_center + offset - Vector2(target_page_size.x / 2, 0.0)
		_animate_container_transform(true, false, 0.0)
		_update_stack_direct(1.0, -1.0)
		_update_static_visuals_immediate()
	else:
		var offset = _get_compensation_offset(false, false)
		visuals_container.global_position = screen_center + offset - Vector2(target_page_size.x / 2, 0.0)
		_animate_container_transform(false, false, 0.0)
		_update_stack_direct(0.0, float(current_spread))
		_update_static_visuals_immediate()
	_update_volume_visuals()

# ==============================================================================
# VOLUME
# ==============================================================================
func _generate_volume_layers():
	if _volume_root and is_instance_valid(_volume_root): _volume_root.queue_free()
	var final_layer_count = 0
	if total_spreads > 0: final_layer_count = clampi(total_spreads, min_layers, max_layers)
	if final_layer_count <= 0: return
	
	_volume_root = Node2D.new()
	_volume_root.name = "VolumeStackPages"
	visuals_container.add_child(_volume_root)
	visuals_container.move_child(_volume_root, 0)
	
	for i in range(final_layer_count):
		var layer_node = Node2D.new()
		layer_node.name = "Layer_%d" % i
		var layer_col = volume_color
		if i % 2 != 0:
			layer_col.r *= stripe_darken_ratio
			layer_col.g *= stripe_darken_ratio
			layer_col.b *= stripe_darken_ratio
		layer_node.modulate = layer_col
		var s_left = static_left.duplicate()
		var s_right = static_right.duplicate()
		s_left.position = Vector2.ZERO; s_right.position = Vector2.ZERO
		s_left.set_script(null); s_right.set_script(null)
		layer_node.add_child(s_left)
		layer_node.add_child(s_right)
		_volume_root.add_child(layer_node)

func _tween_expansion_only(factor: float):
	_update_stack_direct(factor, _visual_spread_index)

func _update_stack_direct(expansion_factor: float, visual_spread: float):
	_current_expansion_factor = expansion_factor
	_visual_spread_index = visual_spread
	if not _volume_root: return
	var current_step = layer_offset_open.lerp(layer_offset_closed, expansion_factor)
	var total_layers = _volume_root.get_child_count()
	var y_dir = -1.0 if invert_stack_direction else 1.0
	
	var count_left = 0
	var count_right = 0
	
	if is_animating:
		var layers_at_start = _get_layer_count_for_spread(current_spread, total_layers)
		var layers_at_target = _get_layer_count_for_spread(_pending_target_spread_idx, total_layers)
		if going_forward:
			count_left = layers_at_start
			count_right = total_layers - layers_at_target
		else:
			count_left = layers_at_target
			count_right = total_layers - layers_at_start
			
		var L_start_is_thin = (layers_at_start == 0)
		var L_target_is_thin = (layers_at_target == 0)
		if L_start_is_thin != L_target_is_thin: count_left = max(layers_at_start, layers_at_target)

		var R_start_vol = total_layers - layers_at_start
		var R_target_vol = total_layers - layers_at_target
		var R_start_is_thin = (R_start_vol == 0)
		var R_target_is_thin = (R_target_vol == 0)
		if R_start_is_thin != R_target_is_thin: count_right = max(R_start_vol, R_target_vol)
	else:
		count_left = _get_layer_count_for_spread(visual_spread, total_layers)
		count_right = total_layers - count_left

	var force_hide_left = false
	var force_hide_right = false
	if _stack_scale_left <= 0.001: force_hide_left = true
	if _stack_scale_right <= 0.001: force_hide_right = true
	if _force_hide_vol_left: force_hide_left = true
	if _force_hide_vol_right: force_hide_right = true
	var left_threshold_idx = total_layers - count_left
	var right_threshold_idx = total_layers - count_right

	for i in range(total_layers):
		var layer = _volume_root.get_child(i)
		var reverse_multiplier = total_layers - i
		var base_off_x = current_step.x * reverse_multiplier
		var base_off_y = (current_step.y * reverse_multiplier) * y_dir
		layer.position = Vector2.ZERO
		var l_node = layer.get_child(0)
		var r_node = layer.get_child(1)
		var final_off_left = Vector2(-base_off_x, base_off_y) * _stack_scale_left
		var final_off_right = Vector2(base_off_x, base_off_y) * _stack_scale_right
		var show_l = (i >= left_threshold_idx)
		var show_r = (i >= right_threshold_idx)
		if force_hide_left: show_l = false
		if force_hide_right: show_r = false
		if static_left:
			l_node.position = static_left.position + final_off_left
			l_node.visible = show_l
		if static_right:
			r_node.position = static_right.position + final_off_right
			r_node.visible = show_r

func _get_layer_count_for_spread(spread_idx: float, total_layers: int) -> int:
	if total_spreads <= 2: return 0
	var effective_total = float(total_spreads - 2)
	var adjusted_idx = spread_idx - 1.0
	var real_max = max(1.0, effective_total)
	var safe_spread = clamp(adjusted_idx, 0.0, real_max)
	var ratio = safe_spread / real_max
	return int(round(ratio * total_layers))

func _update_volume_visuals():
	if not _volume_root: return
	_volume_root.position = volume_stack_offset

# ==============================================================================
# EDITOR TOOLS & SIZING
# ==============================================================================
func _on_apply_size_pressed(val):
	if not val: return
	apply_size_change = false
	_apply_new_size()

func _apply_new_size():
	print("[BookController] Rebuilding Book with size: ", target_page_size)
	page_width = target_page_size.x
	_update_viewports_recursive(self, target_page_size)
	var w = target_page_size.x
	var h = target_page_size.y
	var poly_shape = PackedVector2Array([Vector2(0, -h/2.0), Vector2(w, -h/2.0), Vector2(w, h/2.0), Vector2(0, h/2.0)])
	var uv_rect = PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)])

	if static_left:
		static_left.polygon = poly_shape; static_left.uv = uv_rect; static_left.position = Vector2(-w, 0); static_left.visible = false
	if static_right:
		static_right.polygon = poly_shape; static_right.uv = uv_rect; static_right.position = Vector2(0, 0); static_right.visible = true
	if dynamic_poly:
		dynamic_poly.position = Vector2(0.0, -h / 2.0); dynamic_poly.visible = false 
		if dynamic_poly.has_method("rebuild"): dynamic_poly.rebuild(target_page_size)

	_build_spine()
	_generate_volume_layers()
	_fit_camera_to_book()

func _update_viewports_recursive(node: Node, new_size: Vector2):
	for child in node.get_children():
		if child is SubViewport:
			child.size = new_size; child.render_target_update_mode = SubViewport.UPDATE_ALWAYS 
		if child.get_child_count() > 0: _update_viewports_recursive(child, new_size)

func _fit_camera_to_book():
	var cam = get_node_or_null("Camera2D")
	if not cam: return
	var total_book_width = target_page_size.x * 2.0
	var total_book_height = target_page_size.y * 2.0
	var margin = 1.0
	var required_width = total_book_width * margin
	var required_height = total_book_height * margin
	var screen_size = get_viewport_rect().size
	if screen_size == Vector2.ZERO: return
	var zoom_x = screen_size.x / required_width
	var zoom_y = screen_size.y / required_height
	var final_zoom = min(zoom_x, zoom_y)
	cam.zoom = Vector2(final_zoom, final_zoom)

func _build_spine():
	if _spine_poly and is_instance_valid(_spine_poly): _spine_poly.queue_free()
	elif visuals_container.has_node("RuntimeSpine"): 
		var node = visuals_container.get_node("RuntimeSpine")
		node.queue_free()
		visuals_container.remove_child(node)
	if spine_width <= 0: return
	_spine_poly = Polygon2D.new()
	_spine_poly.name = "RuntimeSpine"
	_spine_poly.z_index = 15 
	_spine_poly.texture = spine_texture
	var hw = spine_width / 2.0
	var h = target_page_size.y
	_spine_poly.polygon = PackedVector2Array([Vector2(-hw, -h/2.0), Vector2(hw, -h/2.0), Vector2(hw, h/2.0), Vector2(-hw, h/2.0)])
	if spine_texture:
		var tw = spine_texture.get_width()
		var th = spine_texture.get_height()
		_spine_poly.uv = PackedVector2Array([Vector2(0, 0), Vector2(tw, 0), Vector2(tw, th), Vector2(0, th)])
	else: _spine_poly.color = spine_color
	visuals_container.add_child(_spine_poly)
	_spine_poly.position = Vector2.ZERO 
	if Engine.is_editor_hint(): _spine_poly.owner = get_tree().edited_scene_root

func _set_page_visible(node: Node2D, show: bool):
	if show: node.visible = true
	else: node.call_deferred("set_visible", false)

func _prepare_book_content():
	_runtime_pages = pages_paths.duplicate()
	if _runtime_pages.size() > 0 and _runtime_pages.size() % 2 != 0:
		_runtime_pages.append("internal://blank_page")
	var num = _runtime_pages.size()
	if num == 0: total_spreads = 1
	else: total_spreads = (num / 2) + 1

# ==============================================================================
# INPUT
# ==============================================================================
func _input(event):
	if not _active_interactive_is_left and not _active_interactive_is_right: return 
	if event is InputEventMouse:
		var mouse_pos = get_global_mouse_position()
		if _active_interactive_is_left:
			var new_mouse_pos = static_left.to_local(mouse_pos)
			new_mouse_pos.y += target_page_size.y / 2
			var ev = event.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
			ev.position = new_mouse_pos
			ev.global_position = new_mouse_pos
			_slot_1.push_input(ev)
		if _active_interactive_is_right:
			var new_mouse_pos = static_right.to_local(mouse_pos)
			new_mouse_pos.y += target_page_size.y / 2
			var ev = event.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
			ev.position = new_mouse_pos
			ev.global_position = new_mouse_pos
			_slot_2.push_input(ev)
	elif event is InputEventKey:
		if _active_interactive_is_left: _slot_1.push_input(event.duplicate(true))
		if _active_interactive_is_right: _slot_2.push_input(event.duplicate(true))

func _unhandled_input(event):
	if Engine.is_editor_hint(): return
	if not visible or is_animating: return
	
	if event.is_action_pressed("ui_cancel") and close_condition == CloseCondition.ON_CANCEL_INPUT:
		_perform_close_action()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_right"): next_page(); get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_left"): prev_page(); get_viewport().set_input_as_handled()

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var local_pos = visuals_container.get_local_mouse_position()
		local_pos.y /= visuals_container.scale.y
		if local_pos.x > -page_width/2.0: next_page(); get_viewport().set_input_as_handled()
		else: prev_page(); get_viewport().set_input_as_handled()

func next_page():
	if is_animating or current_spread >= total_spreads: return
	_start_animation(true)

func prev_page():
	if is_animating or current_spread <= -1: return
	_start_animation(false)

func _pageflip_set_input_enabled(give_control_to_book: bool):
	set_process_unhandled_input(give_control_to_book)
	if _slot_1.get_child_count() > 0:
		var node = _slot_1.get_child(-1)
		if node.has_meta("_pageflip_node") and node.has_signal("manage_pageflip"):
			node.set_process_input(not give_control_to_book)
			node.set_process_unhandled_input(not give_control_to_book)
			_active_interactive_is_left = not give_control_to_book
	if _slot_2.get_child_count() > 0:
		var node = _slot_2.get_child(-1)
		if node.has_meta("_pageflip_node") and node.has_signal("manage_pageflip"):
			node.set_process_input(not give_control_to_book)
			node.set_process_unhandled_input(not give_control_to_book)
			_active_interactive_is_right = not give_control_to_book

## start from the current visual state and end at the cover.
func force_close_book(to_front_cover: bool):
	if is_animating: return
	_pageflip_set_input_enabled(true)
	
	# Flag to tell _start_animation and _on_animation_finished that this is a special case
	_is_force_closing = true
	
	if to_front_cover:
		# To Front Cover = Closing Backwards (Right to Left)
		# We don't change current_spread here. We let the animation run.
		# The target is logically -1, but we handle the jump at end of animation.
		_start_animation(false) 
	else:
		# To Back Cover = Closing Forwards (Left to Right)
		_start_animation(true)


# ==============================================================================
# ANIMATION LOGIC
# ==============================================================================
func _start_animation(forward: bool):
	is_animating = true; going_forward = forward
	
	var is_rigid_motion = false; var use_tween = false
	var closing_to_back = false; var closing_to_front = false; var target_is_closed = false
	
	var target_spread_idx = 0
	
	if _is_force_closing:
		if forward: # Closing to Back
			target_spread_idx = total_spreads
			is_rigid_motion = covers_are_rigid; use_tween = true; is_book_open = false; closing_to_back = true; target_is_closed = true
		else: # Closing to Front
			target_spread_idx = -1
			is_rigid_motion = covers_are_rigid; use_tween = true; is_book_open = false; closing_to_front = true; target_is_closed = true
	else:
		# Standard Animation
		target_spread_idx = current_spread + 1 if forward else current_spread - 1
		
		if forward:
			if current_spread == -1: is_rigid_motion = covers_are_rigid; use_tween = true; is_book_open = true; target_is_closed = false
			elif current_spread == total_spreads - 1: is_rigid_motion = covers_are_rigid; use_tween = true; is_book_open = false; closing_to_back = true; target_is_closed = true
		else:
			if current_spread == total_spreads: is_rigid_motion = covers_are_rigid; use_tween = true; is_book_open = true; target_is_closed = false
			elif current_spread == 0: is_rigid_motion = covers_are_rigid; use_tween = true; is_book_open = false; closing_to_front = true; target_is_closed = true

	_pending_target_spread_idx = target_spread_idx

	_force_hide_vol_left = false; _force_hide_vol_right = false
	if target_is_closed and is_rigid_motion:
		if forward: _force_hide_vol_right = true
		else: _force_hide_vol_left = true
	
	_is_page_flying = true; _flying_from_right = forward
	_visual_spread_index = float(current_spread)

	# --- SLOT PRE-CONFIGURATION ---
	var idx_static_left = -999; var idx_static_right = -999
	var idx_anim_a = -999; var idx_anim_b = -999
	
	if _is_force_closing:
		if forward: # Closing to Back (Left to Right motion)
			# The Static Left stays as the Current Left Page.
			idx_static_left = _get_page_index_for_spread(current_spread, true)
			# The Static Right must be empty/cover underneath.
			idx_static_right = -999 
			# Moving Part: The Current Right Page flips over to become the Back Cover.
			idx_anim_a = _get_page_index_for_spread(current_spread, false)
			idx_anim_b = -103 # Back Cover Out
		else: # Closing to Front (Right to Left motion)
			# The Static Right stays as the Current Right Page.
			idx_static_right = _get_page_index_for_spread(current_spread, false)
			# The Static Left must be empty.
			idx_static_left = -999
			# Moving Part: The Current Left Page flips over to become the Front Cover.
			idx_anim_a = _get_page_index_for_spread(current_spread, true)
			idx_anim_b = -100 # Front Cover Out
	else:
		# Standard Logic
		if forward:
			idx_static_left = _get_page_index_for_spread(current_spread, true)
			idx_static_right = _get_page_index_for_spread(target_spread_idx, false)
			idx_anim_a = _get_page_index_for_spread(current_spread, false) 
			idx_anim_b = _get_page_index_for_spread(target_spread_idx, true) 
		else:
			idx_static_left = _get_page_index_for_spread(target_spread_idx, true)
			idx_static_right = _get_page_index_for_spread(current_spread, false)
			idx_anim_a = _get_page_index_for_spread(current_spread, true) 
			idx_anim_b = _get_page_index_for_spread(target_spread_idx, false) 

	_update_slot_content(_slot_1, idx_static_left)
	_update_slot_content(_slot_2, idx_static_right)
	_update_slot_content(_slot_3, idx_anim_a)
	_update_slot_content(_slot_4, idx_anim_b)

	static_left.texture = _slot_1.get_texture()
	static_right.texture = _slot_2.get_texture()
	compositor_sprite.texture = _slot_3.get_texture()
	compositor_sprite.flip_h = !forward

	if closing_to_back: _set_page_visible.call_deferred(static_right, false)
	elif closing_to_front: _set_page_visible.call_deferred(static_left, false)
	
	var anim_name = "turn_rigid_page" if is_rigid_motion else "turn_flexible_page"
	var anim_len = 1.0
	if anim_player.has_animation(anim_name):
		anim_len = anim_player.get_animation(anim_name).length
		anim_player.current_animation = anim_name
		if forward: anim_player.seek(0.0, true)
		else: anim_player.seek(anim_len, true)

	_set_page_visible.call_deferred(dynamic_poly, true); dynamic_poly.z_index = 10
	_update_stack_direct(_current_expansion_factor, float(current_spread))
	
	await RenderingServer.frame_post_draw
	
	var motion_duration = anim_len / (anim_player.speed_scale if anim_player.speed_scale > 0 else 1.0)
	var land_time = max(0.0, motion_duration - landing_overlap)
	get_tree().create_timer(land_time).timeout.connect(_on_page_landed_early)
	
	var start_exp = _current_expansion_factor
	var end_exp = 1.0 if target_is_closed else 0.0
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT).set_parallel(true)
	var half_duration = motion_duration * 0.5
	
	# Stack thickness logic...
	var start_thin_L = (current_spread <= 1)
	var end_thin_L = (target_spread_idx <= 1)
	
	if start_thin_L and not end_thin_L:
		_stack_scale_left = 0.0; tween.tween_property(self, "_stack_scale_left", 1.0, half_duration).set_delay(half_duration)
	elif not start_thin_L and end_thin_L:
		_stack_scale_left = 1.0; tween.tween_property(self, "_stack_scale_left", 0.0, half_duration * 0.5)
	elif start_thin_L and end_thin_L: _stack_scale_left = 0.0
	else: _stack_scale_left = 1.0

	var start_thin_R = (current_spread >= total_spreads - 2)
	var end_thin_R = (target_spread_idx >= total_spreads - 2)
	
	if start_thin_R and not end_thin_R:
		_stack_scale_right = 0.0; tween.tween_property(self, "_stack_scale_right", 1.0, half_duration).set_delay(half_duration)
	elif not start_thin_R and end_thin_R:
		_stack_scale_right = 1.0; tween.tween_property(self, "_stack_scale_right", 0.0, half_duration)
	elif start_thin_R and end_thin_R: _stack_scale_right = 0.0
	else: _stack_scale_right = 1.0
	
	if use_tween:
		var compensation_offset = _get_compensation_offset(target_is_closed, closing_to_back)
		var screen_center = get_viewport().get_camera_2d().get_screen_center_position()
		var final_pos = screen_center + compensation_offset - Vector2(target_page_size.x / 2, 0.0)
		_animate_container_transform(target_is_closed, closing_to_back, motion_duration)
		tween.tween_property(visuals_container, "global_position", final_pos, motion_duration)
	
	tween.tween_method(_tween_expansion_only.bind(), start_exp, end_exp, motion_duration)

	if forward: anim_player.play(anim_name)
	else: anim_player.play_backwards(anim_name)
	
	if is_rigid_motion:
		var trigger_time = max(0.0, motion_duration - impact_sync_offset)
		get_tree().create_timer(trigger_time).timeout.connect(func(): _play_sound(sfx_book_impact))
	else: _play_sound(sfx_page_flip)

func _on_page_landed_early():
	_is_page_flying = false
	_visual_spread_index = float(_pending_target_spread_idx)
	_update_stack_direct(_current_expansion_factor, _visual_spread_index)

# ==============================================================================
# PROCESS
# ==============================================================================
func _process(_delta):
	if visuals_container and is_animating:
		_update_stack_direct(_current_expansion_factor, _visual_spread_index)
		_update_volume_visuals()

func _get_compensation_offset(is_closed: bool, is_back: bool) -> Vector2:
	var target_local_x = 0.0
	if is_closed:
		if is_back: target_local_x = -page_width
		else: target_local_x = 0.0
	else: target_local_x = -page_width * 0.5
	var target_vec = Vector2(target_local_x, 0)
	var t_scale = closed_scale if is_closed else open_scale
	var t_rot = closed_rotation if is_closed else open_rotation
	if is_closed and is_back: t_rot *= -1.0
	target_vec *= t_scale
	target_vec = target_vec.rotated(deg_to_rad(t_rot))
	return -target_vec

func _animate_container_transform(target_is_closed: bool, is_back: bool, duration: float):
	if not visuals_container: return
	var t_scale = closed_scale if target_is_closed else open_scale
	var t_skew = closed_skew if target_is_closed else open_skew
	var t_rot = closed_rotation if target_is_closed else open_rotation
	if target_is_closed and is_back: t_skew *= -1.0; t_rot *= -1.0
	if duration <= 0.0:
		visuals_container.scale = t_scale; visuals_container.skew = t_skew; visuals_container.rotation = deg_to_rad(t_rot)
	else:
		var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(visuals_container, "scale", t_scale, duration)
		tween.tween_property(visuals_container, "skew", t_skew, duration)
		tween.tween_property(visuals_container, "rotation", deg_to_rad(t_rot), duration)

func _play_sound(stream: AudioStream):
	if not audio_player or not stream: return
	audio_player.stream = stream; audio_player.pitch_scale = randf_range(0.95, 1.05); audio_player.play()

# ==============================================================================
# CORE SIGNALS
# ==============================================================================
func _on_midpoint_signal():
	compositor_sprite.texture = _slot_4.get_texture()
	compositor_sprite.flip_h = !compositor_sprite.flip_h

func _on_animation_finished(_anim_name: String):
	_set_page_visible(dynamic_poly, false)
	dynamic_poly.z_index = 10
	
	_force_hide_vol_left = false; _force_hide_vol_right = false
	_is_page_flying = false
	
	if _is_force_closing:
		_is_force_closing = false
		# Snap to the final target spread
		if going_forward: current_spread = total_spreads
		else: current_spread = -1
	else:
		# Standard increment
		if going_forward and current_spread == -1: current_spread = 0; 
		elif going_forward and current_spread == total_spreads - 1: current_spread = total_spreads; 
		elif !going_forward and current_spread == total_spreads: current_spread = total_spreads - 1; 
		elif !going_forward and current_spread == 0: current_spread = -1; 
		else:
			if going_forward: current_spread += 1
			else: current_spread -= 1
	
	_update_static_visuals_immediate()
	is_animating = false
	_visual_spread_index = float(current_spread)
	_update_stack_direct(_current_expansion_factor, _visual_spread_index)
	_update_volume_visuals()
	
	if current_spread == total_spreads:
		if close_condition == CloseCondition.CLOSE_FROM_BACK or close_condition == CloseCondition.ANY_CLOSE:
			_perform_close_action()
			return
	if current_spread == -1:
		if close_condition == CloseCondition.CLOSE_FROM_FRONT or close_condition == CloseCondition.ANY_CLOSE:
			_perform_close_action()
			return
	_check_scene_activation.call_deferred()

func _perform_close_action():
	if close_behavior == CloseBehavior.DESTROY_BOOK: queue_free()
	elif close_behavior == CloseBehavior.CHANGE_SCENE:
		if target_scene_on_close != "": get_tree().change_scene_to_file(target_scene_on_close)

func _check_scene_activation() -> void:
	var scene_found = false
	if _slot_1.get_child_count() > 0:
		var node = _slot_1.get_child(-1)
		if node.has_meta("_pageflip_node") and node.has_signal("manage_pageflip"):
			node.emit_signal("manage_pageflip", false)
			node.set_process_input(true); node.set_process_unhandled_input(true); scene_found = true
	if _slot_2.get_child_count() > 0:
		var node = _slot_2.get_child(-1)
		if node.has_meta("_pageflip_node") and node.has_signal("manage_pageflip"):
			node.emit_signal("manage_pageflip", false)
			node.set_process_input(true); node.set_process_unhandled_input(true); scene_found = true
	if not scene_found: _pageflip_set_input_enabled(true)

# ==============================================================================
# ASSET LOADING & SLOT MANAGEMENT
# ==============================================================================
func _get_page_index_for_spread(spread_idx: int, is_left: bool) -> int:
	if spread_idx == -1: return -999 if is_left else -100 # Front Cover Out
	if spread_idx == total_spreads: return -103 if is_left else -999 # Back Cover Out
	if spread_idx == 0:
		if is_left: return -101 # Front Cover In
		if _runtime_pages.size() == 0: return -102 # Back Cover In
		return 0 # Page 1
	if is_left: return (spread_idx * 2) - 1
	else:
		var content_idx = spread_idx * 2
		if content_idx >= _runtime_pages.size(): return -102 # Back Cover In
		return content_idx

func _update_slot_content(slot: SubViewport, content_index: int) -> void:
	if not slot: return
	for child in slot.get_children():
		if child is TextureRect: child.queue_free()
		else: slot.remove_child(child)
	var resource_path = ""
	var cover_tex: Texture2D = null
	if content_index == -100: cover_tex = tex_cover_front_out
	elif content_index == -101: cover_tex = tex_cover_front_in
	elif content_index == -102: cover_tex = tex_cover_back_in
	elif content_index == -103: cover_tex = tex_cover_back_out
	elif content_index >= 0 and content_index < _runtime_pages.size(): resource_path = _runtime_pages[content_index]
	
	if cover_tex: _setup_texture_in_slot(slot, cover_tex)
	elif resource_path != "":
		if resource_path == "internal://blank_page": _setup_texture_in_slot(slot, blank_page_texture)
		elif ResourceLoader.exists(resource_path):
			var res = load(resource_path)
			if res is PackedScene: _setup_scene_in_slot(slot, res, content_index)
			elif res is Texture2D: _setup_texture_in_slot(slot, res)
			else: _setup_texture_in_slot(slot, blank_page_texture)
	else: _setup_texture_in_slot(slot, blank_page_texture)

func _setup_texture_in_slot(slot: SubViewport, tex: Texture2D):
	if enable_composite_pages: _add_composite_blank_bg(slot)
	if not tex: 
		tex = blank_page_texture
		if not tex: return
	var rect = TextureRect.new()
	rect.texture = tex
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = page_stretch_mode as TextureRect.StretchMode
	rect.size = slot.size
	rect.position = Vector2.ZERO
	slot.add_child(rect)

func _setup_scene_in_slot(slot: SubViewport, scene_pkg: PackedScene, texture_index: int):
	if enable_composite_pages: _add_composite_blank_bg(slot)
	var cache_key = scene_pkg.get_path() + "#" + str(texture_index)
	var instance
	if not cache_key in _scene_cache:
		instance = scene_pkg.instantiate()
		instance.set_meta("_pageflip_node", self)
		instance.position = Vector2.ZERO
		if instance.has_signal("manage_pageflip"): instance.connect("manage_pageflip", _pageflip_set_input_enabled)
		slot.add_child(instance)
		_scene_cache[cache_key] = instance
	else:
		instance = _scene_cache[cache_key]
		if instance.is_inside_tree(): instance.reparent(slot)
		else: slot.add_child(instance)
	instance.set_process_input(false); instance.set_process_unhandled_input(false)

func _add_composite_blank_bg(slot: SubViewport):
	if not blank_page_texture: return
	var bg = TextureRect.new()
	bg.texture = blank_page_texture
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = page_stretch_mode as TextureRect.StretchMode
	bg.size = slot.size
	bg.position = Vector2.ZERO
	slot.add_child(bg)

func _update_static_visuals_immediate():
	var idx_l = _get_page_index_for_spread(current_spread, true)
	var idx_r = _get_page_index_for_spread(current_spread, false)
	_update_slot_content(_slot_1, idx_l)
	_update_slot_content(_slot_2, idx_r)
	static_left.texture = _slot_1.get_texture()
	static_right.texture = _slot_2.get_texture()
	var valid_l = (idx_l != -999)
	var valid_r = (idx_r != -999)
	_set_page_visible(static_left, valid_l)
	_set_page_visible(static_right, valid_r)
