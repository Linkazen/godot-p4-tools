@tool
extends RefCounted

class_name PerforceClient

## Handles all Perforce operations and state management

var workspace_root: String = ""
var checked_out_files: Dictionary = {}
var last_cleanup_time: float = 0.0
var godot_changelist_number: String = ""
const GODOT_CHANGELIST_DESCRIPTION = "Checked Out by Godot"

signal file_checked_out(file_path: String, success: bool)
signal checkout_failed(file_path: String, error_message: String)

func _init():
	_get_p4_info()
	_ensure_godot_changelist()

func _get_p4_info():
	var output = []
	var exit_code = OS.execute("p4", ["info"], output, true)
	
	if exit_code == 0:
		for line in output:
			if line.begins_with("Client root:"):
				workspace_root = line.split(":")[1].strip_edges()
				break

func is_file_checked_out(file_path: String) -> bool:
	return file_path in checked_out_files

func is_file_writable(file_path: String) -> bool:
	if file_path == "" or not file_path.begins_with("res://"):
		return false
	
	var absolute_path = ProjectSettings.globalize_path(file_path)
	
	# Try to open for reading first to check if file exists
	var test_file = FileAccess.open(absolute_path, FileAccess.READ)
	if test_file == null:
		return false
	test_file.close()
	
	# Try to open for writing
	var write_file = FileAccess.open(absolute_path, FileAccess.READ_WRITE)
	if write_file != null:
		write_file.close()
		return true
	
	return false

func ensure_checked_out(file_path: String) -> bool:
	if file_path == "" or not file_path.begins_with("res://"):
		return false
	
	# If already checked out this session, still verify changelist
	if is_file_checked_out(file_path):
		# Make sure it's in the right changelist
		if godot_changelist_number != "":
			if not _move_file_to_changelist(file_path, godot_changelist_number):
				# If moving failed, try to ensure we have a valid changelist
				_ensure_godot_changelist()
				if godot_changelist_number != "":
					_move_file_to_changelist(file_path, godot_changelist_number)
		return true
	
	# Check if file is already writable
	if is_file_writable(file_path):
		checked_out_files[file_path] = Time.get_unix_time_from_system()
		
		# Even if writable, try to move to Godot changelist if not already there
		if godot_changelist_number != "":
			if not _move_file_to_changelist(file_path, godot_changelist_number):
				# If moving failed, try to ensure we have a valid changelist
				_ensure_godot_changelist()
				if godot_changelist_number != "":
					_move_file_to_changelist(file_path, godot_changelist_number)
		
		return true
	
	# File is read-only, checkout from P4
	return checkout_file(file_path)

func checkout_file(file_path: String) -> bool:
	var absolute_path = ProjectSettings.globalize_path(file_path)
	
	if DirAccess.dir_exists_absolute(absolute_path):
		print("[PerforceClient] Checking out directory: ", absolute_path)
		var dir = DirAccess.open(absolute_path)
		if dir:
			dir.list_dir_begin()
			var file_name = dir.get_next()
			while file_name != "":
				if file_name != "." and file_name != "..":
					checkout_file(file_path.path_join(file_name))
				file_name = dir.get_next()
			dir.list_dir_end()
		return true

	
	var output = []
	var exit_code = OS.execute("p4", ["edit", absolute_path], output, true)
	
	if exit_code == 0:
		checked_out_files[file_path] = Time.get_unix_time_from_system()
		
		# Move file to Godot changelist if we have one
		if godot_changelist_number != "":
			if not _move_file_to_changelist(file_path, godot_changelist_number):
				# If moving failed, try to ensure we have a valid changelist
				_ensure_godot_changelist()
				if godot_changelist_number != "":
					_move_file_to_changelist(file_path, godot_changelist_number)
		
		file_checked_out.emit(file_path, true)
		return true
	else:
		var error_msg = "Failed to checkout " + file_path
		if output.size() > 0:
			error_msg += ": " + output[0]
		checkout_failed.emit(file_path, error_msg)
		return false

func add_file(file_path: String) -> bool:
	var absolute_path = ProjectSettings.globalize_path(file_path)
	
	
	var output = []
	var exit_code = OS.execute("p4", ["add", absolute_path], output, true)
	
	if exit_code == 0:
		checked_out_files[file_path] = Time.get_unix_time_from_system()
		
		# Move file to Godot changelist if we have one
		if godot_changelist_number != "":
			if not _move_file_to_changelist(file_path, godot_changelist_number):
				# If moving failed, try to ensure we have a valid changelist
				_ensure_godot_changelist()
				if godot_changelist_number != "":
					_move_file_to_changelist(file_path, godot_changelist_number)
		
		file_checked_out.emit(file_path, true)
		return true
	else:
		var error_msg = "Failed to add " + file_path
		if output.size() > 0:
			error_msg += ": " + output[0]
		checkout_failed.emit(file_path, error_msg)
		return false

func get_file_status(file_path: String) -> String:
	var absolute_path = ProjectSettings.globalize_path(file_path)
	
	var output = []
	var exit_code = OS.execute("p4", ["fstat", absolute_path], output, true)
	
	if exit_code == 0 and output.size() > 0:
		return output[0]
	else:
		return "Unknown"

func revert_file(file_path: String) -> bool:
	var absolute_path = ProjectSettings.globalize_path(file_path)
	
	var output = []
	var exit_code = OS.execute("p4", ["revert", absolute_path], output, true)
	
	if exit_code == 0:
		checked_out_files.erase(file_path)
		return true
	else:
		var error_msg = "Failed to revert " + file_path
		if output.size() > 0:
			error_msg += ": " + output[0]
		return false

func cleanup_old_entries():
	# Clean up entries older than 10 minutes to prevent memory bloat
	var current_time = Time.get_unix_time_from_system()
	
	# Only cleanup every 5 minutes
	if current_time - last_cleanup_time < 300:
		return
	
	last_cleanup_time = current_time
	var keys_to_remove = []
	
	for file_path in checked_out_files:
		if current_time - checked_out_files[file_path] > 600: # 10 minutes
			keys_to_remove.append(file_path)
	
	for key in keys_to_remove:
		checked_out_files.erase(key)
	

func get_checked_out_files() -> Array:
	return checked_out_files.keys()

func get_workspace_root() -> String:
	return workspace_root

func get_godot_changelist_number() -> String:
	return godot_changelist_number

func _ensure_godot_changelist():
	# Check if our current changelist is still valid
	if godot_changelist_number != "" and _is_changelist_valid(godot_changelist_number):
		return
	
	# Check if we already have a Godot changelist
	var existing_changelist = _find_godot_changelist()
	if existing_changelist != "":
		godot_changelist_number = existing_changelist
		return
	
	# Create a new changelist for Godot
	godot_changelist_number = _create_changelist(GODOT_CHANGELIST_DESCRIPTION)

func _find_godot_changelist() -> String:
	# Look for existing changelist with our description
	var output = []
	var exit_code = OS.execute("p4", ["changes", "-s", "pending", "-u", _get_current_user()], output, true)
	
	if exit_code == 0:
		for line in output:
			# Line format: "Change 12345 on 2023/12/01 by user@client 'Description'"
			if GODOT_CHANGELIST_DESCRIPTION in line:
				var parts = line.split(" ")
				if parts.size() >= 2:
					return parts[1] # Return the changelist number
	
	return ""

func _get_current_user() -> String:
	var output = []
	var exit_code = OS.execute("p4", ["user", "-o"], output, true)
	
	if exit_code == 0:
		for line in output:
			if line.begins_with("User:"):
				return line.split(":")[1].strip_edges()
	
	return ""

func _is_changelist_valid(changelist_number: String) -> bool:
	if changelist_number == "":
		return false
	
	var output = []
	var exit_code = OS.execute("p4", ["change", "-o", changelist_number], output, true)
	
	# If the command succeeds, the changelist exists
	return exit_code == 0

func _create_changelist(description: String) -> String:
	# Use a simpler approach - just create with description directly
	var output = []
	var exit_code = OS.execute("p4", ["change", "-o"], output, true)
	
	if exit_code != 0:
		return ""
	
	# Join all output and replace the description
	var full_spec = "\n".join(output)
	full_spec = full_spec.replace("<enter description here>", description)
	
	# Write the modified spec to a temp file
	var temp_file_path = OS.get_user_data_dir() + "/p4_changelist.tmp"
	var file = FileAccess.open(temp_file_path, FileAccess.WRITE)
	if file == null:
		return ""
	
	file.store_string(full_spec)
	file.close()
	
	# Use shell to pipe the file into p4 change -i
	var create_output = []
	var shell_command = "p4 change -i < \"" + temp_file_path + "\""
	var create_exit_code = OS.execute("cmd", ["/c", shell_command], create_output, true)
	
	# Clean up temp file
	if FileAccess.file_exists(temp_file_path):
		DirAccess.remove_absolute(temp_file_path)
	
	if create_exit_code == 0 and create_output.size() > 0:
		# Output format: "Change 12345 created."
		var result = create_output[0]
		var parts = result.split(" ")
		if parts.size() >= 2:
			return parts[1] # Return the changelist number
	
	return ""

func _move_file_to_changelist(file_path: String, changelist_number: String) -> bool:
	if changelist_number == "":
		return false
	
	var absolute_path = ProjectSettings.globalize_path(file_path)
	
	var output = []
	var exit_code = OS.execute("p4", ["reopen", "-c", changelist_number, absolute_path], output, true)
	
	# If the changelist doesn't exist anymore, recreate it
	if exit_code != 0 and output.size() > 0:
		var error_text = output[0].to_lower()
		if "invalid changelist" in error_text or "unknown changelist" in error_text:
			# Changelist was deleted, recreate it
			godot_changelist_number = _create_changelist(GODOT_CHANGELIST_DESCRIPTION)
			if godot_changelist_number != "":
				# Try again with the new changelist
				output.clear()
				exit_code = OS.execute("p4", ["reopen", "-c", godot_changelist_number, absolute_path], output, true)
	
	return exit_code == 0
