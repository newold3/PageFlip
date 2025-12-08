# Ultimate PageFlip for Godot

**A robust, "Fake 3D" book system for Godot Engine.** (Click on the image to see a video demonstration)

<div align="center">
  <a href="https://www.youtube.com/watch?v=uvx7dPstcvg" alt="Click to watch on YouTube">
    <img src="https://i.ibb.co/99pWs7GV/preview-ezgif-com-resize.gif" alt="video preview" border="0">
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

---

## 🛠️ Dependencies

* **Godot 4.x**
* No external plugins required. All logic is contained within `PageFlip2D.gd` and `PageRigger.gd`.

---

## 📄 License

**MIT License**

Copyright (c) 2025 Newold
