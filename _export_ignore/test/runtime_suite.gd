extends RefCounted
## gdsh_lib tui runtime checks, driven by runtime_test.gd (headless and editor console `test`).
## The checks live in tui_tests.gd, which reports through check/equal here.

var checks = 0
var failures = 0
var report:Array[String] = []


func run_sync():
	preload("res://addons/_lib/gdsh_lib/tui/_export_ignore/test/tui_tests.gd").new().run_sync(self)


func run_frames() -> void:
	await preload("res://addons/_lib/gdsh_lib/tui/_export_ignore/test/tui_tests.gd").new().run_frames(self)


func finish() -> Array[String]:
	report.append("GDSh tui: %d checks, %d failures" % [checks, failures])
	return report


func check(condition:bool, label:String):
	checks += 1
	if not condition:
		failures += 1
		report.append("FAIL: " + label)


func equal(actual, expected, label:String):
	check(actual == expected, "%s (expected %s, got %s)" % [label, str(expected), str(actual)])
