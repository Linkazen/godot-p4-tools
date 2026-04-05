@tool
extends Control

@onready var sync_button: Button = %SyncButton
@onready var refresh_button: Button = %RefreshButton
@onready var view_as_tree_button: Button = %ViewAsTreeButton
@onready var tree: Tree = %Tree
@onready var repository_label: RichTextLabel = %RichTextLabel
@onready var changelist_item_popup : PopupMenu = %ChangelistItemPopup

var perforce_client: PerforceClient
var is_tree_view: bool = false

func set_perforce_client(client: PerforceClient):
	perforce_client = client
	if is_inside_tree():
		_update_repository_info()
		_refresh_file_list()

func _ready():
	# Connect button signals
	sync_button.pressed.connect(_on_sync_pressed)
	refresh_button.pressed.connect(_on_refresh_pressed)
	view_as_tree_button.pressed.connect(_on_view_as_tree_pressed)
	
	# Setup tree
	tree.columns = 2
	tree.set_column_title(0, "File")
	tree.set_column_title(1, "Status")
	tree.set_column_titles_visible(true)
	tree.set_column_expand(0, true)
	tree.set_column_expand(1, false)
	tree.set_column_custom_minimum_width(1, 100)
	
	# Connect tree signals for lazy loading
	tree.item_selected.connect(_on_tree_item_selected)
	
	# perforce_client will be set by the plugin when instantiated
	
	# Update repository name and initial file list
	_update_repository_info()
	_refresh_file_list()

func _update_repository_info():
	if perforce_client:
		var client_name = perforce_client.get_client_name()
		if client_name != "":
			repository_label.text = client_name
		else:
			repository_label.text = "Not Connected"
	else:
		repository_label.text = "P4 Client: Not Available"

func _refresh_file_list():
	if not perforce_client:
		return
	
	# Clear existing items
	tree.clear()
	
	# Get all changelists
	var changelists = perforce_client.get_all_changelists()
	
	if changelists.is_empty():
		var root = tree.create_item()
		root.set_text(0, "No pending changelists")
		root.set_text(1, "")
		root.set_selectable(0, false)
		root.set_selectable(1, false)
		return
	
	# Create changelists directly as root items (no parent)
	_populate_changelist_view(null, changelists)

func _populate_changelist_view(parent: TreeItem, changelists: Array):
	# Get the root of the tree to ensure all CLs are at root level
	var root = tree.get_root()
	if not root:
		root = tree.create_item() # Create root if it doesn't exist
		root.set_text(0, "Pending Changelists")
		root.set_collapsed(false)
	
	for cl_data in changelists:
		var cl_number = cl_data["number"]
		var cl_description = cl_data["description"]
		
		# Create changelist item as direct child of root
		var cl_item = tree.create_item(root)
		cl_item.set_text(0, "CL " + cl_number + ": " + cl_description)
		cl_item.set_selectable(1, false)
		cl_item.set_collapsed(false) # Expand by default
		
		# Show placeholder for files (load on demand)
		cl_item.set_text(1, "Click to load files")
		cl_item.set_metadata(0, cl_number) # Store CL number for lazy loading
		
		# Add a placeholder child so the changelist shows as expandable
		var placeholder = tree.create_item(cl_item)
		placeholder.set_text(0, "Click parent to load files...")
		placeholder.set_selectable(0, false)
		placeholder.set_selectable(1, false)

func _populate_list_view(root: TreeItem, files: Array):
	print("P4Tab: Populating list view with ", files.size(), " files")
	for file_path in files:
		print("P4Tab: Processing file: ", file_path)
		var item = tree.create_item(root)
		
		# Display relative path from project root
		var display_path = file_path
		if file_path.begins_with("res://"):
			display_path = file_path.substr(6) # Remove "res://" prefix
		
		print("P4Tab: Display path: ", display_path)
		item.set_text(0, display_path)
		item.set_text(1, "Edit")
		item.set_metadata(0, file_path) # Store full path for operations
		
		# Set icon based on file type
		var icon = _get_file_icon(file_path)
		if icon:
			item.set_icon(0, icon)

func _populate_tree_view(root: TreeItem, files: Array):
	var folders = {}
		
	# Group files by directory
	for file_path in files:
		var display_path = file_path
		if file_path.begins_with("res://"):
			display_path = file_path.substr(6) # Remove "res://" prefix
		
		var parts = display_path.split("/")
		var current_dict = folders
		
		# Build folder structure
		for i in range(parts.size() - 1):
			var folder_name = parts[i]
			if not current_dict.has(folder_name):
				current_dict[folder_name] = {}
			current_dict = current_dict[folder_name]
		
		# Add file to final folder
		var filename = parts[-1]
		current_dict[filename] = file_path # Store full path for files
	
	# Create tree items recursively
	_create_tree_items(root, folders)

func _create_tree_items(parent: TreeItem, folder_dict: Dictionary):
	var sorted_keys = folder_dict.keys()
	sorted_keys.sort()
	
	for key in sorted_keys:
		var value = folder_dict[key]
		var item = tree.create_item(parent)
		
		if value is Dictionary:
			# This is a folder
			item.set_text(0, key + "/")
			item.set_text(1, "")
			item.set_selectable(1, false)
			
			# Set folder icon
			var folder_icon = _get_folder_icon()
			if folder_icon:
				item.set_icon(0, folder_icon)
			
			# Recursively create children
			_create_tree_items(item, value)
		else:
			# This is a file
			item.set_text(0, key)
			item.set_text(1, "Edit")
			item.set_metadata(0, value) # Store full path
			
			# Set file icon
			var icon = _get_file_icon(value)
			if icon:
				item.set_icon(0, icon)

func _get_file_icon(file_path: String) -> Texture2D:
	var extension = file_path.get_extension().to_lower()
	var editor_theme = EditorInterface.get_editor_theme()
	
	match extension:
		"gd":
			return editor_theme.get_icon("GDScript", "EditorIcons")
		"cs":
			return editor_theme.get_icon("CSharpScript", "EditorIcons")
		"tscn":
			return editor_theme.get_icon("PackedScene", "EditorIcons")
		"tres":
			return editor_theme.get_icon("Resource", "EditorIcons")
		"png", "jpg", "jpeg", "webp":
			return editor_theme.get_icon("Image", "EditorIcons")
		"mp3", "ogg", "wav":
			return editor_theme.get_icon("AudioStreamPlayer", "EditorIcons")
		"txt", "md":
			return editor_theme.get_icon("TextFile", "EditorIcons")
		_:
			return editor_theme.get_icon("File", "EditorIcons")

func _get_folder_icon() -> Texture2D:
	var editor_theme = EditorInterface.get_editor_theme()
	return editor_theme.get_icon("Folder", "EditorIcons")

func _on_sync_pressed():
	if not perforce_client:
		push_warning("Perforce client not available")
		return
	
	# Show dialog to confirm sync
	var dialog = AcceptDialog.new()
	dialog.title = "P4 Sync"
	dialog.dialog_text = "This will sync all files from the depot. Continue?"
	dialog.add_cancel_button("Cancel")
	get_viewport().add_child(dialog)
	dialog.popup_centered()
	
	# Connect to confirmed signal
	dialog.confirmed.connect(_perform_sync)
	dialog.confirmed.connect(func(): dialog.queue_free())
	dialog.canceled.connect(func(): dialog.queue_free())

func _perform_sync():
	if not perforce_client:
		return
	
	# TODO: Implement P4 sync functionality
	push_warning("P4 Sync not yet implemented")

func _on_refresh_pressed():
	_refresh_file_list()

func _on_view_as_tree_pressed():
	is_tree_view = not is_tree_view
	view_as_tree_button.text = "Expand All" if not is_tree_view else "Collapse All"
	_expand_collapse_all()

func _expand_collapse_all():
	var root = tree.get_root()
	if root:
		_expand_collapse_recursive(root, is_tree_view)

func _expand_collapse_recursive(item: TreeItem, expand: bool):
	if item.get_child_count() > 0:
		item.set_collapsed(not expand)
		var child = item.get_first_child()
		while child:
			_expand_collapse_recursive(child, expand)
			child = child.get_next()

func _on_tree_item_selected():
	var selected = tree.get_selected()
	if not selected:
		return
	
	var cl_number = selected.get_metadata(0)
	
	if cl_number and cl_number is String:
		# Check if this changelist has already been loaded
		var first_child = selected.get_first_child()
		if first_child and first_child.get_text(0).contains("Click parent to load"):
			# Load files for this changelist
			_load_changelist_files(selected, cl_number)

func _load_changelist_files(cl_item: TreeItem, cl_number: String):
	# Update placeholder to show loading
	var placeholder = cl_item.get_first_child()
	if placeholder:
		placeholder.set_text(0, "Loading files...")
	
	cl_item.set_text(1, "Loading...")
	
	# Start async loading
	_load_files_async(cl_item, cl_number)

func _load_files_async(cl_item: TreeItem, cl_number: String):
	# Update progress
	if cl_item:
		cl_item.set_text(1, "Getting file list...")
	
	# Get files in background (this is the slow part)
	var files = await _get_files_async(cl_number)
	
	# Update UI on main thread
	if cl_item and files.size() > 0:
		if cl_item:
			cl_item.set_text(1, "Building UI...")
		await get_tree().process_frame
		_populate_files_ui(cl_item, files)
	else:
		# Handle no files or error
		if cl_item:
			cl_item.set_text(1, "No files")

func _get_files_async(cl_number: String) -> Array:
	# This will run the P4 commands in chunks to avoid blocking
	return await _process_files_in_chunks(cl_number)

func _process_files_in_chunks(cl_number: String) -> Array:
	# Get the raw file list first (just depot paths and actions)
	var raw_files = await _get_raw_changelist_files(cl_number)
	
	if raw_files.is_empty():
		return []
	
	# Extract all depot paths for batch conversion
	var depot_paths = []
	for file_data in raw_files:
		depot_paths.append(file_data["depot_path"])
	
	# Yield before the batch conversion
	await get_tree().process_frame
	
	# Convert all depot paths to local paths in one P4 command
	var path_mapping = perforce_client.convert_depot_paths_batch(depot_paths)
	
	# Yield after the batch conversion
	await get_tree().process_frame
	
	# Build the final file list
	var processed_files = []
	for file_data in raw_files:
		var depot_path = file_data["depot_path"]
		var action = file_data["action"]
		
		if path_mapping.has(depot_path):
			var local_path = path_mapping[depot_path]
			processed_files.append({
				"path": local_path,
				"action": action
			})

	return processed_files

func _get_raw_changelist_files(cl_number: String) -> Array:
	# Yield first to make this truly async
	await get_tree().process_frame
	
	# This gets just the depot paths and actions without converting to local paths
	var output = []
	var exit_code = OS.execute("p4", ["-ztag", "-Mj", "describe", "-s", cl_number], output, true)
	
	# Yield after the P4 command
	await get_tree().process_frame
	
	var raw_files = []
	if exit_code == 0 and output.size() > 0:
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
				
				# Extract all depot files and actions
				var file_index = 0
				while data.has("depotFile" + str(file_index)):
					var depot_path = data["depotFile" + str(file_index)]
					var action = data.get("action" + str(file_index), "edit")
					
					raw_files.append({
						"depot_path": depot_path,
						"action": action
					})
					
					file_index += 1
	
	return raw_files

func _populate_files_ui(cl_item: TreeItem, files: Array):
	# Remove placeholder
	var placeholder := cl_item.get_first_child()
	if placeholder:
		placeholder.free()
	
	cl_item.set_text(1, str(files.size()) + " files")
	
	# Add files as children
	for file_data in files:
		var file_path = file_data["path"]
		var file_action = file_data["action"]
		
		var file_item = tree.create_item(cl_item)
		if not file_item:
			continue
		
		# Display relative path from project root
		var display_path = file_path
		if file_path.begins_with("res://"):
			display_path = file_path.substr(6) # Remove "res://" prefix
		
		file_item.set_text(0, display_path)
		file_item.set_text(1, file_action)
		file_item.set_metadata(0, file_path) # Store full path for operations
		
		# Set icon based on file type
		var icon = _get_file_icon(file_path)
		if icon:
			file_item.set_icon(0, icon)


# Allow external refresh calls
func refresh():
	_refresh_file_list()


func _on_tree_item_mouse_selected(mouse_position: Vector2, mouse_button_index: int) -> void:
	if mouse_button_index == MOUSE_BUTTON_RIGHT and tree.get_selected().get_parent() != tree.get_root():
		tree.get_selected()
		changelist_item_popup.popup(Rect2i(get_global_mouse_position(), Vector2i.ZERO))


## Handles changelist file popup
func _on_changelist_item_popup_id_pressed(id: int) -> void:
	match id:
		0: # Revert file (if unchanged)
			perforce_client.revert_file(tree.get_selected().get_metadata(0), true)
			refresh()
			pass
		1: # Revert file
			var scene_path : String = tree.get_selected().get_metadata(0)
			perforce_client.revert_file(scene_path, false)
			refresh()
			EditorInterface.reload_scene_from_path(scene_path)
			pass
		2: # Lock file
			print("P4Client: Lock file not implemented yet")
			pass
		3: # Unlock file
			print("P4Client: Unlock file not implemented yet")
			pass
		_:
			printerr("Invalid menu option")
			pass
