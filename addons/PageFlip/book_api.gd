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
static func configure_visuals(book: PageFlip2D, data: Dictionary) -> void:
	if not is_instance_valid(book): return

	if "pages" in data:
		book.pages_paths = data["pages"]
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
static func find_book_controller(caller_node: Node) -> PageFlip2D:
	var current = caller_node
	while current:
		if current is PageFlip2D:
			return current
		current = current.get_parent()
	return null


## Safely locks or unlocks the book's ability to turn pages manually.
## WARNING: If locked, the interactive scene MUST be responsible for unlocking it later,
## or calling go_to_spread() which forces an unlock at the end.
static func set_interaction_lock(book: PageFlip2D, locked: bool) -> void:
	if not is_instance_valid(book): return
	book.call("_pageflip_set_input_enabled", not locked)


## Forces the book to regain input control immediately.
## Useful as a failsafe if an interactive scene closes unexpectedly.
static func force_release_control(book: PageFlip2D) -> void:
	if not is_instance_valid(book): return
	book.call("_pageflip_set_input_enabled", true)


## Navigates to a specific spread.
## [b]ASYNC:[/b] Must be called with 'await' if animated is true.
## - Animated: Fast-forwards through pages and restores control at the end.
## - Instant: Snaps to page and manually triggers the scene activation handshake.
static func go_to_spread(book: PageFlip2D, target_spread: int, animated: bool = true) -> void:
	if not is_instance_valid(book): return
	
	# Clamp target
	var final_target = clampi(target_spread, -1, book.total_spreads)
	var diff = final_target - book.current_spread
	
	force_release_control(book)

	if diff == 0:
		return
	
	if not animated:
		# INSTANT TELEPORT
		book.current_spread = final_target
		book.call("_update_static_visuals_immediate")
		book.call("_update_volume_visuals")
		
	else:
		# ANIMATED FAST-FORWARD
		if book.is_animating: return # Don't interrupt an existing animation
		
		var original_speed = book.anim_player.speed_scale
		# Speed up significantly for the traversal (5x speed)
		book.anim_player.speed_scale = 5.0
		
		var steps = abs(diff)
		var going_forward = diff > 0
		
		for i in range(steps):
			if not is_instance_valid(book): break
			
			if going_forward: book.next_page()
			else: book.prev_page()
			
			# Wait for the physical page turn to finish before starting the next one.
			# This ensures signals fire correctly and the stack updates physically.
			if book.anim_player.is_playing():
				await book.anim_player.animation_finished
			else:
				# Fallback if animation didn't start for some reason
				await book.get_tree().process_frame
		
		# RESTORE STATE
		if is_instance_valid(book):
			book.anim_player.speed_scale = original_speed



## Checks if the book is currently playing a page-turn animation.
static func is_busy(book: PageFlip2D) -> bool:
	if not is_instance_valid(book): return false
	return book.is_animating