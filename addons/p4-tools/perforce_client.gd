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
		for output_chunk in output:
			var lines = output_chunk.split("\n")
			for line in lines:
				if line.begins_with("Client root:"):
					var colon_pos = line.find(":")
					if colon_pos != -1:
						workspace_root = line.substr(colon_pos + 1).strip_edges()
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

func revert_file(file_path: String, only_revert_if_unchanged : bool) -> bool:
	var absolute_path = ProjectSettings.globalize_path(file_path)
	
	var output = []
	var exit_code : int
	
	if only_revert_if_unchanged:
		exit_code = OS.execute("p4", ["revert", "-a", absolute_path], output, true)
	else:
		exit_code = OS.execute("p4", ["revert", absolute_path], output, true)
	
	if exit_code == 0:
		checked_out_files.erase(file_path)
		print("P4Client: Successfully reverted")
		return true
	else:
		var error_msg = "Failed to revert " + file_path
		if output.size() > 0:
			error_msg += ": " + output[0]
			printerr("P4Client: " + error_msg)
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

func get_client_name() -> String:
	var output = []
	var exit_code = OS.execute("p4", ["info"], output, true)
	
	if exit_code == 0:
		for output_chunk in output:
			var lines = output_chunk.split("\n")
			for line in lines:
				if line.begins_with("Client name:"):
					return line.split(":")[1].strip_edges()
	return ""

func get_godot_changelist_number() -> String:
	return godot_changelist_number

func get_all_changelists() -> Array:
	var user = _get_p4_user()
	var output = []
	var exit_code = -1
	
	# Try with user filter if we have a username, using JSON output
	if user != "":
		exit_code = OS.execute("p4", ["-ztag", "-Mj", "changes", "-s", "pending", "-u", user], output, true)
	
	# If user filter failed or no username, try without user filter
	if exit_code != 0:
		output.clear()
		exit_code = OS.execute("p4", ["-ztag", "-Mj", "changes", "-s", "pending"], output, true)
	
	var changelists = []
	if exit_code == 0 and output.size() > 0:
		# Parse JSON Lines output (each line is a separate JSON object)
		var json_text = ""
		for chunk in output:
			json_text += chunk
		
		var lines = json_text.split("\n")
		var json = JSON.new()
		
		for line in lines:
			line = line.strip_edges()
			if line == "":
				continue
				
			var parse_result = json.parse(line)
			
			if parse_result == OK:
				var change_data = json.data
				
				if change_data.has("change") and change_data.has("desc") and change_data.has("status"):
					# Only include pending changelists
					if change_data["status"] == "pending":
						var cl_number = str(change_data["change"])
						var description = change_data["desc"].strip_edges()
						
						changelists.append({
							"number": cl_number,
							"description": description
						})
			else:
				# If any line fails, fall back to text parsing for the whole output
				changelists.clear()
				_parse_text_output(output, changelists)
				break
	
	return changelists

func _parse_text_output(output: Array, changelists: Array):
	for output_chunk in output:
		var lines = output_chunk.split("\n")
		for line in lines:
			line = line.strip_edges()
			if line == "":
				continue
			var parts = line.split(" ")
			if parts.size() >= 2 and parts[0] == "Change":
				var cl_number = parts[1]
				var description = ""
				var desc_start = line.find("'")
				if desc_start != -1:
					var desc_end = line.rfind("'")
					if desc_end > desc_start:
						description = line.substr(desc_start + 1, desc_end - desc_start - 1)
				
				changelists.append({
					"number": cl_number,
					"description": description
				})

func get_changelist_files(cl_number: String) -> Array:
	var output = []
	var exit_code = OS.execute("p4", ["-ztag", "-Mj", "describe", "-s", cl_number], output, true)
	
	var files = []
	if exit_code == 0 and output.size() > 0:
		# Parse JSON Lines output
		var json_text = ""
		for chunk in output:
			json_text += chunk
		
		var lines = json_text.split("\n")
		var json = JSON.new()
		
		for line in lines:
			line = line.strip_edges()
			if line == "":
				continue
				
			var parse_result = json.parse(line)
			if parse_result == OK:
				var data = json.data
				
				# Look for file entries (depotFile0, depotFile1, etc.)
				var file_index = 0
				while data.has("depotFile" + str(file_index)):
					var depot_path = data["depotFile" + str(file_index)]
					var action = data.get("action" + str(file_index), "edit")
					
					# Convert depot path to local path
					var local_path = _depot_to_local_path(depot_path)
					if local_path != "":
						files.append({
							"path": local_path,
							"action": action
						})
					
					file_index += 1
	
	return files

func _get_p4_user() -> String:
	var output = []
	var exit_code = OS.execute("p4", ["user", "-o"], output, true)
	
	if exit_code != 0:
		return ""
	
	for output_chunk in output:
		var lines = output_chunk.split("\n")
		for line in lines:
			if line.begins_with("User:"):
				var parts = line.split(":")
				if parts.size() >= 2:
					return parts[1].strip_edges()
	
	return ""

func _depot_to_local_path(depot_path: String) -> String:
	# Remove version info (e.g., #1, #2, etc.)
	var clean_path = depot_path
	var hash_pos = clean_path.rfind("#")
	if hash_pos != -1:
		clean_path = clean_path.substr(0, hash_pos)
	
	# Query P4 to get the local path
	var output = []
	var exit_code = OS.execute("p4", ["where", clean_path], output, true)
	
	if exit_code == 0 and output.size() > 0:
		var where_line = output[0]
		
		# P4 where output format: "depot_path client_path local_path"
		var parts = where_line.split(" ")
		
		if parts.size() >= 3:
			var local_path = parts[2].strip_edges()
			
			# Normalize paths to use forward slashes
			local_path = local_path.replace("\\", "/")
			var normalized_workspace = workspace_root.replace("\\", "/")
			
			# Convert to Godot resource path
			if local_path.begins_with(normalized_workspace):
				var relative_path = local_path.substr(normalized_workspace.length())
				if relative_path.begins_with("/"):
					relative_path = relative_path.substr(1)
				return "res://" + relative_path
	
	return ""

func convert_depot_paths_batch(depot_paths: Array) -> Dictionary:
	# Convert multiple depot paths at once to reduce P4 calls
	var result = {}
	
	if depot_paths.is_empty():
		return result
	
	# Clean depot paths (remove version info)
	var clean_paths = []
	for depot_path in depot_paths:
		var clean_path = depot_path
		var hash_pos = clean_path.rfind("#")
		if hash_pos != -1:
			clean_path = clean_path.substr(0, hash_pos)
		clean_paths.append(clean_path)
	
	# Build P4 where command with multiple paths
	var cmd_args = ["where"] + clean_paths
	var output = []
	var exit_code = OS.execute("p4", cmd_args, output, true)
	
	if exit_code == 0 and output.size() > 0:
		# Parse the output - each line corresponds to a depot path
		var output_text = ""
		for chunk in output:
			output_text += chunk
		
		var lines = output_text.split("\n")
		var line_index = 0
		
		for i in range(depot_paths.size()):
			if line_index < lines.size():
				var line = lines[line_index].strip_edges()
				line_index += 1
				
				if line != "":
					# Parse line format: "depot_path client_path local_path"
					var parts = line.split(" ")
					
					if parts.size() >= 3:
						var local_path = parts[2].strip_edges()
						
						# Normalize paths to use forward slashes
						local_path = local_path.replace("\\", "/")
						var normalized_workspace = workspace_root.replace("\\", "/")
						
						# Convert to Godot resource path
						if local_path.begins_with(normalized_workspace):
							var relative_path = local_path.substr(normalized_workspace.length())
							if relative_path.begins_with("/"):
								relative_path = relative_path.substr(1)
							result[depot_paths[i]] = "res://" + relative_path
	
	return result

func _ensure_godot_changelist():
	print("P4Client: Ensuring Godot changelist...")
	print("P4Client: Current godot_changelist_number: ", godot_changelist_number)
	
	# Check if our current changelist is still valid
	if godot_changelist_number != "" and _is_changelist_valid(godot_changelist_number):
		print("P4Client: Current changelist is still valid: ", godot_changelist_number)
		return
	
	# Check if we already have a Godot changelist
	var existing_changelist = _find_godot_changelist()
	if existing_changelist != "":
		print("P4Client: Found existing Godot changelist: ", existing_changelist)
		godot_changelist_number = existing_changelist
		return
	
	# Create a new changelist for Godot
	print("P4Client: Creating new Godot changelist...")
	godot_changelist_number = _create_changelist(GODOT_CHANGELIST_DESCRIPTION)
	print("P4Client: Created new changelist: ", godot_changelist_number)

func _find_godot_changelist() -> String:
	print("P4Client: Looking for existing Godot changelist...")
	# Look for existing changelist with our description
	var output = []
	var exit_code = -1
	
	var user = _get_p4_user()
	
	# Try with user filter if we have a username
	if user != "":
		exit_code = OS.execute("p4", ["-ztag", "-Mj", "changes", "-s", "pending", "-u", user], output, true)
		print("P4Client: _find_godot_changelist with user filter exit code: ", exit_code)
	
	# If user filter failed or no username, try without user filter
	if exit_code != 0:
		print("P4Client: _find_godot_changelist trying without user filter...")
		output.clear()
		exit_code = OS.execute("p4", ["-ztag", "-Mj", "changes", "-s", "pending"], output, true)
	
	print("P4Client: _find_godot_changelist exit code: ", exit_code)
	if exit_code == 0:
		print("P4Client: _find_godot_changelist output size: ", output.size())
		
		# Parse JSON Lines output
		var json_text = ""
		for chunk in output:
			json_text += chunk
		
		var lines = json_text.split("\n")
		var json = JSON.new()
		
		for line in lines:
			line = line.strip_edges()
			if line == "":
				continue
				
			print("P4Client: Checking JSON line: ", line)
			var parse_result = json.parse(line)
			
			if parse_result == OK:
				var change_data = json.data
				if change_data.has("change") and change_data.has("desc") and change_data.has("status"):
					if change_data["status"] == "pending":
						var description = change_data["desc"].strip_edges()
						if GODOT_CHANGELIST_DESCRIPTION in description:
							var cl_number = str(change_data["change"])
							print("P4Client: Found existing Godot changelist: ", cl_number)
							return cl_number
	else:
		print("P4Client: _find_godot_changelist failed with exit code: ", exit_code)
		if output.size() > 0:
			print("P4Client: Error output: ", output)
	
	print("P4Client: No existing Godot changelist found")
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
	
	var os_name := OS.get_name()
	var create_exit_code : int
	if os_name == "Windows":
		create_exit_code = OS.execute("cmd", ["/c", shell_command], create_output, true)
	elif os_name == "Linux":
		create_exit_code = OS.execute("bash", ["/c", shell_command], create_output, true)
	else:
		print("Your OS is not supported to run p4 change. If you would like to ")
	
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
