# Namespace hub; component implementations use direct preloads to avoid cycles.
class_name GDShTUI

const ScreenCommand = preload("res://addons/addon_lib/gdsh_lib/tui/core/screen_command.gd")
const Router = preload("res://addons/addon_lib/gdsh_lib/tui/core/router.gd")
const Screen = preload("res://addons/addon_lib/gdsh_lib/tui/core/screen.gd")
const Component = preload("res://addons/addon_lib/gdsh_lib/tui/core/component.gd")
const List = preload("res://addons/addon_lib/gdsh_lib/tui/components/list.gd")
const TextEntry = preload("res://addons/addon_lib/gdsh_lib/tui/components/text_entry.gd")
const Confirmation = preload("res://addons/addon_lib/gdsh_lib/tui/components/confirmation.gd")
