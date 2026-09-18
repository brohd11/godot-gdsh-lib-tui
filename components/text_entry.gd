#! namespace GDShTUI class TextEntry
extends "res://addons/addon_lib/gdsh_lib/tui/core/component.gd"
## Single-line, codepoint-based editing. No selection or IME composition.
signal changed(text:String)
signal submitted(text:String)
signal cancelled
var text:String = ""
var placeholder:String = ""
var caret:int = 0
var _first:int = 0

func _init(value:String="", placeholder_text:String="") -> void:
	text = single_line(value)
	caret = text.length()
	placeholder = single_line(placeholder_text)
	hint = "Enter Submit · Esc Cancel · Ctrl/Cmd+V Paste"

func set_text(value:String) -> void:
	var next = single_line(value)
	var modified = text != next
	text = next
	caret = text.length()
	_first = 0
	_reveal_caret()
	if modified: changed.emit(text)
	request_redraw()

func set_size(value:Vector2i) -> void:
	super(value)
	_reveal_caret()

func _reveal_caret() -> void:
	caret = clampi(caret, 0, text.length())
	_first = clampi(_first, maxi(0, caret - maxi(1, size.x) + 1), caret)
	_first = mini(_first, maxi(0, text.length() + 1 - maxi(1, size.x)))

func insert_text(value:String) -> void:
	value = single_line(value)
	if value.is_empty(): return
	text = text.left(caret) + value + text.substr(caret)
	caret += value.length()
	_reveal_caret()
	changed.emit(text)
	request_redraw()

func _clipboard_text() -> String:
	return DisplayServer.clipboard_get()

func update(message:TUIMsg) -> bool:
	if not focused or _finished or message.type != TUIMsg.Type.KEY: return false
	var key:InputEventKey = message.payload
	if not key.pressed: return false
	if key.keycode == KEY_V and (key.ctrl_pressed or key.meta_pressed):
		if not key.echo: insert_text(_clipboard_text())
		return true
	var previous = text
	match key.keycode:
		KEY_ENTER, KEY_KP_ENTER:
			if not key.echo: submitted.emit(text)
			return true
		KEY_ESCAPE:
			if not key.echo: cancelled.emit()
			return true
		KEY_LEFT: caret = maxi(0, caret - 1)
		KEY_RIGHT: caret = mini(text.length(), caret + 1)
		KEY_HOME: caret = 0
		KEY_END: caret = text.length()
		KEY_BACKSPACE:
			if caret > 0:
				text = text.left(caret - 1) + text.substr(caret)
				caret -= 1
		KEY_DELETE:
			if caret < text.length(): text = text.left(caret) + text.substr(caret + 1)
		_:
			if key.unicode >= 32 and key.unicode != 127 and not key.ctrl_pressed and not key.meta_pressed:
				insert_text(String.chr(key.unicode))
				return true
			return false
	_reveal_caret()
	if text != previous: changed.emit(text)
	request_redraw()
	return true

func view() -> String:
	if size.x <= 0 or size.y <= 0: return ""
	if text.is_empty() and not focused:
		return "[color=#888888]%s[/color]" % escape(placeholder.left(size.x))
	if text.is_empty() and focused:
		var cursor = placeholder.left(1) if not placeholder.is_empty() else " "
		return "[bgcolor=#ffffff][color=#20242c]%s[/color][/bgcolor][color=#888888]%s[/color]" % [escape(cursor), escape(placeholder.substr(1, maxi(0, size.x - 1)))]
	if not focused: return escape(text.substr(_first, size.x))
	var before = text.substr(_first, caret - _first)
	var cursor = text.substr(caret, 1) if caret < text.length() else " "
	var after = text.substr(caret + 1, maxi(0, size.x - before.length() - 1))
	return "%s[bgcolor=#ffffff][color=#20242c]%s[/color][/bgcolor]%s" % [escape(before), escape(cursor), escape(after)]
