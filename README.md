# Ultimate PageFlip for Godot

A robust, "Fake 3D" book system for Godot Engine

📄 MIT License | 🎮 Godot 4.x

> Click on the image below to watch a demo video on YouTube
<div align="center">
  <a href="https://www.youtube.com/watch?v=uvx7dPstcvg" alt="Click to watch on YouTube">
    <img src="https://i.ibb.co/yn3cKH0K/preview-ezgif-com-speed.gif" border="0">
  </a>
</div>

---

## 📑 Table of Contents

- [✨ Features](#-features)
- [📦 Installation](#-installation)
- [🚀 Quick Start](#-quick-start)
- [📖 Configuration](#-configuration)
- [🎮 Interactive Scenes](#-interactive-scenes--input-handshake)
- [🔌 BookAPI Reference](#-bookapi-reference)
- [⚙️ BookAPI Setup & Management](#️-bookapi-setup--management)
- [🗂️ Navigation Functions](#️-navigation-functions)
- [🎨 Configuration Functions](#-configuration-functions)
- [🛠️ Helper Functions](#️-helper-functions)
- [🛠️ Dependencies](#️-dependencies)
- [📄 License](#-license)

---

## ✨ Features

- **Easy Configuration:** Drag and drop setup.
- **Universal Content Support:** Accepts `.png`, `.jpg`, and `.tscn` (Scenes) in the same list.
- **Fake 3D Volume:** Procedurally generates the "stack" of pages on the side, expanding and contracting as you flip.
- **Smart Closing System:** Configure how the book closes (via animation, "Escape" key, or API) and what happens next (destroy object or change scene).
- **Composite Pages:** Native support for transparent `.png` images that automatically blend over the paper texture.
- **Physics Rigger:** Built-in `PageRigger` tool generates `Skeleton2D` and `Polygon2D` meshes automatically.
- **Input Handshake:** Automatic system to handle input focus between the Book controller and interactive page content.
- **Book Input:** You can turn the book's pages using the left and right arrow keys, and by clicking on the page you want to flip.

---

## 📦 Installation

1. **Extract:** Copy the `addons` folder directly into your Godot project folder.
2. **Import:** Open Godot and allow the engine to import the scripts and assets.

---

## 🚀 Quick Start

1. **Add the Node:** Inside the Godot Editor, click **Add Child Node** (`Ctrl+A`) and search for **`PageFlip2D`**.

2. **Auto-Build:** As soon as the node enters the Scene Tree, it will automatically recreate all necessary sub-nodes (Viewports, Slots, Visuals, etc.) for you.

3. **💡 Pro Tip (One-Click Setup):** Select your new `PageFlip2D` node. In the Inspector, look for the category **"Newold Config"** and click **`Apply Newold Preset`**.
   - This will instantly apply a polished configuration (physics, sizes, visual style), making the book ready to use immediately. You just need to add your content!

4. **Add Content:** In the Inspector, find the **Content Source** category. Add elements to the `Pages Paths` array:
   - Paths to images (`res://art/page1.png`)
   - ...or paths to scenes (`res://gui/InventoryPage.tscn`)

---

## 📖 Configuration

### The Page Rigger

The pages are not simple static sprites; they are deformable meshes handled by `PageRigger.gd`. The book **automatically rebuilds** the rig and recalculates animations every time you run the game to ensure they match your current page size.

### Book Logic & Closing

You can control how the book behaves when it reaches the covers or when the user wants to exit.

#### Close Condition:

- **NEVER:** The book stays open or just shows the cover.
- **CLOSE_FROM_BACK / CLOSE_FROM_FRONT:** Triggers the close behavior automatically after the specific cover animation finishes.
- **ANY_CLOSE:** Triggers if either the front or back cover is closed.
- **ON_CANCEL_INPUT:** Closes immediately when the `ui_cancel` action (usually ESC) is pressed.
- **DELEGATED:** The book waits for a manual call from a script (see API below).

#### Close Behavior:

- **DESTROY_BOOK:** Removes the node from the tree (`queue_free`).
- **CHANGE_SCENE:** Changes the main scene to the one specified in `Target Scene On Close`.

### Visual Style

- **Composite Pages:** If enabled, pages with transparency (like a handwritten note `.png` with alpha) will be rendered **on top** of the `Blank Page Texture`. If disabled, transparent areas will show through to the page behind.
- **Volume:** Adjust `Min/Max Layers` to change how thick the book looks.
- **Spine:** Customize the width and texture of the book's spine.

---

## 🎮 Interactive Scenes & Input Handshake

This system shines when using **PackedScenes (`.tscn`)** as pages. You can have a functioning inventory, a map with clickable markers, or a puzzle **inside** the book.

### 1. How it Works (The Concept)

The system needs to know if a page is just visual (like a video or text) or if it requires mouse input. It determines this using a specific **Signal**.

- **Interactive Scene:** Any scene script that contains the signal `manage_pageflip`.
- **Passive Scene:** Any scene that **does not** have the signal.

> **The Trigger:** When a page flip animation finishes, the Book checks the newly visible pages. If they contain the signal, the Input Handshake begins.

### 2. The Input Cycle (Lifecycle)

1. **Animation Ends:** The page lands.
2. **Handover (Book → Scene):** The Book detects the signal. It **disables** its own input processing and **enables** input processing on your Scene.
3. **Interaction:** The user clicks buttons, drags items, or scrolls inside your scene.
4. **Return (Scene → Book):** Your scene finishes its task and emits `manage_pageflip(true)`.
5. **Book Regains Control:** The Book disables input on your Scene and re-enables its own.

### 3. Step-by-Step Implementation

#### Step A: Create the Scene

Create a standard Control scene (e.g., `MyMinigame.tscn`).

#### Step B: Add the Script & Signal

Attach a script to the root node and add the required signal.

```gdscript
extends Control

# This line tells the Book: "I am interactive, please give me focus."
signal manage_pageflip(give_control_to_book: bool)
```

#### Step C: Handle the Exit

Since the Book is disabled, the user is "trapped" in your page until you let them out. You must decide when to return control.

```gdscript
func _on_puzzle_solved():
    # The user finished the game. Return control to the Book.
    emit_signal("manage_pageflip", true)
```

### 4. Advanced: Navigation & Force Close

You might want buttons inside your page to control the book (e.g., "Next Chapter" or "Close Book").

> **RECOMMENDATION:** It is highly recommended to use the global [BookAPI](#-bookapi-reference) for navigation instead of retrieving the node manually.

#### Scenario A: Turn the Page

> **✅ SIMPLIFIED WITH BookAPI:** When using the `BookAPI` for navigation, you do **NOT** need to manually emit `manage_pageflip(true)` first. The API automatically handles the input control handover for you!

```gdscript
func _on_next_page_button_pressed():
    # That's it! BookAPI handles everything:
    # - Returns control to the book
    # - Turns the page
    # - Restores input focus as needed
    BookAPI.next_page()
```

> **Legacy Approach (Not Recommended):** If you were directly calling methods on the book node, you had to manually emit the signal first:

```gdscript
func _on_next_page_button_pressed():
    # OLD WAY - Manual control management (NOT recommended)
    emit_signal("manage_pageflip", true)
    _current_book.next_page()
```

---

## 🔌 BookAPI Reference

`BookAPI` is a static utility class that provides helper methods to configure the book and facilitate interaction from embedded scenes or any other script in your game. It acts as a Singleton that automatically tracks the last active book.

> **📍 Key Concept:** This is a global, static API. You do not need to instance it. Simply call `BookAPI.function_name()` from anywhere in your project.

---

## ⚙️ BookAPI Setup & Management

### `set_current_book(book: PageFlip2D) → void`

Registers a book instance as the currently active one. Automatically called by `PageFlip2D` when it enters the scene tree, but can be called manually if you have multiple books active simultaneously.

**Parameters:**
- `book` - The `PageFlip2D` instance to set as active

```gdscript
BookAPI.set_current_book(my_book_instance)
```

### `get_current_book() → PageFlip2D`

Returns the currently active book instance, or `null` if none is registered.

**Returns:** The active `PageFlip2D` instance or `null`

```gdscript
var book = BookAPI.get_current_book()
if book:
    print("Active book found:", book.name)
```

### `register_book(book_id: String, book: PageFlip2D) → void`

Registers a book with a unique ID for later retrieval. If a book with the same ID already exists and is valid, it's freed before the new one is registered.

**Parameters:**
- `book_id` - A unique identifier string
- `book` - The `PageFlip2D` instance to register

```gdscript
BookAPI.register_book("main_book", my_book)
BookAPI.register_book("inventory_book", inventory_page)
```

### `get_book_by_id(book_id: String) → PageFlip2D`

Retrieves a previously registered book using its ID. Returns `null` if the book is not found or has been freed.

**Parameters:**
- `book_id` - The identifier string used during registration

**Returns:** The `PageFlip2D` instance or `null`

```gdscript
var my_book = BookAPI.get_book_by_id("main_book")
if my_book:
    BookAPI.set_current_book(my_book)
```

---

## 🗂️ Navigation Functions

### `next_page() → void`

Turns the page forward (to the next page/spread) in the currently active book. Does nothing if the book is animating or at the end.

**Auto-Tracking:** Uses the current active book set by `set_current_book()`

```gdscript
BookAPI.next_page()
```

### `prev_page() → void`

Turns the page backward (to the previous page/spread) in the currently active book. Does nothing if the book is animating or at the beginning.

**Auto-Tracking:** Uses the current active book set by `set_current_book()`

```gdscript
BookAPI.prev_page()
```

### `force_close_book(to_front_cover: bool) → void`

Forces the active book to close towards a specific cover with animation. Useful for implementing a "Close Book" button or exit logic.

**Parameters:**
- `to_front_cover` - If `true`, closes to Front Cover (Right to Left). If `false`, closes to Back Cover (Left to Right)

```gdscript
# Close the book to the front cover
BookAPI.force_close_book(true)

# Close the book to the back cover
BookAPI.force_close_book(false)
```

### `go_to_page(page_num, target, animated) → async void`

**ASYNC:** Must be called with `await` if `animated` is `true`. Navigates to a specific page number (1-based index). Acts as a wrapper for `go_to_spread()`, calculating the correct spread index automatically.

**Parameters:**
- `page_num` - The 1-based page number (default: 1)
- `target` - Specifies target type (see enum below)
- `animated` - Whether to animate the transition (default: true)

**JumpTarget Enum Values:**
- `JumpTarget.FRONT_COVER` - Jump to closed state showing Front Cover
- `JumpTarget.BACK_COVER` - Jump to closed state showing Back Cover
- `JumpTarget.CONTENT_PAGE` - Jump to a specific content page

```gdscript
# Jump to page 5 with animation
await BookAPI.go_to_page(5, BookAPI.JumpTarget.CONTENT_PAGE, true)

# Jump to back cover instantly
BookAPI.go_to_page(1, BookAPI.JumpTarget.BACK_COVER, false)

# Jump to front cover with animation
await BookAPI.go_to_page(1, BookAPI.JumpTarget.FRONT_COVER, true)
```

### `go_to_spread(book: PageFlip2D, target_spread: int, animated: bool) → async void`

**ASYNC:** Navigates to a specific spread index directly. Supports both instant teleport and animated fast-forward modes.

**Parameters:**
- `book` - The `PageFlip2D` instance to control
- `target_spread` - The spread index to jump to
- `animated` - If `true`, animates with dynamic speed. If `false`, snaps instantly

**Behavior:**
- **Animated:** Fast-forwards through pages with dynamic speed (1.5x to 10.0x based on distance)
- **Instant:** Snaps to page and manually triggers scene activation handshake

```gdscript
# Animated jump
await BookAPI.go_to_spread(my_book, 5, true)

# Instant teleport
BookAPI.go_to_spread(my_book, 0, false)
```

---

## 🎨 Configuration Functions

### `configure_visuals(book: PageFlip2D, data: Dictionary) → void`

Configures the visual properties of a Book instance via a dictionary. Useful for setting up book appearance in one call or for dynamically changing book visuals.

**Parameters:**
- `book` - The `PageFlip2D` instance
- `data` - Dictionary with configuration keys (see below)

**Dictionary Keys:**
- `"pages"` - Array of paths to pages (images or scenes)
- `"cover_front_out"` - Texture for front cover outer side
- `"cover_front_in"` - Texture for front cover inner side
- `"cover_back_in"` - Texture for back cover inner side
- `"cover_back_out"` - Texture for back cover outer side
- `"spine_col"` - Color for the book spine
- `"spine_width"` - Width of the spine in pixels
- `"size"` - Vector2 for page size

```gdscript
BookAPI.configure_visuals(my_book, {
    "pages": ["res://page1.png", "res://page2.png", "res://page3.tscn"],
    "cover_front_out": preload("res://cover_front.png"),
    "cover_back_out": preload("res://cover_back.png"),
    "spine_col": Color.BLACK,
    "spine_width": 20,
    "size": Vector2(800, 600)
})
```

### `configure_physics(book: PageFlip2D, data: Dictionary) → void`

Configures the physics simulation of the page turning effect. Modifies properties of the internal `PageRigger` to change how pages bend and deform.

**Parameters:**
- `book` - The `PageFlip2D` instance with a valid `dynamic_poly`
- `data` - Dictionary of physics properties to configure

**Common Physics Properties:**
- `"paper_stiffness"` - How rigid the paper is (0.0-1.0)
- `"lift_bend"` - Bend angle when lifting the page
- `"gravity_strength"` - Effect of gravity on the page

```gdscript
BookAPI.configure_physics(my_book, {
    "paper_stiffness": 0.8,
    "lift_bend": -15.0
})
```

## 📄 License

MIT License
