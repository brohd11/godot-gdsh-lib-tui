# GDSh TUI components

Reusable screens and BBCode components for GDSh's interactive consoles. The library
is inspired by Bubblestack's retained screen stack and component ownership model.
It works in runtime consoles and Editor Console's docked and floating consoles.

## Use

Place this package under `res://addons/addon_lib/gdsh_lib/tui/`, alongside GDSh.
`GDShTUI` exposes `ScreenCommand`, `Router`, `Screen`, `Component`, `List`, `TextEntry`,
and `Confirmation`. Dependencies flow from this library into GDSh; core GDSh can be
used without it. The library requires no Editor Console services.

Extend `GDShTUI.ScreenCommand` and implement `create_screen() -> Screen`. Normal
command metadata, routing, and `await run()` work as in `GDSh.TUICommand`.

```gdscript
extends GDShTUI.ScreenCommand

class ChoiceScreen extends GDShTUI.Screen:
    var list = GDShTUI.List.new()
    func _init() -> void:
        add_component(list)
        list.set_items([
            GDShTUI.List.Item.new("first", "First choice", 1),
            GDShTUI.List.Item.new("second", "Second choice", 2),
        ])
        list.activated.connect(_pick)
    func _pick(item) -> void:
        pop(item.payload)
    func set_size(value: Vector2i) -> void:
        super(value)
        list.set_size(size)
    func view() -> String:
        return list.view()

static func get_command_name() -> String:
    return "choose"

static func get_self_command_data() -> Dictionary:
    return _command_data({&"help": "Choose an item"})

func create_screen() -> Screen:
    return ChoiceScreen.new()

func _execute(ctx: Context):
    var status = await run()
    if status == ExitCode.OK and result != null:
        ctx.append_output(str(result))
    return status
```

Save your command outside the library and register it through normal command loading,
for example `console.load("res://commands")`. Execute it in a visible console with
an output area. See the [GDSh TUI guide](../../gdsh/_export_ignore/docs/tui.md) for host
setup and [the complete editing flow](_export_ignore/docs/flow.md) for a list, text
entry, and confirmation used together.

This package registers **no commands**. `manifest.gd` preloads the namespace and every
implementation for dependency-walking exports; it can also be used as
`const TUI = preload("res://addons/addon_lib/gdsh_lib/tui/manifest.gd").TUI`.

## Screen stack

The adapter initializes a fresh router and root screen on each run. Screen sizes are
monospace columns/rows, excluding GDSh's hint footer. Only the top screen is drawn and
receives messages. Covered screens retain their components and application state.

| Method | Lifecycle |
| --- | --- |
| `push(screen)` | Blur and suspend the current screen, size/focus/init the new one |
| `pop(result = null)` | Finish the top; resize/focus/resume its parent with the result |
| `replace(screen)` | Finish the top and initialize its replacement, leaving the parent suspended |
| `init()` | Runs once on first attachment; `size` is already available |
| `suspend()` | Runs when another screen covers this one |
| `resume(result)` | Runs when a child pops; `size` has been refreshed |
| `finish()` | Cleanup hook, invoked once when the screen is removed or the session ends |

Navigation requested by an update is applied after that update returns, before the
next message. The event that opens a child never reaches that child. Navigation from
covered or finished screens is ignored; already owned or finished screens cannot be
pushed again. Create a fresh screen for a new visit.

Unconsumed Escape pops one screen. Popping the root stores the returned value in
`ScreenCommand.result` and ends with status 0. Nothing is automatically printed.
Ctrl+C cancels with status 1 and finishes the entire stack. Host removal also cleans
up all retained screens. A screen's `finish()` is an application cleanup hook; it does
not need to call `super()`. A command overriding `finish()` must call `super()` so
its router is cleaned up.

## Components and manual composition

Components are `RefCounted` objects, not scene-tree controls. Their interface is:

- `set_size(Vector2i)` and `set_focused(bool)` establish the rendering/input bounds.
- `update(message: GDSh.TUIMsg) -> bool` handles a message and reports consumption.
- `view() -> String` returns BBCode without changing application state.
- `hint` supplies footer text; a nonempty screen `hint` takes precedence.
- `request_redraw()` schedules a frame after an external state change.
- `finish()` releases application resources or signal subscriptions.

Use `screen.add_component(component)` to transfer ownership and
`focus_component(component)` to choose focus. Tab and Shift+Tab cycle in registration
order, without leaving the console. `remove_component()` finishes that component.
Each component has one owner and cannot be reused after removal.

Construct components in `_init()` so they exist when the router first calls
`set_size()`. Override `set_size()` to allocate space and `view()` to join the pieces.
For example, allocate one row to a text entry and the remaining rows to a list, then
join their views with a newline only when both allocations are nonempty. The screen
owns those layout decisions. There is no automatic wrapping or clipping of arbitrary
custom BBCode; budget rows and use the normal font size.

`Screen.update()` reserves Tab, forwards messages to the focused component, then
handles unconsumed Escape. Override it for screen shortcuts and call `super(message)`
for the component/default behavior. Do not steal printable keys from a focused text
entry. Wheel and pan events go to the focused component; pointer hit-testing is not
part of this first version.

All updates and views are synchronous. Async callbacks can call
`command.post_message(GDSh.TUIMsg.new(GDSh.TUIMsg.Type.USER, payload))`; that message
reaches the screen active when it is processed. Use screen `finish()` to disconnect
callbacks that belong to that screen. State setters request redraws; after assigning
custom state or `hint` directly, call `request_redraw()`. The adapter coalesces external
requests and does not render while idle.

## Built-in components

### List

`List.Item.new(id: String, label: String, payload: Variant = null)` keeps identity,
presentation, and data separate. IDs should be unique and stable. Labels are plain
text: the component normalizes line breaks, clips to its width, and escapes BBCode.

Call `set_items(Array[List.Item])` to replace data; selection is preserved by ID or
clamped if the selected item disappeared. Use `get_selected()`, `selected_index`, and
`select(index)` for selection. `first_visible` tracks the drawn slice separately.

Arrow keys, Page Up/Down, and Home/End move selection. Wheel/pan scroll the slice without
changing selection; subsequent keyboard navigation reveals the selection. `activated(item)`
fires once per Enter press and leaves the component open. `selection_changed(item)`
fires on selection changes and data replacement; its item is null for an empty list.
`empty_text` controls the empty-state message.

### TextEntry

`TextEntry.new(value = "", placeholder = "")` supports typing, Left/Right, Home/End,
Backspace/Delete, and Ctrl/Cmd+V. Pasted tabs and line breaks become spaces. Use
`set_text(value)` to replace text and put the caret at the end, or `insert_text(value)`
to insert at the caret. `text` and `caret` expose the current state.

`changed(text)`, `submitted(text)`, and `cancelled` are application signals. Enter and
Escape do not repeat. The static caret scrolls into view and is hidden when unfocused.
Editing is codepoint-based; there is no selection, IME composition, or grapheme-aware
delete/navigation. Width budgets use the same monospace-cell approximation as GDSh.

### Confirmation

`Confirmation.new(prompt = "Continue?")` renders plain text and Yes/No hints.
Enter/Y emits `resolved(true)`; Escape/N emits `resolved(false)`. Repeats are ignored.
The owner connects that signal to navigation or application behavior. This is a
full-screen flow when housed in a screen; it does not overlay another view.

## Validation

`tests/gdsh_lib/run_headless.py --godot <godot> --export` exercises components, routing,
real console sessions, and compiled-script exports. Editor Console's plugin manager
uses the screen stack and List as a production consumer. The larger modular layout
system, overlays, and mouse hit-testing can build on these interfaces later.
