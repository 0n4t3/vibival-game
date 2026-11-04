extends Node
## Loads every script under res://src one by one so parse errors are reported
## per file (the release runtime does not explain dependency failures).


func _ready() -> void:
	var files := []
	_collect("res://src", files)
	var failed := 0
	for f in files:
		var s: Script = ResourceLoader.load(f, "", ResourceLoader.CACHE_MODE_IGNORE)
		if s == null or not s.can_instantiate():
			print("FAIL ", f)
			failed += 1
	print("CHECKED %d scripts, %d failed" % [files.size(), failed])
	get_tree().quit(1 if failed else 0)


func _collect(dir: String, out: Array) -> void:
	for d in DirAccess.get_directories_at(dir):
		_collect(dir.path_join(d), out)
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
