#! namespace GDShTUI class Confirmation
extends "res://addons/addon_lib/gdsh_lib/tui/core/component.gd"
## The owner decides whether resolving this component should pop a screen.
signal resolved(accepted:bool)
var prompt:String

func _init(question:String="Continue?") -> void:
	prompt = question
	hint = "Enter/Y Yes · Esc/N No"

func update(message:TUIMsg) -> bool:
	if not focused or _finished or message.type != TUIMsg.Type.KEY: return false
	var key:InputEventKey = message.payload
	if not key.pressed: return false
	if key.ctrl_pressed or key.meta_pressed or key.alt_pressed: return false
	match key.keycode:
		KEY_ENTER, KEY_KP_ENTER, KEY_Y:
			if not key.echo: resolved.emit(true)
		KEY_ESCAPE, KEY_N:
			if not key.echo: resolved.emit(false)
		_: return false
	return true

func view() -> String:
	if size.x <= 0 or size.y <= 0: return ""
	var lines:PackedStringArray = []
	for line in prompt.replace("\r\n", "\n").replace("\r", "\n").split("\n"):
		if lines.size() >= size.y: break
		lines.append(escape(line.replace("\t", " ").left(size.x)))
	if lines.size() < size.y: lines.append(escape("[Yes / No]".left(size.x)))
	return "\n".join(lines)
