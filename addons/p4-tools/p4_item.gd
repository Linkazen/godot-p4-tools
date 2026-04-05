extends Node
class_name P4Item


static var p4 : PerforceClient = null

## Stored as a relative path (E.G. res://xxx.file)
var _file_path : String = ""
var locked : bool = false
var changelist : int = 0


func _init(file_path : String) -> void:
	if p4 == null:
		printerr("P4Client: P4 client must be set")
		pass
	
	_file_path = file_path
	locked = p4.is_file_locked(get_file_path_globalised())
	print("Locked: ", locked)


func get_file_path_globalised() -> String:
	if _file_path != "":
		return ProjectSettings.globalize_path(_file_path)
	else:
		return ""