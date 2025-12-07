@tool
class_name BookAPI
extends RefCounted

## Static utility class for the PageFlip2D system by Newold.
## Provides helper methods to configure the book and facilitate interaction
## from embedded scenes (UI, puzzles, maps).
## Note: This file is not required for the PageFlip2D system to work properly.
## To use any of the included functions, place this script in the folder of
## your project where PageFlip2D is installed, and in your scripts you can
## call the functions as BookAPI.function_name(parameters).



# ==============================================================================
# CONFIGURATION HELPERS
# ==============================================================================

## Configures the visual properties of a Book instance via a dictionary.
## Useful for loading saved states or generating books procedurally.
static func configure_visuals(book: PageFlip2D, data: Dictionary) -> void:
	if not is_instance_valid(book): return

	if "pages" in data:
		book.pages_paths = data["pages"]
		# We access the private method via call to respect encapsulation or public API if made public.
		# Since _prepare_book_content is internal, we trigger a rebuild implicitly or manually.
		book.call("_prepare_book_content")

	if "cover_front_out" in data: book.tex_cover_front_out = data["cover_front_out"]
	if "cover_front_in" in data: book.tex_cover_front_in = data["cover_front_in"]
	if "cover_back_in" in data: book.tex_cover_back_in = data["cover_back_in"]
	if "cover_back_out" in data: book.tex_cover_back_out = data["cover_back_out"]
	
	if "spine_col" in data: book.spine_color = data["spine_col"]
	if "spine_width" in data: 
		book.spine_width = data["spine_width"]
		book.call("_build_spine")

	if "size" in data:
		book.target_page_size = data["size"]
		book.call("_apply_new_size")
	
	book.call("_update_static_visuals_immediate")
	book.call("_update_volume_visuals")


## Configures the physics simulation of the page turning effect.
## Keys match the properties in the PageRigger script (e.g., "paper_stiffness", "anim_duration").
static func configure_physics(book: PageFlip2D, data: Dictionary) -> void:
	if not is_instance_valid(book) or not book.dynamic_poly: return
	
	var rigger = book.dynamic_poly
	for key in data.keys():
		rigger.set(key, data[key])
	
	if rigger.has_method("rebuild"):
		rigger.rebuild(book.target_page_size)


# ==============================================================================
# INTERACTIVE SCENE HELPERS
# ==============================================================================

## Locates the PageFlip2D controller ancestor from any node inside an interactive page.
## Essential because the scene is buried inside Viewports and Slots.
static func find_book_controller(caller_node: Node) -> PageFlip2D:
	var current = caller_node
	while current:
		if current is PageFlip2D:
			return current
		current = current.get_parent()
	return null


## Forces the book to jump to a specific page spread instantly or animated.
static func go_to_spread(book: PageFlip2D, spread_index: int, animated: bool = true) -> void:
	if not is_instance_valid(book): return
	
	# Clamp to valid range
	var target = clampi(spread_index, -1, book.total_spreads)
	
	if not animated:
		book.current_spread = target
		book.call("_update_static_visuals_immediate")
		book.call("_update_volume_visuals")
	else:
		# Simple logic: if target > current, turn next. 
		# Note: Detailed multi-page skipping requires complex logic in the main controller.
		# This represents a single step interaction.
		if target > book.current_spread:
			book.next_page()
		elif target < book.current_spread:
			book.prev_page()


## Locks the book input, preventing the user from turning pages manually.
## Useful when a puzzle or minigame is active inside the page.
static func set_interaction_lock(book: PageFlip2D, locked: bool) -> void:
	if not is_instance_valid(book): return
	
	# This uses the internal handshake method.
	# False means "don't give control to book" (so, locked for player navigation).
	book.call("_pageflip_set_input_enabled", not locked)


## Checks if the book is currently playing a page-turn animation.
static func is_busy(book: PageFlip2D) -> bool:
	if not is_instance_valid(book): return false
	return book.is_animating