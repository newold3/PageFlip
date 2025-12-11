# Ultimate PageFlip for Godot

A robust, "Fake 3D" book system for Godot Engine

[![MIT License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Godot 4.x](https://img.shields.io/badge/Godot-4.x-blue.svg)](https://godotengine.org/)

> Click on the image below to watch a demo video on YouTube
<div align="center">
  <a href="https://www.youtube.com/watch?v=uvx7dPstcvg" alt="Click to watch on YouTube">
    <img src="https://i.ibb.co/yn3cKH0K/preview-ezgif-com-speed.gif" border="0">
  </a>
</div>

## 📑 Table of Contents

- [✨ Features](#-features)
- [📦 Installation](#-installation)
- [🚀 Quick Start](#-quick-start)
- [📖 Configuration](#-configuration)
- [🎮 Interactive Scenes & Input Handshake](#-interactive-scenes--input-handshake)
- [5️⃣ API Reference (Legacy)](#️⃣-api-reference-for-interactive-scenes-legacy)
- [🔌 External API (BookAPI)](#-external-api-bookapi)
- [🛠️ Dependencies](#️-dependencies)
- [📄 License](#-license)

## ✨ Features

- **Easy Configuration:** Drag and drop setup.
- **Universal Content Support:** Accepts `.png`, `.jpg`, and `.tscn` (Scenes) in the same list.
- **Fake 3D Volume:** Procedurally generates the "stack" of pages on the side, expanding and contracting as you flip.
- **Smart Closing System:** Configure how the book closes (via animation, "Escape" key, or API) and what happens next (destroy object or change scene).
- **Composite Pages:** Native support for transparent `.png` images that automatically blend over the paper texture.
- **Physics Rigger:** Built-in `PageRigger` tool generates `Skeleton2D` and `Polygon2D` meshes automatically.
- **Input Handshake:** Automatic system to handle input focus between the Book controller and interactive page content.
- **Book Input:** Turn the book's pages using the left and right arrow keys, and by clicking on the page you want to flip.

## 📦 Installation

1. **Extract:** Copy the `addons` folder directly into your Godot project folder.
2. **Import:** Open Godot and allow the engine to import the scripts and assets.

## 🚀 Quick Start

1. **Add the Node:** Inside the Godot Editor, click **Add Child Node** (`Ctrl+A`) and search for **`PageFlip2D`**.

2. **Auto-Build:** As soon as the node enters the Scene Tree, it will automatically recreate all necessary sub-nodes (Viewports, Slots, Visuals, etc.) for you.

3. **💡 Pro Tip (One-Click Setup):** Select your new `PageFlip2D` node. In the Inspector, look for the category **"Newold Config"** and click **`Apply Newold Preset`**.
   - This will instantly apply a polished configuration (physics, sizes, visual style), making the book ready to use immediately. You just need to add your content!

4. **Add Content:** In the Inspector, find the **Content Source** category. Add elements to the `Pages Paths` array:
   - Paths to images (`res://art/page1.png`)
   - ...or paths to scenes (`res://gui/InventoryPage.tscn`)

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

> **RECOMMENDATION:** It is highly recommended to use the global [BookAPI](#-external-api-bookapi) for navigation instead of retrieving the node manually.

#### Scenario A: Turn the Page

> **CRITICAL:** You must return input control (`emit_signal`) **BEFORE** calling navigation methods.

```gdscript
func _on_next_page_button_pressed():
    # 1. Return control logic FIRST
    emit_signal("manage_pageflip", true)
    
    # 2. Call navigation using the static API (Recommended)
    BookAPI.next_page()
```

## 5️⃣ API Reference for Interactive Scenes (Legacy)

> ⚠️ **OBSOLETE APPROACH:**
> 
> While accessing the book node via metadata (`get_meta("_pageflip_node")`) still works, it is considered **obsolete**.
> 
> We strongly recommend using the static **[BookAPI](#-external-api-bookapi)** instead (see below). It allows you to call functions globally without manual node retrieval, offers type safety, and is cleaner to use.

The following reference is kept for legacy support. These methods can be called directly on the book node.

| Function | Parameters | Description |
|----------|-----------|-------------|
| `next_page()` | None | Triggers the animation to the next spread. |
| `prev_page()` | None | Triggers the animation to the previous spread. |
| `go_to_page(index)` | `int` | Navigates to a specific spread. |
| `force_close_book(to_front)` | `bool` | Closes the book animated. |

## 🔌 External API (BookAPI)

The `BookAPI` is a static utility class that provides helper methods to configure the book and facilitate interaction from embedded scenes or any other script in your game. It acts as a Singleton that automatically tracks the last active book.

### Setup

Place the `BookAPI.gd` script in your PageFlip2D addon folder. You can then use it globally by calling `BookAPI.function_name(parameters)`.

> **Auto-Tracking:** When a `PageFlip2D` node enters the scene tree, it automatically registers itself as the current book in the API. You don't need to pass the book instance manually unless you have multiple books and want to control a specific one.

### Navigation Functions

#### next_page() / prev_page()

Turns the page of the currently active book.

```gdscript
# Simple navigation
BookAPI.next_page()
BookAPI.prev_page()
```

#### go_to_page(page_num, target, animated)

**ASYNC:** Must be called with `await` if `animated` is true.

```gdscript
# Jump to page 5 content
await BookAPI.go_to_page(5, BookAPI.JumpTarget.CONTENT_PAGE, true)

# Jump to back cover instantly
BookAPI.go_to_page(1, BookAPI.JumpTarget.BACK_COVER, false)
```

### Configuration Functions

#### configure_visuals(book, data)

Configures the visual properties of a Book instance via a dictionary. Useful for setting up book appearance in one call.

```gdscript
BookAPI.configure_visuals(my_book_instance, {
    "pages": ["res://page1.png", "res://page2.tscn"],
    "cover_front_out": preload("res://cover_front.png"),
    "spine_col": Color.BLACK,
    "size": Vector2(800, 600)
})
```

#### configure_physics(book, data)

Configures the physics simulation settings.

```gdscript
BookAPI.configure_physics(my_book_instance, {
    "paper_stiffness": 0.8,
    "lift_bend": -15.0
})
```

### Interactive Scene Helpers

#### find_book_controller(caller_node)

Locates the PageFlip2D controller ancestor from any node inside an interactive page.

```gdscript
var book = BookAPI.find_book_controller(self)
```

#### is_busy(book_instance)

Checks if the book is currently playing a page-turn animation. If no instance is passed, checks the global active book.

```gdscript
if not BookAPI.is_busy():
    print("Ready for input")
```

## 🛠️ Dependencies

- **Godot 4.x**
- No external plugins required. All logic is contained within `PageFlip2D.gd` and `PageRigger.gd`.

## 📄 License

**MIT License**

Copyright (c) 2025 Newold
