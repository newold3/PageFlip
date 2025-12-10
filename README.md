# Ultimate PageFlip for Godot

**A robust, "Fake 3D" book system for Godot Engine.** (Click on the image to see a video demonstration)

<div align="center">
  <a href="https://www.youtube.com/watch?v=uvx7dPstcvg" alt="Click to watch on YouTube">
    <img src="https://i.ibb.co/yn3cKH0K/preview-ezgif-com-speed.gif" border="0">
  </a>
</div>


This tool allows you to create fully animated books, journals, grimoires, or UI menus. Unlike simple sprite swappers, this system uses real-time vertex deformation to bend pages, supports simulated page thickness (volume), and—most importantly—supports **Interactive Viewport Content**.

You can render static textures, animated videos, or **fully functional interactive Scenes (GUIs, puzzles, mini-games)** directly inside the book pages.

![MIT License](https://img.shields.io/badge/License-MIT-green.svg) ![Godot 4.x](https://img.shields.io/badge/Godot-4.x-blue.svg)

---

## ✨ Features

* **Easy Configuration:** Drag and drop setup.
* **Universal Content Support:** Accepts `.png`, `.jpg`, and `.tscn` (Scenes) in the same list.
* **Fake 3D Volume:** Procedurally generates the "stack" of pages on the side, expanding and contracting as you flip.
* **Smart Closing System:** Configure how the book closes (via animation, "Escape" key, or API) and what happens next (destroy object or change scene).
* **Composite Pages:** Native support for transparent `.png` images that automatically blend over the paper texture.
* **Physics Rigger:** Built-in `PageRigger` tool generates `Skeleton2D` and `Polygon2D` meshes automatically.
* **Input Handshake:** Automatic system to handle input focus between the Book controller and interactive page content.
* **Book Input:** You can turn the book’s pages using the left and right arrow keys, and by clicking on the page you want to flip.

---

## 📦 Installation

1.  **Extract:** Copy the addons folder directly into your Godot project folder.
2.  **Import:** Open Godot and allow the engine to import the scripts and assets.

---

## 🚀 Quick Start

1.  **Add the Node:** inside the Godot Editor, click **Add Child Node** (`Ctrl+A`) and search for **`PageFlip2D`**.
2.  **Auto-Build:** As soon as the node enters the Scene Tree, it will automatically recreate all necessary sub-nodes (Viewports, Slots, Visuals, etc.) for you.
3.  **💡 Pro Tip (One-Click Setup):** Select your new `PageFlip2D` node. In the Inspector, look for the category **"Newold Config"** and click **`Apply Newold Preset`**.
    * This will instantly apply a polished configuration (physics, sizes, visual style), making the book ready to use immediately. You just need to add your content!
4.  **Add Content:** In the Inspector, find the **Content Source** category. Add elements to the `Pages Paths` array:
    * Paths to images (`res://art/page1.png`)
    * ...or paths to scenes (`res://gui/InventoryPage.tscn`)

---

## 📖 Configuration

### The Page Rigger
The pages are not simple static sprites; they are deformable meshes handled by `PageRigger.gd`. The book **automatically rebuilds** the rig and recalculates animations every time you run the game to ensure they match your current page size.

### Book Logic & Closing
You can control how the book behaves when it reaches the covers or when the user wants to exit.

* **Close Condition:**
    * `NEVER`: The book stays open or just shows the cover.
    * `CLOSE_FROM_BACK` / `CLOSE_FROM_FRONT`: Triggers the close behavior automatically after the specific cover animation finishes.
    * `ANY_CLOSE`: Triggers if either the front or back cover is closed.
    * `ON_CANCEL_INPUT`: Closes immediately when the `ui_cancel` action (usually ESC) is pressed.
    * `DELEGATED`: The book waits for a manual call from a script (see API below).
* **Close Behavior:**
    * `DESTROY_BOOK`: Removes the node from the tree (`queue_free`).
    * `CHANGE_SCENE`: Changes the main scene to the one specified in `Target Scene On Close`.

### Visual Style
* **Composite Pages:** If enabled, pages with transparency (like a handwritten note `.png` with alpha) will be rendered **on top** of the `Blank Page Texture`. If disabled, transparent areas will show through to the page behind.
* **Volume:** Adjust `Min/Max Layers` to change how thick the book looks.
* **Spine:** Customize the width and texture of the book's spine.

---

## 🎮 Interactive Scenes & Input Handshake

This system shines when using **PackedScenes (`.tscn`)** as pages. You can have a functioning inventory, a map with clickable markers, or a puzzle **inside** the book.

### 1. How it Works (The Concept)

The system needs to know if a page is just visual (like a video or text) or if it requires mouse input. It determines this using a specific **Signal**.

* **Interactive Scene:** Any scene script that contains the signal `manage_pageflip`.
* **Passive Scene:** Any scene that **does not** have the signal.

**The Trigger:**
When a page flip animation finishes, the Book checks the newly visible pages. If they contain the signal, the Input Handshake begins.

### 2. The Input Cycle (Lifecycle)

1.  **Animation Ends:** The page lands.
2.  **Handover (Book -> Scene):** The Book detects the signal. It **disables** its own input processing and **enables** input processing on your Scene.
3.  **Interaction:** The user clicks buttons, drags items, or scrolls inside your scene.
4.  **Return (Scene -> Book):** Your scene finishes its task and emits `manage_pageflip(true)`.
5.  **Book Regains Control:** The Book disables input on your Scene and re-enables its own.

### 3. Step-by-Step Implementation

**Step A: Create the Scene:**
Create a standard Control scene (e.g., `MyMinigame.tscn`).

**Step B: Add the Script & Signal:**
Attach a script to the root node and add the required signal.

```gdscript
extends Control

# This line tells the Book: "I am interactive, please give me focus."
signal manage_pageflip(give_control_to_book: bool)
```

### Step C: Handle the Exit
Since the Book is disabled, the user is "trapped" in your page until you let them out. You must decide when to return control.

```gdscript
func _on_puzzle_solved():
    # The user finished the game. Return control to the Book.
    emit_signal("manage_pageflip", true)
```

### 4. Advanced: Navigation & Force Close
You might want buttons inside your page to control the book (e.g., "Next Chapter" or "Close Book").
The Book automatically injects a metadata reference called `_pageflip_node` into your scene.

#### Scenario A: Turn the Page
⚠️ **CRITICAL:** You must return input control (`emit_signal`) **BEFORE** calling `next_page()`.

```gdscript
func _on_next_page_button_pressed():
    var book = get_meta("_pageflip_node")
    
    # 1. Return control logic FIRST
    emit_signal("manage_pageflip", true)
    
    # 2. Call navigation
    book.next_page()
```

#### Scenario B: Close the Book (Force Close)
The `force_close_book` function is a special helper. It automatically handles the input return for you, so you don't need to emit the signal manually.

* `to_front_cover = true`: Animates closing towards the front cover.
* `to_front_cover = false`: Animates closing towards the back cover.

```gdscript
func _on_close_button_pressed():
    var book = get_meta("_pageflip_node")
    
    # This function handles the input handshake automatically!
    # Just tell it which way to close.
    book.force_close_book(true) 
```

### 5. API Reference for Interactive Scenes

You can call these functions on the `book` node (retrieved via `get_meta("_pageflip_node")`).

| Function | Parameters | Description | Input Requirement |
| :--- | :--- | :--- | :--- |
| `next_page()` | None | Triggers the animation to the next spread. | ⚠️ **Manual Return:** You **MUST** emit `signal("manage_pageflip", true)` BEFORE calling this. |
| `prev_page()` | None | Triggers the animation to the previous spread. | ⚠️ **Manual Return:** You **MUST** emit `signal("manage_pageflip", true)` BEFORE calling this. |
`go_to_page(index)` | `int` | Navigates to a specific spread (the page corresponds to the position in the array of pages starting at 1). | ⚠️ **Manual Return:** You **MUST** emit `signal("manage_pageflip", true)` BEFORE calling this. |
| `force_close_book(to_front)` | `bool` | Closes the book animated. `true` = To Front Cover, `false` = To Back Cover. | ✅ **Automatic:** This function handles the input handshake internally. Safe to call directly. |
| `current_spread` | (Property) | Returns the current index of the open pages. `-1` is closed front, `0` is first pages. | N/A |
| `total_spreads` | (Property) | Returns the total number of spreads calculated from the content list. | N/A |


# 🔌 External API (BookAPI)

The `BookAPI` is a static utility class that provides helper methods to configure the book and facilitate interaction from embedded scenes. It's not required for PageFlip2D to work, but greatly simplifies common tasks.

## Setup

Place the `BookAPI.gd` script in your PageFlip2D addon folder. You can then use it in your scripts by calling `BookAPI.function_name(parameters)`.

## Enums

### JumpTarget

Used to specify where to jump when navigating to a page.

```gdscript
enum JumpTarget {
    FRONT_COVER,     # Jump to the front cover
    BACK_COVER,      # Jump to the back cover
    CONTENT_PAGE     # Jump to a specific content page
}
```

## Configuration Functions

### configure_visuals(book, data)

Configures the visual properties of a Book instance via a dictionary. Useful for setting up book appearance in one call.

```gdscript
BookAPI.configure_visuals(book, {
    "pages": ["res://page1.png", "res://page2.tscn"],
    "cover_front_out": preload("res://cover_front.png"),
    "cover_front_in": preload("res://cover_inner.png"),
    "cover_back_in": preload("res://back_inner.png"),
    "cover_back_out": preload("res://back_cover.png"),
    "spine_col": Color.BLACK,
    "spine_width": 10,
    "size": Vector2(800, 600)
})
```

**Accepted keys:**

- `pages` - Array of page paths (images or scenes)
- `cover_front_out` - Front cover outer texture
- `cover_front_in` - Front cover inner texture
- `cover_back_in` - Back cover inner texture
- `cover_back_out` - Back cover outer texture
- `spine_col` - Color of the book spine
- `spine_width` - Width of the spine in pixels
- `size` - Page size as Vector2

### configure_physics(book, data)

Configures the physics simulation of the page turning effect. Pass a dictionary with physics properties to customize how pages bend and deform.

```gdscript
BookAPI.configure_physics(book, {
    "bend_strength": 0.8,
    "follow_speed": 8.0,
    "stiffness": 0.5
})
```

## Interactive Scene Functions

### find_book_controller(caller_node)

Locates the PageFlip2D controller ancestor from any node inside an interactive page. Returns the PageFlip2D instance or null.

```gdscript
var book = BookAPI.find_book_controller(self)
if book:
    print("Found book controller!")
```

### set_interaction_lock(book, locked)

Safely locks or unlocks the book's ability to turn pages manually. When locked, the interactive scene is responsible for unlocking it.

> **WARNING:** If locked, the interactive scene MUST unlock it later, or call `go_to_spread()` which forces an unlock at the end.

```gdscript
# Lock the book while a puzzle is in progress
BookAPI.set_interaction_lock(book, true)

# Unlock when done
BookAPI.set_interaction_lock(book, false)
```

### force_release_control(book)

Forces the book to regain input control immediately. Useful as a failsafe if an interactive scene closes unexpectedly.

```gdscript
BookAPI.force_release_control(book)
```

## Navigation Functions

### go_to_spread(book, target_spread, animated)

**ASYNC:** Must be called with `await` if `animated` is true. Navigates to a specific spread (a two-page view).

```gdscript
# Jump to spread 3 instantly
BookAPI.go_to_spread(book, 3, false)

# Animate to spread 5 (must be awaited)
await BookAPI.go_to_spread(book, 5, true)
```

**Parameters:**

- `book` - The PageFlip2D instance
- `target_spread` - The spread index (-1 = front cover, 0 = first pages, etc.)
- `animated` - If true, animates with dynamic speed; if false, snaps instantly

**Behavior:**

- **Animated:** Fast-forwards through pages with dynamic speed (faster for longer distances) and restores control at the end.
- **Instant:** Snaps to page immediately and triggers the scene activation handshake.

### go_to_page(book, page_num, target, animated)

**ASYNC:** Must be called with `await` if `animated` is true. Navigates to a specific page number (1-based index). Acts as a wrapper for `go_to_spread`.

```gdscript
# Jump to page 1 (front cover)
await BookAPI.go_to_page(book, 1, BookAPI.JumpTarget.FRONT_COVER, true)

# Jump to page 5 of content
await BookAPI.go_to_page(book, 5, BookAPI.JumpTarget.CONTENT_PAGE, true)

# Jump to back cover instantly
BookAPI.go_to_page(book, 1, BookAPI.JumpTarget.BACK_COVER, false)
```

**Parameters:**

- `book` - The PageFlip2D instance
- `page_num` - The 1-based page number (ignored for covers)
- `target` - The target type: `FRONT_COVER`, `BACK_COVER`, or `CONTENT_PAGE`
- `animated` - Whether to animate the transition

> **Note:** Spread 0 usually shows Page 1 on the right and Page 2 on the left. The function automatically calculates which spread to jump to based on the page number.

### is_busy(book)

Checks if the book is currently playing a page-turn animation. Returns true if animating, false otherwise.

```gdscript
if not BookAPI.is_busy(book):
    print("Book is ready for input!")
else:
    print("Book is still animating...")
```

---

## 🛠️ Dependencies

* **Godot 4.x**
* No external plugins required. All logic is contained within `PageFlip2D.gd` and `PageRigger.gd`.

---

## 📄 License

**MIT License**

Copyright (c) 2025 Newold
